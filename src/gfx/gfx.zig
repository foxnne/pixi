const std = @import("std");
const zm = @import("zmath");
const Pixi = @import("../Pixi.zig");
const zstbi = @import("zstbi");

const build_options = @import("build-options");

const mach = @import("mach");
const Core = mach.Core;
const gpu = mach.gpu;

pub const Quad = @import("quad.zig").Quad;
pub const Batcher = @import("batcher.zig").Batcher;
pub const Texture = @import("texture.zig").Texture;
pub const Camera = @import("camera.zig").Camera;
pub const Atlas = @import("atlas.zig").Atlas;
pub const Sprite = @import("sprite.zig").Sprite;

pub const Vertex = struct {
    position: [3]f32 = [_]f32{ 0.0, 0.0, 0.0 },
    uv: [2]f32 = [_]f32{ 0.0, 0.0 },
    color: [4]f32 = [_]f32{ 1.0, 1.0, 1.0, 1.0 },
    data: [3]f32 = [_]f32{ 0.0, 0.0, 0.0 },
};

pub const UniformBufferObject = struct {
    mvp: zm.Mat,
};

pub fn init(app: *Pixi) !void {
    const device: *gpu.Device = Pixi.core.windows.get(Pixi.app.window, .device);

    const default_shader = @embedFile("../shaders/default.wgsl");
    const default_shader_module = device.createShaderModuleWGSL("default.wgsl", default_shader);

    defer default_shader_module.release();

    const compute_shader = @embedFile("../shaders/compute.wgsl");
    const compute_shader_module = device.createShaderModuleWGSL("compute.wgsl", compute_shader);

    defer compute_shader_module.release();

    const vertex_attributes = [_]gpu.VertexAttribute{
        .{ .format = .float32x3, .offset = @offsetOf(Vertex, "position"), .shader_location = 0 },
        .{ .format = .float32x2, .offset = @offsetOf(Vertex, "uv"), .shader_location = 1 },
        .{ .format = .float32x4, .offset = @offsetOf(Vertex, "color"), .shader_location = 2 },
        .{ .format = .float32x3, .offset = @offsetOf(Vertex, "data"), .shader_location = 3 },
    };
    const vertex_buffer_layout = gpu.VertexBufferLayout.init(.{
        .array_stride = @sizeOf(Vertex),
        .step_mode = .vertex,
        .attributes = &vertex_attributes,
    });

    const blend = gpu.BlendState{
        .color = .{
            .operation = .add,
            .src_factor = .src_alpha,
            .dst_factor = .one_minus_src_alpha,
        },
        .alpha = .{
            .operation = .add,
            .src_factor = .src_alpha,
            .dst_factor = .one_minus_src_alpha,
        },
    };

    const color_target = gpu.ColorTargetState{
        .format = .rgba8_unorm,
        .blend = &blend,
        .write_mask = gpu.ColorWriteMaskFlags.all,
    };

    const default_fragment = gpu.FragmentState.init(.{
        .module = default_shader_module,
        .entry_point = "frag_main",
        .targets = &.{color_target},
    });

    const default_vertex = gpu.VertexState.init(.{
        .module = default_shader_module,
        .entry_point = "vert_main",
        .buffers = &.{vertex_buffer_layout},
    });

    const default_pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .fragment = &default_fragment,
        .vertex = default_vertex,
    };

    app.pipeline_default = device.createRenderPipeline(&default_pipeline_descriptor);

    app.uniform_buffer_default = device.createBuffer(&.{
        .usage = .{ .copy_dst = true, .uniform = true },
        .size = @sizeOf(UniformBufferObject),
        .mapped_at_creation = .false,
    });

    const compute_pipeline_descriptor = gpu.ComputePipeline.Descriptor{
        .compute = gpu.ProgrammableStageDescriptor{
            .module = compute_shader_module,
            .entry_point = "copyTextureToBuffer",
        },
    };

    app.pipeline_compute = device.createComputePipeline(&compute_pipeline_descriptor);
}
