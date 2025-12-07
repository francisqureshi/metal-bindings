const std = @import("std");
const metal = @import("metal_bindings");

// test jj again

pub fn main() !void {
    std.debug.print("\n╔════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║      Metal Bindings for Zig - Demo            ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════╝\n\n", .{});

    // Check Metal availability
    if (!metal.isAvailable()) {
        std.debug.print("ERROR: Metal is not available on this system\n", .{});
        return;
    }
    std.debug.print("✓ Metal is available\n\n", .{});

    // Device enumeration
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("Available Metal Devices:\n", .{});
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    const device_count = metal.getDeviceCount();
    std.debug.print("Found {d} device(s):\n", .{device_count});
    for (0..device_count) |i| {
        var dev = try metal.MetalDevice.initAtIndex(@intCast(i));
        defer dev.deinit();
        if (dev.getName()) |name| {
            std.debug.print("  [{d}] {s}\n", .{ i, name });
            std.c.free(@constCast(name.ptr));
        }
    }
    std.debug.print("\n", .{});

    // Create device
    var device = try metal.MetalDevice.init();
    defer device.deinit();
    std.debug.print("✓ Using default Metal device\n", .{});

    // Create command queue
    var queue = try device.createCommandQueue();
    defer queue.deinit();
    std.debug.print("✓ Created command queue\n\n", .{});

    // Compute shader example
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("Compute Shader Example (Array Addition)\n", .{});
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});

    const shader_source =
        \\#include <metal_stdlib>
        \\using namespace metal;
        \\
        \\kernel void add_arrays(
        \\    const device float* inA [[buffer(0)]],
        \\    const device float* inB [[buffer(1)]],
        \\    device float* result [[buffer(2)]],
        \\    uint index [[thread_position_in_grid]])
        \\{
        \\    result[index] = inA[index] + inB[index];
        \\}
    ;

    var library = try device.createLibraryFromSource(shader_source);
    defer library.deinit();
    std.debug.print("✓ Compiled shader from source\n", .{});

    var function = try library.createFunction("add_arrays");
    defer function.deinit();
    std.debug.print("✓ Extracted kernel function\n", .{});

    var pipeline = try function.createPipeline(&device);
    defer pipeline.deinit();
    std.debug.print("✓ Created compute pipeline\n", .{});

    // Create buffers with shared storage (allows direct CPU/GPU access)
    const array_length = 1024;
    const buffer_size = array_length * @sizeOf(f32);

    var bufferA = try device.createBuffer(buffer_size);
    defer bufferA.deinit();
    var bufferB = try device.createBuffer(buffer_size);
    defer bufferB.deinit();
    var bufferResult = try device.createBuffer(buffer_size);
    defer bufferResult.deinit();
    std.debug.print("✓ Created 3 buffers ({d} bytes each)\n", .{buffer_size});

    // Use direct buffer access - write straight to GPU memory!
    std.debug.print("✓ Using direct buffer access (getContentsAs)\n", .{});
    const dataA = bufferA.getContentsAs(f32) orelse return error.BufferAccessFailed;
    const dataB = bufferB.getContentsAs(f32) orelse return error.BufferAccessFailed;

    for (dataA, dataB, 0..) |*a, *b, i| {
        a.* = @floatFromInt(i);
        b.* = @floatFromInt(i * 2);
    }
    std.debug.print("✓ Filled buffers with test data\n", .{});

    // Create command buffer
    var commandBuffer = try queue.createCommandBuffer();
    defer commandBuffer.deinit();

    // Create compute encoder
    var encoder = try commandBuffer.createComputeEncoder();
    defer encoder.deinit();

    encoder.setPipeline(&pipeline);
    encoder.setBuffer(&bufferA, 0);
    encoder.setBuffer(&bufferB, 1);
    encoder.setBuffer(&bufferResult, 2);

    // Dispatch compute (1D grid)
    const threadGroupSize: u32 = 64;
    const numThreadgroups: u32 = (array_length + threadGroupSize - 1) / threadGroupSize;
    encoder.dispatch(numThreadgroups, 1, threadGroupSize, 1);
    encoder.end();

    // Execute
    commandBuffer.commit();
    commandBuffer.waitForCompletion();
    std.debug.print("✓ Executed compute shader on GPU\n", .{});

    // Read results using direct buffer access (no download needed!)
    const result = bufferResult.getContentsAs(f32) orelse return error.BufferAccessFailed;

    // Verify results
    var all_correct = true;
    for (dataA, dataB, result, 0..) |a, b, r, i| {
        const expected = a + b;
        if (r != expected) {
            std.debug.print("ERROR at index {d}: got {d}, expected {d}\n", .{ i, r, expected });
            all_correct = false;
            break;
        }
    }

    if (all_correct) {
        std.debug.print("✓ Results verified - all correct!\n\n", .{});

        // Display 5x5 grid of results
        std.debug.print("Sample results (5x5 grid):\n", .{});
        std.debug.print("Format: A[i] + B[i] = Result[i]\n\n", .{});

        for (0..5) |row| {
            for (0..5) |col| {
                const idx = row * 5 + col;
                std.debug.print("{d:3.0} +{d:3.0} ={d:4.0}    ", .{ dataA[idx], dataB[idx], result[idx] });
            }
            std.debug.print("\n", .{});
        }
    } else {
        std.debug.print("\n❌ Verification failed\n", .{});
        return;
    }

    // Demonstrate direct GPU memory slice operations
    std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("Direct GPU Memory Slice Operations\n", .{});
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});

    const demo_size = 20 * @sizeOf(f32);
    var demo_buf = try device.createBuffer(demo_size);
    defer demo_buf.deinit();

    const gpu_slice = demo_buf.getContentsAs(f32) orelse return error.BufferAccessFailed;
    std.debug.print("Buffer size: {d} floats\n\n", .{gpu_slice.len});

    // Example 1: Direct write to GPU memory
    std.debug.print("1. Writing directly to GPU memory:\n", .{});
    for (gpu_slice, 0..) |*val, i| {
        val.* = @as(f32, @floatFromInt(i)) * 3.14;
    }
    std.debug.print("   Written: ", .{});
    for (gpu_slice[0..10]) |val| {
        std.debug.print("{d:.2} ", .{val});
    }
    std.debug.print("...\n\n", .{});

    // Example 2: Direct read from GPU memory
    std.debug.print("2. Reading directly from GPU memory:\n", .{});
    std.debug.print("   gpu_slice[5] = {d:.2}\n", .{gpu_slice[5]});
    std.debug.print("   gpu_slice[15] = {d:.2}\n\n", .{gpu_slice[15]});

    // Example 3: Modify in-place using slice operations
    std.debug.print("3. In-place modification (double first 5 values):\n", .{});
    for (gpu_slice[0..5]) |*val| {
        val.* *= 2.0;
    }
    std.debug.print("   Modified: ", .{});
    for (gpu_slice[0..10]) |val| {
        std.debug.print("{d:.2} ", .{val});
    }
    std.debug.print("...\n\n", .{});

    // Example 4: Fill a range with a constant
    std.debug.print("4. Fill range [10..15] with 99.0:\n", .{});
    @memset(gpu_slice[10..15], 99.0);
    std.debug.print("   Result: ", .{});
    for (gpu_slice[8..17]) |val| {
        std.debug.print("{d:.1} ", .{val});
    }
    std.debug.print("\n\n", .{});

    // Example 5: Copy between slices
    std.debug.print("5. Copy first 3 elements to positions [16..19]:\n", .{});
    @memcpy(gpu_slice[16..19], gpu_slice[0..3]);
    std.debug.print("   Source [0..3]:  ", .{});
    for (gpu_slice[0..3]) |val| {
        std.debug.print("{d:.2} ", .{val});
    }
    std.debug.print("\n   Dest [16..19]: ", .{});
    for (gpu_slice[16..19]) |val| {
        std.debug.print("{d:.2} ", .{val});
    }
    std.debug.print("\n\n", .{});

    // Example 6: Iterate and sum
    std.debug.print("6. Calculate sum of all values:\n", .{});
    var sum: f32 = 0.0;
    for (gpu_slice) |val| {
        sum += val;
    }
    std.debug.print("   Sum = {d:.2}\n\n", .{sum});

    // Demonstrate resource storage modes
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("Resource Storage Modes\n", .{});
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});

    var shared_buf = try device.createBufferWithOptions(1024, .shared);
    defer shared_buf.deinit();
    std.debug.print("✓ Shared buffer    - CPU + GPU can both access\n", .{});

    var private_buf = try device.createBufferWithOptions(1024, .private);
    defer private_buf.deinit();
    std.debug.print("✓ Private buffer   - GPU only (fastest)\n", .{});

    var managed_buf = try device.createBufferWithOptions(1024, .managed);
    defer managed_buf.deinit();
    std.debug.print("✓ Managed buffer   - Auto-sync between CPU/GPU\n", .{});

    std.debug.print("\n✅ All features demonstrated successfully!\n\n", .{});
}
