const std = @import("std");
const ofx = @import("ofx");

// Metal C bridge bindings
const c = @cImport({
    @cInclude("metal_bridge.h");
});

pub const GPUError = error{
    DeviceNotFound,
    CommandQueueCreationFailed,
    LibraryCreationFailed,
    FunctionNotFound,
    PipelineCreationFailed,
    BufferCreationFailed,
    TextureCreationFailed,
    CommandBufferCreationFailed,
};

const MetalContext = struct {
    device: c.MetalDevice,
    command_queue: c.MetalCommandQueue,
    pipeline: c.MetalPipeline,
    ndi_pipeline: c.MetalPipeline,
    ndi_texture_pipeline: c.MetalPipeline, // Fast path: texture → BGRA
    p216_pipeline: c.MetalPipeline, // 10-bit 4:2:2 P216 conversion

    pub fn isAvailable() bool {
        return c.metal_is_available();
    }

    pub fn init() !MetalContext {
        const device = c.metal_create_device() orelse return GPUError.DeviceNotFound;
        errdefer c.metal_release_device(device);

        const command_queue = c.metal_create_command_queue(device) orelse {
            return GPUError.CommandQueueCreationFailed;
        };
        errdefer c.metal_release_command_queue(command_queue);

        // Load the shader library from embedded source
        const shader_source = @embedFile("shaders/invert.metal");
        var error_msg: [*c]u8 = null;
        const library = c.metal_create_library_from_source(device, shader_source, @ptrCast(&error_msg)) orelse {
            if (error_msg != null) {
                std.debug.print("Metal library error: {s}\n", .{error_msg});
                std.c.free(error_msg);
            }
            return GPUError.LibraryCreationFailed;
        };
        defer c.metal_release_library(library);

        const function = c.metal_create_function(library, "invertKernel") orelse {
            return GPUError.FunctionNotFound;
        };
        defer c.metal_release_function(function);

        const pipeline = c.metal_create_pipeline(device, function, @ptrCast(&error_msg)) orelse {
            if (error_msg != null) {
                std.debug.print("Metal pipeline error: {s}\n", .{error_msg});
                std.c.free(error_msg);
            }
            return GPUError.PipelineCreationFailed;
        };

        // Create NDI conversion pipeline
        const ndi_shader_source = @embedFile("ndi_convert.metal");
        const ndi_library = c.metal_create_library_from_source(device, ndi_shader_source, @ptrCast(&error_msg)) orelse {
            if (error_msg != null) {
                std.debug.print("NDI Metal library error: {s}\n", .{error_msg});
                std.c.free(error_msg);
            }
            return GPUError.LibraryCreationFailed;
        };
        defer c.metal_release_library(ndi_library);

        const ndi_function = c.metal_create_function(ndi_library, "convert_rgba_to_bgra") orelse {
            return GPUError.FunctionNotFound;
        };
        defer c.metal_release_function(ndi_function);

        const ndi_pipeline = c.metal_create_pipeline(device, ndi_function, @ptrCast(&error_msg)) orelse {
            if (error_msg != null) {
                std.debug.print("NDI Metal pipeline error: {s}\n", .{error_msg});
                std.c.free(error_msg);
            }
            return GPUError.PipelineCreationFailed;
        };

        // Create texture-based NDI conversion pipeline (fast path)
        const ndi_texture_function = c.metal_create_function(ndi_library, "convert_texture_to_bgra") orelse {
            return GPUError.FunctionNotFound;
        };
        defer c.metal_release_function(ndi_texture_function);

        const ndi_texture_pipeline = c.metal_create_pipeline(device, ndi_texture_function, @ptrCast(&error_msg)) orelse {
            if (error_msg != null) {
                std.debug.print("NDI texture Metal pipeline error: {s}\n", .{error_msg});
                std.c.free(error_msg);
            }
            return GPUError.PipelineCreationFailed;
        };

        // Create P216 conversion pipeline (10-bit 4:2:2)
        const p216_function = c.metal_create_function(ndi_library, "convert_rgba_to_p216") orelse {
            return GPUError.FunctionNotFound;
        };
        defer c.metal_release_function(p216_function);

        const p216_pipeline = c.metal_create_pipeline(device, p216_function, @ptrCast(&error_msg)) orelse {
            if (error_msg != null) {
                std.debug.print("P216 Metal pipeline error: {s}\n", .{error_msg});
                std.c.free(error_msg);
            }
            return GPUError.PipelineCreationFailed;
        };

        return .{
            .device = device,
            .command_queue = command_queue,
            .pipeline = pipeline,
            .ndi_pipeline = ndi_pipeline,
            .ndi_texture_pipeline = ndi_texture_pipeline,
            .p216_pipeline = p216_pipeline,
        };
    }

    pub fn deinit(self: *MetalContext) void {
        c.metal_release_pipeline(self.p216_pipeline);
        c.metal_release_pipeline(self.ndi_texture_pipeline);
        c.metal_release_pipeline(self.ndi_pipeline);
        c.metal_release_pipeline(self.pipeline);
        c.metal_release_command_queue(self.command_queue);
        c.metal_release_device(self.device);
    }

    pub fn invert(self: *MetalContext, src: ofx.Image, dst: ofx.Image, mix: f32) !void {
        const width: u32 = @intCast(src.bounds.x2 - src.bounds.x1);
        const height: u32 = @intCast(src.bounds.y2 - src.bounds.y1);

        // Create textures
        const src_texture = c.metal_create_texture(self.device, width, height, false) orelse {
            return GPUError.TextureCreationFailed;
        };
        defer c.metal_release_texture(src_texture);

        const dst_texture = c.metal_create_texture(self.device, width, height, true) orelse {
            return GPUError.TextureCreationFailed;
        };
        defer c.metal_release_texture(dst_texture);

        // Upload source data to GPU
        const bytes_per_row: u32 = @intCast(src.stride);
        c.metal_texture_upload(src_texture, src.data, width, height, bytes_per_row);

        // Create command buffer and encoder
        const command_buffer = c.metal_create_command_buffer(self.command_queue) orelse {
            return GPUError.CommandBufferCreationFailed;
        };
        defer c.metal_release_command_buffer(command_buffer);

        const encoder = c.metal_create_compute_encoder(command_buffer) orelse {
            return GPUError.CommandBufferCreationFailed;
        };
        defer c.metal_release_encoder(encoder);

        // Set pipeline and resources
        c.metal_encoder_set_pipeline(encoder, self.pipeline);
        c.metal_encoder_set_texture(encoder, src_texture, 0);
        c.metal_encoder_set_texture(encoder, dst_texture, 1);
        c.metal_encoder_set_bytes(encoder, &mix, @sizeOf(f32), 0);

        // Dispatch threads (16x16 thread groups)
        const grid_w = (width + 15) / 16;
        const grid_h = (height + 15) / 16;
        c.metal_encoder_dispatch(encoder, grid_w, grid_h, 16, 16);
        c.metal_encoder_end(encoder);

        // Commit and wait
        c.metal_commit_command_buffer(command_buffer);
        c.metal_wait_for_completion(command_buffer);

        // Download result from GPU
        const dst_bytes_per_row: u32 = @intCast(dst.stride);
        c.metal_texture_download(dst_texture, dst.data, width, height, dst_bytes_per_row);
    }

    // Convert Metal texture to 8-bit BGRA for NDI (zero-copy on Apple Silicon!)
    pub fn convertTextureForNDI(self: *MetalContext, src_texture: *anyopaque, output_buffer: []u8, width: c_int, height: c_int) !void {
        const w: u32 = @intCast(width);
        const h: u32 = @intCast(height);
        const pixel_count = w * h;
        const dst_size = pixel_count * 4; // 4 bytes per pixel (BGRA)

        // Create output buffer on GPU
        const dst_buffer = c.metal_create_buffer(self.device, dst_size) orelse {
            return GPUError.BufferCreationFailed;
        };
        defer c.metal_release_buffer(dst_buffer);

        // Create command buffer and encoder
        const command_buffer = c.metal_create_command_buffer(self.command_queue) orelse {
            return GPUError.CommandBufferCreationFailed;
        };
        defer c.metal_release_command_buffer(command_buffer);

        const encoder = c.metal_create_compute_encoder(command_buffer) orelse {
            return GPUError.CommandBufferCreationFailed;
        };
        defer c.metal_release_encoder(encoder);

        // Set pipeline and resources (texture fast path)
        c.metal_encoder_set_pipeline(encoder, self.ndi_texture_pipeline);
        c.metal_encoder_set_texture(encoder, @ptrCast(src_texture), 0); // Texture input at index 0
        c.metal_encoder_set_buffer(encoder, dst_buffer, 1); // Buffer output at index 1
        c.metal_encoder_set_bytes(encoder, &width, @sizeOf(c_int), 2);
        c.metal_encoder_set_bytes(encoder, &height, @sizeOf(c_int), 3);

        // Dispatch threads (16x16 thread groups)
        const grid_w = (w + 15) / 16;
        const grid_h = (h + 15) / 16;
        c.metal_encoder_dispatch(encoder, grid_w, grid_h, 16, 16);
        c.metal_encoder_end(encoder);

        // Commit and wait
        c.metal_commit_command_buffer(command_buffer);
        c.metal_wait_for_completion(command_buffer);

        // Download result (on Apple Silicon, this is just a pointer cast with shared storage!)
        c.metal_buffer_download(dst_buffer, output_buffer.ptr, dst_size);
    }

    // Copy Metal buffer using host's command queue (for OFX Metal render)
    pub fn copyMetalBufferWithQueue(self: *MetalContext, host_queue: *anyopaque, src_buffer: *anyopaque, dst_buffer: *anyopaque, size: usize) !void {
        _ = self; // We use host's queue, not our own

        const command_buffer = c.metal_create_command_buffer(@ptrCast(host_queue)) orelse {
            return GPUError.CommandBufferCreationFailed;
        };
        // Don't defer release - host owns the command buffer

        const blit_encoder = c.metal_create_blit_encoder(command_buffer) orelse {
            return GPUError.CommandBufferCreationFailed;
        };
        defer c.metal_release_encoder(blit_encoder);

        c.metal_blit_copy_buffer(blit_encoder, @ptrCast(src_buffer), @ptrCast(dst_buffer), @intCast(size));
        c.metal_encoder_end(blit_encoder);

        // Commit but don't wait - let host handle synchronization
        c.metal_commit_command_buffer(command_buffer);
    }

    // Convert Metal buffer (from OFX) to 8-bit BGRA for NDI
    // Used when OfxImageEffectPropMetalEnabled=1 (src.data is id<MTLBuffer>)
    pub fn convertMetalBufferForNDI(self: *MetalContext, src_metal_buffer: *anyopaque, output_buffer: []u8, width: c_int, height: c_int) !void {
        const w: u32 = @intCast(width);
        const h: u32 = @intCast(height);
        const pixel_count = w * h;
        const dst_size = pixel_count * 4; // 4 bytes per pixel (BGRA)

        // Create output buffer
        const dst_buffer = c.metal_create_buffer(self.device, dst_size) orelse {
            return GPUError.BufferCreationFailed;
        };
        defer c.metal_release_buffer(dst_buffer);

        // Create command buffer and encoder
        const command_buffer = c.metal_create_command_buffer(self.command_queue) orelse {
            return GPUError.CommandBufferCreationFailed;
        };
        defer c.metal_release_command_buffer(command_buffer);

        const encoder = c.metal_create_compute_encoder(command_buffer) orelse {
            return GPUError.CommandBufferCreationFailed;
        };
        defer c.metal_release_encoder(encoder);

        // Set pipeline and resources
        // src_metal_buffer is the id<MTLBuffer> from OFX (already on GPU!)
        c.metal_encoder_set_pipeline(encoder, self.ndi_pipeline);
        c.metal_encoder_set_buffer(encoder, @ptrCast(src_metal_buffer), 0);
        c.metal_encoder_set_buffer(encoder, dst_buffer, 1);
        c.metal_encoder_set_bytes(encoder, &width, @sizeOf(c_int), 2);
        c.metal_encoder_set_bytes(encoder, &height, @sizeOf(c_int), 3);

        // Dispatch threads (16x16 thread groups)
        const grid_w = (w + 15) / 16;
        const grid_h = (h + 15) / 16;
        c.metal_encoder_dispatch(encoder, grid_w, grid_h, 16, 16);
        c.metal_encoder_end(encoder);

        // Commit and wait
        c.metal_commit_command_buffer(command_buffer);
        c.metal_wait_for_completion(command_buffer);

        // Download result
        c.metal_buffer_download(dst_buffer, output_buffer.ptr, dst_size);
    }

    // Convert Metal buffer (from OFX) to P216 (10-bit 4:2:2) for NDI
    // P216 layout: Y plane (16-bit) followed by UV pairs (16-bit)
    pub fn convertMetalBufferForNDI_P216(self: *MetalContext, src_metal_buffer: *anyopaque, output_buffer: []u8, width: c_int, height: c_int) !void {
        const w: u32 = @intCast(width);
        const h: u32 = @intCast(height);

        // P216: Y plane (width*height*2) + UV plane (width*height*2)
        const y_size = w * h * 2; // 16-bit per pixel
        const uv_size = w * h * 2; // (width/2) UV pairs * 4 bytes per pair = width * 2 * height
        const total_size = y_size + uv_size;

        if (output_buffer.len < total_size) {
            return GPUError.BufferCreationFailed;
        }

        // Create GPU output buffers for Y and UV planes
        const dst_y_buffer = c.metal_create_buffer(self.device, @intCast(y_size)) orelse {
            return GPUError.BufferCreationFailed;
        };
        defer c.metal_release_buffer(dst_y_buffer);

        const dst_uv_buffer = c.metal_create_buffer(self.device, @intCast(uv_size)) orelse {
            return GPUError.BufferCreationFailed;
        };
        defer c.metal_release_buffer(dst_uv_buffer);

        // Create command buffer and encoder
        const command_buffer = c.metal_create_command_buffer(self.command_queue) orelse {
            return GPUError.CommandBufferCreationFailed;
        };
        defer c.metal_release_command_buffer(command_buffer);

        const encoder = c.metal_create_compute_encoder(command_buffer) orelse {
            return GPUError.CommandBufferCreationFailed;
        };
        defer c.metal_release_encoder(encoder);

        // Set pipeline and resources
        c.metal_encoder_set_pipeline(encoder, self.p216_pipeline);
        c.metal_encoder_set_buffer(encoder, @ptrCast(src_metal_buffer), 0); // src RGBA
        c.metal_encoder_set_buffer(encoder, dst_y_buffer, 1); // dst Y plane
        c.metal_encoder_set_buffer(encoder, dst_uv_buffer, 2); // dst UV pairs
        c.metal_encoder_set_bytes(encoder, &width, @sizeOf(c_int), 3);
        c.metal_encoder_set_bytes(encoder, &height, @sizeOf(c_int), 4);

        // Dispatch threads (process pairs of pixels for 4:2:2)
        // Each thread handles 2 horizontal pixels
        const grid_w = ((w / 2) + 15) / 16;
        const grid_h = (h + 15) / 16;
        c.metal_encoder_dispatch(encoder, grid_w, grid_h, 16, 16);
        c.metal_encoder_end(encoder);

        // Commit and wait
        c.metal_commit_command_buffer(command_buffer);
        c.metal_wait_for_completion(command_buffer);

        // Download results: Y plane followed by UV plane
        c.metal_buffer_download(dst_y_buffer, output_buffer.ptr, @intCast(y_size));
        c.metal_buffer_download(dst_uv_buffer, output_buffer.ptr + y_size, @intCast(uv_size));
    }

    // Convert float RGBA to 8-bit BGRA for NDI (with vertical flip)
    // Used for CPU rendering (uploads from CPU memory)
    pub fn convertForNDI(self: *MetalContext, src: ofx.Image, output_buffer: []u8, width: c_int, height: c_int) !void {
        const w: u32 = @intCast(width);
        const h: u32 = @intCast(height);
        const pixel_count = w * h;

        // Create GPU buffers
        const src_size = pixel_count * @sizeOf(ofx.PixelRGBA);
        const dst_size = pixel_count * 4; // 4 bytes per pixel (BGRA)

        const src_buffer = c.metal_create_buffer(self.device, src_size) orelse {
            return GPUError.BufferCreationFailed;
        };
        defer c.metal_release_buffer(src_buffer);

        const dst_buffer = c.metal_create_buffer(self.device, dst_size) orelse {
            return GPUError.BufferCreationFailed;
        };
        defer c.metal_release_buffer(dst_buffer);

        // Upload source data from CPU
        c.metal_buffer_upload(src_buffer, src.data, src_size);

        // Create command buffer and encoder
        const command_buffer = c.metal_create_command_buffer(self.command_queue) orelse {
            return GPUError.CommandBufferCreationFailed;
        };
        defer c.metal_release_command_buffer(command_buffer);

        const encoder = c.metal_create_compute_encoder(command_buffer) orelse {
            return GPUError.CommandBufferCreationFailed;
        };
        defer c.metal_release_encoder(encoder);

        // Set pipeline and resources
        c.metal_encoder_set_pipeline(encoder, self.ndi_pipeline);
        c.metal_encoder_set_buffer(encoder, src_buffer, 0);
        c.metal_encoder_set_buffer(encoder, dst_buffer, 1);
        c.metal_encoder_set_bytes(encoder, &width, @sizeOf(c_int), 2);
        c.metal_encoder_set_bytes(encoder, &height, @sizeOf(c_int), 3);

        // Dispatch threads (16x16 thread groups)
        const grid_w = (w + 15) / 16;
        const grid_h = (h + 15) / 16;
        c.metal_encoder_dispatch(encoder, grid_w, grid_h, 16, 16);
        c.metal_encoder_end(encoder);

        // Commit and wait
        c.metal_commit_command_buffer(command_buffer);
        c.metal_wait_for_completion(command_buffer);

        // Download result
        c.metal_buffer_download(dst_buffer, output_buffer.ptr, dst_size);
    }
};

// Placeholder for future backends
const OpenCLContext = struct {
    pub fn isAvailable() bool {
        return false; // TODO: implement
    }
    pub fn init() !OpenCLContext {
        return error.NotImplemented;
    }
};

const CUDAContext = struct {
    pub fn isAvailable() bool {
        return false; // TODO: implement
    }
    pub fn init() !CUDAContext {
        return error.NotImplemented;
    }
};

pub const GPUContext = struct {
    backend: Backend,

    pub const Backend = union(enum) {
        metal: MetalContext,
        opencl: OpenCLContext,
        cuda: CUDAContext,
        cpu: void,
    };

    pub fn init() !GPUContext {
        // Try each backend in order
        if (MetalContext.isAvailable()) {
            return .{ .backend = .{ .metal = try MetalContext.init() } };
        }
        if (OpenCLContext.isAvailable()) {
            return .{ .backend = .{ .opencl = try OpenCLContext.init() } };
        }
        // Fall back to CPU
        return .{ .backend = .{ .cpu = {} } };
    }

    pub fn deinit(self: *GPUContext) void {
        switch (self.backend) {
            .metal => |*ctx| ctx.deinit(),
            .opencl, .cuda, .cpu => {},
        }
    }

    pub fn invert(self: *GPUContext, src: ofx.Image, dst: ofx.Image, mix: f32) !void {
        switch (self.backend) {
            .metal => |*ctx| try ctx.invert(src, dst, mix),
            .opencl => return error.NotImplemented,
            .cuda => return error.NotImplemented,
            .cpu => try cpuInvert(src, dst, mix),
        }
    }

    pub fn convertForNDI(self: *GPUContext, src: ofx.Image, output_buffer: []u8, width: c_int, height: c_int) !void {
        switch (self.backend) {
            .metal => |*ctx| try ctx.convertForNDI(src, output_buffer, width, height),
            .opencl => return error.NotImplemented,
            .cuda => return error.NotImplemented,
            .cpu => return error.NotImplemented, // Fall back to CPU conversion in plugin
        }
    }

    pub fn copyMetalBufferWithQueue(self: *GPUContext, host_queue: *anyopaque, src_buffer: *anyopaque, dst_buffer: *anyopaque, size: usize) !void {
        switch (self.backend) {
            .metal => |*ctx| try ctx.copyMetalBufferWithQueue(host_queue, src_buffer, dst_buffer, size),
            .opencl => return error.NotImplemented,
            .cuda => return error.NotImplemented,
            .cpu => return error.NotImplemented,
        }
    }

    pub fn convertMetalBufferForNDI(self: *GPUContext, src_metal_buffer: *anyopaque, output_buffer: []u8, width: c_int, height: c_int) !void {
        switch (self.backend) {
            .metal => |*ctx| try ctx.convertMetalBufferForNDI(src_metal_buffer, output_buffer, width, height),
            .opencl => return error.NotImplemented,
            .cuda => return error.NotImplemented,
            .cpu => return error.NotImplemented,
        }
    }

    pub fn convertMetalBufferForNDI_P216(self: *GPUContext, src_metal_buffer: *anyopaque, output_buffer: []u8, width: c_int, height: c_int) !void {
        switch (self.backend) {
            .metal => |*ctx| try ctx.convertMetalBufferForNDI_P216(src_metal_buffer, output_buffer, width, height),
            .opencl => return error.NotImplemented,
            .cuda => return error.NotImplemented,
            .cpu => return error.NotImplemented,
        }
    }

    pub fn convertTextureForNDI(self: *GPUContext, src_texture: *anyopaque, output_buffer: []u8, width: c_int, height: c_int) !void {
        switch (self.backend) {
            .metal => |*ctx| try ctx.convertTextureForNDI(src_texture, output_buffer, width, height),
            .opencl => return error.NotImplemented,
            .cuda => return error.NotImplemented,
            .cpu => return error.NotImplemented,
        }
    }
};

// CPU fallback implementation
fn cpuInvert(src: ofx.Image, dst: ofx.Image, mix: f32) !void {
    var y = src.bounds.y1;
    while (y < src.bounds.y2) : (y += 1) {
        var x = src.bounds.x1;
        while (x < src.bounds.x2) : (x += 1) {
            const src_pixel = src.pixelAtConst(x, y);
            const dst_pixel = dst.pixelAt(x, y);

            const inverted = src_pixel.invert();
            dst_pixel.* = ofx.PixelRGBA.mix(src_pixel.*, inverted, mix);
        }
    }
}

// Summary of GPU Acceleration Implementation
//
//   What We Built:
//
//   1. Multi-backend GPU Architecture (src/gpu.zig)
//   - Created GPUContext with runtime backend detection
//   (Metal/OpenCL/CUDA/CPU)
//   - Implemented MetalContext for Apple Silicon GPU acceleration
//   - Added automatic fallback to CPU if GPU unavailable
//
//   2. Metal Objective-C Bridge (src/metal_bridge.h/m)
//   - Created C wrapper to avoid Zig's Objective-C import
//   limitations
//   - Wrapped Metal device, command queue, textures, shaders, and
//    encoders
//   - Used ARC for automatic memory management
//
//   3. Metal Compute Shader (src/shaders/invert.metal)
//   - GPU kernel for parallel pixel processing
//   - Inverts RGB channels with mix parameter
//   - Runs on 16x16 thread groups for optimal performance
//
//   4. Build System Updates (build.zig)
//   - Added GPU module with Metal bridge headers
//   - Compiled Objective-C bridge with -fobjc-arc
//   - Linked Metal, CoreFoundation, and Foundation frameworks
//
//   5. Plugin Integration (src/invert_plugin.zig)
//   - Initialize GPU on plugin load
//   - Use GPU for rendering with automatic CPU fallback
//   - Added debug logging to verify backend selection
//
//   Result:
//
//   ✅ Plugin now renders 1920x1080 frames on Apple Silicon GPU
//   using Metal
//   ✅ Clean architecture ready for OpenCL/CUDA backends
//   ✅ Automatic fallback ensures compatibility
//
//   Log proof: GPU initialized with Metal backend → Using GPU for
//    rendering → RENDER SUCCESS!
