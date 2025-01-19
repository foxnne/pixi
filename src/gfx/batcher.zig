const std = @import("std");
const Pixi = @import("../Pixi.zig");
const gfx = Pixi.gfx;
const zmath = @import("zmath");
const Core = @import("mach").Core;
const gpu = @import("mach").gpu;

const num_triangles: usize = 4;
const num_verts: usize = 5;
const num_indices: usize = 12;

pub const Batcher = struct {
    allocator: std.mem.Allocator,
    encoder: ?*gpu.CommandEncoder = null,
    vertices: []gfx.Vertex,
    vertex_buffer_handle: *gpu.Buffer,
    indices: []u32,
    index_buffer_handle: *gpu.Buffer,
    context: Context = undefined,
    vert_index: usize = 0,
    quad_count: usize = 0,
    start_count: usize = 0,
    state: State = .idle,
    empty: bool = true,

    /// Contains instructions on pipeline and binding for the current batch
    pub const Context = struct {
        pipeline_handle: *gpu.RenderPipeline,
        bind_group_handle: *gpu.BindGroup,
        compute_pipeline_handle: ?*gpu.ComputePipeline = null,
        compute_bind_group_handle: ?*gpu.BindGroup = null,
        compute_buffer: ?*gpu.Buffer = null,
        staging_buffer: ?*gpu.Buffer = null,
        buffer_size: usize = 0,
        // If output handle is null, render to the back buffer
        // otherwise, render to offscreen texture view handle
        //output_handle: ?*gpu.TextureView = null,
        output_texture: ?*gfx.Texture = null,
        clear_color: gpu.Color = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 },
    };

    /// Describes the current state of the Batcher
    pub const State = enum {
        progress,
        idle,
    };

    pub fn init(allocator: std.mem.Allocator, max_quads: usize) !Batcher {
        const vertices = try allocator.alloc(gfx.Vertex, max_quads * num_verts);
        var indices = try allocator.alloc(u32, max_quads * num_indices);

        // Arrange index buffer for quads
        var i: usize = 0;
        while (i < max_quads) : (i += 1) {
            indices[i * num_indices + 0] = @as(u32, @intCast(i * num_verts + 0));
            indices[i * num_indices + 1] = @as(u32, @intCast(i * num_verts + 1));
            indices[i * num_indices + 2] = @as(u32, @intCast(i * num_verts + 4));
            indices[i * num_indices + 3] = @as(u32, @intCast(i * num_verts + 1));
            indices[i * num_indices + 4] = @as(u32, @intCast(i * num_verts + 2));
            indices[i * num_indices + 5] = @as(u32, @intCast(i * num_verts + 4));
            indices[i * num_indices + 6] = @as(u32, @intCast(i * num_verts + 2));
            indices[i * num_indices + 7] = @as(u32, @intCast(i * num_verts + 3));
            indices[i * num_indices + 8] = @as(u32, @intCast(i * num_verts + 4));
            indices[i * num_indices + 9] = @as(u32, @intCast(i * num_verts + 3));
            indices[i * num_indices + 10] = @as(u32, @intCast(i * num_verts + 0));
            indices[i * num_indices + 11] = @as(u32, @intCast(i * num_verts + 4));
        }

        const vertex_buffer_descriptor: gpu.Buffer.Descriptor = .{
            .usage = .{ .copy_dst = true, .vertex = true },
            .size = vertices.len * @sizeOf(gfx.Vertex),
        };

        const device: *gpu.Device = Pixi.core.windows.get(Pixi.app.window, .device);

        const vertex_buffer_handle = device.createBuffer(&vertex_buffer_descriptor);

        const index_buffer_descriptor: gpu.Buffer.Descriptor = .{
            .usage = .{ .copy_dst = true, .index = true },
            .size = indices.len * @sizeOf(u32),
        };

        const index_buffer_handle = device.createBuffer(&index_buffer_descriptor);

        return Batcher{
            .allocator = allocator,
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
            const device: *gpu.Device = Pixi.core.windows.get(Pixi.app.window, .device);
            self.encoder = device.createCommandEncoder(null);
        }
    }

    /// Returns true if vertices array has room for another quad
    pub fn hasCapacity(self: Batcher) bool {
        return self.quad_count * num_verts < self.vertices.len - num_verts;
    }

    /// Attempts to resize the buffers to hold a larger capacity
    pub fn resize(self: *Batcher, max_quads: usize) !void {
        if (max_quads <= self.quad_count) return error.BufferTooSmall;

        self.vertices = try self.allocator.realloc(self.vertices, max_quads * num_verts);
        self.indices = try self.allocator.realloc(self.indices, max_quads * num_indices);

        // Arrange index buffer for quads
        var i: usize = 0;
        while (i < max_quads) : (i += 1) {
            self.indices[i * num_indices + 0] = @as(u32, @intCast(i * num_verts + 0));
            self.indices[i * num_indices + 1] = @as(u32, @intCast(i * num_verts + 1));
            self.indices[i * num_indices + 2] = @as(u32, @intCast(i * num_verts + 4));
            self.indices[i * num_indices + 3] = @as(u32, @intCast(i * num_verts + 1));
            self.indices[i * num_indices + 4] = @as(u32, @intCast(i * num_verts + 2));
            self.indices[i * num_indices + 5] = @as(u32, @intCast(i * num_verts + 4));
            self.indices[i * num_indices + 6] = @as(u32, @intCast(i * num_verts + 2));
            self.indices[i * num_indices + 7] = @as(u32, @intCast(i * num_verts + 4));
            self.indices[i * num_indices + 8] = @as(u32, @intCast(i * num_verts + 3));
            self.indices[i * num_indices + 9] = @as(u32, @intCast(i * num_verts + 3));
            self.indices[i * num_indices + 10] = @as(u32, @intCast(i * num_verts + 4));
            self.indices[i * num_indices + 11] = @as(u32, @intCast(i * num_verts + 0));
        }

        std.log.warn("[{s}] Batcher buffers resized, previous size: {d} - new size: {d}", .{ "Pixi", self.quad_count, max_quads });

        self.vertex_buffer_handle.release();
        self.index_buffer_handle.release();

        const device: *gpu.Device = Pixi.core.windows.get(Pixi.app.window, .device);

        const vertex_buffer_handle = device.createBuffer(&.{
            .usage = .{ .copy_dst = true, .vertex = true },
            .size = self.vertices.len * @sizeOf(gfx.Vertex),
        });

        const index_buffer_handle = device.createBuffer(&.{
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

        self.empty = false;
    }

    pub const TextureOptions = struct {
        color: zmath.F32x4 = Pixi.math.Colors.white.value,
        origin: [2]f32 = .{ 0.0, 0.0 }, //tl
        width: f32 = 0.0, // if not 0.0, will scale to use this width
        height: f32 = 0.0, // if not 0.0, will scale to use this height
        flip_y: bool = false,
        flip_x: bool = false,
        rotation: f32 = 0.0,
        data_0: f32 = 0.0,
        data_1: f32 = 0.0,
        data_2: f32 = 0.0,
    };

    /// Appends a quad at the passed position set to the size needed to render the target texture.
    pub fn texture(self: *Batcher, position: zmath.F32x4, t: *gfx.Texture, options: TextureOptions) !void {
        const width = if (options.width != 0.0) options.width else @as(f32, @floatFromInt(t.image.width));
        const height = if (options.height != 0.0) options.height else @as(f32, @floatFromInt(t.image.height));
        const pos = zmath.trunc(position);

        var color: [4]f32 = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
        zmath.store(&color, options.color, 4);

        const max: f32 = if (!options.flip_y) 1.0 else 0.0;
        const min: f32 = if (!options.flip_y) 0.0 else 1.0;

        var quad = gfx.Quad{
            .vertices = [_]gfx.Vertex{
                .{
                    .position = [3]f32{ pos[0], pos[1] + height, pos[2] },
                    .uv = [2]f32{ if (options.flip_x) max else min, min },
                    .color = color,
                    .data = [3]f32{ options.data_0, options.data_1, options.data_2 },
                }, //Bl
                .{
                    .position = [3]f32{ pos[0] + width, pos[1] + height, pos[2] },
                    .uv = [2]f32{ if (options.flip_x) min else max, min },
                    .color = color,
                    .data = [3]f32{ options.data_0, options.data_1, options.data_2 },
                }, //Br
                .{
                    .position = [3]f32{ pos[0] + width, pos[1], pos[2] },
                    .uv = [2]f32{ if (options.flip_x) min else max, max },
                    .color = color,
                    .data = [3]f32{ options.data_0, options.data_1, options.data_2 },
                }, //Tr
                .{
                    .position = [3]f32{ pos[0], pos[1], pos[2] },
                    .uv = [2]f32{ if (options.flip_x) max else min, max },
                    .color = color,
                    .data = [3]f32{ options.data_0, options.data_1, options.data_2 },
                }, //Tl
            },
        };

        // Apply mirroring
        if (options.flip_x) quad.flipHorizontally();
        if (options.flip_y) quad.flipVertically();

        // Apply rotation
        if (options.rotation > 0.0 or options.rotation < 0.0) quad.rotate(options.rotation, pos[0], pos[1], options.origin[0], options.origin[1]);

        return self.append(quad);
    }

    pub const TransformTextureOptions = struct {
        color: zmath.F32x4 = Pixi.math.Colors.white.value,
        flip_y: bool = false,
        flip_x: bool = false,
        rotation: f32 = 0.0,
        data_0: f32 = 0.0,
        data_1: f32 = 0.0,
        data_2: f32 = 0.0,
    };
    /// Appends a quad at the passed position set to the size needed to render the target texture.
    pub fn transformTexture(self: *Batcher, vertices: [4]Pixi.storage.internal.PixiFile.TransformVertex, offset: [2]f32, pivot: [2]f32, options: TransformTextureOptions) !void {
        var color: [4]f32 = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
        zmath.store(&color, options.color, 4);

        var centroid = zmath.f32x4(0.0, 0.0, 0.0, 0.0);
        for (vertices) |v| {
            centroid += v.position;
        }
        centroid = centroid / zmath.f32x4s(4.0);

        const max: f32 = if (!options.flip_y) 1.0 else 0.0;
        const min: f32 = if (!options.flip_y) 0.0 else 1.0;

        var quad = gfx.Quad{
            .vertices = [_]gfx.Vertex{
                .{
                    .position = [3]f32{ vertices[0].position[0] + offset[0], -vertices[0].position[1] + offset[1], vertices[0].position[2] },
                    .uv = [2]f32{ if (options.flip_x) max else min, min },
                    .color = color,
                    .data = [3]f32{ options.data_0, options.data_1, options.data_2 },
                }, //Bl
                .{
                    .position = [3]f32{ vertices[1].position[0] + offset[0], -vertices[1].position[1] + offset[1], vertices[1].position[2] },
                    .uv = [2]f32{ if (options.flip_x) min else max, min },
                    .color = color,
                    .data = [3]f32{ options.data_0, options.data_1, options.data_2 },
                }, //Br
                .{
                    .position = [3]f32{ vertices[2].position[0] + offset[0], -vertices[2].position[1] + offset[1], vertices[2].position[2] },
                    .uv = [2]f32{ if (options.flip_x) min else max, max },
                    .color = color,
                    .data = [3]f32{ options.data_0, options.data_1, options.data_2 },
                }, //Tr
                .{
                    .position = [3]f32{ vertices[3].position[0] + offset[0], -vertices[3].position[1] + offset[1], vertices[3].position[2] },
                    .uv = [2]f32{ if (options.flip_x) max else min, max },
                    .color = color,
                    .data = [3]f32{ options.data_0, options.data_1, options.data_2 },
                }, //Tl
                .{
                    .position = [3]f32{ centroid[0] + offset[0], -centroid[1] + offset[1], 0.0 },
                    .uv = [2]f32{ 0.5, 0.5 },
                    .color = color,
                    .data = [3]f32{ options.data_0, options.data_1, options.data_2 },
                }, //Center
            },
        };

        // Apply mirroring
        if (options.flip_x) quad.flipHorizontally();
        if (options.flip_y) quad.flipVertically();

        // Apply rotation
        if (options.rotation > 0.0 or options.rotation < 0.0) quad.rotate(options.rotation, zmath.loadArr2(pivot) + zmath.loadArr2(offset));

        return self.append(quad);
    }

    /// Appends a quad at the passed position set to the size needed to render the target sprite.
    pub fn transformSprite(self: *Batcher, t: *const gfx.Texture, s: gfx.Sprite, vertices: [4]Pixi.storage.internal.PixiFile.TransformVertex, offset: [2]f32, pivot: [2]f32, options: TransformTextureOptions) !void {
        var color: [4]f32 = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
        zmath.store(&color, options.color, 4);

        const x = @as(f32, @floatFromInt(s.source[0]));
        const y = @as(f32, @floatFromInt(s.source[1]));
        const width = @as(f32, @floatFromInt(s.source[2]));
        const height = @as(f32, @floatFromInt(s.source[3]));

        const tex_width = @as(f32, @floatFromInt(t.image.width));
        const tex_height = @as(f32, @floatFromInt(t.image.height));

        var centroid = zmath.f32x4(0.0, 0.0, 0.0, 0.0);
        for (vertices) |v| {
            centroid += v.position;
        }
        centroid = centroid / zmath.f32x4s(4.0);

        const max: f32 = if (!options.flip_y) 1.0 else 0.0;
        const min: f32 = if (!options.flip_y) 0.0 else 1.0;

        var quad = gfx.Quad{
            .vertices = [_]gfx.Vertex{
                .{
                    .position = [3]f32{ vertices[0].position[0] + offset[0], -vertices[0].position[1] + offset[1], vertices[0].position[2] },
                    .uv = [2]f32{ if (options.flip_x) max else min, min },
                    .color = color,
                    .data = [3]f32{ options.data_0, options.data_1, options.data_2 },
                }, //Bl
                .{
                    .position = [3]f32{ vertices[1].position[0] + offset[0], -vertices[1].position[1] + offset[1], vertices[1].position[2] },
                    .uv = [2]f32{ if (options.flip_x) min else max, min },
                    .color = color,
                    .data = [3]f32{ options.data_0, options.data_1, options.data_2 },
                }, //Br
                .{
                    .position = [3]f32{ vertices[2].position[0] + offset[0], -vertices[2].position[1] + offset[1], vertices[2].position[2] },
                    .uv = [2]f32{ if (options.flip_x) min else max, max },
                    .color = color,
                    .data = [3]f32{ options.data_0, options.data_1, options.data_2 },
                }, //Tr
                .{
                    .position = [3]f32{ vertices[3].position[0] + offset[0], -vertices[3].position[1] + offset[1], vertices[3].position[2] },
                    .uv = [2]f32{ if (options.flip_x) max else min, max },
                    .color = color,
                    .data = [3]f32{ options.data_0, options.data_1, options.data_2 },
                }, //Tl
                .{
                    .position = [3]f32{ centroid[0] + offset[0], -centroid[1] + offset[1], 0.0 },
                    .uv = [2]f32{ 0.5, 0.5 },
                    .color = color,
                    .data = [3]f32{ options.data_0, options.data_1, options.data_2 },
                }, //Center
            },
        };

        // Set viewport of quad to the sprite
        quad.setViewport(x, y, width, height, tex_width, tex_height);

        // Apply mirroring
        if (options.flip_x) quad.flipHorizontally();
        if (options.flip_y) quad.flipVertically();

        // Apply rotation
        if (options.rotation > 0.0 or options.rotation < 0.0) quad.rotate(options.rotation, zmath.loadArr2(pivot) + zmath.loadArr2(offset));

        return self.append(quad);
    }

    pub const SpriteOptions = struct {
        color: [4]f32 = .{ 1.0, 1.0, 1.0, 1.0 },
        flip_x: bool = false,
        flip_y: bool = false,
        scale: [2]f32 = .{ 1.0, 1.0 },
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
    pub fn sprite(self: *Batcher, position: zmath.F32x4, t: *gfx.Texture, s: gfx.Sprite, options: SpriteOptions) !void {
        const x = @as(f32, @floatFromInt(s.source[0]));
        const y = @as(f32, @floatFromInt(s.source[1]));
        const width = @as(f32, @floatFromInt(s.source[2]));
        const height = @as(f32, @floatFromInt(s.source[3]));
        const o_x = @as(f32, @floatFromInt(s.origin[0]));
        const o_y = @as(f32, @floatFromInt(s.origin[1]));
        const tex_width = @as(f32, @floatFromInt(t.image.width));
        const tex_height = @as(f32, @floatFromInt(t.image.height));

        const origin_x = if (options.flip_x) o_x - width else -o_x;
        const origin_y = if (options.flip_y) -o_y else o_y - height;
        const pos = @trunc(position);

        const vert_mode: f32 = switch (options.vert_mode) {
            .standard => 0.0,
            .top_sway => 1.0,
        };

        const frag_mode: f32 = switch (options.frag_mode) {
            .standard => 0.0,
            .palette => 1.0,
        };

        var quad = gfx.Quad{
            .vertices = [_]gfx.Vertex{
                .{
                    .position = [3]f32{ (pos[0] + origin_x), (pos[1] + height) + origin_y, pos[2] },
                    .uv = [2]f32{ 0.0, 0.0 },
                    .color = options.color,
                    .data = [3]f32{ vert_mode, frag_mode, options.time },
                }, //Bl
                .{
                    .position = [3]f32{ (pos[0] + width + origin_x), (pos[1] + height) + origin_y, pos[2] },
                    .uv = [2]f32{ 1.0, 0.0 },
                    .color = options.color,
                    .data = [3]f32{ vert_mode, frag_mode, options.time },
                }, //Br
                .{
                    .position = [3]f32{ (pos[0] + width + origin_x), (pos[1]) + origin_y, pos[2] },
                    .uv = [2]f32{ 1.0, 1.0 },
                    .color = options.color,
                    .data = [3]f32{ vert_mode, frag_mode, options.time },
                }, //Tr
                .{
                    .position = [3]f32{ (pos[0] + origin_x), (pos[1]) + origin_y, pos[2] },
                    .uv = [2]f32{ 0.0, 1.0 },
                    .color = options.color,
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

    pub fn end(self: *Batcher, uniforms: anytype, uniform_buffer: *gpu.Buffer) !void {
        const UniformsType = @TypeOf(uniforms);
        const uniforms_type_info = @typeInfo(UniformsType);
        if (uniforms_type_info != .@"struct") {
            @compileError("Expected tuple or struct argument, found " ++ @typeName(UniformsType));
        }
        const uniforms_fields_info = uniforms_type_info.@"struct".fields;

        if (self.state == .idle) return error.EndCalledTwice;
        self.state = .idle;

        // Get the quad count for the current batch.
        const quad_count = self.quad_count - self.start_count;
        if (quad_count < 1) return;

        // Begin the render pass
        pass_blk: {
            const encoder = self.encoder orelse break :pass_blk;
            const swap_chain: *gpu.SwapChain = Pixi.core.windows.get(Pixi.app.window, .swap_chain);
            const back_buffer_view = swap_chain.getCurrentTextureView() orelse break :pass_blk;
            defer back_buffer_view.release();

            const color_attachments = [_]gpu.RenderPassColorAttachment{.{
                .view = if (self.context.output_texture) |out_texture| out_texture.view_handle else back_buffer_view,
                .load_op = .load,
                .store_op = .store,
                .clear_value = self.context.clear_color,
            }};

            const render_pass_info = gpu.RenderPassDescriptor{
                .color_attachment_count = color_attachments.len,
                .color_attachments = &color_attachments,
            };

            encoder.writeBuffer(uniform_buffer, 0, &[_]UniformsType{uniforms});

            const pass: *gpu.RenderPassEncoder = encoder.beginRenderPass(&render_pass_info);
            defer {
                pass.end();
                pass.release();
            }

            pass.setVertexBuffer(0, self.vertex_buffer_handle, 0, self.vertex_buffer_handle.getSize());
            pass.setIndexBuffer(self.index_buffer_handle, .uint32, 0, self.index_buffer_handle.getSize());

            pass.setPipeline(self.context.pipeline_handle);

            if (uniforms_fields_info.len > 0) {
                pass.setBindGroup(0, self.context.bind_group_handle, &.{});
            } else {
                pass.setBindGroup(0, self.context.bind_group_handle, null);
            }

            // Draw only the quads appended this cycle
            pass.drawIndexed(@as(u32, @intCast(quad_count * num_indices)), 1, @as(u32, @intCast(self.start_count * num_indices)), 0, 0);
        }

        pass_blk: {
            if (self.context.compute_bind_group_handle) |compute_bind_group_handle| {
                if (self.context.compute_pipeline_handle) |compute_pipeline_handle| {
                    if (self.context.compute_buffer) |compute_buffer| {
                        if (self.context.staging_buffer) |staging_buffer| {
                            const encoder = self.encoder orelse break :pass_blk;
                            { // Compute pass for blur shader to blur bloom texture
                                const compute_pass = encoder.beginComputePass(null);
                                defer {
                                    compute_pass.end();
                                    compute_pass.release();
                                }
                                compute_pass.setPipeline(compute_pipeline_handle);
                                compute_pass.setBindGroup(0, compute_bind_group_handle, &.{});

                                compute_pass.dispatchWorkgroups(self.context.output_texture.?.image.width, self.context.output_texture.?.image.height, 1);
                            }

                            encoder.copyBufferToBuffer(compute_buffer, 0, staging_buffer, 0, self.context.buffer_size);

                            // TODO: The below method is not implemented in sysgpu yet. In the meantime, we are using a compute shader to copy the
                            // TODO: data to the staging buffer. If this gets implemented, we can skip the compute shader and use this.

                            // encoder.copyTextureToBuffer(
                            //     &.{
                            //         .texture = self.context.output_texture.?.handle,
                            //     },
                            //     &.{
                            //         .buffer = self.context.staging_buffer,
                            //         .layout = .{
                            //             .bytes_per_row = @sizeOf([4]u8) * self.context.output_texture.?.image.width,
                            //             .rows_per_image = self.context.output_texture.?.image.height,
                            //         },
                            //     },
                            //     &.{
                            //         .width = self.context.output_texture.?.image.width,
                            //         .height = self.context.output_texture.?.image.height,
                            //     },
                            // );
                        }
                    }
                }
            }
        }
    }

    pub fn finish(self: *Batcher) !*gpu.CommandBuffer {
        if (self.encoder) |encoder| {
            self.empty = true;

            const queue: *gpu.Queue = Pixi.core.windows.get(Pixi.app.window, .queue);
            // Write the current vertex and index buffers to the queue.
            queue.writeBuffer(self.vertex_buffer_handle, 0, self.vertices[0 .. self.quad_count * num_verts]);
            queue.writeBuffer(self.index_buffer_handle, 0, self.indices[0 .. self.quad_count * num_indices]);
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
        if (self.encoder) |encoder| {
            encoder.release();
        }
        self.encoder = null;
        self.index_buffer_handle.release();
        self.vertex_buffer_handle.release();
        self.allocator.free(self.vertices);
        self.allocator.free(self.indices);
    }
};
