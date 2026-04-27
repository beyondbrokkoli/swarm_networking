local ffi = require("ffi")

-- FLOAT PUNNING HELPER: Safely converts a float to a uint32_t
local function f32_to_u32(f)
    return ffi.cast("uint32_t*", ffi.new("float[1]", f))[0]
end

-- We pass VibeMath (the C lib) and MainCamera as arguments
return function(VibeMath, MainCamera)
    local TextModule = {}
    local TextCaches = {}

    function TextModule.Bake(id, str)
        local font = love.graphics.getFont()
        local tw, th = font:getWidth(str) + 4, font:getHeight() + 4
        
        local canvas = love.graphics.newCanvas(tw, th)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0,0,0,0)
        love.graphics.setColor(1,1,1,1)
        love.graphics.print(str, 2, 2)
        love.graphics.setCanvas()
        
        local imgData = canvas:newImageData()
        -- [SAFE] Write to the C-Global Array
        VibeMath.g_TextPointers[id] = ffi.cast("uint32_t*", imgData:getPointer())
        
        TextCaches[id] = {
            w = tw, h = th, imgData = imgData,
            active = false, x = 0, y = 0, z = 0
        }
        canvas:release()
    end

    function TextModule.SetState(id, active, x, y, z)
        local c = TextCaches[id]
        if c then
            c.active = active
            if x then c.x, c.y, c.z = x, y, z end
        end
    end

    function TextModule.QueueRaster(CANVAS_W, CANVAS_H, q, q_len)
        local cam = MainCamera
        local HW, HH = CANVAS_W * 0.5, CANVAS_H * 0.5

        for id, cache in pairs(TextCaches) do
            if cache.active then
                local vdx, vdy, vdz = cache.x - cam.x, cache.y - cam.y, cache.z - cam.z
                local depth = vdx*cam.fwx + vdy*cam.fwy + vdz*cam.fwz
                
                if depth > 10 then
                    local f = cam.fov / depth
                    local cx = math.floor(HW + (vdx*cam.rtx + vdz*cam.rtz) * f + 0.5)
                    local cy = math.floor(HH + (vdx*cam.upx + vdy*cam.upy + vdz*cam.upz) * f + 0.5)

                    -- INJECT CMD_STAMP_TEXT (15)
                    q[q_len] = 15;                       q_len = q_len + 1
                    q[q_len] = id;                       q_len = q_len + 1
                    q[q_len] = cache.w;                  q_len = q_len + 1
                    q[q_len] = cache.h;                  q_len = q_len + 1
                    q[q_len] = math.floor(cx - cache.w*0.5); q_len = q_len + 1
                    q[q_len] = math.floor(cy - cache.h*0.5); q_len = q_len + 1
                    q[q_len] = f32_to_u32(depth - 5);    q_len = q_len + 1
                    q[q_len] = f32_to_u32(1.0);          q_len = q_len + 1
                    q[q_len] = f32_to_u32(1.0);          q_len = q_len + 1
                end
            end
        end
        return q_len
    end

    return TextModule
end
