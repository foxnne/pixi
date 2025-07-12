const pixi = @import("../pixi.zig");
const dvui = @import("dvui");
const std = @import("std");

const Texture = @This();

ptr: *anyopaque,
width: u32,
height: u32,

pub fn loadFromFilePath(path: []const u8, interpolation: dvui.enums.TextureInterpolation) !Texture {
    const p = pixi.fs.read(path) catch return error.FailedToOpenFile;
    return .fromDvui(dvui.Texture.fromImageFile(path, p, interpolation) catch return error.FailedToCreateTexture);
}

pub fn loadFromFileData(name: []const u8, file_data: []const u8, interpolation: dvui.enums.TextureInterpolation) !Texture {
    return .fromDvui(dvui.Texture.fromImageFile(name, file_data, interpolation) catch return error.FailedToCreateTexture);
}

pub fn loadFromMemory(p: []const dvui.Color.PMA, width: u32, height: u32, interpolation: dvui.enums.TextureInterpolation) !Texture {
    std.debug.assert(p.len == width * height);
    return .fromDvui(dvui.Texture.fromPixelsPMA(p, width, height, interpolation) catch return error.FailedToCreateTexture);
}

pub fn create(width: u32, height: u32, interpolation: dvui.enums.TextureInterpolation) !Texture {
    const p = try pixi.app.allocator.alloc(dvui.Color.PMA, width * height);
    @memset(p, .{ .r = 0, .g = 0, .b = 0, .a = 255 });
    return .fromDvui(dvui.Texture.fromPixelsPMA(p, width, height, interpolation) catch return error.FailedToCreateTexture);
}

pub fn toTarget(self: *Texture) dvui.TextureTarget {
    return .{
        .ptr = self.ptr,
        .width = self.width,
        .height = self.height,
    };
}

pub fn fromTarget(target: dvui.TextureTarget) Texture {
    return .{
        .ptr = target.ptr,
        .width = target.width,
        .height = target.height,
    };
}

pub fn fromDvui(texture: dvui.Texture) Texture {
    return .{
        .ptr = texture.ptr,
        .width = texture.width,
        .height = texture.height,
    };
}

pub fn toDvui(self: *Texture) dvui.Texture {
    return .{
        .ptr = self.ptr,
        .width = self.width,
        .height = self.height,
    };
}

pub fn data(self: *Texture) []u8 {
    return @as([*]u8, @ptrCast(self.ptr))[0 .. self.width * self.height * 4];
}

pub fn pixels(self: *Texture) [][4]u8 {
    return @as([*][4]u8, @ptrCast(self.ptr))[0 .. (self.width * self.height) / 4];
}

pub fn pixel(self: *Texture, x: u32, y: u32) u8 {
    return self.pixels()[y * self.width + x];
}

pub fn getPixelIndex(self: Texture, pixel_coords: [2]u32) usize {
    return @as(usize, @intCast(pixel_coords[0])) + @as(usize, @intCast(pixel_coords[1])) * @as(usize, @intCast(self.width));
}

pub fn getPixel(self: Texture, pixel_coords: [2]u32) u8 {
    const index = self.getPixelIndex(pixel_coords);
    if (index < self.pixels().len) {
        return self.pixels()[index];
    }
    return 0;
}

pub fn setPixel(self: *Texture, pixel_coords: [2]u32, color: [4]u8, update: bool) void {
    _ = update; // TODO: Update texture on GPU

    const index = self.getPixelIndex(pixel_coords);
    if (index < self.pixels().len) {
        self.pixels()[index] = color;
    }
}

pub fn setPixelIndex(self: *Texture, index: usize, color: [4]u8, update: bool) void {
    _ = update; // TODO: Update texture on GPU
    self.pixels()[index] = color;
}

pub fn blit(self: *Texture, src_pixels: [][4]u8, dst_rect: [4]u32) void {
    const x = @as(usize, @intCast(dst_rect[0]));
    const y = @as(usize, @intCast(dst_rect[1]));
    const width = @as(usize, @intCast(dst_rect[2]));
    const height = @as(usize, @intCast(dst_rect[3]));

    const tex_width = @as(usize, @intCast(self.width));

    var yy = y;
    var h = height;

    var dst_pixels = @as([*][4]u8, @ptrCast(self.pixels().ptr))[0 .. self.pixels().len / 4];

    var d = dst_pixels[x + yy * tex_width .. x + yy * tex_width + width];
    var src_y: usize = 0;
    while (h > 0) : (h -= 1) {
        const src_row = src_pixels[src_y * width .. (src_y * width) + width];
        @memcpy(d, src_row);

        // next row and move our slice to it as well
        src_y += 1;
        yy += 1;
        d = dst_pixels[x + yy * tex_width .. x + yy * tex_width + width];
    }
}
