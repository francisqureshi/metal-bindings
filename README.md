# Metal Bindings for Zig

A clean, generic Zig wrapper around Apple's Metal API for GPU compute.

## Features

- 🎯 Simple, type-safe Zig API
- ⚡ Zero-overhead wrappers around Metal
- 🔧 Support for compute shaders, buffers, textures
- 📦 Easy to integrate as a Zig module
- 🍎 macOS/iOS only (Metal is Apple-specific)

## Installation

### As a dependency (recommended)

Add to your `build.zig.zon`:

```zig
.dependencies = .{
    .metal_bindings = .{
        .path = "/Users/fq/Zig/metal-bindings",
    },
},
```

In your `build.zig`:

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

## Quick Example

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
        \\kernel void my_kernel(device float* data [[buffer(0)]]) {
        \\    uint index = thread_position_in_grid.x;
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

## API Overview

### Core Types

- `MetalDevice` - GPU device handle
- `MetalCommandQueue` - Command submission queue
- `MetalLibrary` - Compiled shader library
- `MetalFunction` - Shader entry point
- `MetalPipeline` - Compiled compute pipeline
- `MetalBuffer` - GPU memory buffer
- `MetalTexture` - GPU texture
- `MetalCommandBuffer` - Command recording buffer
- `MetalComputeEncoder` - Compute command encoder
- `MetalBlitEncoder` - Blit (copy) command encoder

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

// Command Queue
queue.createCommandBuffer() -> !MetalCommandBuffer

// Command Buffer
cmdBuffer.createComputeEncoder() -> !MetalComputeEncoder
cmdBuffer.createBlitEncoder() -> !MetalBlitEncoder
cmdBuffer.commit() -> void
cmdBuffer.waitForCompletion() -> void

// Compute Encoder
encoder.setPipeline(pipeline: *MetalPipeline) -> void
encoder.setBuffer(buffer: *MetalBuffer, index: u32) -> void
encoder.setTexture(texture: *MetalTexture, index: u32) -> void
encoder.setBytes(bytes: *const anyopaque, length: u32, index: u32) -> void
encoder.dispatch(grid_w: u32, grid_h: u32, group_w: u32, group_h: u32) -> void
encoder.end() -> void

// Buffer
buffer.upload(data: []const u8) -> void
buffer.download(data: []u8) -> void

// Texture
texture.upload(data: []const u8, width: u32, height: u32, bytes_per_row: u32) -> void
texture.download(data: []u8, width: u32, height: u32, bytes_per_row: u32) -> void
```

## License

MIT

## Contributing

This is a generic Metal bindings library. Keep it simple and free of application-specific code (no OFX, NDI, or other domain-specific functionality).
