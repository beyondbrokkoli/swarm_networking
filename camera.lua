-- modules/camera.lua
local max, min, cos, sin = math.max, math.min, math.cos, math.sin

return function(MainCamera)
    local CameraModule = {}

    local function UpdateBasis()
        local cy, sy = cos(MainCamera.yaw), sin(MainCamera.yaw)
        local cp, sp = cos(MainCamera.pitch), sin(MainCamera.pitch)
        MainCamera.fwx, MainCamera.fwy, MainCamera.fwz = sy * cp, sp, cy * cp
        MainCamera.rtx, MainCamera.rty, MainCamera.rtz = cy, 0, -sy
        MainCamera.upx = MainCamera.fwy * MainCamera.rtz
        MainCamera.upy = MainCamera.fwz * MainCamera.rtx - MainCamera.fwx * MainCamera.rtz
        MainCamera.upz = -MainCamera.fwy * MainCamera.rtx
    end

    --function CameraModule.Init()
        --MainCamera.x, MainCamera.y, MainCamera.z = 0, 0, -10000
        --MainCamera.yaw, MainCamera.pitch = 0, 0.3
        --UpdateBasis()
    --end
    function CameraModule.Init()
        -- [THE CINEMATIC SPAWN]
        -- Placed offset from the Sun vector to reveal perfect Lambertian shadows
        MainCamera.x, MainCamera.y, MainCamera.z = -12000, 3000, 12000

        -- Yaw 2.35 radians mathematically points the lens straight back at (0, 3000, 0)
        MainCamera.yaw, MainCamera.pitch = 2.35, 0.0

        UpdateBasis()
    end
    -- Expose the basis update for the benchmark script
    function CameraModule.UpdateVectors()
        UpdateBasis()
    end
    function CameraModule.Tick(dt)
        local s = 20000 * dt
        if love.keyboard.isDown("w") then MainCamera.x, MainCamera.y, MainCamera.z = MainCamera.x + MainCamera.fwx * s, MainCamera.y + MainCamera.fwy * s, MainCamera.z + MainCamera.fwz * s end
        if love.keyboard.isDown("s") then MainCamera.x, MainCamera.y, MainCamera.z = MainCamera.x - MainCamera.fwx * s, MainCamera.y - MainCamera.fwy * s, MainCamera.z - MainCamera.fwz * s end
        if love.keyboard.isDown("a") then MainCamera.x, MainCamera.z = MainCamera.x - MainCamera.rtx * s, MainCamera.z - MainCamera.rtz * s end
        if love.keyboard.isDown("d") then MainCamera.x, MainCamera.z = MainCamera.x + MainCamera.rtx * s, MainCamera.z + MainCamera.rtz * s end
        if love.keyboard.isDown("e") then MainCamera.y = MainCamera.y - s end
        if love.keyboard.isDown("q") then MainCamera.y = MainCamera.y + s end
        local rotSpeed = 2.5 * dt
        if love.keyboard.isDown("left") then MainCamera.yaw = MainCamera.yaw - rotSpeed end
        if love.keyboard.isDown("right") then MainCamera.yaw = MainCamera.yaw + rotSpeed end
        if love.keyboard.isDown("up") then MainCamera.pitch = MainCamera.pitch - rotSpeed end
        if love.keyboard.isDown("down") then MainCamera.pitch = MainCamera.pitch + rotSpeed end

        MainCamera.pitch = math.max(-1.56, math.min(1.56, MainCamera.pitch))
        UpdateBasis()
    end

    function CameraModule.MouseMoved(x, y, dx, dy)
        if love.mouse.getRelativeMode() then
            MainCamera.yaw = MainCamera.yaw + (dx * 0.002)
            MainCamera.pitch = MainCamera.pitch + (dy * 0.002)
            MainCamera.pitch = max(-1.56, min(1.56, MainCamera.pitch))
            UpdateBasis()
        end
    end

    return CameraModule
end
