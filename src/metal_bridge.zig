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
pub const MetalCommandBuffer = c.MetalCommandBuffer;
pub const MetalCommandEncoder = c.MetalCommandEncoder;
pub const MetalTexture = c.MetalTexture;
pub const MetalBuffer = c.MetalBuffer;

// Re-export functions
pub const metal_is_available = c.metal_is_available;
pub const metal_create_device = c.metal_create_device;
pub const metal_release_device = c.metal_release_device;
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
pub const metal_release_buffer = c.metal_release_buffer;
pub const metal_buffer_upload = c.metal_buffer_upload;
pub const metal_buffer_download = c.metal_buffer_download;
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
