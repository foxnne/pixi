const std = @import("std");
const pixi = @import("pixi");
const gfx = pixi.gfx;
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const zm = @import("zmath");

pub const Batcher = struct {
    allocator: std.mem.Allocator,
    gctx: *zgpu.GraphicsContext,
    encoder: ?wgpu.CommandEncoder = null,
    vertices: []gfx.Vertex,
    vertex_buffer_handle: zgpu.BufferHandle,
    indices: []u32,
    index_buffer_handle: zgpu.BufferHandle,
    context: Context = undefined,
    vert_index: usize = 0,
    quad_count: usize = 0,
    start_count: usize = 0,
    state: State = .idle,

    /// Contains instructions on pipeline and binding for the current batch
    pub const Context = struct {
        pipeline_handle: zgpu.RenderPipelineHandle,
        bind_group_handle: zgpu.BindGroupHandle,
        // If output handle is null, render to the back buffer
        // otherwise, render to offscreen texture view handle
        output_handle: ?zgpu.TextureViewHandle = null,
        clear_color: zm.F32x4 = zm.f32x4(0, 0, 0, 255),
    };

    /// Describes the current state of the Batcher
    pub const State = enum {
        progress,
        idle,
    };

    pub fn init(allocator: std.mem.Allocator, gctx: *zgpu.GraphicsContext, max_quads: usize) !Batcher {
        var vertices = try allocator.alloc(gfx.Vertex, max_quads * 4);
        var indices = try allocator.alloc(u32, max_quads * 6);

        // Arrange index buffer for quads
        var i: usize = 0;
        while (i < max_quads) : (i += 1) {
            indices[i * 2 * 3 + 0] = @as(u32, @intCast(i * 4 + 0));
            indices[i * 2 * 3 + 1] = @as(u32, @intCast(i * 4 + 1));
            indices[i * 2 * 3 + 2] = @as(u32, @intCast(i * 4 + 3));
            indices[i * 2 * 3 + 3] = @as(u32, @intCast(i * 4 + 1));
            indices[i * 2 * 3 + 4] = @as(u32, @intCast(i * 4 + 2));
            indices[i * 2 * 3 + 5] = @as(u32, @intCast(i * 4 + 3));
        }

        const vertex_buffer_handle = gctx.createBuffer(.{
            .usage = .{ .copy_dst = true, .vertex = true },
            .size = vertices.len * @sizeOf(gfx.Vertex),
        });

        const index_buffer_handle = gctx.createBuffer(.{
            .usage = .{ .copy_dst = true, .index = true },
            .size = indices.len * @sizeOf(u32),
        });

        return Batcher{
            .allocator = allocator,
            .gctx = gctx,
            .vertices = vertices,
            .vertex_buffer_handle = vertex_buffer_handle,
            .indices = indices,
            .index_buffer_handle = index_buffer_handle,
        };
    }

    pub fn begin(self: *Batcher, context: Context) !void {
        if (self.state == .progress) return error.BeginCalledTwice;
        self.context = context;
        self.state = .progress;
        self.start_count = self.quad_count;
        if (self.encoder == null) {
            self.encoder = self.gctx.device.createCommandEncoder(null);
        }
    }

    /// Returns true if vertices array has room for another quad
    pub fn hasCapacity(self: Batcher) bool {
        return self.quad_count * 4 < self.vertices.len - 1;
    }

    /// Attempts to resize the buffers to hold a larger capacity
    pub fn resize(self: *Batcher, max_quads: usize) !void {
        if (max_quads <= self.quad_count) return error.BufferTooSmall;

        self.vertices = try self.allocator.realloc(self.vertices, max_quads * 4);
        self.indices = try self.allocator.realloc(self.indices, max_quads * 6);

        // Arrange index buffer for quads
        var i: usize = 0;
        while (i < max_quads) : (i += 1) {
            self.indices[i * 2 * 3 + 0] = @as(u32, @intCast(i * 4 + 0));
            self.indices[i * 2 * 3 + 1] = @as(u32, @intCast(i * 4 + 1));
            self.indices[i * 2 * 3 + 2] = @as(u32, @intCast(i * 4 + 3));
            self.indices[i * 2 * 3 + 3] = @as(u32, @intCast(i * 4 + 1));
            self.indices[i * 2 * 3 + 4] = @as(u32, @intCast(i * 4 + 2));
            self.indices[i * 2 * 3 + 5] = @as(u32, @intCast(i * 4 + 3));
        }

        std.log.warn("[{s}] Batcher buffers resized, previous size: {d} - new size: {d}", .{ pixi.name, self.quad_count, max_quads });

        self.gctx.releaseResource(self.vertex_buffer_handle);
        self.gctx.releaseResource(self.index_buffer_handle);

        const vertex_buffer_handle = self.gctx.createBuffer(.{
            .usage = .{ .copy_dst = true, .vertex = true },
            .size = self.vertices.len * @sizeOf(gfx.Vertex),
        });

        const index_buffer_handle = self.gctx.createBuffer(.{
            .usage = .{ .copy_dst = true, .index = true },
            .size = self.indices.len * @sizeOf(u32),
        });

        self.vertex_buffer_handle = vertex_buffer_handle;
        self.index_buffer_handle = index_buffer_handle;
    }

    /// Attempts to append a new quad to the Batcher's buffers.
    /// If the buffer is full, attempt to resize the buffer first.
    pub fn append(self: *Batcher, quad: gfx.Quad) !void {
        if (self.state == .idle) return error.CallBeginFirst;
        if (!self.hasCapacity()) try self.resize(self.quad_count * 2);

        for (quad.vertices) |vertex| {
            self.vertices[self.vert_index] = vertex;
            self.vert_index += 1;
        }

        self.quad_count += 1;
    }

    pub const TextureOptions = struct {
        color: zm.F32x4 = pixi.math.Colors.white.value,
    };

    /// Appends a quad at the passed position set to the size needed to render the target texture.
    pub fn texture(self: *Batcher, position: zm.F32x4, t: gfx.Texture, options: TextureOptions) !void {
        const width = @as(f32, @floatFromInt(t.width));
        const height = @as(f32, @floatFromInt(t.height));
        const pos = zm.trunc(position);

        var color: [4]f32 = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
        zm.store(color[0..], options.color, 4);

        var quad = gfx.Quad{
            .vertices = [_]gfx.Vertex{
                .{
                    .position = [3]f32{ pos[0], pos[1] + height, pos[2] },
                    .uv = [2]f32{ 0.0, 0.0 },
                    .color = color,
                }, //Bl
                .{
                    .position = [3]f32{ pos[0] + width, pos[1] + height, pos[2] },
                    .uv = [2]f32{ 1.0, 0.0 },
                    .color = color,
                }, //Br
                .{
                    .position = [3]f32{ pos[0] + width, pos[1], pos[2] },
                    .uv = [2]f32{ 1.0, 1.0 },
                    .color = color,
                }, //Tr
                .{
                    .position = [3]f32{ pos[0], pos[1], pos[2] },
                    .uv = [2]f32{ 0.0, 1.0 },
                    .color = color,
                }, //Tl
            },
        };

        return self.append(quad);
    }

    pub const SpriteOptions = struct {
        color: zm.F32x4 = pixi.math.Colors.white.value,
        flip_x: bool = false,
        flip_y: bool = false,
        vert_mode: VertRenderMode = .standard,
        frag_mode: FragRenderMode = .standard,
        time: f32 = 0.0,
        rotation: f32 = 0.0,

        pub const VertRenderMode = enum {
            standard,
            top_sway,
        };

        pub const FragRenderMode = enum {
            standard,
            palette,
        };
    };

    /// Appends a quad to the batcher set to the size needed to render the target sprite from the target texture.
    pub fn sprite(self: *Batcher, position: zm.F32x4, t: gfx.Texture, s: gfx.Sprite, options: SpriteOptions) !void {
        const x = @as(f32, @floatFromInt(s.source.x));
        const y = @as(f32, @floatFromInt(s.source.y));
        const width = @as(f32, @floatFromInt(s.source.width));
        const height = @as(f32, @floatFromInt(s.source.height));
        const o_x = @as(f32, @floatFromInt(s.origin.x));
        const o_y = @as(f32, @floatFromInt(s.origin.y));
        const tex_width = @as(f32, @floatFromInt(t.width));
        const tex_height = @as(f32, @floatFromInt(t.height));

        const origin_x = if (options.flip_x) o_x - width else -o_x;
        const origin_y = if (options.flip_y) -o_y else o_y - height;
        const pos = zm.trunc(position);
        var color: [4]f32 = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
        zm.store(color[0..], options.color, 4);

        const vert_mode = switch (options.vert_mode) {
            .standard => @as(f32, 0.0),
            .top_sway => @as(f32, 1.0),
        };

        const frag_mode = switch (options.frag_mode) {
            .standard => @as(f32, 0.0),
            .palette => @as(f32, 1.0),
        };

        var quad = gfx.Quad{
            .vertices = [_]gfx.Vertex{
                .{
                    .position = [3]f32{ pos[0] + origin_x, pos[1] + height + origin_y, pos[2] },
                    .uv = [2]f32{ 0.0, 0.0 },
                    .color = color,
                    .data = [3]f32{ vert_mode, frag_mode, options.time },
                }, //Bl
                .{
                    .position = [3]f32{ pos[0] + width + origin_x, pos[1] + height + origin_y, pos[2] },
                    .uv = [2]f32{ 1.0, 0.0 },
                    .color = color,
                    .data = [3]f32{ vert_mode, frag_mode, options.time },
                }, //Br
                .{
                    .position = [3]f32{ pos[0] + width + origin_x, pos[1] + origin_y, pos[2] },
                    .uv = [2]f32{ 1.0, 1.0 },
                    .color = color,
                    .data = [3]f32{ vert_mode, frag_mode, options.time },
                }, //Tr
                .{
                    .position = [3]f32{ pos[0] + origin_x, pos[1] + origin_y, pos[2] },
                    .uv = [2]f32{ 0.0, 1.0 },
                    .color = color,
                    .data = [3]f32{ vert_mode, frag_mode, options.time },
                }, //Tl
            },
        };

        // Set viewport of quad to the sprite
        quad.setViewport(x, y, width, height, tex_width, tex_height);

        // Apply mirroring
        if (options.flip_x) quad.flipHorizontally();
        if (options.flip_y) quad.flipVertically();

        // Apply rotation
        if (options.rotation > 0.0 or options.rotation < 0.0) quad.rotate(options.rotation, pos[0], pos[1], origin_x, origin_y);

        return self.append(quad);
    }

    pub fn end(self: *Batcher, uniforms: anytype) !void {
        const UniformsType = @TypeOf(uniforms);
        const uniforms_type_info = @typeInfo(UniformsType);
        if (uniforms_type_info != .Struct) {
            @compileError("Expected tuple or struct argument, found " ++ @typeName(UniformsType));
        }
        const uniforms_fields_info = uniforms_type_info.Struct.fields;

        if (self.state == .idle) return error.EndCalledTwice;
        self.state = .idle;

        // Get the quad count for the current batch.
        const quad_count = self.quad_count - self.start_count;
        if (quad_count < 1) return;

        // Begin the render pass
        pass: {
            const vb_info = self.gctx.lookupResourceInfo(self.vertex_buffer_handle) orelse break :pass;
            const ib_info = self.gctx.lookupResourceInfo(self.index_buffer_handle) orelse break :pass;
            const pipeline = self.gctx.lookupResource(self.context.pipeline_handle) orelse break :pass;
            const bind_group = self.gctx.lookupResource(self.context.bind_group_handle) orelse break :pass;
            const encoder = self.encoder orelse break :pass;

            // Get the back buffer view in case we want to directly render to the back buffer
            const back_buffer_view = self.gctx.swapchain.getCurrentTextureView();
            defer back_buffer_view.release();

            const color_attachments = [_]wgpu.RenderPassColorAttachment{.{
                .view = if (self.context.output_handle) |out_handle| self.gctx.lookupResource(out_handle).? else back_buffer_view,
                .load_op = .clear,
                .store_op = .store,
                .clear_value = .{ .r = self.context.clear_color[0], .g = self.context.clear_color[1], .b = self.context.clear_color[2], .a = self.context.clear_color[3] },
            }};

            const render_pass_info = wgpu.RenderPassDescriptor{
                .color_attachment_count = color_attachments.len,
                .color_attachments = &color_attachments,
            };

            const pass = encoder.beginRenderPass(render_pass_info);
            defer {
                pass.end();
                pass.release();
            }

            pass.setVertexBuffer(0, vb_info.gpuobj.?, 0, vb_info.size);
            pass.setIndexBuffer(ib_info.gpuobj.?, .uint32, 0, ib_info.size);

            pass.setPipeline(pipeline);

            if (uniforms_fields_info.len > 0) {
                const mem = self.gctx.uniformsAllocate(UniformsType, 1);
                mem.slice[0] = uniforms;
                pass.setBindGroup(0, bind_group, &.{mem.offset});
            } else {
                pass.setBindGroup(0, bind_group, null);
            }

            // Draw only the quads appended this cycle
            pass.drawIndexed(@as(u32, @intCast(quad_count * 6)), @as(u32, @intCast(quad_count)), @as(u32, @intCast(self.start_count * 6)), 0, 0);
        }
    }

    pub fn finish(self: *Batcher) !wgpu.CommandBuffer {
        if (self.encoder) |encoder| {
            // Write the current vertex and index buffers to the queue.
            self.gctx.queue.writeBuffer(self.gctx.lookupResource(self.vertex_buffer_handle).?, 0, gfx.Vertex, self.vertices[0 .. self.quad_count * 4]);
            self.gctx.queue.writeBuffer(self.gctx.lookupResource(self.index_buffer_handle).?, 0, u32, self.indices[0 .. self.quad_count * 6]);
            // Reset the Batcher for the next time begin is called.
            self.quad_count = 0;
            self.vert_index = 0;
            const commands = encoder.finish(null);
            encoder.release();
            self.encoder = null;
            return commands;
        } else return error.NullEncoder;
    }

    pub fn deinit(self: *Batcher) void {
        self.allocator.free(self.vertices);
        self.allocator.free(self.indices);
    }
};
