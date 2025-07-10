const std = @import("std");
const dvui = @import("dvui");
const pixi = @import("../pixi.zig");

const Texture = @import("Texture.zig");
const Layer = @This();

name: [:0]const u8,
texture: Texture,
visible: bool = true,
collapse: bool = false,
id: u64,
//transform_bindgroup: ?*gpu.BindGroup = null,

pub fn pixels(self: *const Layer) [][4]u8 {
    return @as([*][4]u8, @ptrCast(self.texture.ptr))[0 .. (self.texture.width * self.texture.height) / 4];
}

pub fn getPixelIndex(self: Layer, pixel: [2]usize) usize {
    return pixel[0] + pixel[1] * @as(usize, @intCast(self.texture.width));
}

pub fn getPixel(self: Layer, pixel: [2]usize) [4]u8 {
    const index = self.getPixelIndex(pixel);
    return self.pixels()[index];
}

pub fn setPixel(self: *Layer, pixel: [2]usize, color: [4]u8, update: bool) void {
    _ = update; // TODO: Update texture on GPU
    const index = self.getPixelIndex(pixel);
    var p = self.pixels();
    p[index] = color;
    //if (update)
    //self.texture.update(pixi.core.windows.get(pixi.app.window, .device));
}

pub fn setPixelIndex(self: *Layer, index: usize, color: [4]u8, update: bool) void {
    _ = update; // TODO: Update texture on GPU
    var p = self.pixels();
    p[index] = color;
}

pub const ShapeOffsetResult = struct {
    index: usize,
    color: [4]u8,
};

/// Only used for handling getting the pixels surrounding the origin
/// for stroke sizes larger than 1
pub fn getIndexShapeOffset(self: Layer, origin: [2]usize, current_index: usize) ?ShapeOffsetResult {
    const shape = pixi.editor.tools.stroke_shape;
    const size: i32 = @intCast(pixi.editor.tools.stroke_size);

    if (size == 1) {
        if (current_index != 0)
            return null;

        return .{
            .index = self.getPixelIndex(origin),
            .color = self.getPixel(origin),
        };
    }

    const size_center_offset: i32 = -@divFloor(@as(i32, @intCast(size)), 2);
    const index_i32: i32 = @as(i32, @intCast(current_index));
    const pixel_offset: [2]i32 = .{ @mod(index_i32, size) + size_center_offset, @divFloor(index_i32, size) + size_center_offset };

    if (shape == .circle) {
        const extra_pixel_offset_circle: [2]i32 = if (@mod(size, 2) == 0) .{ 1, 1 } else .{ 0, 0 };
        const pixel_offset_circle: [2]i32 = .{ pixel_offset[0] * 2 + extra_pixel_offset_circle[0], pixel_offset[1] * 2 + extra_pixel_offset_circle[1] };
        const sqr_magnitude = pixel_offset_circle[0] * pixel_offset_circle[0] + pixel_offset_circle[1] * pixel_offset_circle[1];

        // adjust radius check for nicer looking circles
        const radius_check_mult: f32 = (if (size == 3 or size > 10) 0.7 else 0.8);

        if (@as(f32, @floatFromInt(sqr_magnitude)) > @as(f32, @floatFromInt(size * size)) * radius_check_mult) {
            return null;
        }
    }

    const pixel_i32: [2]i32 = .{ @as(i32, @intCast(origin[0])) + pixel_offset[0], @as(i32, @intCast(origin[1])) + pixel_offset[1] };

    if (pixel_i32[0] < 0 or pixel_i32[1] < 0 or pixel_i32[0] >= self.texture.width or pixel_i32[1] >= self.texture.height) {
        return null;
    }

    const pixel: [2]usize = .{ @intCast(pixel_i32[0]), @intCast(pixel_i32[1]) };

    return .{
        .index = getPixelIndex(self, pixel),
        .color = getPixel(self, pixel),
    };
}

pub fn clear(self: *Layer, update: bool) void {
    const p = self.pixels();
    @memset(p, .{ 0, 0, 0, 0 });

    if (update)
        self.texture.update(pixi.core.windows.get(pixi.app.window, .device));
}
