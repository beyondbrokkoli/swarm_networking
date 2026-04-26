-- ========================================================================
-- memory.lua
-- Pure SoA Motherboard. Dynamic Metaprogramming Allocator.
-- ========================================================================
local ffi = require("ffi")
local Memory = {
    Arrays = {}, -- <--- The new safe haven!
    Anchors = {} -- THE LIFESAVER: Prevents Lua GC from deleting our memory!
}
-- ==========================================
-- [1] THE UNIVERSE BOUNDARIES (Static Limits)
-- ==========================================
MAX_OBJS = 200000
MAX_VERTS = 1500000 -- Raised from 500k
MAX_TRIS = 2500000  -- Raised from 1 Million

MAX_BOUND_SPHERES = 512
MAX_BOUND_BOXES = 512

BOUND_CONTAIN = 1; BOUND_REPEL = 2; BOUND_SOLID = 3;

-- Global Counters (Used by Allocator below)
local next_obj_id = 0
local next_vert_id = 0
local next_tri_id = 0
local next_sphere_id = 0
local next_box_id = 0

-- ========================================================================
-- PRO-LEVEL CACHE-ALIGNED MEMORY ALLOCATOR (64-Byte Boundaries)
-- ========================================================================
local function AllocateSoA(type_str, count, names)
    -- 1. Extract the base C type (e.g., "float[?]" or "double[1]" -> "float" / "double")
    -- The pattern "%[.-%]" safely strips brackets and anything inside them!
    local base_type = string.gsub(type_str, "%[.-%]", "")
    local bytes_needed = ffi.sizeof(base_type) * count

    -- 2. Over-allocate by 64 bytes to guarantee room for shifting
    local alloc_size = bytes_needed + 64 

    for i = 1, #names do
        local name = names[i]
        
        -- 3. Allocate raw bytes
        local raw_bytes = ffi.new("uint8_t[?]", alloc_size)
        
        -- 4. ANCHOR IT! Prevents the Garbage Collector from vaporizing our memory
        Memory.Anchors[name] = raw_bytes 

        -- 5. Calculate the exact offset needed to hit a 64-byte boundary
        local ptr_num = tonumber(ffi.cast("uintptr_t", raw_bytes))
        local offset = (64 - (ptr_num % 64)) % 64

        -- 6. Shift the pointer and cast it to the actual type (e.g., float*)
        local aligned_ptr = ffi.cast(base_type .. "*", raw_bytes + offset)

        Memory.Arrays[name] = aligned_ptr
    end
end
-- ========================================================================
-- [3] THE SCHEMA (The Pure Data Arrays)
-- ========================================================================

-- 1. Object Spatial Data (Transforms, Velocities, and Basis Matrices)
AllocateSoA("float[?]", MAX_OBJS, {
    "Obj_Radius", "Obj_X", "Obj_Y", "Obj_Z",
    "Obj_VelX", "Obj_VelY", "Obj_VelZ",
    "Obj_Yaw", "Obj_Pitch", "Obj_RotSpeedYaw", "Obj_RotSpeedPitch",
    "Obj_FWX", "Obj_FWY", "Obj_FWZ",
    "Obj_RTX", "Obj_RTY", "Obj_RTZ",
    "Obj_UPX", "Obj_UPY", "Obj_UPZ"
})

-- 2. Object Geometry Linking
AllocateSoA("int[?]", MAX_OBJS, {
    "Obj_VertStart", "Obj_VertCount", "Obj_TriStart", "Obj_TriCount"
})

-- 3. The Visibility Buffer (Used by the Camera Cull phase to pass to Raster)
-- Note: Modules will clear and populate this buffer every frame.
AllocateSoA("double[?]", 1, {"Count_Visible"})
AllocateSoA("int[?]", MAX_OBJS, {"Visible_IDs"})

-- 4. Vertex Data (Local, Camera, and Projected Points)
AllocateSoA("float[?]", MAX_VERTS, {
    "Vert_LX", "Vert_LY", "Vert_LZ",
    "Vert_WX", "Vert_WY", "Vert_WZ", -- <<< ADD THESE THREE
    "Vert_CX", "Vert_CY", "Vert_CZ",
    "Vert_PX", "Vert_PY", "Vert_PZ"
})
AllocateSoA("bool[?]", MAX_VERTS, {"Vert_Valid"})

-- 5 Triangle Data (Faces, Colors, and Shading Channels)
AllocateSoA("int[?]", MAX_TRIS, {"Tri_V1", "Tri_V2", "Tri_V3"})
AllocateSoA("float[?]", MAX_TRIS, {"Tri_A", "Tri_R", "Tri_G", "Tri_B", "Tri_MinY", "Tri_MaxY"}) -- <--- ADDED HERE
AllocateSoA("uint32_t[?]", MAX_TRIS, {"Tri_Color", "Tri_BakedColor"})
AllocateSoA("float[?]", MAX_TRIS, {"Tri_LNX", "Tri_LNY", "Tri_LNZ"})
-- Output from C Assembly
AllocateSoA("bool[?]", MAX_TRIS, { "Tri_Valid" })
AllocateSoA("uint32_t[?]", MAX_TRIS, { "Tri_ShadedColor" })

-- 6. Physics Collision (Bounding Volumes)
AllocateSoA("float[?]", MAX_BOUND_SPHERES, {"BoundSphere_X", "BoundSphere_Y", "BoundSphere_Z", "BoundSphere_RSq"})
AllocateSoA("uint8_t[?]", MAX_BOUND_SPHERES, {"BoundSphere_Mode"})

AllocateSoA("float[?]", MAX_BOUND_BOXES, {
    "BoundBox_X", "BoundBox_Y", "BoundBox_Z",
    "BoundBox_HW", "BoundBox_HH", "BoundBox_HT",
    "BoundBox_FWX", "BoundBox_FWY", "BoundBox_FWZ",
    "BoundBox_RTX", "BoundBox_RTY", "BoundBox_RTZ",
    "BoundBox_UPX", "BoundBox_UPY", "BoundBox_UPZ"
})
AllocateSoA("uint8_t[?]", MAX_BOUND_BOXES, {"BoundBox_Mode"})

-- 7. The Command Queue (For C-Backend Dispatch)
AllocateSoA("int[?]", 64, {"CommandQueue"})

-- 8. The Dual-Core Swarm Arrays (Safely anchored in Memory.Arrays!)
AllocateSoA("float[?]", MAX_OBJS, {
    "Swarm_PX_0", "Swarm_PX_1", "Swarm_PY_0", "Swarm_PY_1", "Swarm_PZ_0", "Swarm_PZ_1",
    "Swarm_VX_0", "Swarm_VX_1", "Swarm_VY_0", "Swarm_VY_1", "Swarm_VZ_0", "Swarm_VZ_1",
    "Swarm_Seed", "Swarm_Distances", "Swarm_TempDistances"
})
AllocateSoA("int[?]", MAX_OBJS, {
    "Swarm_Indices_0", "Swarm_Indices_1", "Swarm_TempIndices"
})


-- ==========================================
-- [4] GLOBAL SINGLETONS & STRUCTS
-- ==========================================

ffi.cdef[[
    typedef struct {
        float minX, minY, minZ;
        float maxX, maxY, maxZ;
        bool isActive;
    } GlobalCage;

    typedef struct {
        float x, y, z;
        float yaw, pitch;
        float fov;
        float fwx, fwy, fwz;
        float rtx, rty, rtz;
        float upx, upy, upz;
    } CameraState;

    typedef struct {
        float *Obj_X, *Obj_Y, *Obj_Z, *Obj_Radius;
        float *Obj_FWX, *Obj_FWY, *Obj_FWZ;
        float *Obj_RTX, *Obj_RTY, *Obj_RTZ;
        float *Obj_UPX, *Obj_UPY, *Obj_UPZ;
        int *Obj_VertStart, *Obj_VertCount;
        int *Obj_TriStart, *Obj_TriCount;

        float *Vert_LX, *Vert_LY, *Vert_LZ;
        float *Vert_PX, *Vert_PY, *Vert_PZ; bool *Vert_Valid;

        int *Tri_V1, *Tri_V2, *Tri_V3;
        uint32_t *Tri_BakedColor, *Tri_ShadedColor; bool *Tri_Valid;
        float *Tri_MinY, *Tri_MaxY;

        float *Tri_LNX, *Tri_LNY, *Tri_LNZ;

        float *Swarm_PX[2]; float *Swarm_PY[2]; float *Swarm_PZ[2];
        float *Swarm_VX[2]; float *Swarm_VY[2]; float *Swarm_VZ[2];
        int *Swarm_Indices[2];

        float *Swarm_Seed;
        int Swarm_State;
        float Swarm_GravityBlend;
        float Swarm_MetalBlend;
        float Swarm_ParadoxBlend;

        int *Swarm_TempIndices;
        float *Swarm_Distances;
        float *Swarm_TempDistances;
    } RenderMemory;

    // THE COMMAND QUEUE (Our one and only entry point)
    void vmath_execute_queue(
        int* queue, int command_count,
        CameraState* cam, RenderMemory* mem,
        uint32_t* ScreenPtr, float* ZBuffer,
        int CANVAS_W, int CANVAS_H,
        float time, float dt,
        int read_idx, int write_idx //
    );
    void vmath_init_thread_pool();
    void vmath_shutdown_thread_pool();
]]

UniverseCage = ffi.new("GlobalCage", {-15000, -4000, -15000, 15000, 15000, 15000, true})
MainCamera = ffi.new("CameraState") -- Officially part of the Motherboard now!

-- ========================================================================
-- [5] THE SLICE CHECKOUT SYSTEM (The Engine's Core Protection)
-- ========================================================================

function Memory.ClaimObjects(count)
    local start_id = next_obj_id
    next_obj_id = next_obj_id + count
    if next_obj_id > MAX_OBJS then error("FATAL: Out of Object Memory!") end
    return start_id, next_obj_id - 1
end

function Memory.ClaimGeometry(v_count, t_count)
    local v_start, t_start = next_vert_id, next_tri_id
    next_vert_id = next_vert_id + v_count
    next_tri_id = next_tri_id + t_count
    if next_vert_id > MAX_VERTS or next_tri_id > MAX_TRIS then error("FATAL: Out of Geometry Memory!") end
    return v_start, t_start
end

function Memory.ClaimBoundSpheres(count)
    local start_id = next_sphere_id
    next_sphere_id = next_sphere_id + count
    if next_sphere_id > MAX_BOUND_SPHERES then error("FATAL: Out of Bounding Sphere Memory!") end
    return start_id, next_sphere_id - 1
end

function Memory.ClaimBoundBoxes(count)
    local start_id = next_box_id
    next_box_id = next_box_id + count
    if next_box_id > MAX_BOUND_BOXES then error("FATAL: Out of Bounding Box Memory!") end
    return start_id, next_box_id - 1
end
function Memory.Reset()
    next_obj_id = 0
    next_vert_id = 0
    next_tri_id = 0
    next_sphere_id = 0
    next_box_id = 0
    print("[MEMORY] FFI Allocator Indices Reset to Zero.")
end

Memory.RenderStruct = ffi.new("RenderMemory")

-- ========================================================================
-- [5] THE DUAL-CORE STRUCT BINDING
-- ========================================================================
-- First, manually bind the Ping-Pong arrays into the C-Struct arrays
Memory.RenderStruct.Swarm_PX[0] = Memory.Arrays.Swarm_PX_0
Memory.RenderStruct.Swarm_PX[1] = Memory.Arrays.Swarm_PX_1
Memory.RenderStruct.Swarm_PY[0] = Memory.Arrays.Swarm_PY_0
Memory.RenderStruct.Swarm_PY[1] = Memory.Arrays.Swarm_PY_1
Memory.RenderStruct.Swarm_PZ[0] = Memory.Arrays.Swarm_PZ_0
Memory.RenderStruct.Swarm_PZ[1] = Memory.Arrays.Swarm_PZ_1

Memory.RenderStruct.Swarm_VX[0] = Memory.Arrays.Swarm_VX_0
Memory.RenderStruct.Swarm_VX[1] = Memory.Arrays.Swarm_VX_1
Memory.RenderStruct.Swarm_VY[0] = Memory.Arrays.Swarm_VY_0
Memory.RenderStruct.Swarm_VY[1] = Memory.Arrays.Swarm_VY_1
Memory.RenderStruct.Swarm_VZ[0] = Memory.Arrays.Swarm_VZ_0
Memory.RenderStruct.Swarm_VZ[1] = Memory.Arrays.Swarm_VZ_1

Memory.RenderStruct.Swarm_Indices[0] = Memory.Arrays.Swarm_Indices_0
Memory.RenderStruct.Swarm_Indices[1] = Memory.Arrays.Swarm_Indices_1

-- ========================================================================
-- [6] THE AUTOMATIC STRUCT BINDING
-- ========================================================================
-- Now let your pcall loop safely bind all the remaining single-arrays!
for array_name, array_ptr in pairs(Memory.Arrays) do
    pcall(function() Memory.RenderStruct[array_name] = array_ptr end)
end

return Memory

