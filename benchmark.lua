-- benchmark.lua
local Benchmark = {}

-- Toggle this to false to return to free-roam mode!
Benchmark.active = true

Benchmark.time = 0
Benchmark.frames = 0
Benchmark.fps_accum = 0
Benchmark.measurements = 0

-- We now pass CameraData (the C struct) AND CamLogic (the Lua module)
function Benchmark.Tick(dt, CameraData, CamLogic, Swarm)
    if not Benchmark.active then return end

    Benchmark.time = Benchmark.time + dt
    local t = Benchmark.time

    -- 1. WARMUP
    if t < 2.0 then
        CameraData.x, CameraData.y, CameraData.z = 0, 0, -10000
        CameraData.yaw, CameraData.pitch = 0, 0
    end

    -- 2. TRIGGER THE BUNDLE
    if t >= 2.0 and t < 2.05 then
        Swarm.ForceState(1)
    end

    -- 3. THE FLIGHT PATH
    if t >= 2.0 then
        local angle = t * 0.5

        local radius = 10000
        if t > 4.0 and t < 18.0 then -- Extended dive window to match your 20s run!
            -- Creates a smooth, slow dive curve over 14 seconds
            local dive = math.sin((t - 4.0) * (math.pi / 14.0))
            radius = 10000 - (dive * 7500)
        end

        local target_y = 5000 -- The exact height the C-engine spawns the Bundle!

        -- WRITE TO THE C STRUCT!
        CameraData.x = math.cos(angle) * radius
        CameraData.z = math.sin(angle) * radius
        CameraData.y = target_y + math.sin(t) * 3000 -- Bob up and down around the sphere

        CameraData.yaw = -angle - (math.pi / 2)
        -- Pitch based on the relative distance to the target!
        CameraData.pitch = -math.atan2(CameraData.y - target_y, radius)

        -- EXECUTE THE LUA LOGIC!
        CamLogic.UpdateVectors()
    end

    -- 4. MEASURE FPS (Measure the whole flight!)
    if t >= 4.0 and t <= 60.0 then
        Benchmark.frames = Benchmark.frames + 1
        Benchmark.fps_accum = Benchmark.fps_accum + (1.0 / dt)
        Benchmark.measurements = Benchmark.measurements + 1
    end

    -- 5. REPORT AND QUIT
    if t > 60.0 then
        local avg_fps = Benchmark.fps_accum / Benchmark.measurements
        print("\n===========================================")
        print(string.format("[BENCHMARK] Quad Core Average FPS: %.2f", avg_fps))
        print("===========================================\n")
        love.event.quit()
    end
end
return Benchmark
