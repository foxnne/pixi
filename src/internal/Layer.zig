const std = @import("std");
const dvui = @import("dvui");
const pixi = @import("../pixi.zig");
const zip = @import("zip");

const Layer = @This();

id: u64,
name: []const u8,
source: dvui.ImageSource,
visible: bool = true,
collapse: bool = false,
dirty: bool = false,

//transform_bindgroup: ?*gpu.BindGroup = null,

pub fn init(id: u64, name: []const u8, s: [2]u32, default_color: dvui.Color.PMA, invalidation: dvui.ImageSource.InvalidationStrategy) !Layer {
    const num_pixels = s[0] * s[1];
    const p = pixi.app.allocator.alloc(dvui.Color.PMA, num_pixels) catch return error.MemoryAllocationFailed;

    @memset(p, default_color);

    return .{
        .id = id,
        .name = pixi.app.allocator.dupe(u8, name) catch return error.MemoryAllocationFailed,
        .source = .{
            .pixelsPMA = .{
                .rgba = p,
                .width = s[0],
                .height = s[1],
                .interpolation = .nearest,
                .invalidation = invalidation,
            },
        },
    };
}

pub fn fromImageFile(id: u64, name: []const u8, bytes: []const u8, invalidation: dvui.ImageSource.InvalidationStrategy) !Layer {
    return .{
        .id = id,
        .name = pixi.app.allocator.dupe(u8, name) catch return error.MemoryAllocationFailed,
        .source = pixi.fs.sourceFromImageFileBytes(name, bytes, invalidation) catch return error.ErrorCreatingImageSource,
    };
}

pub fn fromPixelsPMA(id: u64, name: []const u8, p: []dvui.Color.PMA, invalidation: dvui.ImageSource.InvalidationStrategy) Layer {
    return .{
        .id = id,
        .name = pixi.app.allocator.dupe(u8, name) catch return error.MemoryAllocationFailed,
        .source = pixi.fs.sourceFromPixelsPMA(name, p, invalidation) catch return error.ErrorCreatingImageSource,
    };
}

pub fn fromPixels(name: [:0]const u8, p: []u8, invalidation: dvui.ImageSource.InvalidationStrategy) Layer {
    return .{
        .name = pixi.app.allocator.dupe(u8, name) catch return error.MemoryAllocationFailed,
        .source = pixi.fs.sourceFromPixels(name, p, invalidation) catch return error.ErrorCreatingImageSource,
    };
}

pub fn fromTexture(id: u64, name: []const u8, texture: dvui.Texture, invalidation: dvui.ImageSource.InvalidationStrategy) Layer {
    return .{
        .id = id,
        .name = pixi.app.allocator.dupe(u8, name) catch return error.MemoryAllocationFailed,
        .source = pixi.fs.sourceFromTexture(name, texture, invalidation) catch return error.ErrorCreatingImageSource,
    };
}

pub fn size(self: Layer) dvui.Size {
    return dvui.imageSize(self.source) catch .{ .w = 0, .h = 0 };
}

pub fn deinit(self: *Layer) void {
    switch (self.source) {
        .imageFile => |image| pixi.app.allocator.free(image.bytes),
        .pixels => |p| pixi.app.allocator.free(p.rgba),
        .pixelsPMA => |p| pixi.app.allocator.free(p.rgba),
        .texture => |t| dvui.textureDestroyLater(t),
        else => {},
    }

    pixi.app.allocator.free(self.name);
}

pub fn pixels(self: *Layer) [][4]u8 {
    return pixi.image.pixels(self.source);
}

pub fn getPixelIndex(self: *Layer, pixel: dvui.Point) ?usize {
    return pixi.image.getPixelIndex(self.source, pixel);
}

pub fn getPointFromIndex(self: *Layer, index: usize) ?dvui.Point {
    return pixi.image.getPointFromIndex(self.source, index);
}

pub fn getPixel(self: *Layer, pixel: dvui.Point) ?[4]u8 {
    return pixi.image.getPixel(self.source, pixel);
}

pub fn setPixel(self: *Layer, pixel: dvui.Point, color: [4]u8) void {
    pixi.image.setPixel(self.source, pixel, color);
    //if (update)
    //self.texture.update(pixi.core.windows.get(pixi.app.window, .device));
}

pub fn setPixelIndex(self: *Layer, index: usize, color: [4]u8) void {
    pixi.image.setPixelIndex(self.source, index, color);
}

pub const ShapeOffsetResult = struct {
    index: usize,
    color: [4]u8,
    point: dvui.Point,
};

pub fn invalidate(self: *Layer) void {
    dvui.textureInvalidateCache(self.source.hash());
}

/// Only used for handling getting the pixels surrounding the origin
/// for stroke sizes larger than 1
pub fn getIndexShapeOffset(self: *Layer, origin: dvui.Point, current_index: usize) ?ShapeOffsetResult {
    const shape = pixi.editor.tools.stroke_shape;
    const s: i32 = @intCast(pixi.editor.tools.stroke_size);

    if (s == 1) {
        if (current_index != 0)
            return null;

        if (self.getPixelIndex(origin)) |index| {
            return .{
                .index = index,
                .color = self.pixels()[index],
                .point = origin,
            };
        }
    }

    const size_center_offset: i32 = -@divFloor(@as(i32, @intCast(s)), 2);
    const index_i32: i32 = @as(i32, @intCast(current_index));
    const pixel_offset: [2]i32 = .{ @mod(index_i32, s) + size_center_offset, @divFloor(index_i32, s) + size_center_offset };

    if (shape == .circle) {
        const extra_pixel_offset_circle: [2]i32 = if (@mod(s, 2) == 0) .{ 1, 1 } else .{ 0, 0 };
        const pixel_offset_circle: [2]i32 = .{ pixel_offset[0] * 2 + extra_pixel_offset_circle[0], pixel_offset[1] * 2 + extra_pixel_offset_circle[1] };
        const sqr_magnitude = pixel_offset_circle[0] * pixel_offset_circle[0] + pixel_offset_circle[1] * pixel_offset_circle[1];

        // adjust radius check for nicer looking circles
        const radius_check_mult: f32 = (if (s == 3 or s > 10) 0.7 else 0.8);

        if (@as(f32, @floatFromInt(sqr_magnitude)) > @as(f32, @floatFromInt(s * s)) * radius_check_mult) {
            return null;
        }
    }

    const pixel_i32: [2]i32 = .{ @as(i32, @intFromFloat(origin.x)) + pixel_offset[0], @as(i32, @intFromFloat(origin.y)) + pixel_offset[1] };
    const size_i32: [2]i32 = .{ @as(i32, @intFromFloat(self.size().w)), @as(i32, @intFromFloat(self.size().h)) };

    if (pixel_i32[0] < 0 or pixel_i32[1] < 0 or pixel_i32[0] >= size_i32[0] or pixel_i32[1] >= size_i32[1]) {
        return null;
    }

    const pixel: dvui.Point = .{ .x = @floatFromInt(pixel_i32[0]), .y = @floatFromInt(pixel_i32[1]) };

    if (self.getPixelIndex(pixel)) |index| {
        return .{
            .index = index,
            .color = self.pixels()[index],
            .point = pixel,
        };
    }

    return null;
}

pub fn blit(self: *Layer, src_pixels: [][4]u8, dst_rect: [4]u32, transparent: bool) void {
    pixi.image.blit(self.source, src_pixels, dst_rect, transparent);
}

pub fn clear(self: *Layer) void {
    const p = self.pixels();
    @memset(p, .{ 0, 0, 0, 0 });
}

pub fn writeSourceToZip(
    layer: *const Layer,
    zip_file: ?*anyopaque,
) !void {
    return pixi.fs.writeSourceToZip(layer.source, zip_file);
}

pub fn writeSourceToPng(layer: *const Layer, path: []const u8) !void {
    return pixi.fs.writeSourceToPng(layer.source, path);
}

/// Takes a texture and a src rect and reduces the rect removing all fully transparent pixels
/// If the src rect doesn't contain any opaque pixels, returns null
pub fn reduce(layer: *Layer, src: [4]usize) ?[4]usize {
    const layer_width = @as(usize, @intCast(layer.size().w));
    const read_pixels = layer.pixels();

    const src_x = src[0];
    const src_y = src[1];
    const src_width = src[2];
    const src_height = src[3];

    var top = src_y;
    var bottom = src_y + src_height - 1;
    var left = src_x;
    var right = src_x + src_width - 1;

    top: {
        while (top < bottom) : (top += 1) {
            const start = left + top * layer_width;
            const row = read_pixels[start .. start + src_width];
            for (row) |pixel| {
                if (pixel[3] != 0) {
                    break :top;
                }
            }
        }
    }
    if (top == bottom) return null;

    bottom: {
        while (bottom > top) : (bottom -= 1) {
            const start = left + bottom * layer_width;
            const row = read_pixels[start .. start + src_width];
            for (row) |pixel| {
                if (pixel[3] != 0) {
                    if (bottom < src_y + src_height)
                        bottom += 0; // Replace with 1 if needed
                    break :bottom;
                }
            }
        }
    }

    const height = bottom - top + 1;
    if (height == 0)
        return null;

    const new_top: usize = if (top > 0) top - 1 else 0;

    left: {
        while (left < right) : (left += 1) {
            var y = bottom + 1;
            while (y > new_top) {
                y -= 1;
                if (read_pixels[left + y * layer_width][3] != 0) {
                    break :left;
                }
            }
        }
    }

    right: {
        while (right > left) : (right -= 1) {
            var y = bottom + 1;
            while (y > new_top) {
                y -= 1;
                if (read_pixels[right + y * layer_width][3] != 0) {
                    if (right < src_x + src_width)
                        right += 1;
                    break :right;
                }
            }
        }
    }

    const width = right - left;
    if (width == 0)
        return null;

    // // If we are packing a tileset, we want a uniform / non-tightly-packed grid. We remove all
    // // completely empty sprite cells (the return null cases above), but do not trim transparent
    // // regions during packing.
    // if (pixi.app.pack_tileset) return src;

    return .{
        left,
        top,
        width,
        height,
    };
}
