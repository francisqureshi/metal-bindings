//! Generic Metal bindings for Zig
//! Provides a clean Zig wrapper around Metal API for GPU compute

const std = @import("std");
const c = @import("metal_bridge.zig");

pub const MetalError = error{
    DeviceNotFound,
    LibraryCreationFailed,
    FunctionNotFound,
    PipelineCreationFailed,
    BufferCreationFailed,
    TextureCreationFailed,
    CommandBufferCreationFailed,
    ShaderCompilationFailed,
};

/// Opaque Metal object handles (re-export from bridge)
pub const Device = c.MetalDevice;
pub const CommandQueue = c.MetalCommandQueue;
pub const Library = c.MetalLibrary;
pub const Function = c.MetalFunction;
pub const Pipeline = c.MetalPipeline;
pub const CommandBuffer = c.MetalCommandBuffer;
pub const CommandEncoder = c.MetalCommandEncoder;
pub const Texture = c.MetalTexture;
pub const Buffer = c.MetalBuffer;

/// Check if Metal is available on this system
pub fn isAvailable() bool {
    return c.metal_is_available();
}

/// Metal Device wrapper
pub const MetalDevice = struct {
    handle: Device,

    pub fn init() MetalError!MetalDevice {
        const device = c.metal_create_device() orelse return MetalError.DeviceNotFound;
        return .{ .handle = device };
    }

    pub fn deinit(self: *MetalDevice) void {
        c.metal_release_device(self.handle);
    }

    pub fn createCommandQueue(self: *MetalDevice) MetalError!MetalCommandQueue {
        const queue = c.metal_create_command_queue(self.handle) orelse return MetalError.CommandBufferCreationFailed;
        return .{ .handle = queue };
    }

    pub fn createLibraryFromSource(self: *MetalDevice, source: [:0]const u8) MetalError!MetalLibrary {
        var error_msg: [*c]u8 = null;
        const library = c.metal_create_library_from_source(self.handle, source.ptr, @ptrCast(&error_msg)) orelse {
            if (error_msg) |msg| {
                std.debug.print("Metal library error: {s}\n", .{msg});
                std.c.free(msg);
            }
            return MetalError.LibraryCreationFailed;
        };
        return .{ .handle = library };
    }

    pub fn createBuffer(self: *MetalDevice, size: u32) MetalError!MetalBuffer {
        const buffer = c.metal_create_buffer(self.handle, size) orelse return MetalError.BufferCreationFailed;
        return .{ .handle = buffer };
    }

    pub fn createTexture(self: *MetalDevice, width: u32, height: u32, writable: bool) MetalError!MetalTexture {
        const texture = c.metal_create_texture(self.handle, width, height, writable) orelse return MetalError.TextureCreationFailed;
        return .{ .handle = texture };
    }
};

/// Metal Command Queue wrapper
pub const MetalCommandQueue = struct {
    handle: CommandQueue,

    pub fn deinit(self: *MetalCommandQueue) void {
        c.metal_release_command_queue(self.handle);
    }

    pub fn createCommandBuffer(self: *MetalCommandQueue) MetalError!MetalCommandBuffer {
        const buffer = c.metal_create_command_buffer(self.handle) orelse return MetalError.CommandBufferCreationFailed;
        return .{ .handle = buffer };
    }
};

/// Metal Library wrapper
pub const MetalLibrary = struct {
    handle: Library,

    pub fn deinit(self: *MetalLibrary) void {
        c.metal_release_library(self.handle);
    }

    pub fn createFunction(self: *MetalLibrary, name: [:0]const u8) MetalError!MetalFunction {
        const function = c.metal_create_function(self.handle, name.ptr) orelse return MetalError.FunctionNotFound;
        return .{ .handle = function };
    }
};

/// Metal Function wrapper
pub const MetalFunction = struct {
    handle: Function,

    pub fn deinit(self: *MetalFunction) void {
        c.metal_release_function(self.handle);
    }

    pub fn createPipeline(self: *MetalFunction, device: *MetalDevice) MetalError!MetalPipeline {
        var error_msg: [*c]u8 = null;
        const pipeline = c.metal_create_pipeline(device.handle, self.handle, @ptrCast(&error_msg)) orelse {
            if (error_msg) |msg| {
                std.debug.print("Metal pipeline error: {s}\n", .{msg});
                std.c.free(msg);
            }
            return MetalError.PipelineCreationFailed;
        };
        return .{ .handle = pipeline };
    }
};

/// Metal Pipeline wrapper
pub const MetalPipeline = struct {
    handle: Pipeline,

    pub fn deinit(self: *MetalPipeline) void {
        c.metal_release_pipeline(self.handle);
    }
};

/// Metal Buffer wrapper
pub const MetalBuffer = struct {
    handle: Buffer,

    pub fn deinit(self: *MetalBuffer) void {
        c.metal_release_buffer(self.handle);
    }

    pub fn upload(self: *MetalBuffer, data: []const u8) void {
        c.metal_buffer_upload(self.handle, data.ptr, @intCast(data.len));
    }

    pub fn download(self: *MetalBuffer, data: []u8) void {
        c.metal_buffer_download(self.handle, data.ptr, @intCast(data.len));
    }
};

/// Metal Texture wrapper
pub const MetalTexture = struct {
    handle: Texture,

    pub fn deinit(self: *MetalTexture) void {
        c.metal_release_texture(self.handle);
    }

    pub fn upload(self: *MetalTexture, data: []const u8, width: u32, height: u32, bytes_per_row: u32) void {
        c.metal_texture_upload(self.handle, data.ptr, width, height, bytes_per_row);
    }

    pub fn download(self: *MetalTexture, data: []u8, width: u32, height: u32, bytes_per_row: u32) void {
        c.metal_texture_download(self.handle, data.ptr, width, height, bytes_per_row);
    }
};

/// Metal Command Buffer wrapper
pub const MetalCommandBuffer = struct {
    handle: CommandBuffer,

    pub fn deinit(self: *MetalCommandBuffer) void {
        c.metal_release_command_buffer(self.handle);
    }

    pub fn commit(self: *MetalCommandBuffer) void {
        c.metal_commit_command_buffer(self.handle);
    }

    pub fn waitForCompletion(self: *MetalCommandBuffer) void {
        c.metal_wait_for_completion(self.handle);
    }

    pub fn createComputeEncoder(self: *MetalCommandBuffer) MetalError!MetalComputeEncoder {
        const encoder = c.metal_create_compute_encoder(self.handle) orelse return MetalError.CommandBufferCreationFailed;
        return .{ .handle = encoder };
    }

    pub fn createBlitEncoder(self: *MetalCommandBuffer) MetalError!MetalBlitEncoder {
        const encoder = c.metal_create_blit_encoder(self.handle) orelse return MetalError.CommandBufferCreationFailed;
        return .{ .handle = encoder };
    }
};

/// Metal Compute Encoder wrapper
pub const MetalComputeEncoder = struct {
    handle: CommandEncoder,

    pub fn deinit(self: *MetalComputeEncoder) void {
        c.metal_release_encoder(self.handle);
    }

    pub fn setPipeline(self: *MetalComputeEncoder, pipeline: *MetalPipeline) void {
        c.metal_encoder_set_pipeline(self.handle, pipeline.handle);
    }

    pub fn setTexture(self: *MetalComputeEncoder, texture: *MetalTexture, index: u32) void {
        c.metal_encoder_set_texture(self.handle, texture.handle, index);
    }

    pub fn setBuffer(self: *MetalComputeEncoder, buffer: *MetalBuffer, index: u32) void {
        c.metal_encoder_set_buffer(self.handle, buffer.handle, index);
    }

    pub fn setBytes(self: *MetalComputeEncoder, bytes: *const anyopaque, length: u32, index: u32) void {
        c.metal_encoder_set_bytes(self.handle, bytes, length, index);
    }

    pub fn dispatch(self: *MetalComputeEncoder, grid_w: u32, grid_h: u32, group_w: u32, group_h: u32) void {
        c.metal_encoder_dispatch(self.handle, grid_w, grid_h, group_w, group_h);
    }

    pub fn end(self: *MetalComputeEncoder) void {
        c.metal_encoder_end(self.handle);
    }
};

/// Metal Blit Encoder wrapper
pub const MetalBlitEncoder = struct {
    handle: CommandEncoder,

    pub fn deinit(self: *MetalBlitEncoder) void {
        c.metal_release_encoder(self.handle);
    }

    pub fn copyBuffer(self: *MetalBlitEncoder, src: *MetalBuffer, dst: *MetalBuffer, size: u32) void {
        c.metal_blit_copy_buffer(self.handle, src.handle, dst.handle, size);
    }

    pub fn end(self: *MetalBlitEncoder) void {
        c.metal_encoder_end(self.handle);
    }
};

test "Metal availability" {
    // On macOS, Metal should always be available
    try std.testing.expect(isAvailable());
}

test "Metal device creation" {
    if (!isAvailable()) return error.SkipZigTest;

    var device = try MetalDevice.init();
    defer device.deinit();

    try std.testing.expect(device.handle != null);
}

test "Command queue creation" {
    if (!isAvailable()) return error.SkipZigTest;

    var device = try MetalDevice.init();
    defer device.deinit();

    var queue = try device.createCommandQueue();
    defer queue.deinit();

    try std.testing.expect(queue.handle != null);
}

test "Simple compute shader" {
    if (!isAvailable()) return error.SkipZigTest;

    var device = try MetalDevice.init();
    defer device.deinit();

    var queue = try device.createCommandQueue();
    defer queue.deinit();

    const shader =
        \\#include <metal_stdlib>
        \\using namespace metal;
        \\kernel void double_values(
        \\    device float* data [[buffer(0)]],
        \\    uint index [[thread_position_in_grid]])
        \\{
        \\    data[index] *= 2.0;
        \\}
    ;

    var library = try device.createLibraryFromSource(shader);
    defer library.deinit();

    var function = try library.createFunction("double_values");
    defer function.deinit();

    var pipeline = try function.createPipeline(&device);
    defer pipeline.deinit();

    // Create and fill buffer
    var buffer = try device.createBuffer(16);
    defer buffer.deinit();

    var data = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    buffer.upload(std.mem.sliceAsBytes(&data));

    // Execute
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

    // Verify
    buffer.download(std.mem.sliceAsBytes(&data));
    try std.testing.expectEqual(@as(f32, 2.0), data[0]);
    try std.testing.expectEqual(@as(f32, 4.0), data[1]);
    try std.testing.expectEqual(@as(f32, 6.0), data[2]);
    try std.testing.expectEqual(@as(f32, 8.0), data[3]);
}
