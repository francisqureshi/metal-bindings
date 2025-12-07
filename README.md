# Metal Bindings for Zig

A clean, generic Zig wrapper around Apple's Metal API for GPU compute and rendering.

## Installation

### As a dependency (recommended)

First, fetch the package:

```bash
zig fetch --save git+https://github.com/francisqureshi/metal-bindings.git
```

This will automatically add the dependency to your `build.zig.zon`.

Then in your `build.zig`:

```zig
const metal_dep = b.dependency("metal_bindings", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("metal", metal_dep.module("metal_bindings"));
```

### Build from source

```bash
cd /Users/fq/Zig/metal-bindings
zig build        # Build library
zig build run    # Run example
zig build test   # Run tests
```

## Quick Examples

### Compute Shader Example

```zig
const std = @import("std");
const metal = @import("metal");

pub fn main() !void {
    // Check if Metal is available
    if (!metal.isAvailable()) {
        return error.MetalNotAvailable;
    }

    // Create device and command queue
    var device = try metal.MetalDevice.init();
    defer device.deinit();

    var queue = try device.createCommandQueue();
    defer queue.deinit();

    // Compile a compute shader
    const shader_source =
        \\#include <metal_stdlib>
        \\using namespace metal;
        \\
        \\kernel void my_kernel(device float* data [[buffer(0)]],
        \\                      uint index [[thread_position_in_grid]]) {
        \\    data[index] *= 2.0;
        \\}
    ;

    var library = try device.createLibraryFromSource(shader_source);
    defer library.deinit();

    var function = try library.createFunction("my_kernel");
    defer function.deinit();

    var pipeline = try function.createPipeline(&device);
    defer pipeline.deinit();

    // Create a buffer
    var buffer = try device.createBuffer(1024);
    defer buffer.deinit();

    // Upload data
    var data = [_]f32{1.0, 2.0, 3.0, 4.0};
    buffer.upload(std.mem.sliceAsBytes(&data));

    // Execute shader
    var cmdBuffer = try queue.createCommandBuffer();
    defer cmdBuffer.deinit();

    var encoder = try cmdBuffer.createComputeEncoder();
    defer encoder.deinit();

    encoder.setPipeline(&pipeline);
    encoder.setBuffer(&buffer, 0);
    encoder.dispatch(1, 1, 4, 1);
    encoder.end();

    cmdBuffer.commit();
    cmdBuffer.waitForCompletion();

    // Download results
    buffer.download(std.mem.sliceAsBytes(&data));
    // data is now [2.0, 4.0, 6.0, 8.0]
}
```

### Render Pipeline Example

```zig
const std = @import("std");
const metal = @import("metal");

pub fn main() !void {
    var device = try metal.MetalDevice.init();
    defer device.deinit();

    // Compile vertex and fragment shaders
    const shader_source =
        \\#include <metal_stdlib>
        \\using namespace metal;
        \\
        \\struct VertexOut {
        \\    float4 position [[position]];
        \\    float4 color;
        \\};
        \\
        \\vertex VertexOut vertexShader(
        \\    device const float2* positions [[buffer(0)]],
        \\    device const float4* colors [[buffer(1)]],
        \\    uint vid [[vertex_id]])
        \\{
        \\    VertexOut out;
        \\    out.position = float4(positions[vid], 0.0, 1.0);
        \\    out.color = colors[vid];
        \\    return out;
        \\}
        \\
        \\fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
        \\    return in.color;
        \\}
    ;

    var library = try device.createLibraryFromSource(shader_source);
    defer library.deinit();

    var vertex_fn = try library.createFunction("vertexShader");
    defer vertex_fn.deinit();

    var fragment_fn = try library.createFunction("fragmentShader");
    defer fragment_fn.deinit();

    // Create render pipeline
    const pipeline_desc = metal.RenderPipelineDescriptor{
        .pixel_format = .bgra8_unorm,
    };
    var pipeline = try vertex_fn.createRenderPipeline(&device, &fragment_fn, pipeline_desc);
    defer pipeline.deinit();

    // Create render target texture
    var texture = try device.createTexture(800, 600, true);
    defer texture.deinit();

    // Set up render pass
    var render_pass = metal.MetalRenderPassDescriptor.init();
    defer render_pass.deinit();
    render_pass.setColorTexture(&texture, 0);
    render_pass.setClearColor(0.0, 0.0, 0.0, 1.0, 0);

    // Create vertex data
    const positions = [_]f32{ 0.0, 0.5, -0.5, -0.5, 0.5, -0.5 };
    const colors = [_]f32{ 1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0 };

    var pos_buffer = try device.createBuffer(@sizeOf(@TypeOf(positions)));
    defer pos_buffer.deinit();
    pos_buffer.upload(std.mem.sliceAsBytes(&positions));

    var color_buffer = try device.createBuffer(@sizeOf(@TypeOf(colors)));
    defer color_buffer.deinit();
    color_buffer.upload(std.mem.sliceAsBytes(&colors));

    // Render
    var queue = try device.createCommandQueue();
    defer queue.deinit();

    var cmd_buffer = try queue.createCommandBuffer();
    defer cmd_buffer.deinit();

    var encoder = try cmd_buffer.createRenderEncoder(&render_pass);
    defer encoder.deinit();

    encoder.setPipeline(&pipeline);
    encoder.setVertexBuffer(&pos_buffer, 0, 0);
    encoder.setVertexBuffer(&color_buffer, 0, 1);
    encoder.drawPrimitives(.triangle, 0, 3);
    encoder.end();

    cmd_buffer.commit();
    cmd_buffer.waitForCompletion();
}
```

## API Overview

### Core Types

**Device & Resources:**
- `MetalDevice` - GPU device handle
- `MetalCommandQueue` - Command submission queue
- `MetalBuffer` - GPU memory buffer
- `MetalTexture` - GPU texture

**Shaders & Pipelines:**
- `MetalLibrary` - Compiled shader library
- `MetalFunction` - Shader entry point (vertex/fragment/compute)
- `MetalPipeline` - Compiled compute pipeline
- `MetalRenderPipelineState` - Compiled render pipeline

**Command Encoding:**
- `MetalCommandBuffer` - Command recording buffer
- `MetalComputeEncoder` - Compute command encoder
- `MetalRenderEncoder` - Render command encoder
- `MetalBlitEncoder` - Blit (copy) command encoder

**Rendering:**
- `MetalRenderPassDescriptor` - Render pass configuration
- `RenderPipelineDescriptor` - Render pipeline settings
- `PixelFormat` - Texture/render target pixel formats
- `PrimitiveType` - Triangle, line, point primitives

### Key Functions

```zig
// Device
metal.isAvailable() -> bool
MetalDevice.init() -> !MetalDevice
device.createCommandQueue() -> !MetalCommandQueue
device.createLibraryFromSource(source: [:0]const u8) -> !MetalLibrary
device.createBuffer(size: u32) -> !MetalBuffer
device.createTexture(width: u32, height: u32, writable: bool) -> !MetalTexture

// Library
library.createFunction(name: [:0]const u8) -> !MetalFunction

// Function
function.createPipeline(device: *MetalDevice) -> !MetalPipeline
function.createRenderPipeline(device: *MetalDevice, fragment: *MetalFunction, desc: RenderPipelineDescriptor) -> !MetalRenderPipelineState

// Command Queue
queue.createCommandBuffer() -> !MetalCommandBuffer

// Command Buffer
cmdBuffer.createComputeEncoder() -> !MetalComputeEncoder
cmdBuffer.createRenderEncoder(render_pass: *MetalRenderPassDescriptor) -> !MetalRenderEncoder
cmdBuffer.createBlitEncoder() -> !MetalBlitEncoder
cmdBuffer.commit() -> void
cmdBuffer.waitForCompletion() -> void

// Compute Encoder
compute_encoder.setPipeline(pipeline: *MetalPipeline) -> void
compute_encoder.setBuffer(buffer: *MetalBuffer, index: u32) -> void
compute_encoder.setTexture(texture: *MetalTexture, index: u32) -> void
compute_encoder.setBytes(bytes: *const anyopaque, length: u32, index: u32) -> void
compute_encoder.dispatch(grid_w: u32, grid_h: u32, group_w: u32, group_h: u32) -> void
compute_encoder.end() -> void

// Render Encoder
render_encoder.setPipeline(pipeline: *MetalRenderPipelineState) -> void
render_encoder.setVertexBuffer(buffer: *MetalBuffer, offset: u32, index: u32) -> void
render_encoder.setVertexBytes(bytes: *const anyopaque, length: u32, index: u32) -> void
render_encoder.setFragmentBuffer(buffer: *MetalBuffer, offset: u32, index: u32) -> void
render_encoder.setFragmentBytes(bytes: *const anyopaque, length: u32, index: u32) -> void
render_encoder.drawPrimitives(type: PrimitiveType, vertex_start: u32, vertex_count: u32) -> void
render_encoder.end() -> void

// Render Pass Descriptor
MetalRenderPassDescriptor.init() -> MetalRenderPassDescriptor
render_pass.setColorTexture(texture: *MetalTexture, index: u32) -> void
render_pass.setClearColor(r: f64, g: f64, b: f64, a: f64, index: u32) -> void

// Buffer
buffer.upload(data: []const u8) -> void
buffer.download(data: []u8) -> void
buffer.getContentsAs(T: type) -> ?[]T

// Texture
texture.upload(data: []const u8, width: u32, height: u32, bytes_per_row: u32) -> void
texture.download(data: []u8, width: u32, height: u32, bytes_per_row: u32) -> void
```

## License

MIT

## Contributing

This is a generic Metal bindings library. Keep it simple and free of application-specific code (no OFX, NDI, or other domain-specific functionality).
