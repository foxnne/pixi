const std = @import("std");
const dvui = @import("dvui");
const pixi = @import("../pixi.zig");

const Texture = @import("Texture.zig");
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
    var w: c_int = undefined;
    var h: c_int = undefined;
    var channels_in_file: c_int = undefined;
    const data = dvui.c.stbi_load_from_memory(bytes.ptr, @as(c_int, @intCast(bytes.len)), &w, &h, &channels_in_file, 4);
    if (data == null) {
        dvui.log.warn("imageTexture stbi_load error on image \"{s}\": {s}\n", .{ name, dvui.c.stbi_failure_reason() });
        return dvui.StbImageError.stbImageError;
    }
    defer dvui.c.stbi_image_free(data);

    return .{
        .id = id,
        .name = pixi.app.allocator.dupe(u8, name) catch return error.MemoryAllocationFailed,
        .source = .{ .pixelsPMA = .{
            .rgba = dvui.Color.PMA.sliceFromRGBA(pixi.app.allocator.dupe(u8, data[0..@intCast(w * h * @sizeOf(dvui.Color.PMA))]) catch return error.MemoryAllocationFailed),
            .width = @as(u32, @intCast(w)),
            .height = @as(u32, @intCast(h)),
            .interpolation = .nearest,
            .invalidation = invalidation,
        } },
    };
}

pub fn fromPixelsPMA(id: u64, name: []const u8, p: []dvui.Color.PMA, invalidation: dvui.ImageSource.InvalidationStrategy) Layer {
    return .{
        .id = id,
        .name = pixi.app.allocator.dupe(u8, name) catch return error.MemoryAllocationFailed,
        .source = .{ .pixelsPMA = .{
            .rgba = p,
            .interpolation = .nearest,
            .invalidation = invalidation,
        } }, // TODO: Check if this is correct
    };
}

pub fn fromPixels(name: [:0]const u8, p: []u8, invalidation: dvui.ImageSource.InvalidationStrategy) Layer {
    return .{
        .name = pixi.app.allocator.dupe(u8, name) catch return error.MemoryAllocationFailed,
        .source = .{ .pixels = .{
            .rgba = p,
            .interpolation = .nearest,
            .invalidation = invalidation,
        } }, // TODO: Check if this is correct
    };
}

pub fn fromTexture(id: u64, name: []const u8, texture: dvui.Texture, invalidation: dvui.ImageSource.InvalidationStrategy) Layer {
    return .{
        .id = id,
        .name = pixi.app.allocator.dupe(u8, name) catch return error.MemoryAllocationFailed,
        .source = .{ .texture = texture, .invalidation = invalidation, .interpolation = .nearest },
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
    switch (self.source) {
        .pixels => |p| return @as([*][4]u8, @ptrCast(@constCast(p.rgba.ptr)))[0..(p.width * p.height)],
        .pixelsPMA => |p| return @as([*][4]u8, @ptrCast(@constCast(p.rgba.ptr)))[0..(p.width * p.height)],
        .texture => |t| return @as([*][4]u8, @ptrCast(t.ptr))[0..(t.width * t.height)],
        else => {},
    }
    return &.{};
}

pub fn getPixelIndex(self: *Layer, pixel: dvui.Point) ?usize {
    if (pixel.x < 0 or pixel.y < 0) {
        return null;
    }

    if (pixel.x >= self.size().w or pixel.y >= self.size().h) {
        return null;
    }

    const p: [2]usize = .{ @intFromFloat(pixel.x), @intFromFloat(pixel.y) };

    const index = p[0] + p[1] * @as(usize, @intFromFloat(self.size().w));
    if (index >= self.pixels().len) {
        return 0;
    }
    return index;
}

pub fn getPixel(self: *Layer, pixel: dvui.Point) ?[4]u8 {
    if (self.getPixelIndex(pixel)) |index| {
        return self.pixels()[index];
    }
    return null;
}

pub fn setPixel(self: *Layer, pixel: dvui.Point, color: [4]u8) void {
    if (self.getPixelIndex(pixel)) |index| {
        self.pixels()[index] = color;
    }
    //if (update)
    //self.texture.update(pixi.core.windows.get(pixi.app.window, .device));
}

pub fn setPixelIndex(self: *Layer, index: usize, color: [4]u8) void {
    if (index >= self.pixels().len) {
        return;
    }
    self.pixels()[index] = color;
}

pub const ShapeOffsetResult = struct {
    index: usize,
    color: [4]u8,
};

pub fn invalidateCache(self: *Layer) void {
    dvui.textureInvalidateCache(self.source.hash());
}

/// Only used for handling getting the pixels surrounding the origin
/// for stroke sizes larger than 1
// pub fn getIndexShapeOffset(self: Layer, origin: [2]usize, current_index: usize) ?ShapeOffsetResult {
//     const shape = pixi.editor.tools.stroke_shape;
//     const size: i32 = @intCast(pixi.editor.tools.stroke_size);

//     if (size == 1) {
//         if (current_index != 0)
//             return null;

//         return .{
//             .index = self.getPixelIndex(origin),
//             .color = self.getPixel(origin),
//         };
//     }

//     const size_center_offset: i32 = -@divFloor(@as(i32, @intCast(size)), 2);
//     const index_i32: i32 = @as(i32, @intCast(current_index));
//     const pixel_offset: [2]i32 = .{ @mod(index_i32, size) + size_center_offset, @divFloor(index_i32, size) + size_center_offset };

//     if (shape == .circle) {
//         const extra_pixel_offset_circle: [2]i32 = if (@mod(size, 2) == 0) .{ 1, 1 } else .{ 0, 0 };
//         const pixel_offset_circle: [2]i32 = .{ pixel_offset[0] * 2 + extra_pixel_offset_circle[0], pixel_offset[1] * 2 + extra_pixel_offset_circle[1] };
//         const sqr_magnitude = pixel_offset_circle[0] * pixel_offset_circle[0] + pixel_offset_circle[1] * pixel_offset_circle[1];

//         // adjust radius check for nicer looking circles
//         const radius_check_mult: f32 = (if (size == 3 or size > 10) 0.7 else 0.8);

//         if (@as(f32, @floatFromInt(sqr_magnitude)) > @as(f32, @floatFromInt(size * size)) * radius_check_mult) {
//             return null;
//         }
//     }

//     const pixel_i32: [2]i32 = .{ @as(i32, @intCast(origin[0])) + pixel_offset[0], @as(i32, @intCast(origin[1])) + pixel_offset[1] };

//     if (pixel_i32[0] < 0 or pixel_i32[1] < 0 or pixel_i32[0] >= self.texture.width or pixel_i32[1] >= self.texture.height) {
//         return null;
//     }

//     const pixel: [2]usize = .{ @intCast(pixel_i32[0]), @intCast(pixel_i32[1]) };

//     return .{
//         .index = getPixelIndex(self, pixel),
//         .color = getPixel(self, pixel),
//     };
// }

pub fn clear(self: *Layer) void {
    const p = self.pixels();
    @memset(p, .{ 0, 0, 0, 0 });
}
