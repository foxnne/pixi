const std = @import("std");
const pixi = @import("../pixi.zig");
const dvui = @import("dvui");
const zip = @import("zip");

pub fn init(width: u32, height: u32, default_color: dvui.Color.PMA, invalidation: dvui.ImageSource.InvalidationStrategy) !dvui.ImageSource {
    const num_pixels = width * height;
    const p = pixi.app.allocator.alloc(dvui.Color.PMA, num_pixels) catch return error.MemoryAllocationFailed;

    @memset(p, default_color);

    return .{
        .pixelsPMA = .{
            .rgba = p,
            .width = width,
            .height = height,
            .interpolation = .nearest,
            .invalidation = invalidation,
        },
    };
}

pub fn fromImageFileBytes(name: []const u8, file_bytes: []const u8, invalidation: dvui.ImageSource.InvalidationStrategy) !dvui.ImageSource {
    var w: c_int = undefined;
    var h: c_int = undefined;
    var channels_in_file: c_int = undefined;
    const data = dvui.c.stbi_load_from_memory(file_bytes.ptr, @as(c_int, @intCast(file_bytes.len)), &w, &h, &channels_in_file, 4);
    if (data == null) {
        dvui.log.warn("imageTexture stbi_load error on image \"{s}\": {s}\n", .{ name, dvui.c.stbi_failure_reason() });
        return dvui.StbImageError.stbImageError;
    }
    defer dvui.c.stbi_image_free(data);

    return .{
        .pixelsPMA = .{
            .rgba = dvui.Color.PMA.sliceFromRGBA(pixi.app.allocator.dupe(u8, data[0..@intCast(w * h * @sizeOf(dvui.Color.PMA))]) catch return error.MemoryAllocationFailed),
            .width = @as(u32, @intCast(w)),
            .height = @as(u32, @intCast(h)),
            .interpolation = .nearest,
            .invalidation = invalidation,
        },
    };
}

pub fn fromImageFilePath(name: []const u8, path: []const u8, invalidation: dvui.ImageSource.InvalidationStrategy) !dvui.ImageSource {
    const file_byes = try pixi.fs.read(pixi.app.allocator, path);
    defer pixi.app.allocator.free(file_byes);
    return fromImageFileBytes(name, file_byes, invalidation);
}

pub fn fromPixelsPMA(p: []dvui.Color.PMA, width: u32, height: u32, invalidation: dvui.ImageSource.InvalidationStrategy) !dvui.ImageSource {
    return .{
        .pixelsPMA = .{
            .rgba = pixi.app.allocator.dupe(u8, p) catch return error.MemoryAllocationFailed,
            .interpolation = .nearest,
            .invalidation = invalidation,
            .width = width,
            .height = height,
        }, // TODO: Check if this is correct
    };
}

pub fn fromPixels(pixel_data: []u8, width: u32, height: u32, invalidation: dvui.ImageSource.InvalidationStrategy) dvui.ImageSource {
    return .{
        .pixels = .{
            .rgba = pixel_data,
            .interpolation = .nearest,
            .invalidation = invalidation,
            .width = width,
            .height = height,
        }, // TODO: Check if this is correct
    };
}

pub fn fromTexture(name: []const u8, texture: dvui.Texture, invalidation: dvui.ImageSource.InvalidationStrategy) dvui.ImageSource {
    return .{
        .name = pixi.app.allocator.dupe(u8, name) catch name,
        .texture = texture,
        .invalidation = invalidation,
        .interpolation = .nearest,
    };
}

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

pub fn bytes(source: dvui.ImageSource) []u8 {
    switch (source) {
        .pixels => |p| return @as([*]u8, @ptrCast(@constCast(p.rgba.ptr)))[0..(p.width * p.height * 4)],
        .pixelsPMA => |p| return @as([*]u8, @ptrCast(@constCast(p.rgba.ptr)))[0..(p.width * p.height * 4)],
        .texture => |t| return @as([*]u8, @ptrCast(t.ptr))[0..(t.width * t.height * 4)],
        else => {},
    }
    return &.{};
}

pub fn pixelIndex(source: dvui.ImageSource, px: dvui.Point) ?usize {
    if (px.x < 0 or px.y < 0) {
        return null;
    }

    const s = size(source);

    if (px.x > s.w or px.y > s.h) {
        return null;
    }

    const p: [2]usize = .{ @intFromFloat(px.x), @intFromFloat(px.y) };

    const index = p[0] + p[1] * @as(usize, @intFromFloat(s.w));
    if (index >= pixels(source).len) {
        return null;
    }
    return index;
}

pub fn point(source: dvui.ImageSource, index: usize) ?dvui.Point {
    if (index >= pixels(source).len) {
        return null;
    }
    const s = size(source);

    return .{ .x = @floatFromInt(index % @as(usize, @intFromFloat(s.w))), .y = @floatFromInt(index / @as(usize, @intFromFloat(s.w))) };
}

pub fn pixel(source: dvui.ImageSource, p: dvui.Point) ?[4]u8 {
    if (pixelIndex(source, p)) |index| {
        return pixels(source)[index];
    }
    return null;
}

pub fn setPixel(source: dvui.ImageSource, p: dvui.Point, color: [4]u8) void {
    if (pixelIndex(source, p)) |index| {
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

    const tex_width = @as(usize, @intFromFloat(s.w));

    var yy = y;
    var h = height;

    var d = pixels(source)[x + yy * tex_width .. x + yy * tex_width + width];
    var src_y: usize = 0;
    while (h > 0) : (h -= 1) {
        const src_row = src_pixels[src_y * width .. (src_y * width) + width];
        if (!transparent) {
            @memcpy(d, src_row);
        } else {
            for (src_row, d) |src, *dst| {
                if (src[3] > 0) {
                    dst.* = src;
                }
            }
        }

        // next row and move our slice to it as well
        src_y += 1;
        yy += 1;
        d = pixels(source)[x + yy * tex_width .. x + yy * tex_width + width];
    }
}

pub fn writeToZip(
    source: dvui.ImageSource,
    zip_file: ?*anyopaque,
) !void {
    const s: dvui.Size = dvui.imageSize(source) catch .{ .w = 0, .h = 0 };

    const w = @as(c_int, @intFromFloat(s.w));
    const h = @as(c_int, @intFromFloat(s.h));
    const png_encoded = dvui.pngEncode(pixi.editor.arena.allocator(), pixi.image.bytes(source), @intCast(w), @intCast(h), .{ .resolution = 0 }) catch return error.CouldNotWriteImage;

    if (@as(?*zip.struct_zip_t, @ptrCast(zip_file))) |z| {
        _ = zip.zip_entry_write(z, png_encoded.ptr, @as(usize, @intCast(png_encoded.len)));
    }
}

pub fn writeToPng(source: dvui.ImageSource, path: []const u8) !void {
    const s: dvui.Size = dvui.imageSize(source) catch .{ .w = 0, .h = 0 };

    const w: u32 = @intFromFloat(s.w);
    const h: u32 = @intFromFloat(s.h);
    const data: []u8 = switch (source) {
        .pixels => |p| @as([*]u8, @ptrCast(@constCast(p.rgba.ptr)))[0..(p.width * p.height * 4)],
        .pixelsPMA => |p| @as([*]u8, @ptrCast(@constCast(p.rgba.ptr)))[0..(p.width * p.height * 4)],
        else => return error.InvalidImageSource,
    };

    var handle = try std.fs.cwd().createFile(path, .{});
    defer handle.close();

    const out_stream = handle.writer();

    const png_encoded = dvui.pngEncode(dvui.currentWindow().arena(), data, w, h, .{}) catch return error.CouldNotWriteImage;

    out_stream.writeAll(png_encoded) catch return error.CouldNotWriteImage;
}
