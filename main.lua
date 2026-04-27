local ffi = require("ffi")
local bit = require("bit")
local VibeMath = require("load")
local Memory = require("memory")
local Sequence = require("sequence")
local Benchmark = require("benchmark")

-- [ THE GLOBALS ]
-- Keep these global because the C-Engine needs to see these specific pointers
CANVAS_W, CANVAS_H = 0, 0
HALF_W, HALF_H = 0, 0
ZBuffer = nil

-- [ THE LOCALS ]
-- These belong to main.lua's state only
local Net = nil
local TextModule = nil
local SwarmModule, CameraModule
local ScreenBuffer, ScreenImage, ScreenPtr
local read_buffer, write_buffer = 0, 1
local global_time = 0
local pendingResize = false
local resizeTimer = 0.0

-- [ THE TICK METRONOME ]
local TICK_RATE = 1.0 / 60.0
local accumulator = 0.0

local CMD = {
    CLEAR = 1,
    SWARM_APPLY_BASE_PHYSICS = 2,
    SWARM_BUNDLE = 3,
    SWARM_GALAXY = 4,
    SWARM_TORNADO = 5,
    SWARM_GYROSCOPE = 6,
    SWARM_METAL = 7,
    SWARM_PARADOX = 8,
    SWARM_GEN_QUADS = 9,
    SPHERE_TICK = 10,
    RENDER_CULL = 11,
    SWARM_EXPLOSION_PUSH = 12,
    SWARM_EXPLOSION_PULL = 13,
    SWARM_SORT_DEPTH = 14,
    STAMP_TEXT = 15 -- [NEW] Match your vibemath.c case 15
}

local function ReinitBuffers()
    CANVAS_W, CANVAS_H = love.graphics.getPixelDimensions()
    HALF_W, HALF_H = CANVAS_W * 0.5, CANVAS_H * 0.5

    -- Recalculate FOV based on new aspect ratio
    MainCamera.fov = (CANVAS_W / 800) * 600

    -- Reallocate the massive RAM chunks
    ScreenBuffer = love.image.newImageData(CANVAS_W, CANVAS_H)
    ScreenImage = love.graphics.newImage(ScreenBuffer)
    ScreenPtr = ffi.cast("uint32_t*", ScreenBuffer:getPointer())
    ZBuffer = ffi.new("float[?]", CANVAS_W * CANVAS_H)

    collectgarbage()
    print("[SYSTEM] Buffers Reinitialized: " .. CANVAS_W .. "x" .. CANVAS_H)
end

function love.load(arg)
    -- 1. Infrastructure
    ReinitBuffers()
    VibeMath.vmath_init_thread_pool()

    -- 2. Load Modules into Sequence Registry
    Sequence.LoadModule("camera", MainCamera)
    Sequence.LoadModule("swarm")
    Sequence.LoadModule("text", MainCamera)
    Sequence.LoadModule("network")

    -- 3. Extract References
    SwarmModule  = Sequence.Loaded["swarm"]
    CameraModule = Sequence.Loaded["camera"]
    TextModule   = Sequence.Loaded["text"]
    local NetFactory = Sequence.Loaded["network"]

    -- 4. THE FACTORY SEPARATION
    -- We figure out who we are...
    local is_client = false
    for _, v in ipairs(arg) do if v == "--client" then is_client = true end end

    -- ...and we hire the correct specialist (Server or Client)
    -- This Init call returns a NEW table (net_server or net_client)
    Net = NetFactory.Init(not is_client)
    
    -- Now Net is a dedicated object. We call its internal Init to open the port.
    Net.Init()

    -- 5. Final Setup
    TextModule.Bake(1, "WAITING FOR PEER...")
    TextModule.Bake(2, "CONNECTION ESTABLISHED")
    TextModule.Bake(3, "SWARM CORE")

    Sequence.RunPhase("Init")
end

function love.update(dt)
    dt = math.min(dt, 0.1) -- "Lag Spike" safety valve

    if pendingResize then
        resizeTimer = resizeTimer - dt
        if resizeTimer <= 0 then ReinitBuffers(); pendingResize = false end
        return
    end

    -- A. Process Network Inbox immediately
    Net.Tick()

    -- B. Handle HUD Transitions
    if Net.Connected then
        TextModule.SetState(1, false)
        TextModule.SetState(2, true, 0, 8000, 0)
    else
        TextModule.SetState(1, true, 0, 8000, 0)
        TextModule.SetState(2, false)
    end
    TextModule.SetState(3, true, 0, 5000, 0)

    -- C. THE METRONOME (Logical Heartbeat)
    accumulator = accumulator + dt
    while accumulator >= TICK_RATE do
        global_time = global_time + TICK_RATE

        -- LOCKSTEP RULE: We only run the physics logic in 16.6ms chunks.
        -- This is what prevents Age of Empires style desyncs.
        Sequence.RunPhase("Tick", TICK_RATE)

        accumulator = accumulator - TICK_RATE
    end
end
function love.draw()
    if pendingResize then
        love.graphics.clear(0.05, 0.05, 0.05)
        return
    end

    local q = Memory.Arrays.CommandQueue
    local q_len = 0
    local mem = Memory.RenderStruct

    -- [ COMMAND QUEUE BUILDING ]
    q[q_len] = CMD.CLEAR; q_len = q_len + 1
    q[q_len] = CMD.SWARM_APPLY_BASE_PHYSICS; q_len = q_len + 1

    -- Inject Mouse interaction
    if love.mouse.isDown(1) then q[q_len] = CMD.SWARM_EXPLOSION_PUSH; q_len = q_len + 1 end
    if love.mouse.isDown(2) then q[q_len] = CMD.SWARM_EXPLOSION_PULL; q_len = q_len + 1 end

    -- Inject Network commands from the inbox
    for _, incoming_cmd in ipairs(Net.CommandInbox) do
        q[q_len] = incoming_cmd; q_len = q_len + 1
    end

    -- Swarm state & rendering
    local state = mem.Swarm_State
    if state == 1 then q[q_len] = CMD.SWARM_BUNDLE; q_len = q_len + 1
    elseif state == 2 then q[q_len] = CMD.SWARM_GALAXY; q_len = q_len + 1
    elseif state == 3 then q[q_len] = CMD.SWARM_TORNADO; q_len = q_len + 1
    elseif state == 4 then q[q_len] = CMD.SWARM_GYROSCOPE; q_len = q_len + 1
    elseif state == 5 then q[q_len] = CMD.SWARM_METAL; q_len = q_len + 1
    elseif state == 6 then q[q_len] = CMD.SWARM_PARADOX; q_len = q_len + 1
    end

    q[q_len] = CMD.SWARM_SORT_DEPTH; q_len = q_len + 1
    q[q_len] = CMD.SWARM_GEN_QUADS; q_len = q_len + 1
    
    q[q_len] = CMD.RENDER_CULL; q_len = q_len + 1
    q[q_len] = 0;               q_len = q_len + 1 

    -- [ THE TEXT STAMP INJECTION ]
    -- This calculates the 3D anchors and puts CMD.STAMP_TEXT in the queue
    q_len = TextModule.QueueRaster(CANVAS_W, CANVAS_H, q, q_len)

    -- [ EXECUTE ]
    read_buffer, write_buffer = write_buffer, read_buffer

    VibeMath.vmath_execute_queue(
        q, q_len,
        MainCamera, mem,
        ScreenPtr, ZBuffer, CANVAS_W, CANVAS_H,
        global_time, love.timer.getDelta(), read_buffer, write_buffer
    )

    -- [ BLIT TO SCREEN ]
    ScreenImage:replacePixels(ScreenBuffer)
    love.graphics.setBlendMode("replace")
    love.graphics.draw(ScreenImage, 0, 0)
    -- FPS Counter
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS() .. " | Net: " .. (Net.Connected and "OK" or "WAIT"), 10, 10)
    love.graphics.setColor(1, 1, 1, 1)
end

function love.keypressed(key)
    if key == "escape" then
        if love.mouse.getRelativeMode() then love.mouse.setRelativeMode(false) else love.event.quit() end
    end
    if key == "tab" then love.mouse.setRelativeMode(not love.mouse.getRelativeMode()) end
    
    -- Network Ping Test
    if key == "t" then Net.SendCmd(CMD.SWARM_TORNADO) end

    Sequence.RunPhase("KeyPressed", key)
end

function love.mousemoved(x, y, dx, dy) Sequence.RunPhase("MouseMoved", x, y, dx, dy) end
function love.mousepressed(x, y, button) if not love.mouse.getRelativeMode() then love.mouse.setRelativeMode(true) end end

function love.quit()
    VibeMath.vmath_shutdown_thread_pool()
end

function love.resize(w, h)
    pendingResize = true
    resizeTimer = 0.5
end
