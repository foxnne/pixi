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
        .source = pixi.fs.fromImageFileBytes(name, bytes, invalidation) catch return error.ErrorCreatingImageSource,
    };
}

pub fn fromPixelsPMA(id: u64, name: []const u8, p: []dvui.Color.PMA, invalidation: dvui.ImageSource.InvalidationStrategy) Layer {
    return .{
        .id = id,
        .name = pixi.app.allocator.dupe(u8, name) catch return error.MemoryAllocationFailed,
        .source = pixi.fs.fromPixelsPMA(name, p, invalidation) catch return error.ErrorCreatingImageSource,
    };
}

pub fn fromPixels(name: [:0]const u8, p: []u8, invalidation: dvui.ImageSource.InvalidationStrategy) Layer {
    return .{
        .name = pixi.app.allocator.dupe(u8, name) catch return error.MemoryAllocationFailed,
        .source = pixi.fs.fromPixels(name, p, invalidation) catch return error.ErrorCreatingImageSource,
    };
}

pub fn fromTexture(id: u64, name: []const u8, texture: dvui.Texture, invalidation: dvui.ImageSource.InvalidationStrategy) Layer {
    return .{
        .id = id,
        .name = pixi.app.allocator.dupe(u8, name) catch return error.MemoryAllocationFailed,
        .source = pixi.fs.fromTexture(name, texture, invalidation) catch return error.ErrorCreatingImageSource,
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

pub fn getPointFromIndex(self: *Layer, index: usize) ?dvui.Point {
    if (index >= self.pixels().len) {
        return null;
    }
    return .{ .x = @floatFromInt(index % @as(i32, @intFromFloat(self.size().w))), .y = @floatFromInt(index / @as(i32, @intFromFloat(self.size().w))) };
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
    const x = @as(usize, @intCast(dst_rect[0]));
    const y = @as(usize, @intCast(dst_rect[1]));
    const width = @as(usize, @intCast(dst_rect[2]));
    const height = @as(usize, @intCast(dst_rect[3]));

    const tex_width = @as(usize, @intCast(self.size().w));

    var yy = y;
    var h = height;

    var d = self.pixels()[x + yy * tex_width .. x + yy * tex_width + width];
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
        d = self.pixels()[x + yy * tex_width .. x + yy * tex_width + width];
    }
}

pub fn clear(self: *Layer) void {
    const p = self.pixels();
    @memset(p, .{ 0, 0, 0, 0 });
}

fn write(context: ?*anyopaque, data: ?*anyopaque, size_in_bytes: c_int) callconv(.C) void {
    const zip_file = @as(?*zip.struct_zip_t, @ptrCast(context));

    if (zip_file) |z| {
        _ = zip.zip_entry_write(z, data, @as(usize, @intCast(size_in_bytes)));
    }
}

pub fn writePngToFn(
    layer: *const Layer,
    // image_source: dvui.ImageSource,
    // write_fn: *const fn (ctx: ?*anyopaque, data: ?*anyopaque, size: c_int) callconv(.C) void,
    context: ?*anyopaque,
) !void {
    const s = layer.size();

    const w = @as(c_int, @intFromFloat(s.w));
    const h = @as(c_int, @intFromFloat(s.h));
    const comp = @as(c_int, @intCast(4));
    const data: *anyopaque = switch (layer.source) {
        .pixels => |p| @constCast(@ptrCast(p.rgba.ptr)),
        .pixelsPMA => |p| @constCast(@ptrCast(p.rgba.ptr)),
        else => return error.InvalidImageSource,
    };
    const result = dvui.c.stbi_write_png_to_func(write, context, w, h, comp, data, 0);

    // if the result is 0 then it means an error occured (per stb image write docs)
    if (result == 0) {
        return error.CouldNotWriteImage;
    }
}
