local ffi = require("ffi")
local VibeMath = require("load")
-- FLOAT PUNNING HELPER: Safely converts a float to a uint32_t so it fits in our C Queue
local function f32_to_u32(f)
    return ffi.cast("uint32_t*", ffi.new("float[1]", f))[0]
end

return function(MainCamera)
    local TextModule = {}
    
    local TextCaches = {}

    -- 1. BAKE THE TEXT (Call this once during love.load)
    function TextModule.Bake(id, str)
        local font = love.graphics.getFont()
        local tw = font:getWidth(str) + 4
        local th = font:getHeight() + 4
        
        -- Create the invisible Canvas
        local canvas = love.graphics.newCanvas(tw, th)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(str, 2, 2)
        love.graphics.setCanvas()
        
        -- Extract the raw pixels
        local imgData = canvas:newImageData()
        local ptr = ffi.cast("uint32_t*", imgData:getPointer())
        
        -- PASS THE 64-BIT POINTER TO THE C ENGINE!
        VibeMath.g_TextPointers[id] = ptr
        
        -- Save the metadata in Lua
        TextCaches[id] = {
            w = tw, h = th, 
            imgData = imgData, -- Crucial: Keeps the memory alive from Lua's Garbage Collector
            active = false,
            x = 0, y = 0, z = 0
        }
    end

    -- 2. UPDATE STATE (Call this to move text or turn it on/off)
    function TextModule.SetState(id, active, x, y, z)
        if TextCaches[id] then
            TextCaches[id].active = active
            if x then TextCaches[id].x = x end
            if y then TextCaches[id].y = y end
            if z then TextCaches[id].z = z end
        end
    end

    -- 3. THE QUEUE INJECTOR (Call this right before vmath_execute_queue)
    function TextModule.QueueRaster(CANVAS_W, CANVAS_H, q, q_len)
        local cam = MainCamera
        local HALF_W, HALF_H = CANVAS_W * 0.5, CANVAS_H * 0.5

        for id, cache in pairs(TextCaches) do
            if cache.active then
                -- Exactly the same 3D math as your C-kernel
                local vdx = cache.x - cam.x
                local vdy = cache.y - cam.y
                local vdz = cache.z - cam.z
                
                local depth = vdx*cam.fwx + vdy*cam.fwy + vdz*cam.fwz
                if depth < 10 then goto continue end

                local f = cam.fov / depth
                local cx = math.floor(HALF_W + (vdx*cam.rtx + vdz*cam.rtz) * f + 0.5)
                local cy = math.floor(HALF_H + (vdx*cam.upx + vdy*cam.upy + vdz*cam.upz) * f + 0.5)

                local startX = math.floor(cx - cache.w * 0.5)
                local startY = math.floor(cy - cache.h * 0.5)
                
                -- INJECT CMD_STAMP_TEXT (Opcode 15) INTO THE C-QUEUE
                q[q_len] = 15;                       q_len = q_len + 1
                q[q_len] = id;                       q_len = q_len + 1
                q[q_len] = cache.w;                  q_len = q_len + 1
                q[q_len] = cache.h;                  q_len = q_len + 1
                q[q_len] = startX;                   q_len = q_len + 1
                q[q_len] = startY;                   q_len = q_len + 1
                
                -- Float punning the float parameters
                q[q_len] = f32_to_u32(depth - 5);    q_len = q_len + 1 -- z_threshold
                q[q_len] = f32_to_u32(1.0);          q_len = q_len + 1 -- draw_scale
                q[q_len] = f32_to_u32(1.0);          q_len = q_len + 1 -- master_alpha

                ::continue::
            end
        end
        return q_len -- Return the updated queue length back to main!
    end
    
    return TextModule
end
