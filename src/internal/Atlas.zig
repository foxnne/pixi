const std = @import("std");
const pixi = @import("../pixi.zig");
const dvui = @import("dvui");

const Atlas = @This();
const ExternalAtlas = @import("../Atlas.zig");

/// The packed atlas texture
source: dvui.ImageSource,
canvas: pixi.dvui.CanvasWidget = .{},

// /// The packed atlas heightmap
// heightmap: ?pixi.gfx.Texture = null,

/// The actual atlas, which contains the sprites and animations data
data: ExternalAtlas,

pub const Selector = enum {
    source,
    data,
};

pub fn save(atlas: Atlas, path: []const u8, selector: Selector) !void {
    switch (selector) {
        .source => {
            if (!std.mem.eql(u8, ".png", std.fs.path.extension(path))) {
                std.log.debug("File name must end with .png extension!", .{});
                return error.InvalidExtension;
            }
            const write_path = std.fmt.allocPrintZ(pixi.editor.arena.allocator(), "{s}", .{path}) catch unreachable;

            try pixi.image.writeToPng(atlas.source, write_path);
        },
        .data => {
            if (!std.mem.eql(u8, ".atlas", std.fs.path.extension(path))) {
                std.log.debug("File name must end with .atlas extension!", .{});
                return error.InvalidExtension;
            }
            var handle = try std.fs.cwd().createFile(path, .{});
            defer handle.close();

            const out_stream = handle.writer();
            const options: std.json.StringifyOptions = .{};

            try std.json.stringify(atlas.data, options, out_stream);
        },
    }
}
