const std = @import("std");
const zm = @import("zmath");
const game = @import("game");
const zstbi = @import("zstbi");

pub const utils = @import("utils.zig");

pub const Quad = @import("quad.zig").Quad;
pub const Batcher = @import("batcher.zig").Batcher;
pub const Texture = @import("texture.zig").Texture;
pub const Camera = @import("camera.zig").Camera;

pub const Vertex = struct {
    position: [3]f32 = [_]f32{ 0.0, 0.0, 0.0 },
    uv: [2]f32 = [_]f32{ 0.0, 0.0 },
    color: [4]f32 = [_]f32{ 1.0, 1.0, 1.0, 1.0 },
    data: [3]f32 = [_]f32{ 0.0, 0.0, 0.0 },
};

pub const Uniforms = struct {
    mvp: zm.Mat,
};

pub fn createImage(data: []u8, width: u32, height: u32) zstbi.Image {
    return .{
        .data = data,
        .width = width,
        .height = height,
        .num_components = 4,
        .bytes_per_component = 1,
        .bytes_per_row = 4 * width,
        .is_hdr = false,
    };
}
