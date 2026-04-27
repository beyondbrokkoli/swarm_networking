local ffi = require("ffi")
local bit = require("bit")
local VibeMath = require("load")
local Memory = require("memory")
local Sequence = require("sequence")
local Benchmark = require("benchmark")
    require("text")
-- [NEW] Declare the module references here
local SwarmModule
local CameraModule
local CANVAS_W, CANVAS_H
local ScreenBuffer, ScreenImage, ScreenPtr
-- i think we have to make some of the things global now?
ZBuffer
local read_buffer = 0
local write_buffer = 1
local global_time = 0
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
    SWARM_SORT_DEPTH = 14
}
local pendingResize = false
local resizeTimer = 0.0
-- [NEW VARIABLES FOR FIXED TIMESTEP]
local TICK_RATE = 1.0 / 60.0 -- Exactly 60 Hz logical ticks
local accumulator = 0.0
local function ReinitBuffers()
    CANVAS_W, CANVAS_H = love.graphics.getPixelDimensions()
    
    -- Recalculate FOV based on new aspect ratio
    MainCamera.fov = (CANVAS_W / 800) * 600

    -- Reallocate the massive RAM chunks
    ScreenBuffer = love.image.newImageData(CANVAS_W, CANVAS_H)
    ScreenImage = love.graphics.newImage(ScreenBuffer)
    ScreenPtr = ffi.cast("uint32_t*", ScreenBuffer:getPointer())
    ZBuffer = ffi.new("float[?]", CANVAS_W * CANVAS_H)

    -- Force Lua's Garbage Collector to instantly delete the old buffers
    collectgarbage() 
    print("[SYSTEM] Buffers Reinitialized: " .. CANVAS_W .. "x" .. CANVAS_H)
end
function love.load()
    CANVAS_W, CANVAS_H = love.graphics.getPixelDimensions()
    MainCamera.fov = (CANVAS_W / 800) * 600

    ScreenBuffer = love.image.newImageData(CANVAS_W, CANVAS_H)
    ScreenImage = love.graphics.newImage(ScreenBuffer)
    ScreenPtr = ffi.cast("uint32_t*", ScreenBuffer:getPointer())
    ZBuffer = ffi.new("float[?]", CANVAS_W * CANVAS_H)

    Sequence.LoadModule("camera", MainCamera)
    Sequence.LoadModule("swarm")
    -- [NEW] Cache the reference exactly once after loading!
    SwarmModule = Sequence.Loaded["swarm"]
    CameraModule = Sequence.Loaded["camera"]
    Sequence.RunPhase("Init")
    -- Ignite the Permanent Quad-Core Engine!
    VibeMath.vmath_init_thread_pool()
    TextModule.Bake(1, "WAITING FOR PEER...")
    TextModule.Bake(2, "CONNECTION ESTABLISHED")
    TextModule.Bake(3, "SWARM CORE")
    TextModule.SetState(3, true, 0, 5000, 0) -- Turns on "SWARM CORE" at X, Y, Z
    collectgarbage()
end

function love.update(dt)
    -- Cap maximum frame-skip so a giant lag spike doesn't spiral out of control
    if dt > 0.1 then dt = 0.1 end 

    if pendingResize then
        resizeTimer = resizeTimer - dt
        if resizeTimer <= 0 then ReinitBuffers(); pendingResize = false end
        return 
    end

    Net.Tick()

    -- [THE ACCUMULATOR]
    -- We pour the real-world time into the bucket
    accumulator = accumulator + dt

    -- We drain the bucket in exact, identical chunks
    while accumulator >= TICK_RATE do
        global_time = global_time + TICK_RATE
        
        -- IMPORTANT: Notice we pass TICK_RATE, not dt!
        -- The C-Engine will always, mathematically, receive 0.0166666666...
        Sequence.RunPhase("Tick", TICK_RATE)
        
        accumulator = accumulator - TICK_RATE
    end
end

function love.draw()
    if pendingResize then
        love.graphics.clear(0.05, 0.05, 0.05)
        love.graphics.print("REBUILDING SWAPCHAIN...", 20, 20)
        return
    end
    local q = Memory.Arrays.CommandQueue
    local q_len = 0
    local mem = Memory.RenderStruct

    -- 1. CLEAR BUFFERS
    q[q_len] = CMD.CLEAR; q_len = q_len + 1

    -- 2. BASE PHYSICS (Always runs)
    q[q_len] = CMD.SWARM_APPLY_BASE_PHYSICS; q_len = q_len + 1

    -- 3. CONDITIONAL EXPLOSIONS (The Logic lives in Lua!)
    if love.mouse.isDown(1) then
        q[q_len] = CMD.SWARM_EXPLOSION_PUSH; q_len = q_len + 1
    end
    if love.mouse.isDown(2) then
        q[q_len] = CMD.SWARM_EXPLOSION_PULL; q_len = q_len + 1
    end

    -- 4. TARGET SHAPE KERNEL (Only queue the one we need)
    local state = mem.Swarm_State
    if state == 1 then q[q_len] = CMD.SWARM_BUNDLE; q_len = q_len + 1
    elseif state == 2 then q[q_len] = CMD.SWARM_GALAXY; q_len = q_len + 1
    elseif state == 3 then q[q_len] = CMD.SWARM_TORNADO; q_len = q_len + 1
    elseif state == 4 then q[q_len] = CMD.SWARM_GYROSCOPE; q_len = q_len + 1
    elseif state == 5 then q[q_len] = CMD.SWARM_METAL; q_len = q_len + 1
    elseif state == 6 then q[q_len] = CMD.SWARM_PARADOX; q_len = q_len + 1
    end
    -- 5. SORT FRONT-TO-BACK
    q[q_len] = CMD.SWARM_SORT_DEPTH; q_len = q_len + 1
    -- 6. GENERATE GEOMETRY
    q[q_len] = CMD.SWARM_GEN_QUADS; q_len = q_len + 1

    -- 7. RENDER THE SWARM
    q[q_len] = CMD.RENDER_CULL; q_len = q_len + 1
    q[q_len] = 0;               q_len = q_len + 1 -- Pass ID 0 as argument
    -- 8. RENDER THE TEXT
    q_len = TextModule.QueueRaster(CANVAS_W, CANVAS_H, q, q_len)
    -- Ping-Pong the buffers!
    read_buffer, write_buffer = write_buffer, read_buffer

    VibeMath.vmath_execute_queue(
        q, q_len,
        MainCamera, mem,
        ScreenPtr, ZBuffer, CANVAS_W, CANVAS_H,
        global_time, love.timer.getDelta(), read_buffer, write_buffer
    )


    ScreenImage:replacePixels(ScreenBuffer)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("replace")
    love.graphics.draw(ScreenImage, 0, 0)

    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
end

function love.keypressed(key)
    if key == "escape" then
        if love.mouse.getRelativeMode() then love.mouse.setRelativeMode(false) else love.event.quit() end
    end
    if key == "tab" then love.mouse.setRelativeMode(not love.mouse.getRelativeMode()) end
    Sequence.RunPhase("KeyPressed", key)
end
function love.mousemoved(x, y, dx, dy) Sequence.RunPhase("MouseMoved", x, y, dx, dy) end
function love.mousepressed(x, y, button) if not love.mouse.getRelativeMode() then love.mouse.setRelativeMode(true) end end
function love.quit()
    print("[SYSTEM] Initiating Graceful Dual-Core Shutdown...")
    VibeMath.vmath_shutdown_thread_pool()
    print("[SYSTEM] Threads terminated. Goodbye.")
    return false -- Tells Love2D to proceed with the normal closing process
end
function love.resize(w, h)
    pendingResize = true
    resizeTimer = 1
end
