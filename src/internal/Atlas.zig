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
            const ext = std.fs.path.extension(path);
            const write_path = std.fmt.allocPrintSentinel(pixi.editor.arena.allocator(), "{s}", .{path}, 0) catch unreachable;

            if (std.mem.eql(u8, ext, ".png")) {
                try pixi.image.writeToPng(atlas.source, write_path);
            } else if (std.mem.eql(u8, ext, ".jpg") or std.mem.eql(u8, ext, ".jpeg")) {
                try pixi.image.writeToJpg(atlas.source, write_path);
            } else {
                std.log.debug("File name must end with .png, .jpg, or .jpeg extension!", .{});
                return error.InvalidExtension;
            }
        },
        .data => {
            if (!std.mem.eql(u8, ".atlas", std.fs.path.extension(path))) {
                std.log.debug("File name must end with .atlas extension!", .{});
                return error.InvalidExtension;
            }
            const options: std.json.Stringify.Options = .{};

            const output = try std.json.Stringify.valueAlloc(pixi.editor.arena.allocator(), atlas.data, options);

            std.Io.Dir.cwd().writeFile(dvui.io, .{ .sub_path = path, .data = output }) catch return error.CouldNotWriteAtlasData;
        },
    }
}
