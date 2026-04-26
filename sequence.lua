local Sequence = {
    Loaded = {}, -- [NEW] Track loaded modules by their filepath
    Phases = {
        Init = {},
        Tick = {},
        KeyPressed = {},
        MouseMoved = {},
        Raster = {} -- (Removed Cull as discussed)
    }
}

function Sequence.LoadModule(filepath, ...)
    package.loaded[filepath] = nil
    local success, result = pcall(require, filepath)

    if not success then
        print("[FATAL] Module Error: " .. filepath .. "\n" .. tostring(result))
        return nil
    end

    local mod
    if type(result) == "function" then
        mod = result(...)
    else
        mod = result
    end

    Sequence.Loaded[filepath] = mod -- [NEW] Register it

    if type(mod.Init) == "function" then table.insert(Sequence.Phases.Init, mod.Init) end
    if type(mod.Tick) == "function" then table.insert(Sequence.Phases.Tick, mod.Tick) end
    if type(mod.KeyPressed) == "function" then table.insert(Sequence.Phases.KeyPressed, mod.KeyPressed) end
    if type(mod.MouseMoved) == "function" then table.insert(Sequence.Phases.MouseMoved, mod.MouseMoved) end
    if type(mod.Raster) == "function" then table.insert(Sequence.Phases.Raster, mod.Raster) end

    print("[SEQUENCE] Loaded Module: " .. filepath)
    return mod -- [NEW] Return the instantiated module
end

-- [NEW] The Sharp Cut mechanism
function Sequence.UnloadModule(filepath)
    local mod = Sequence.Loaded[filepath]
    if not mod then return false end

    -- Loop through all phases and surgically remove this module's functions
    for phase_name, phase_list in pairs(Sequence.Phases) do
        -- Iterate backwards when removing from a table to avoid shifting index bugs
        for i = #phase_list, 1, -1 do
            if phase_list[i] == mod[phase_name] then
                table.remove(phase_list, i)
            end
        end
    end
    
    Sequence.Loaded[filepath] = nil
    print("[SEQUENCE] Unloaded Module: " .. filepath)
    return true
end

function Sequence.RunPhase(phase_name, ...)
    local phase = Sequence.Phases[phase_name]
    for i = 1, #phase do
        phase[i](...)
    end
end

return Sequence
