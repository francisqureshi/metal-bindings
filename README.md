# Metal Bindings for Zig

Type-safe Zig bindings for Apple's Metal API, enabling GPU compute and graphics programming on macOS.

## Requirements

- Zig 0.16.0 or later
- macOS (Metal is Apple-specific)
- Xcode Command Line Tools

## Installation

Add as a dependency using Zig's package manager:

```bash
zig fetch --save git+https://github.com/francisqureshi/metal-bindings.git
```

Then add to your `build.zig`:

```zig
const metal_dep = b.dependency("metal_bindings", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("metal", metal_dep.module("metal_bindings"));
```

## Architecture

This library uses [zig-objc](https://github.com/francisqureshi/zig-objc) for Objective-C runtime interop, providing direct access to Metal APIs without C bridge code. All Metal objects are wrapped in Zig types with proper lifetime management.

## Quick Start

### Compute Pipeline

Execute GPU compute operations:

```zig
const std = @import("std");
const metal = @import("metal");

pub fn main() !void {
    var device = try metal.MetalDevice.createSystemDefaultDevice();
    defer device.deinit();

    var queue = try device.createCommandQueue();
    defer queue.deinit();

    const shader_source =
        \\#include <metal_stdlib>
        \\using namespace metal;
        \\kernel void double_values(device float* data [[buffer(0)]],
        \\                          uint index [[thread_position_in_grid]]) {
        \\    data[index] *= 2.0;
        \\}
    ;

    var library = try device.createLibraryFromSource(shader_source, null);
    defer library.deinit();

    var function = try library.createFunction("double_values");
    defer function.deinit();

    var pipeline = try function.createPipeline(&device);
    defer pipeline.deinit();

    var buffer = try device.createBuffer(16);
    defer buffer.deinit();

    const data = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    buffer.upload(std.mem.sliceAsBytes(&data));

    var cmd_buffer = try queue.createCommandBuffer();
    defer cmd_buffer.deinit();

    var encoder = try cmd_buffer.createComputeEncoder();
    defer encoder.deinit();

    encoder.setPipeline(&pipeline);
    encoder.setBuffer(&buffer, 0);
    encoder.dispatch(1, 1, 4, 1);
    encoder.end();

    cmd_buffer.commit();
    cmd_buffer.waitForCompletion();

    var result: [4]f32 = undefined;
    buffer.download(std.mem.sliceAsBytes(&result));
    // result = [2.0, 4.0, 6.0, 8.0]
}
```

### Render Pipeline

Draw graphics to textures or screen:

```zig
const metal = @import("metal");

var device = try metal.MetalDevice.createSystemDefaultDevice();
defer device.deinit();

const shader_source =
    \\#include <metal_stdlib>
    \\using namespace metal;
    \\struct VertexOut {
    \\    float4 position [[position]];
    \\    float4 color;
    \\};
    \\vertex VertexOut vertexShader(uint vid [[vertex_id]]) {
    \\    const float2 positions[] = { {0.0, 0.5}, {-0.5, -0.5}, {0.5, -0.5} };
    \\    const float4 colors[] = { {1,0,0,1}, {0,1,0,1}, {0,0,1,1} };
    \\    VertexOut out;
    \\    out.position = float4(positions[vid], 0.0, 1.0);
    \\    out.color = colors[vid];
    \\    return out;
    \\}
    \\fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    \\    return in.color;
    \\}
;

var library = try device.createLibraryFromSource(shader_source, null);
defer library.deinit();

var vertex_fn = try library.createFunction("vertexShader");
defer vertex_fn.deinit();

var fragment_fn = try library.createFunction("fragmentShader");
defer fragment_fn.deinit();

const pipeline_desc = metal.RenderPipelineDescriptor{
    .pixel_format = .bgra8_unorm,
    .blend_enabled = false,
};

var pipeline = try vertex_fn.createRenderPipeline(&device, &fragment_fn, pipeline_desc);
defer pipeline.deinit();

var texture = try device.createTexture(800, 600, true);
defer texture.deinit();

var render_pass = metal.MetalRenderPassDescriptor.init();
defer render_pass.deinit();
render_pass.setColorTexture(&texture, 0);
render_pass.setClearColor(0.0, 0.0, 0.0, 1.0, 0);

var queue = try device.createCommandQueue();
defer queue.deinit();

var cmd_buffer = try queue.createCommandBuffer();
defer cmd_buffer.deinit();

var encoder = try cmd_buffer.createRenderEncoder(&render_pass);
defer encoder.deinit();

encoder.setPipeline(&pipeline);
encoder.drawPrimitives(.triangle, 0, 3);
encoder.end();

cmd_buffer.commit();
cmd_buffer.waitForCompletion();
```

## Core API

### Device Management

```zig
MetalDevice.createSystemDefaultDevice() !MetalDevice
device.createCommandQueue() !MetalCommandQueue
device.createLibraryFromSource(source: [:0]const u8, options: ?*anyopaque) !MetalLibrary
device.createBuffer(size: u32) !MetalBuffer
device.createTexture(width: u32, height: u32, writable: bool) !MetalTexture
```

### Shader Compilation

```zig
library.createFunction(name: [:0]const u8) !MetalFunction
function.createPipeline(device: *MetalDevice) !MetalPipeline
function.createRenderPipeline(device: *MetalDevice, fragment: *MetalFunction, desc: RenderPipelineDescriptor) !MetalRenderPipelineState
```

### Command Submission

```zig
queue.createCommandBuffer() !MetalCommandBuffer
cmdBuffer.createComputeEncoder() !MetalComputeEncoder
cmdBuffer.createRenderEncoder(pass: *MetalRenderPassDescriptor) !MetalRenderEncoder
cmdBuffer.createBlitEncoder() !MetalBlitEncoder
cmdBuffer.commit() void
cmdBuffer.waitForCompletion() void
cmdBuffer.present(drawable: ?*anyopaque) void
```

### Compute Operations

```zig
encoder.setPipeline(pipeline: *MetalPipeline) void
encoder.setBuffer(buffer: *MetalBuffer, index: u32) void
encoder.setTexture(texture: *MetalTexture, index: u32) void
encoder.setBytes(bytes: *const anyopaque, length: u32, index: u32) void
encoder.dispatch(grid_w: u32, grid_h: u32, group_w: u32, group_h: u32) void
encoder.end() void
```

### Rendering Operations

```zig
encoder.setPipeline(pipeline: *MetalRenderPipelineState) void
encoder.setVertexBuffer(buffer: *MetalBuffer, offset: u32, index: u32) void
encoder.setVertexBytes(bytes: *const anyopaque, length: u32, index: u32) void
encoder.setFragmentBuffer(buffer: *MetalBuffer, offset: u32, index: u32) void
encoder.setFragmentTexture(texture: *MetalTexture, index: u32) void
encoder.drawPrimitives(type: PrimitiveType, vertex_start: u32, vertex_count: u32) void
encoder.drawIndexedPrimitives(type: PrimitiveType, index_count: u32, index_buffer: *MetalBuffer, offset: u32) void
encoder.end() void
```

### Data Transfer

```zig
buffer.upload(data: []const u8) void
buffer.download(data: []u8) void
buffer.getContentsAs(comptime T: type) ?[]T
texture.upload(data: []const u8, width: u32, height: u32, bytes_per_row: u32) void
texture.download(data: []u8, width: u32, height: u32, bytes_per_row: u32) void
```

## Types

### Core Types

- `MetalDevice` - GPU device handle
- `MetalCommandQueue` - Command submission queue
- `MetalCommandBuffer` - Command recording buffer
- `MetalBuffer` - GPU memory buffer
- `MetalTexture` - GPU texture resource

### Shader Types

- `MetalLibrary` - Compiled shader library
- `MetalFunction` - Shader entry point
- `MetalPipeline` - Compute pipeline state
- `MetalRenderPipelineState` - Render pipeline state

### Encoder Types

- `MetalComputeEncoder` - Compute command encoder
- `MetalRenderEncoder` - Render command encoder
- `MetalBlitEncoder` - Copy/blit command encoder

### Configuration Types

- `MetalRenderPassDescriptor` - Render pass configuration
- `RenderPipelineDescriptor` - Render pipeline settings
- `PixelFormat` - Texture pixel formats
- `PrimitiveType` - Rendering primitive types
- `BlendFactor` - Blending factors
- `BlendOperation` - Blending operations

## Render Pipeline Configuration

Configure blending, pixel formats, and render targets:

```zig
const pipeline_desc = metal.RenderPipelineDescriptor{
    .pixel_format = .bgra8_unorm,
    .blend_enabled = true,
    .source_rgb_blend_factor = .source_alpha,
    .destination_rgb_blend_factor = .one_minus_source_alpha,
    .rgb_blend_operation = .add,
    .source_alpha_blend_factor = .one,
    .destination_alpha_blend_factor = .zero,
    .alpha_blend_operation = .add,
};
```

Supported pixel formats: `.bgra8_unorm`, `.rgba8_unorm`, `.rgba32_float`, `.r8_unorm`

Blend factors: `.zero`, `.one`, `.source_alpha`, `.one_minus_source_alpha`

## Screen Rendering

Render to a window using CAMetalLayer drawables:

```zig
// Platform-specific: obtain drawable from CAMetalLayer
const drawable_ptr = getNextDrawable(layer);
const texture_ptr = getDrawableTexture(drawable_ptr);

var drawable_texture = metal.MetalTexture.initFromPtr(texture_ptr);

var render_pass = metal.MetalRenderPassDescriptor.init();
render_pass.setColorTexture(&drawable_texture, 0);
render_pass.setClearColor(0.0, 0.0, 0.0, 1.0, 0);

var encoder = cmd_buffer.createRenderEncoder(&render_pass);
encoder.setPipeline(&pipeline);
encoder.drawPrimitives(.triangle, 0, 3);
encoder.end();

// Schedule presentation when rendering completes
cmd_buffer.present(drawable_ptr);
cmd_buffer.commit();
```

The drawable presentation is synchronized with GPU completion automatically.

## Memory Management

All Metal objects follow Zig ownership patterns:

- Call `deinit()` when done to release resources
- Use `defer` for automatic cleanup
- External textures (from drawables) should use `initFromPtr()` without `deinit()`

## Error Handling

All fallible operations return error unions. Common errors:

- `error.MetalNotAvailable` - Metal not supported on system
- `error.DeviceNotFound` - No GPU device available
- `error.ShaderCompilationFailed` - Shader compilation error
- `error.PipelineCreationFailed` - Pipeline creation error
- `error.FunctionNotFound` - Shader function not found in library

## Platform Support

- macOS 10.13+ (Metal 2)
- Apple Silicon and Intel Macs

Metal is not available on non-Apple platforms.

## Dependencies

- [zig-objc](https://github.com/francisqureshi/zig-objc) - Objective-C runtime bindings (Zig 0.16 compatible)

## License

MIT

## Contributing

Contributions welcome. Please ensure code compiles with Zig 0.16+ and follows existing patterns.
