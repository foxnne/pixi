const std = @import("std");
const glfw = @import("glfw");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const zgui = zgpu.zgui;
const zm = @import("zmath");
const flecs = @import("flecs");
const pixi = @import("pixi");
const gfx = pixi.gfx;

pub const PipelineSettings = struct {
    vertex_shader: [*:0]const u8 = pixi.shaders.default_vs,
    fragment_shader: [*:0]const u8 = pixi.shaders.default_fs,
};

pub fn createPipelineAsync(
    allocator: std.mem.Allocator,
    layout: zgpu.BindGroupLayoutHandle,
    settings: PipelineSettings,
    result: *zgpu.RenderPipelineHandle,
) void {
    const gctx = pixi.state.gctx;

    const pipeline_layout = gctx.createPipelineLayout(&.{
        layout,
    });
    defer gctx.releaseResource(pipeline_layout);

    const vs_module = zgpu.util.createWgslShaderModule(gctx.device, settings.vertex_shader, "vs");
    defer vs_module.release();

    const fs_module = zgpu.util.createWgslShaderModule(gctx.device, settings.fragment_shader, "fs");
    defer fs_module.release();

    // Set blend mode so sprites can overlap
    const blend_state = wgpu.BlendState{
        .color = wgpu.BlendComponent{
            .operation = .add,
            .src_factor = .one,
            .dst_factor = .one_minus_src_alpha,
        },
        .alpha = wgpu.BlendComponent{},
    };

    const color_targets = [_]wgpu.ColorTargetState{.{
        .format = zgpu.GraphicsContext.swapchain_format,
        .blend = &blend_state,
    }};

    const vertex_attributes = [_]wgpu.VertexAttribute{
        .{ .format = .float32x3, .offset = 0, .shader_location = 0 }, // position
        .{ .format = .float32x2, .offset = @offsetOf(gfx.Vertex, "uv"), .shader_location = 1 },
        .{ .format = .float32x4, .offset = @offsetOf(gfx.Vertex, "color"), .shader_location = 2 },
        .{ .format = .float32x3, .offset = @offsetOf(gfx.Vertex, "data"), .shader_location = 3 },
    };
    const vertex_buffer_layouts = [_]wgpu.VertexBufferLayout{.{
        .array_stride = @sizeOf(gfx.Vertex),
        .attribute_count = vertex_attributes.len,
        .attributes = &vertex_attributes,
    }};

    // Create a render pipeline.
    const pipeline_descriptor = wgpu.RenderPipelineDescriptor{
        .vertex = wgpu.VertexState{
            .module = vs_module,
            .entry_point = "main",
            .buffer_count = vertex_buffer_layouts.len,
            .buffers = &vertex_buffer_layouts,
        },
        .primitive = wgpu.PrimitiveState{
            .front_face = .cw,
            .cull_mode = .back,
            .topology = .triangle_list,
        },
        .fragment = &wgpu.FragmentState{
            .module = fs_module,
            .entry_point = "main",
            .target_count = color_targets.len,
            .targets = &color_targets,
        },
    };
    gctx.createRenderPipelineAsync(allocator, pipeline_layout, pipeline_descriptor, result);
}
