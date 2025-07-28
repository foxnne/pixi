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
    both,
};

pub fn save(atlas: Atlas, path: []const u8, selector: Selector) !void {
    switch (selector) {
        .source, .both => {
            if (!std.mem.eql(u8, ".png", std.fs.path.extension(path))) {
                std.log.debug("File name must end with .png extension!", .{});
                return;
            }
            const write_path = std.fmt.allocPrintZ(pixi.editor.arena.allocator(), "{s}", .{path}) catch unreachable;

            try pixi.fs.writeSourceToPng(&atlas.source, write_path);
        },
        .data, .both => {
            if (!std.mem.eql(u8, ".atlas", std.fs.path.extension(path))) {
                std.log.debug("File name must end with .atlas extension!", .{});
                return;
            }
            if (atlas.data) |data| {
                var handle = try std.fs.cwd().createFile(path, .{});
                defer handle.close();

                const out_stream = handle.writer();
                const options: std.json.StringifyOptions = .{};

                try std.json.stringify(data, options, out_stream);
            }
        },
    }
}
