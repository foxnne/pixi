const std = @import("std");
const pixi = @import("../pixi.zig");
const dvui = @import("dvui");

pub fn size(source: dvui.ImageSource) dvui.Size {
    return dvui.imageSize(source) catch .{ .w = 0, .h = 0 };
}

pub fn pixels(source: dvui.ImageSource) [][4]u8 {
    switch (source) {
        .pixels => |p| return @as([*][4]u8, @ptrCast(@constCast(p.rgba.ptr)))[0..(p.width * p.height)],
        .pixelsPMA => |p| return @as([*][4]u8, @ptrCast(@constCast(p.rgba.ptr)))[0..(p.width * p.height)],
        .texture => |t| return @as([*][4]u8, @ptrCast(t.ptr))[0..(t.width * t.height)],
        else => {},
    }
    return &.{};
}

pub fn getPixelIndex(source: dvui.ImageSource, pixel: dvui.Point) ?usize {
    if (pixel.x < 0 or pixel.y < 0) {
        return null;
    }

    const s = size(source);

    if (pixel.x >= s.w or pixel.y >= s.h) {
        return null;
    }

    const p: [2]usize = .{ @intFromFloat(pixel.x), @intFromFloat(pixel.y) };

    const index = p[0] + p[1] * @as(usize, @intFromFloat(s.w));
    if (index >= pixels(source).len) {
        return 0;
    }
    return index;
}

pub fn getPointFromIndex(source: dvui.ImageSource, index: usize) ?dvui.Point {
    if (index >= pixels(source).len) {
        return null;
    }
    const s = size(source);

    return .{ .x = @floatFromInt(index % @as(i32, @intFromFloat(s.w))), .y = @floatFromInt(index / @as(i32, @intFromFloat(s.w))) };
}

pub fn getPixel(source: dvui.ImageSource, pixel: dvui.Point) ?[4]u8 {
    if (getPixelIndex(source, pixel)) |index| {
        return pixels(source)[index];
    }
    return null;
}

pub fn setPixel(source: dvui.ImageSource, pixel: dvui.Point, color: [4]u8) void {
    if (getPixelIndex(source, pixel)) |index| {
        pixels(source)[index] = color;
    }
}

pub fn setPixelIndex(source: dvui.ImageSource, index: usize, color: [4]u8) void {
    if (index >= pixels(source).len) {
        return;
    }
    pixels(source)[index] = color;
}

pub fn blit(source: dvui.ImageSource, src_pixels: [][4]u8, dst_rect: [4]u32, transparent: bool) void {
    const x = @as(usize, @intCast(dst_rect[0]));
    const y = @as(usize, @intCast(dst_rect[1]));
    const width = @as(usize, @intCast(dst_rect[2]));
    const height = @as(usize, @intCast(dst_rect[3]));

    const s = size(source);

    const tex_width = @as(usize, @intCast(s.w));

    var yy = y;
    var h = height;

    var d = pixels(source)[x + yy * tex_width .. x + yy * tex_width + width];
    var src_y: usize = 0;
    while (h > 0) : (h -= 1) {
        const src_row = src_pixels[src_y * width .. (src_y * width) + width];
        if (!transparent) {
            @memcpy(d, src_row);
        } else {
            for (src_row, d) |src, dst| {
                if (src[3] > 0) {
                    dst = src;
                }
            }
        }

        // next row and move our slice to it as well
        src_y += 1;
        yy += 1;
        d = pixels(source)[x + yy * tex_width .. x + yy * tex_width + width];
    }
}
