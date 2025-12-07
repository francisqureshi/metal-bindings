const std = @import("std");
const metal = @import("metal_bindings");

pub fn main() !void {
    std.debug.print("Metal Bindings Example\n", .{});
    std.debug.print("======================\n\n", .{});

    // Check Metal availability
    if (!metal.isAvailable()) {
        std.debug.print("ERROR: Metal is not available on this system\n", .{});
        return;
    }
    std.debug.print("✓ Metal is available\n", .{});

    // Create device
    var device = try metal.MetalDevice.init();
    defer device.deinit();
    std.debug.print("✓ Created Metal device\n", .{});

    // Create command queue
    var queue = try device.createCommandQueue();
    defer queue.deinit();
    std.debug.print("✓ Created command queue\n", .{});

    // Simple compute shader example
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

    // Create library from source
    var library = try device.createLibraryFromSource(shader_source);
    defer library.deinit();
    std.debug.print("✓ Compiled shader library\n", .{});

    // Create function
    var function = try library.createFunction("add_arrays");
    defer function.deinit();
    std.debug.print("✓ Created compute function\n", .{});

    // Create pipeline
    var pipeline = try function.createPipeline(&device);
    defer pipeline.deinit();
    std.debug.print("✓ Created compute pipeline\n", .{});

    // Create buffers
    const array_length = 1024;
    const buffer_size = array_length * @sizeOf(f32);

    var bufferA = try device.createBuffer(buffer_size);
    defer bufferA.deinit();
    var bufferB = try device.createBuffer(buffer_size);
    defer bufferB.deinit();
    var bufferResult = try device.createBuffer(buffer_size);
    defer bufferResult.deinit();
    std.debug.print("✓ Created 3 buffers ({d} bytes each)\n", .{buffer_size});

    // Fill input buffers with test data
    var dataA: [array_length]f32 = undefined;
    var dataB: [array_length]f32 = undefined;
    for (0..array_length) |i| {
        dataA[i] = @floatFromInt(i);
        dataB[i] = @floatFromInt(i * 2);
    }

    bufferA.upload(std.mem.sliceAsBytes(&dataA));
    bufferB.upload(std.mem.sliceAsBytes(&dataB));
    std.debug.print("✓ Uploaded test data\n", .{});

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
    std.debug.print("✓ Executed compute shader\n", .{});

    // Read back results
    var result: [array_length]f32 = undefined;
    bufferResult.download(std.mem.sliceAsBytes(&result));

    // Verify results
    var all_correct = true;
    for (0..array_length) |i| {
        const expected = dataA[i] + dataB[i];
        if (result[i] != expected) {
            std.debug.print("ERROR at index {d}: got {d}, expected {d}\n", .{ i, result[i], expected });
            all_correct = false;
            break;
        }
    }

    if (all_correct) {
        std.debug.print("✓ Results verified - GPU computed correct array addition\n\n", .{});

        // Display 5x5 grid of results
        std.debug.print("First 25 results (5x5 grid):\n", .{});
        std.debug.print("Format: A[i] + B[i] = Result[i]\n\n", .{});

        for (0..5) |row| {
            for (0..5) |col| {
                const idx = row * 5 + col;
                std.debug.print("{d:3.0} +{d:3.0} ={d:4.0}    ", .{ dataA[idx], dataB[idx], result[idx] });
            }
            std.debug.print("\n", .{});
        }

        std.debug.print("\n✅ All tests passed!\n", .{});
    } else {
        std.debug.print("\n❌ Verification failed\n", .{});
    }
}
