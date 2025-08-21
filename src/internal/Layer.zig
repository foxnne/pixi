const std = @import("std");
const dvui = @import("dvui");
const pixi = @import("../pixi.zig");
const zip = @import("zip");

const Layer = @This();

id: u64,
name: []const u8,
source: dvui.ImageSource,
mask: std.DynamicBitSet,
visible: bool = true,
collapse: bool = false,
dirty: bool = false,

//transform_bindgroup: ?*gpu.BindGroup = null,

pub fn init(id: u64, name: []const u8, width: u32, height: u32, default_color: dvui.Color.PMA, invalidation: dvui.ImageSource.InvalidationStrategy) !Layer {
    const num_pixels = width * height;
    const p = pixi.app.allocator.alloc(dvui.Color.PMA, num_pixels) catch return error.MemoryAllocationFailed;

    @memset(p, default_color);

    return .{
        .id = id,
        .name = pixi.app.allocator.dupe(u8, name) catch return error.MemoryAllocationFailed,
        .source = .{
            .pixelsPMA = .{
                .rgba = p,
                .width = width,
                .height = height,
                .interpolation = .nearest,
                .invalidation = invalidation,
            },
        },
        .mask = std.DynamicBitSet.initEmpty(pixi.app.allocator, num_pixels) catch return error.MemoryAllocationFailed,
    };
}

pub fn fromImageFile(id: u64, name: []const u8, image_bytes: []const u8, invalidation: dvui.ImageSource.InvalidationStrategy) !Layer {
    const source = pixi.image.fromImageFileBytes(name, image_bytes, invalidation) catch return error.ErrorCreatingImageSource;
    const s: dvui.Size = dvui.imageSize(source) catch .{ .w = 0, .h = 0 };
    const mask = std.DynamicBitSet.initEmpty(pixi.app.allocator, @as(usize, @intFromFloat(s.w * s.h))) catch return error.MemoryAllocationFailed;

    return .{
        .id = id,
        .name = pixi.app.allocator.dupe(u8, name) catch return error.MemoryAllocationFailed,
        .source = source,
        .mask = mask,
    };
}

pub fn fromPixelsPMA(id: u64, name: []const u8, pixel_data: []dvui.Color.PMA, width: u32, height: u32, invalidation: dvui.ImageSource.InvalidationStrategy) Layer {
    const source = pixi.image.fromPixelsPMA(pixel_data, width, height, invalidation) catch return error.ErrorCreatingImageSource;
    const mask = std.DynamicBitSet.initEmpty(pixi.app.allocator, @as(usize, @intCast(width * height))) catch return error.MemoryAllocationFailed;

    return .{
        .id = id,
        .name = pixi.app.allocator.dupe(u8, name) catch return error.MemoryAllocationFailed,
        .source = source,
        .mask = mask,
    };
}

pub fn fromPixels(id: u64, name: []const u8, pixel_data: []u8, width: u32, height: u32, invalidation: dvui.ImageSource.InvalidationStrategy) !Layer {
    const source = pixi.image.fromPixels(pixel_data, width, height, invalidation) catch return error.ErrorCreatingImageSource;
    const mask = std.DynamicBitSet.initEmpty(pixi.app.allocator, @as(usize, @intCast(width * height))) catch return error.MemoryAllocationFailed;

    return .{
        .id = id,
        .name = pixi.app.allocator.dupe(u8, name) catch return error.MemoryAllocationFailed,
        .source = source,
        .mask = mask,
    };
}

pub fn fromTexture(id: u64, name: []const u8, texture: dvui.Texture, invalidation: dvui.ImageSource.InvalidationStrategy) Layer {
    const source = pixi.fs.sourceFromTexture(name, texture, invalidation) catch return error.ErrorCreatingImageSource;
    const s: dvui.Size = dvui.imageSize(source) catch .{ .w = 0, .h = 0 };
    const mask = std.DynamicBitSet.initEmpty(pixi.app.allocator, @as(usize, @intFromFloat(s.w * s.h))) catch return error.MemoryAllocationFailed;

    return .{
        .id = id,
        .name = pixi.app.allocator.dupe(u8, name) catch return error.MemoryAllocationFailed,
        .source = source,
        .mask = mask,
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
    }

    pixi.app.allocator.free(self.name);
    self.mask.deinit();
}

pub fn pixels(self: *const Layer) [][4]u8 {
    return pixi.image.pixels(self.source);
}

/// Caller owns memory that must be freed!
pub fn pixelsFromRect(self: *const Layer, allocator: std.mem.Allocator, rect: dvui.Rect) ?[][4]u8 {
    return pixi.image.pixelsFromRect(allocator, self.source, rect);
}

pub fn bytes(self: *const Layer) []u8 {
    return pixi.image.bytes(self.source);
}

pub fn pixelIndex(self: *Layer, p: dvui.Point) ?usize {
    return pixi.image.pixelIndex(self.source, p);
}

pub fn point(self: *Layer, index: usize) ?dvui.Point {
    return pixi.image.point(self.source, index);
}

pub fn pixel(self: *Layer, p: dvui.Point) ?[4]u8 {
    return pixi.image.pixel(self.source, p);
}

pub fn setPixel(self: *Layer, p: dvui.Point, color: [4]u8) void {
    pixi.image.setPixel(self.source, p, color);
}

pub fn setMaskPoint(self: *Layer, p: dvui.Point) void {
    if (self.pixelIndex(p)) |index| {
        self.mask.set(index);
    }
}

pub fn clearMask(self: *Layer) void {
    self.mask.setRangeValue(.{ .start = 0, .end = self.mask.capacity() }, false);
}

pub fn setMaskFromColor(self: *Layer, color: [4]u8) void {
    self.clearMask();
    for (self.pixels(), 0..) |*p, index| {
        if (std.meta.eql(color, p.*)) {
            self.mask.set(index);
        }
    }
}

pub fn setColorFromMask(self: *Layer, color: [4]u8) void {
    const iter = self.mask.iterator(.{ .kind = .set, .direction = .forward });
    while (iter.next()) |index| {
        self.pixels()[index] = color;
    }
}

/// Flood fill a pixel and mark the flood to the mask, so you can handle changes.
pub fn setMaskFloodPoint(layer: *Layer, p: dvui.Point, bounds: dvui.Rect) !void {
    if (!bounds.contains(p)) return;

    layer.clearMask();

    var queue = std.ArrayList(dvui.Point).init(pixi.app.allocator);
    defer queue.deinit();
    queue.append(p) catch return error.MemoryAllocationFailed;

    const directions: [4]dvui.Point = .{
        .{ .x = 0, .y = -1 },
        .{ .x = 0, .y = 1 },
        .{ .x = -1, .y = 0 },
        .{ .x = 1, .y = 0 },
    };

    if (layer.pixelIndex(p)) |index| {
        layer.mask.set(index);
        const original_color = layer.pixels()[index];

        while (queue.pop()) |qp| {
            for (directions) |direction| {
                const new_point = qp.plus(direction);
                if (layer.pixelIndex(new_point)) |iter_index| {
                    if (layer.mask.isSet(iter_index)) continue;
                    if (!std.meta.eql(original_color, layer.pixels()[iter_index])) continue;
                    if (!bounds.contains(new_point)) continue;

                    queue.append(new_point) catch return error.MemoryAllocationFailed;
                    layer.mask.set(iter_index);
                }
            }
        }
    }
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
    self.dirty = false;
}

/// Only used for handling getting the pixels surrounding the origin
/// for stroke sizes larger than 1
pub fn getIndexShapeOffset(self: *Layer, origin: dvui.Point, current_index: usize) ?ShapeOffsetResult {
    const shape = pixi.editor.tools.stroke_shape;
    const s: i32 = @intCast(pixi.editor.tools.stroke_size);

    if (s == 1) {
        if (current_index != 0)
            return null;

        if (self.pixelIndex(origin)) |index| {
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

    const p: dvui.Point = .{ .x = @floatFromInt(pixel_i32[0]), .y = @floatFromInt(pixel_i32[1]) };

    if (self.pixelIndex(p)) |index| {
        return .{
            .index = index,
            .color = self.pixels()[index],
            .point = p,
        };
    }

    return null;
}

pub fn clearRect(self: *Layer, rect: dvui.Rect) void {
    pixi.image.clearRect(self.source, rect);
    self.invalidate();
}

pub fn setRect(self: *Layer, rect: dvui.Rect, color: [4]u8) void {
    pixi.image.setRect(self.source, rect, color);
    self.invalidate();
}

pub fn blit(self: *Layer, src_pixels: [][4]u8, dst_rect: dvui.Rect, transparent: bool) void {
    pixi.image.blit(self.source, src_pixels, dst_rect, transparent);
    self.invalidate();
}

pub fn clear(self: *Layer) void {
    @memset(self.pixels(), .{ 0, 0, 0, 0 });
    self.invalidate();
    self.dirty = false;
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
pub fn reduce(layer: *Layer, src: dvui.Rect) ?dvui.Rect {
    const layer_width = @as(usize, @intFromFloat(layer.size().w));
    const read_pixels = layer.pixels();

    const src_x: usize = @as(usize, @intFromFloat(src.x));
    const src_y: usize = @as(usize, @intFromFloat(src.y));
    const src_width: usize = @as(usize, @intFromFloat(src.w));
    const src_height: usize = @as(usize, @intFromFloat(src.h));

    var top = src_y;
    var bottom = src_y + src_height - 1;
    var left = src_x;
    var right = src_x + src_width - 1;

    top: {
        while (top < bottom) : (top += 1) {
            const start = left + top * layer_width;
            const row = read_pixels[start .. start + src_width];
            for (row) |p| {
                if (p[3] != 0) {
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
            for (row) |p| {
                if (p[3] != 0) {
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
        .x = @floatFromInt(left),
        .y = @floatFromInt(top),
        .w = @floatFromInt(width),
        .h = @floatFromInt(height),
    };
}
