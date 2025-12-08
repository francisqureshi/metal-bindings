#ifndef METAL_BRIDGE_H
#define METAL_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handles for Metal objects
typedef void* MetalDevice;
typedef void* MetalCommandQueue;
typedef void* MetalLibrary;
typedef void* MetalFunction;
typedef void* MetalPipeline;
typedef void* MetalRenderPipeline;
typedef void* MetalCommandBuffer;
typedef void* MetalCommandEncoder;
typedef void* MetalRenderPassDescriptor;
typedef void* MetalTexture;
typedef void* MetalBuffer;
typedef void* MetalDrawable;

// Metal context creation/destruction
bool metal_is_available(void);
MetalDevice metal_create_device(void);
void metal_release_device(MetalDevice device);

// Device enumeration
uint32_t metal_get_device_count(void);
MetalDevice metal_get_device_at_index(uint32_t index);
const char* metal_device_get_name(MetalDevice device);

// Command queue
MetalCommandQueue metal_create_command_queue(MetalDevice device);
void metal_release_command_queue(MetalCommandQueue queue);

// Shader compilation
MetalLibrary metal_create_library_from_source(MetalDevice device, const char* source, char** error_msg);
void metal_release_library(MetalLibrary library);

MetalFunction metal_create_function(MetalLibrary library, const char* name);
void metal_release_function(MetalFunction function);

MetalPipeline metal_create_pipeline(MetalDevice device, MetalFunction function, char** error_msg);
void metal_release_pipeline(MetalPipeline pipeline);

// Textures
MetalTexture metal_create_texture(MetalDevice device, uint32_t width, uint32_t height, bool writable);
void metal_release_texture(MetalTexture texture);
void metal_texture_upload(MetalTexture texture, const void* data, uint32_t width, uint32_t height, uint32_t bytes_per_row);
void metal_texture_download(MetalTexture texture, void* data, uint32_t width, uint32_t height, uint32_t bytes_per_row);

// Resource options (matches Metal's MTLResourceOptions)
typedef uint32_t MetalResourceOptions;
#define METAL_RESOURCE_STORAGE_MODE_SHARED 0
#define METAL_RESOURCE_STORAGE_MODE_MANAGED (1 << 4)
#define METAL_RESOURCE_STORAGE_MODE_PRIVATE (2 << 4)

// Buffers
MetalBuffer metal_create_buffer(MetalDevice device, uint32_t size);
MetalBuffer metal_create_buffer_with_options(MetalDevice device, uint32_t size, MetalResourceOptions options);
void metal_release_buffer(MetalBuffer buffer);
void metal_buffer_upload(MetalBuffer buffer, const void* data, uint32_t size);
void metal_buffer_download(MetalBuffer buffer, void* data, uint32_t size);
void* metal_buffer_get_contents(MetalBuffer buffer);
uint32_t metal_buffer_get_length(MetalBuffer buffer);

// Command encoding
MetalCommandBuffer metal_create_command_buffer(MetalCommandQueue queue);
void metal_commit_command_buffer(MetalCommandBuffer buffer);
void metal_wait_for_completion(MetalCommandBuffer buffer);
void metal_command_buffer_present_drawable(MetalCommandBuffer buffer, void* drawable);
void metal_release_command_buffer(MetalCommandBuffer buffer);

MetalCommandEncoder metal_create_compute_encoder(MetalCommandBuffer buffer);
void metal_encoder_set_pipeline(MetalCommandEncoder encoder, MetalPipeline pipeline);
void metal_encoder_set_texture(MetalCommandEncoder encoder, MetalTexture texture, uint32_t index);
void metal_encoder_set_buffer(MetalCommandEncoder encoder, MetalBuffer buffer, uint32_t index);
void metal_encoder_set_bytes(MetalCommandEncoder encoder, const void* bytes, uint32_t length, uint32_t index);
void metal_encoder_dispatch(MetalCommandEncoder encoder, uint32_t grid_w, uint32_t grid_h, uint32_t group_w, uint32_t group_h);
void metal_encoder_end(MetalCommandEncoder encoder);
void metal_release_encoder(MetalCommandEncoder encoder);

// Blit encoder
MetalCommandEncoder metal_create_blit_encoder(MetalCommandBuffer buffer);
void metal_blit_copy_buffer(MetalCommandEncoder encoder, MetalBuffer src, MetalBuffer dst, uint32_t size);

// Render pipeline
typedef struct {
    uint32_t pixel_format;  // MTLPixelFormat (e.g., MTLPixelFormatBGRA8Unorm = 80)
    bool blend_enabled;
    uint32_t source_rgb_blend_factor;
    uint32_t destination_rgb_blend_factor;
    uint32_t rgb_blend_operation;
    uint32_t source_alpha_blend_factor;
    uint32_t destination_alpha_blend_factor;
    uint32_t alpha_blend_operation;
} MetalRenderPipelineDescriptor;

MetalRenderPipeline metal_create_render_pipeline(
    MetalDevice device,
    MetalFunction vertex_function,
    MetalFunction fragment_function,
    const MetalRenderPipelineDescriptor* descriptor,
    char** error_msg
);
void metal_release_render_pipeline(MetalRenderPipeline pipeline);

// Render pass descriptor
MetalRenderPassDescriptor metal_create_render_pass_descriptor(void);
void metal_release_render_pass_descriptor(MetalRenderPassDescriptor descriptor);
void metal_render_pass_set_color_texture(MetalRenderPassDescriptor descriptor, MetalTexture texture, uint32_t index);
void metal_render_pass_set_clear_color(MetalRenderPassDescriptor descriptor, double r, double g, double b, double a, uint32_t index);

// Render encoder
MetalCommandEncoder metal_create_render_encoder(MetalCommandBuffer buffer, MetalRenderPassDescriptor descriptor);
void metal_render_encoder_set_pipeline(MetalCommandEncoder encoder, MetalRenderPipeline pipeline);
void metal_render_encoder_set_vertex_buffer(MetalCommandEncoder encoder, MetalBuffer buffer, uint32_t offset, uint32_t index);
void metal_render_encoder_set_vertex_bytes(MetalCommandEncoder encoder, const void* bytes, uint32_t length, uint32_t index);
void metal_render_encoder_set_fragment_buffer(MetalCommandEncoder encoder, MetalBuffer buffer, uint32_t offset, uint32_t index);
void metal_render_encoder_set_fragment_bytes(MetalCommandEncoder encoder, const void* bytes, uint32_t length, uint32_t index);
void metal_render_encoder_draw_primitives(MetalCommandEncoder encoder, uint32_t primitive_type, uint32_t vertex_start, uint32_t vertex_count);

// Drawable functions
MetalTexture metal_drawable_get_texture(MetalDrawable drawable);
void metal_drawable_present(MetalDrawable drawable);

// Pixel formats (common ones)
#define METAL_PIXEL_FORMAT_BGRA8_UNORM 80
#define METAL_PIXEL_FORMAT_RGBA8_UNORM 70
#define METAL_PIXEL_FORMAT_RGBA32_FLOAT 115

// Blend factors
#define METAL_BLEND_FACTOR_ZERO 0
#define METAL_BLEND_FACTOR_ONE 1
#define METAL_BLEND_FACTOR_SOURCE_ALPHA 4
#define METAL_BLEND_FACTOR_ONE_MINUS_SOURCE_ALPHA 5

// Blend operations
#define METAL_BLEND_OP_ADD 0

// Primitive types
#define METAL_PRIMITIVE_TYPE_POINT 0
#define METAL_PRIMITIVE_TYPE_LINE 1
#define METAL_PRIMITIVE_TYPE_LINE_STRIP 2
#define METAL_PRIMITIVE_TYPE_TRIANGLE 3
#define METAL_PRIMITIVE_TYPE_TRIANGLE_STRIP 4

#ifdef __cplusplus
}
#endif

#endif // METAL_BRIDGE_H
