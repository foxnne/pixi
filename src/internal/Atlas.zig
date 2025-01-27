const std = @import("std");
const pixi = @import("../pixi.zig");

const Atlas = @This();
const ExternalAtlas = @import("../Atlas.zig");

/// The packed atlas texture
texture: ?pixi.gfx.Texture = null,

/// The packed atlas heightmap
heightmap: ?pixi.gfx.Texture = null,

/// The actual atlas, which contains the sprites and animations data
data: ?ExternalAtlas = undefined,

pub fn save(self: Atlas, path: [:0]const u8) !void {
    if (self.data) |atlas| {
        const atlas_ext = ".atlas";

        const output_path = try std.fmt.allocPrintZ(pixi.app.allocator, "{s}{s}", .{ path, atlas_ext });
        defer pixi.app.allocator.free(output_path);

        var handle = try std.fs.cwd().createFile(output_path, .{});
        defer handle.close();

        const out_stream = handle.writer();
        const options: std.json.StringifyOptions = .{};

        try std.json.stringify(atlas, options, out_stream);
    }

    if (self.texture) |texture| {
        const png_ext = ".png";

        const output_path = try std.fmt.allocPrintZ(pixi.app.allocator, "{s}{s}", .{ path, png_ext });
        defer pixi.app.allocator.free(output_path);

        try texture.image.writeToFile(output_path, .png);
    }

    if (self.heightmap) |heightmap| {
        const png_ext = ".png";

        const output_path = try std.fmt.allocPrintZ(pixi.app.allocator, "{s}_h{s}", .{ path, png_ext });
        defer pixi.app.allocator.free(output_path);

        try heightmap.image.writeToFile(output_path, .png);
    }
}
