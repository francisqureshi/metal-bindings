//! C bridge to Metal API
//! This file imports the C header that provides the Objective-C Metal bindings

pub const c = @cImport({
    @cInclude("gpu/metal_bridge.h");
});

// Re-export types
pub const MetalDevice = c.MetalDevice;
pub const MetalCommandQueue = c.MetalCommandQueue;
pub const MetalLibrary = c.MetalLibrary;
pub const MetalFunction = c.MetalFunction;
pub const MetalPipeline = c.MetalPipeline;
pub const MetalRenderPipeline = c.MetalRenderPipeline;
pub const MetalCommandBuffer = c.MetalCommandBuffer;
pub const MetalCommandEncoder = c.MetalCommandEncoder;
pub const MetalRenderPassDescriptor = c.MetalRenderPassDescriptor;
pub const MetalTexture = c.MetalTexture;
pub const MetalBuffer = c.MetalBuffer;
pub const MetalResourceOptions = c.MetalResourceOptions;
pub const MetalRenderPipelineDescriptor = c.MetalRenderPipelineDescriptor;

// Re-export resource option constants
pub const RESOURCE_STORAGE_MODE_SHARED = c.METAL_RESOURCE_STORAGE_MODE_SHARED;
pub const RESOURCE_STORAGE_MODE_MANAGED = c.METAL_RESOURCE_STORAGE_MODE_MANAGED;
pub const RESOURCE_STORAGE_MODE_PRIVATE = c.METAL_RESOURCE_STORAGE_MODE_PRIVATE;

// Re-export functions
pub const metal_is_available = c.metal_is_available;
pub const metal_create_device = c.metal_create_device;
pub const metal_release_device = c.metal_release_device;
pub const metal_get_device_count = c.metal_get_device_count;
pub const metal_get_device_at_index = c.metal_get_device_at_index;
pub const metal_device_get_name = c.metal_device_get_name;
pub const metal_create_command_queue = c.metal_create_command_queue;
pub const metal_release_command_queue = c.metal_release_command_queue;
pub const metal_create_library_from_source = c.metal_create_library_from_source;
pub const metal_release_library = c.metal_release_library;
pub const metal_create_function = c.metal_create_function;
pub const metal_release_function = c.metal_release_function;
pub const metal_create_pipeline = c.metal_create_pipeline;
pub const metal_release_pipeline = c.metal_release_pipeline;
pub const metal_create_texture = c.metal_create_texture;
pub const metal_release_texture = c.metal_release_texture;
pub const metal_texture_upload = c.metal_texture_upload;
pub const metal_texture_download = c.metal_texture_download;
pub const metal_create_buffer = c.metal_create_buffer;
pub const metal_create_buffer_with_options = c.metal_create_buffer_with_options;
pub const metal_release_buffer = c.metal_release_buffer;
pub const metal_buffer_upload = c.metal_buffer_upload;
pub const metal_buffer_download = c.metal_buffer_download;
pub const metal_buffer_get_contents = c.metal_buffer_get_contents;
pub const metal_buffer_get_length = c.metal_buffer_get_length;
pub const metal_create_command_buffer = c.metal_create_command_buffer;
pub const metal_commit_command_buffer = c.metal_commit_command_buffer;
pub const metal_wait_for_completion = c.metal_wait_for_completion;
pub const metal_release_command_buffer = c.metal_release_command_buffer;
pub const metal_create_compute_encoder = c.metal_create_compute_encoder;
pub const metal_encoder_set_pipeline = c.metal_encoder_set_pipeline;
pub const metal_encoder_set_texture = c.metal_encoder_set_texture;
pub const metal_encoder_set_buffer = c.metal_encoder_set_buffer;
pub const metal_encoder_set_bytes = c.metal_encoder_set_bytes;
pub const metal_encoder_dispatch = c.metal_encoder_dispatch;
pub const metal_encoder_end = c.metal_encoder_end;
pub const metal_release_encoder = c.metal_release_encoder;
pub const metal_create_blit_encoder = c.metal_create_blit_encoder;
pub const metal_blit_copy_buffer = c.metal_blit_copy_buffer;

// Render pipeline functions
pub const metal_create_render_pipeline = c.metal_create_render_pipeline;
pub const metal_release_render_pipeline = c.metal_release_render_pipeline;

// Render pass descriptor functions
pub const metal_create_render_pass_descriptor = c.metal_create_render_pass_descriptor;
pub const metal_release_render_pass_descriptor = c.metal_release_render_pass_descriptor;
pub const metal_render_pass_set_color_texture = c.metal_render_pass_set_color_texture;
pub const metal_render_pass_set_clear_color = c.metal_render_pass_set_clear_color;

// Render encoder functions
pub const metal_create_render_encoder = c.metal_create_render_encoder;
pub const metal_render_encoder_set_pipeline = c.metal_render_encoder_set_pipeline;
pub const metal_render_encoder_set_vertex_buffer = c.metal_render_encoder_set_vertex_buffer;
pub const metal_render_encoder_set_vertex_bytes = c.metal_render_encoder_set_vertex_bytes;
pub const metal_render_encoder_set_fragment_buffer = c.metal_render_encoder_set_fragment_buffer;
pub const metal_render_encoder_set_fragment_bytes = c.metal_render_encoder_set_fragment_bytes;
pub const metal_render_encoder_draw_primitives = c.metal_render_encoder_draw_primitives;

// Pixel format constants
pub const PIXEL_FORMAT_BGRA8_UNORM = c.METAL_PIXEL_FORMAT_BGRA8_UNORM;
pub const PIXEL_FORMAT_RGBA8_UNORM = c.METAL_PIXEL_FORMAT_RGBA8_UNORM;
pub const PIXEL_FORMAT_RGBA32_FLOAT = c.METAL_PIXEL_FORMAT_RGBA32_FLOAT;

// Blend factor constants
pub const BLEND_FACTOR_ZERO = c.METAL_BLEND_FACTOR_ZERO;
pub const BLEND_FACTOR_ONE = c.METAL_BLEND_FACTOR_ONE;
pub const BLEND_FACTOR_SOURCE_ALPHA = c.METAL_BLEND_FACTOR_SOURCE_ALPHA;
pub const BLEND_FACTOR_ONE_MINUS_SOURCE_ALPHA = c.METAL_BLEND_FACTOR_ONE_MINUS_SOURCE_ALPHA;

// Blend operation constants
pub const BLEND_OP_ADD = c.METAL_BLEND_OP_ADD;

// Primitive type constants
pub const PRIMITIVE_TYPE_POINT = c.METAL_PRIMITIVE_TYPE_POINT;
pub const PRIMITIVE_TYPE_LINE = c.METAL_PRIMITIVE_TYPE_LINE;
pub const PRIMITIVE_TYPE_LINE_STRIP = c.METAL_PRIMITIVE_TYPE_LINE_STRIP;
pub const PRIMITIVE_TYPE_TRIANGLE = c.METAL_PRIMITIVE_TYPE_TRIANGLE;
pub const PRIMITIVE_TYPE_TRIANGLE_STRIP = c.METAL_PRIMITIVE_TYPE_TRIANGLE_STRIP;
