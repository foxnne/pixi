const std = @import("std");
const dvui = @import("dvui");
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

pub fn fromImageFileBytes(name: []const u8, bytes: []const u8, invalidation: dvui.ImageSource.InvalidationStrategy) !dvui.ImageSource {
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

pub fn fromImageFilePath(name: []const u8, path: []const u8, invalidation: dvui.ImageSource.InvalidationStrategy) !dvui.ImageSource {
    const bytes = try read(pixi.app.allocator, path);
    defer pixi.app.allocator.free(bytes);
    return fromImageFileBytes(name, bytes, invalidation);
}

pub fn fromPixelsPMA(name: []const u8, p: []dvui.Color.PMA, invalidation: dvui.ImageSource.InvalidationStrategy) dvui.ImageSource {
    return .{
        .pixelsPMA = .{
            .name = pixi.app.allocator.dupe(u8, name) catch name,
            .rgba = p,
            .interpolation = .nearest,
            .invalidation = invalidation,
        }, // TODO: Check if this is correct
    };
}

pub fn fromPixels(name: [:0]const u8, p: []u8, invalidation: dvui.ImageSource.InvalidationStrategy) dvui.ImageSource {
    return .{
        .pixels = .{
            .name = pixi.app.allocator.dupe(u8, name) catch name,
            .rgba = p,
            .interpolation = .nearest,
            .invalidation = invalidation,
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
