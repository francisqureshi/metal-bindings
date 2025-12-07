#import <Metal/Metal.h>
#import <Foundation/Foundation.h>
#import "metal_bridge.h"
#include <string.h>

bool metal_is_available(void) {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    return (device != nil);
}

MetalDevice metal_create_device(void) {
    return (MetalDevice)CFBridgingRetain(MTLCreateSystemDefaultDevice());
}

void metal_release_device(MetalDevice device) {
    if (device) CFRelease(device);
}

uint32_t metal_get_device_count(void) {
    NSArray<id<MTLDevice>>* devices = MTLCopyAllDevices();
    return (uint32_t)[devices count];
}

MetalDevice metal_get_device_at_index(uint32_t index) {
    NSArray<id<MTLDevice>>* devices = MTLCopyAllDevices();
    if (index >= [devices count]) return NULL;
    return (MetalDevice)CFBridgingRetain(devices[index]);
}

const char* metal_device_get_name(MetalDevice device) {
    id<MTLDevice> dev = (__bridge id<MTLDevice>)device;
    NSString* name = [dev name];
    return strdup([name UTF8String]);
}

MetalCommandQueue metal_create_command_queue(MetalDevice device) {
    id<MTLDevice> dev = (__bridge id<MTLDevice>)device;
    id<MTLCommandQueue> queue = [dev newCommandQueue];
    return (MetalCommandQueue)CFBridgingRetain(queue);
}

void metal_release_command_queue(MetalCommandQueue queue) {
    if (queue) CFRelease(queue);
}

MetalLibrary metal_create_library_from_source(MetalDevice device, const char* source, char** error_msg) {
    id<MTLDevice> dev = (__bridge id<MTLDevice>)device;
    NSString* sourceStr = [NSString stringWithUTF8String:source];

    NSError* error = nil;
    id<MTLLibrary> library = [dev newLibraryWithSource:sourceStr options:nil error:&error];

    if (error && error_msg) {
        NSString* errStr = [error localizedDescription];
        *error_msg = strdup([errStr UTF8String]);
    }

    if (library == nil) return NULL;
    return (MetalLibrary)CFBridgingRetain(library);
}

void metal_release_library(MetalLibrary library) {
    if (library) CFRelease(library);
}

MetalFunction metal_create_function(MetalLibrary library, const char* name) {
    id<MTLLibrary> lib = (__bridge id<MTLLibrary>)library;
    NSString* nameStr = [NSString stringWithUTF8String:name];
    id<MTLFunction> function = [lib newFunctionWithName:nameStr];
    if (function == nil) return NULL;
    return (MetalFunction)CFBridgingRetain(function);
}

void metal_release_function(MetalFunction function) {
    if (function) CFRelease(function);
}

MetalPipeline metal_create_pipeline(MetalDevice device, MetalFunction function, char** error_msg) {
    id<MTLDevice> dev = (__bridge id<MTLDevice>)device;
    id<MTLFunction> func = (__bridge id<MTLFunction>)function;

    NSError* error = nil;
    id<MTLComputePipelineState> pipeline = [dev newComputePipelineStateWithFunction:func error:&error];

    if (error && error_msg) {
        NSString* errStr = [error localizedDescription];
        *error_msg = strdup([errStr UTF8String]);
    }

    if (pipeline == nil) return NULL;
    return (MetalPipeline)CFBridgingRetain(pipeline);
}

void metal_release_pipeline(MetalPipeline pipeline) {
    if (pipeline) CFRelease(pipeline);
}

MetalTexture metal_create_texture(MetalDevice device, uint32_t width, uint32_t height, bool writable) {
    id<MTLDevice> dev = (__bridge id<MTLDevice>)device;

    MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float
                                                                                     width:width
                                                                                    height:height
                                                                                 mipmapped:NO];
    desc.usage = writable ? MTLTextureUsageShaderWrite : MTLTextureUsageShaderRead;

    id<MTLTexture> texture = [dev newTextureWithDescriptor:desc];
    if (texture == nil) return NULL;
    return (MetalTexture)CFBridgingRetain(texture);
}

void metal_release_texture(MetalTexture texture) {
    if (texture) CFRelease(texture);
}

void metal_texture_upload(MetalTexture texture, const void* data, uint32_t width, uint32_t height, uint32_t bytes_per_row) {
    id<MTLTexture> tex = (__bridge id<MTLTexture>)texture;
    MTLRegion region = MTLRegionMake2D(0, 0, width, height);
    [tex replaceRegion:region mipmapLevel:0 withBytes:data bytesPerRow:bytes_per_row];
}

void metal_texture_download(MetalTexture texture, void* data, uint32_t width, uint32_t height, uint32_t bytes_per_row) {
    id<MTLTexture> tex = (__bridge id<MTLTexture>)texture;
    MTLRegion region = MTLRegionMake2D(0, 0, width, height);
    [tex getBytes:data bytesPerRow:bytes_per_row fromRegion:region mipmapLevel:0];
}

MetalBuffer metal_create_buffer(MetalDevice device, uint32_t size) {
    id<MTLDevice> dev = (__bridge id<MTLDevice>)device;
    id<MTLBuffer> buffer = [dev newBufferWithLength:size options:MTLResourceStorageModeShared];
    if (buffer == nil) return NULL;
    return (MetalBuffer)CFBridgingRetain(buffer);
}

MetalBuffer metal_create_buffer_with_options(MetalDevice device, uint32_t size, MetalResourceOptions options) {
    id<MTLDevice> dev = (__bridge id<MTLDevice>)device;
    id<MTLBuffer> buffer = [dev newBufferWithLength:size options:(MTLResourceOptions)options];
    if (buffer == nil) return NULL;
    return (MetalBuffer)CFBridgingRetain(buffer);
}

void metal_release_buffer(MetalBuffer buffer) {
    if (buffer) CFRelease(buffer);
}

void metal_buffer_upload(MetalBuffer buffer, const void* data, uint32_t size) {
    id<MTLBuffer> buf = (__bridge id<MTLBuffer>)buffer;
    memcpy([buf contents], data, size);
}

void metal_buffer_download(MetalBuffer buffer, void* data, uint32_t size) {
    id<MTLBuffer> buf = (__bridge id<MTLBuffer>)buffer;
    memcpy(data, [buf contents], size);
}

void* metal_buffer_get_contents(MetalBuffer buffer) {
    id<MTLBuffer> buf = (__bridge id<MTLBuffer>)buffer;
    return [buf contents];
}

uint32_t metal_buffer_get_length(MetalBuffer buffer) {
    id<MTLBuffer> buf = (__bridge id<MTLBuffer>)buffer;
    return (uint32_t)[buf length];
}

MetalCommandBuffer metal_create_command_buffer(MetalCommandQueue queue) {
    id<MTLCommandQueue> q = (__bridge id<MTLCommandQueue>)queue;
    id<MTLCommandBuffer> buffer = [q commandBuffer];
    if (buffer == nil) return NULL;
    return (MetalCommandBuffer)CFBridgingRetain(buffer);
}

void metal_commit_command_buffer(MetalCommandBuffer buffer) {
    id<MTLCommandBuffer> buf = (__bridge id<MTLCommandBuffer>)buffer;
    [buf commit];
}

void metal_wait_for_completion(MetalCommandBuffer buffer) {
    id<MTLCommandBuffer> buf = (__bridge id<MTLCommandBuffer>)buffer;
    [buf waitUntilCompleted];
}

void metal_release_command_buffer(MetalCommandBuffer buffer) {
    if (buffer) CFRelease(buffer);
}

MetalCommandEncoder metal_create_compute_encoder(MetalCommandBuffer buffer) {
    id<MTLCommandBuffer> buf = (__bridge id<MTLCommandBuffer>)buffer;
    id<MTLComputeCommandEncoder> encoder = [buf computeCommandEncoder];
    if (encoder == nil) return NULL;
    return (MetalCommandEncoder)CFBridgingRetain(encoder);
}

void metal_encoder_set_pipeline(MetalCommandEncoder encoder, MetalPipeline pipeline) {
    id<MTLComputeCommandEncoder> enc = (__bridge id<MTLComputeCommandEncoder>)encoder;
    id<MTLComputePipelineState> pipe = (__bridge id<MTLComputePipelineState>)pipeline;
    [enc setComputePipelineState:pipe];
}

void metal_encoder_set_texture(MetalCommandEncoder encoder, MetalTexture texture, uint32_t index) {
    id<MTLComputeCommandEncoder> enc = (__bridge id<MTLComputeCommandEncoder>)encoder;
    id<MTLTexture> tex = (__bridge id<MTLTexture>)texture;
    [enc setTexture:tex atIndex:index];
}

void metal_encoder_set_buffer(MetalCommandEncoder encoder, MetalBuffer buffer, uint32_t index) {
    id<MTLComputeCommandEncoder> enc = (__bridge id<MTLComputeCommandEncoder>)encoder;
    id<MTLBuffer> buf = (__bridge id<MTLBuffer>)buffer;
    [enc setBuffer:buf offset:0 atIndex:index];
}

void metal_encoder_set_bytes(MetalCommandEncoder encoder, const void* bytes, uint32_t length, uint32_t index) {
    id<MTLComputeCommandEncoder> enc = (__bridge id<MTLComputeCommandEncoder>)encoder;
    [enc setBytes:bytes length:length atIndex:index];
}

void metal_encoder_dispatch(MetalCommandEncoder encoder, uint32_t grid_w, uint32_t grid_h, uint32_t group_w, uint32_t group_h) {
    id<MTLComputeCommandEncoder> enc = (__bridge id<MTLComputeCommandEncoder>)encoder;

    MTLSize gridSize = MTLSizeMake(grid_w, grid_h, 1);
    MTLSize threadGroupSize = MTLSizeMake(group_w, group_h, 1);

    [enc dispatchThreadgroups:gridSize threadsPerThreadgroup:threadGroupSize];
}

void metal_encoder_end(MetalCommandEncoder encoder) {
    id<MTLComputeCommandEncoder> enc = (__bridge id<MTLComputeCommandEncoder>)encoder;
    [enc endEncoding];
}

void metal_release_encoder(MetalCommandEncoder encoder) {
    if (encoder) CFRelease(encoder);
}

// Blit encoder
MetalCommandEncoder metal_create_blit_encoder(MetalCommandBuffer buffer) {
    id<MTLCommandBuffer> cmdBuf = (__bridge id<MTLCommandBuffer>)buffer;
    id<MTLBlitCommandEncoder> blitEnc = [cmdBuf blitCommandEncoder];
    if (blitEnc == nil) return NULL;
    return (MetalCommandEncoder)CFBridgingRetain(blitEnc);
}

void metal_blit_copy_buffer(MetalCommandEncoder encoder, MetalBuffer src, MetalBuffer dst, uint32_t size) {
    id<MTLBlitCommandEncoder> blitEnc = (__bridge id<MTLBlitCommandEncoder>)encoder;
    id<MTLBuffer> srcBuf = (__bridge id<MTLBuffer>)src;
    id<MTLBuffer> dstBuf = (__bridge id<MTLBuffer>)dst;

    [blitEnc copyFromBuffer:srcBuf sourceOffset:0 toBuffer:dstBuf destinationOffset:0 size:size];
}
