-- ========================================================================
-- load.lua
-- Cross-Platform FFI Library Loader (Handles unzipped & .love archives)
-- ========================================================================
local ffi = require("ffi")

local function load_vmath()
    -- 1. Determine OS extension
    local lib_name = "vibemath"
    if jit.os == "Windows" then
        lib_name = lib_name .. ".dll"
    elseif jit.os == "OSX" then
        lib_name = lib_name .. ".dylib"
    else
        lib_name = "lib" .. lib_name .. ".so"
    end

    -- 2. Try Development Path (Absolute path to your unzipped project folder)
    local base_dir = love.filesystem.getSource()
    local dev_path = base_dir .. "/" .. lib_name

    local success, lib = pcall(ffi.load, dev_path)
    if success then
        print("[SIMD] Booted native library from Dev Path: " .. dev_path)
        return lib
    end

    -- 3. Try Production Path (We are inside a .love zip archive)
    print("[SIMD] Dev path failed. Extracting library from .love archive...")
    local save_dir = love.filesystem.getSaveDirectory()
    local save_path = save_dir .. "/" .. lib_name

    -- Read the binary from the virtual filesystem (inside the zip)
    local file_data, size = love.filesystem.read(lib_name)
    if file_data then
        -- Write it to the real OS disk so the linker can actually see it
        love.filesystem.write(lib_name, file_data)

        success, lib = pcall(ffi.load, save_path)
        if success then
            print("[SIMD] Extracted and loaded library from Save Path: " .. save_path)
            return lib
        end
    end

    error("FATAL: Could not load SIMD library on " .. jit.os .. "\nAttempted: " .. dev_path .. "\nAttempted: " .. save_path)
end

return load_vmath()
