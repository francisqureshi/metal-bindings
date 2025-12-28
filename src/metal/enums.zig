//! Metal enumerations and constants

/// Resource storage mode for Metal buffers.
///
/// Determines how memory is shared between CPU and GPU:
/// - `.shared`: CPU and GPU both have direct access (default, easiest)
/// - `.managed`: Automatic synchronization between CPU and GPU copies
/// - `.private`: GPU-only memory (fastest for GPU operations)
pub const ResourceStorageMode = enum(u32) {
    shared = 0,
    managed = 1 << 4,
    private = 2 << 4,
};

/// Pixel format for textures and render targets
pub const PixelFormat = enum(u32) {
    bgra8_unorm = 80,
    rgba8_unorm = 70,
    rgba32_float = 125,
    r8_unorm = 10,
};

/// Blend factor for render pipeline blending
pub const BlendFactor = enum(u32) {
    zero = 0,
    one = 1,
    source_alpha = 6,
    one_minus_source_alpha = 7,
};

/// Blend operation for render pipeline blending
pub const BlendOperation = enum(u32) {
    add = 0,
};

/// Primitive type for rendering
pub const PrimitiveType = enum(u32) {
    point = 0,
    line = 1,
    line_strip = 2,
    triangle = 3,
    triangle_strip = 4,
};

/// Index type for indexed drawing
pub const IndexType = enum(u32) {
    uint16 = 0,
    uint32 = 1,
};

/// Vertex step function (per-vertex vs per-instance)
pub const VertexStepFunction = enum(u32) {
    per_vertex = 0,
    per_instance = 1,
};

/// Vertex format for vertex attributes
pub const VertexFormat = enum(u32) {
    uchar = 45,
    uchar4 = 52,
    short2 = 26,
    ushort2 = 32,
    uint = 36,
    uint2 = 37,
    float = 28,
    float2 = 29,
    float4 = 31,
};
