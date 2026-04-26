function love.conf(t)
    t.identity = "UltimaPlatin" -- The save directory name
    t.window.title = "Ultima Platin v3.0"
    t.window.width = 0          -- 0 means auto-fill desktop
    t.window.height = 0
    t.window.fullscreen = true
    t.window.fullscreentype = "desktop"
    t.window.highdpi = true     -- THIS is the magic flag!
    t.window.vsync = 1
end
