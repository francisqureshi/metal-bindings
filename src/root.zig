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

/// Resource storage mode for Metal buffers.
///
/// Determines how memory is shared between CPU and GPU:
/// - `.shared`: CPU and GPU both have direct access (default, easiest)
/// - `.managed`: Automatic synchronization between CPU and GPU copies
/// - `.private`: GPU-only memory (fastest for GPU operations)
///
/// Example:
/// ```zig
/// // Shared mode - direct CPU/GPU access
/// var buf = try device.createBufferWithOptions(1024, .shared);
/// defer buf.deinit();
///
/// // Private mode - fastest for GPU-only data
/// var gpu_buf = try device.createBufferWithOptions(1024, .private);
/// defer gpu_buf.deinit();
/// ```
pub const ResourceStorageMode = enum(u32) {
    shared = c.RESOURCE_STORAGE_MODE_SHARED,
    managed = c.RESOURCE_STORAGE_MODE_MANAGED,
    private = c.RESOURCE_STORAGE_MODE_PRIVATE,
};

/// Check if Metal is available on this system.
/// Returns true if Metal GPU acceleration is supported.
///
/// Example:
/// ```zig
/// if (!metal.isAvailable()) {
///     std.debug.print("Metal not supported\n", .{});
///     return;
/// }
/// ```
pub fn isAvailable() bool {
    return c.metal_is_available();
}

/// Get the number of Metal-capable GPU devices available.
///
/// Example:
/// ```zig
/// const count = metal.getDeviceCount();
/// std.debug.print("Found {d} GPU(s)\n", .{count});
/// ```
pub fn getDeviceCount() u32 {
    return c.metal_get_device_count();
}

/// Get all available Metal devices.
/// Caller owns the returned slice and must free it.
///
/// Example:
/// ```zig
/// var gpa = std.heap.GeneralPurposeAllocator(.{}){};
/// const allocator = gpa.allocator();
///
/// const devices = try metal.getAllDevices(allocator);
/// defer allocator.free(devices);
///
/// for (devices) |*dev| {
///     defer dev.deinit();
///     if (dev.getName()) |name| {
///         std.debug.print("GPU: {s}\n", .{name});
///     }
/// }
/// ```
pub fn getAllDevices(allocator: std.mem.Allocator) ![]MetalDevice {
    const count = getDeviceCount();
    if (count == 0) return &[_]MetalDevice{};

    var devices = try allocator.alloc(MetalDevice, count);
    for (0..count) |i| {
        const handle = c.metal_get_device_at_index(@intCast(i)) orelse return MetalError.DeviceNotFound;
        devices[i] = .{ .handle = handle };
    }
    return devices;
}

/// Represents a Metal GPU device.
/// Provides access to GPU hardware for compute operations.
///
/// Example:
/// ```zig
/// var device = try metal.MetalDevice.init();
/// defer device.deinit();
///
/// var queue = try device.createCommandQueue();
/// defer queue.deinit();
/// ```
pub const MetalDevice = struct {
    handle: Device,

    /// Create a Metal device using the system default GPU.
    ///
    /// Example:
    /// ```zig
    /// var device = try metal.MetalDevice.init();
    /// defer device.deinit();
    /// ```
    pub fn init() MetalError!MetalDevice {
        const device = c.metal_create_device() orelse return MetalError.DeviceNotFound;
        return .{ .handle = device };
    }

    /// Create a Metal device by index.
    /// Use `getDeviceCount()` to see how many devices are available.
    ///
    /// Example:
    /// ```zig
    /// // Get second GPU if available
    /// var device = try metal.MetalDevice.initAtIndex(1);
    /// defer device.deinit();
    /// ```
    pub fn initAtIndex(index: u32) MetalError!MetalDevice {
        const device = c.metal_get_device_at_index(index) orelse return MetalError.DeviceNotFound;
        return .{ .handle = device };
    }

    /// Release the Metal device.
    pub fn deinit(self: *MetalDevice) void {
        c.metal_release_device(self.handle);
    }

    /// Get the device name (e.g., "Apple M1 Pro").
    /// Caller must free the returned string with `std.c.free()`.
    ///
    /// Example:
    /// ```zig
    /// if (device.getName()) |name| {
    ///     defer std.c.free(@constCast(name.ptr));
    ///     std.debug.print("GPU: {s}\n", .{name});
    /// }
    /// ```
    pub fn getName(self: *const MetalDevice) ?[:0]const u8 {
        const name_ptr = c.metal_device_get_name(self.handle);
        if (name_ptr == null) return null;
        return std.mem.span(name_ptr);
    }

    /// Create a command queue for submitting GPU work.
    ///
    /// Example:
    /// ```zig
    /// var queue = try device.createCommandQueue();
    /// defer queue.deinit();
    /// ```
    pub fn createCommandQueue(self: *MetalDevice) MetalError!MetalCommandQueue {
        const queue = c.metal_create_command_queue(self.handle) orelse return MetalError.CommandBufferCreationFailed;
        return .{ .handle = queue };
    }

    /// Compile a Metal shader from source code at runtime.
    ///
    /// Example:
    /// ```zig
    /// const shader =
    ///     \\#include <metal_stdlib>
    ///     \\using namespace metal;
    ///     \\kernel void add(device float* data [[buffer(0)]], uint i [[thread_position_in_grid]]) {
    ///     \\    data[i] += 1.0;
    ///     \\}
    /// ;
    /// var library = try device.createLibraryFromSource(shader);
    /// defer library.deinit();
    /// ```
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

    /// Create a GPU buffer with shared storage mode (CPU/GPU accessible).
    ///
    /// Example:
    /// ```zig
    /// var buffer = try device.createBuffer(1024);
    /// defer buffer.deinit();
    ///
    /// // Direct access to GPU memory
    /// const data = buffer.getContentsAs(f32) orelse return error.Failed;
    /// data[0] = 42.0;
    /// ```
    pub fn createBuffer(self: *MetalDevice, size: u32) MetalError!MetalBuffer {
        const buffer = c.metal_create_buffer(self.handle, size) orelse return MetalError.BufferCreationFailed;
        return .{ .handle = buffer, .len = size };
    }

    /// Create a GPU buffer with specific storage mode.
    ///
    /// Example:
    /// ```zig
    /// // Private mode - fastest for GPU-only operations
    /// var buffer = try device.createBufferWithOptions(1024, .private);
    /// defer buffer.deinit();
    /// ```
    pub fn createBufferWithOptions(self: *MetalDevice, size: u32, mode: ResourceStorageMode) MetalError!MetalBuffer {
        const buffer = c.metal_create_buffer_with_options(self.handle, size, @intFromEnum(mode)) orelse return MetalError.BufferCreationFailed;
        return .{ .handle = buffer, .len = size };
    }

    /// Create a 2D texture for image processing.
    ///
    /// Example:
    /// ```zig
    /// var texture = try device.createTexture(1920, 1080, true);
    /// defer texture.deinit();
    /// ```
    pub fn createTexture(self: *MetalDevice, width: u32, height: u32, writable: bool) MetalError!MetalTexture {
        const texture = c.metal_create_texture(self.handle, width, height, writable) orelse return MetalError.TextureCreationFailed;
        return .{ .handle = texture };
    }
};

/// Command queue for submitting GPU work.
/// Manages execution of command buffers on the GPU.
///
/// Example:
/// ```zig
/// var queue = try device.createCommandQueue();
/// defer queue.deinit();
///
/// var cmd_buffer = try queue.createCommandBuffer();
/// defer cmd_buffer.deinit();
/// ```
pub const MetalCommandQueue = struct {
    handle: CommandQueue,

    /// Release the command queue.
    pub fn deinit(self: *MetalCommandQueue) void {
        c.metal_release_command_queue(self.handle);
    }

    /// Create a command buffer for recording GPU commands.
    ///
    /// Example:
    /// ```zig
    /// var cmd_buffer = try queue.createCommandBuffer();
    /// defer cmd_buffer.deinit();
    ///
    /// var encoder = try cmd_buffer.createComputeEncoder();
    /// // ... encode commands
    /// encoder.end();
    ///
    /// cmd_buffer.commit();
    /// cmd_buffer.waitForCompletion();
    /// ```
    pub fn createCommandBuffer(self: *MetalCommandQueue) MetalError!MetalCommandBuffer {
        const buffer = c.metal_create_command_buffer(self.handle) orelse return MetalError.CommandBufferCreationFailed;
        return .{ .handle = buffer };
    }
};

/// Compiled Metal shader library.
/// Contains one or more kernel functions.
///
/// Example:
/// ```zig
/// var library = try device.createLibraryFromSource(shader_source);
/// defer library.deinit();
///
/// var function = try library.createFunction("my_kernel");
/// defer function.deinit();
/// ```
pub const MetalLibrary = struct {
    handle: Library,

    /// Release the shader library.
    pub fn deinit(self: *MetalLibrary) void {
        c.metal_release_library(self.handle);
    }

    /// Get a kernel function by name from this library.
    ///
    /// Example:
    /// ```zig
    /// var function = try library.createFunction("add_arrays");
    /// defer function.deinit();
    /// ```
    pub fn createFunction(self: *MetalLibrary, name: [:0]const u8) MetalError!MetalFunction {
        const function = c.metal_create_function(self.handle, name.ptr) orelse return MetalError.FunctionNotFound;
        return .{ .handle = function };
    }
};

/// Metal kernel function.
/// Represents a single compute shader entry point.
///
/// Example:
/// ```zig
/// var function = try library.createFunction("my_kernel");
/// defer function.deinit();
///
/// var pipeline = try function.createPipeline(&device);
/// defer pipeline.deinit();
/// ```
pub const MetalFunction = struct {
    handle: Function,

    /// Release the function.
    pub fn deinit(self: *MetalFunction) void {
        c.metal_release_function(self.handle);
    }

    /// Create a compute pipeline from this function.
    /// The pipeline is the GPU-ready, compiled state needed for execution.
    ///
    /// Example:
    /// ```zig
    /// var pipeline = try function.createPipeline(&device);
    /// defer pipeline.deinit();
    ///
    /// // Use pipeline in encoder
    /// encoder.setPipeline(&pipeline);
    /// ```
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

/// Compute pipeline state.
/// Represents a compiled, GPU-ready shader program.
pub const MetalPipeline = struct {
    handle: Pipeline,

    /// Release the pipeline.
    pub fn deinit(self: *MetalPipeline) void {
        c.metal_release_pipeline(self.handle);
    }
};

/// Metal Buffer wrapper.
/// Represents GPU memory that can be accessed by compute shaders.
///
/// Example:
/// ```zig
/// var buffer = try device.createBuffer(1024);
/// defer buffer.deinit();
///
/// // Direct access
/// const data = buffer.getContentsAs(f32) orelse return error.Failed;
/// data[0] = 42.0;
/// ```
pub const MetalBuffer = struct {
    handle: Buffer,
    len: u32,

    /// Release the buffer.
    pub fn deinit(self: *MetalBuffer) void {
        c.metal_release_buffer(self.handle);
    }

    /// Upload data to the buffer (copies from CPU to GPU).
    ///
    /// Example:
    /// ```zig
    /// var data = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    /// buffer.upload(std.mem.sliceAsBytes(&data));
    /// ```
    pub fn upload(self: *MetalBuffer, data: []const u8) void {
        c.metal_buffer_upload(self.handle, data.ptr, @intCast(data.len));
    }

    /// Download data from the buffer (copies from GPU to CPU).
    ///
    /// Example:
    /// ```zig
    /// var result: [4]f32 = undefined;
    /// buffer.download(std.mem.sliceAsBytes(&result));
    /// ```
    pub fn download(self: *MetalBuffer, data: []u8) void {
        c.metal_buffer_download(self.handle, data.ptr, @intCast(data.len));
    }

    /// Get the buffer contents as a raw byte slice (direct GPU memory access).
    /// Only works for shared storage mode buffers.
    ///
    /// Example:
    /// ```zig
    /// const bytes = buffer.getContents() orelse return error.Failed;
    /// bytes[0] = 42;
    /// ```
    pub fn getContents(self: *MetalBuffer) ?[]u8 {
        const ptr = c.metal_buffer_get_contents(self.handle);
        if (ptr == null) return null;
        const bytes: [*]u8 = @ptrCast(@alignCast(ptr));
        return bytes[0..self.len];
    }

    /// Get the buffer contents as a typed slice (direct GPU memory access).
    /// Only works for shared storage mode buffers.
    ///
    /// Example:
    /// ```zig
    /// const data = buffer.getContentsAs(f32) orelse return error.Failed;
    /// for (data, 0..) |*val, i| {
    ///     val.* = @floatFromInt(i);
    /// }
    /// ```
    pub fn getContentsAs(self: *MetalBuffer, comptime T: type) ?[]T {
        const bytes = self.getContents() orelse return null;
        return @alignCast(std.mem.bytesAsSlice(T, bytes));
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

    var buffer = try device.createBuffer(16);
    defer buffer.deinit();

    var data = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    buffer.upload(std.mem.sliceAsBytes(&data));

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

    buffer.download(std.mem.sliceAsBytes(&data));
    try std.testing.expectEqual(@as(f32, 2.0), data[0]);
    try std.testing.expectEqual(@as(f32, 4.0), data[1]);
    try std.testing.expectEqual(@as(f32, 6.0), data[2]);
    try std.testing.expectEqual(@as(f32, 8.0), data[3]);
}

test "Direct buffer access with getContentsAs" {
    if (!isAvailable()) return error.SkipZigTest;

    var device = try MetalDevice.init();
    defer device.deinit();

    var buffer = try device.createBuffer(16);
    defer buffer.deinit();

    const data = buffer.getContentsAs(f32) orelse return error.BufferAccessFailed;
    try std.testing.expectEqual(@as(usize, 4), data.len);

    data[0] = 10.0;
    data[1] = 20.0;
    data[2] = 30.0;
    data[3] = 40.0;

    try std.testing.expectEqual(@as(f32, 10.0), data[0]);
    try std.testing.expectEqual(@as(f32, 20.0), data[1]);
    try std.testing.expectEqual(@as(f32, 30.0), data[2]);
    try std.testing.expectEqual(@as(f32, 40.0), data[3]);
}

test "Device enumeration" {
    if (!isAvailable()) return error.SkipZigTest;

    const count = getDeviceCount();
    try std.testing.expect(count > 0);

    var device = try MetalDevice.initAtIndex(0);
    defer device.deinit();

    const name = device.getName();
    try std.testing.expect(name != null);
}
