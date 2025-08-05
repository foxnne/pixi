const std = @import("std");
const dvui = @import("dvui");
const zip = @import("zip");
const pixi = @import("../pixi.zig");

/// reads the contents of a file. Returned value is owned by the caller and must be freed!
pub fn read(allocator: std.mem.Allocator, filename: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(filename, .{});

    defer file.close();
    const file_size = try file.getEndPos();

    var buffer = try allocator.alloc(u8, file_size);

    _ = try file.read(buffer[0..buffer.len]);

    return buffer;
}

/// reads the contents of a file. Returned value is owned by the caller and must be freed!
pub fn readZ(allocator: std.mem.Allocator, filename: []const u8) ![:0]u8 {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    var buffer = try allocator.alloc(u8, file_size + 1);
    _ = try file.read(buffer[0..file_size]);
    buffer[file_size] = 0;

    return buffer[0..file_size :0];
}

pub fn sourceFromImageFileBytes(name: []const u8, bytes: []const u8, invalidation: dvui.ImageSource.InvalidationStrategy) !dvui.ImageSource {
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
        .pixelsPMA = .{
            .rgba = dvui.Color.PMA.sliceFromRGBA(pixi.app.allocator.dupe(u8, data[0..@intCast(w * h * @sizeOf(dvui.Color.PMA))]) catch return error.MemoryAllocationFailed),
            .width = @as(u32, @intCast(w)),
            .height = @as(u32, @intCast(h)),
            .interpolation = .nearest,
            .invalidation = invalidation,
        },
    };
}

pub fn sourceFromImageFilePath(name: []const u8, path: []const u8, invalidation: dvui.ImageSource.InvalidationStrategy) !dvui.ImageSource {
    const bytes = try read(pixi.app.allocator, path);
    defer pixi.app.allocator.free(bytes);
    return sourceFromImageFileBytes(name, bytes, invalidation);
}

pub fn sourceFromPixelsPMA(name: []const u8, p: []dvui.Color.PMA, invalidation: dvui.ImageSource.InvalidationStrategy) dvui.ImageSource {
    return .{
        .pixelsPMA = .{
            .name = pixi.app.allocator.dupe(u8, name) catch name,
            .rgba = p,
            .interpolation = .nearest,
            .invalidation = invalidation,
        }, // TODO: Check if this is correct
    };
}

pub fn sourceFromPixels(name: [:0]const u8, p: []u8, invalidation: dvui.ImageSource.InvalidationStrategy) dvui.ImageSource {
    return .{
        .pixels = .{
            .name = pixi.app.allocator.dupe(u8, name) catch name,
            .rgba = p,
            .interpolation = .nearest,
            .invalidation = invalidation,
        }, // TODO: Check if this is correct
    };
}

pub fn sourceFromTexture(name: []const u8, texture: dvui.Texture, invalidation: dvui.ImageSource.InvalidationStrategy) dvui.ImageSource {
    return .{
        .name = pixi.app.allocator.dupe(u8, name) catch name,
        .texture = texture,
        .invalidation = invalidation,
        .interpolation = .nearest,
    };
}

fn write(zip_file: ?*anyopaque, data: ?*anyopaque, size_in_bytes: c_int) callconv(.C) void {
    if (@as(?*zip.struct_zip_t, @ptrCast(zip_file))) |z| {
        _ = zip.zip_entry_write(z, data, @as(usize, @intCast(size_in_bytes)));
    }
}

pub fn writeSourceToZip(
    source: dvui.ImageSource,
    zip_file: ?*anyopaque,
) !void {
    const s: dvui.Size = dvui.imageSize(source) catch .{ .w = 0, .h = 0 };

    const w = @as(c_int, @intFromFloat(s.w));
    const h = @as(c_int, @intFromFloat(s.h));
    const comp = @as(c_int, @intCast(4));
    const data: *anyopaque = switch (source) {
        .pixels => |p| @constCast(@ptrCast(p.rgba.ptr)),
        .pixelsPMA => |p| @constCast(@ptrCast(p.rgba.ptr)),
        else => return error.InvalidImageSource,
    };
    const result = dvui.c.stbi_write_png_to_func(write, zip_file, w, h, comp, data, comp * w);
    // if the result is 0 then it means an error occured (per stb image write docs)
    if (result == 0) {
        return error.CouldNotWriteImage;
    }
}

pub fn writeSourceToPng(source: dvui.ImageSource, path: []const u8) !void {
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
