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

pub const Selector = enum {
    texture,
    heightmap,
    data,
};

pub fn save(atlas: Atlas, path: []const u8, selector: Selector) !void {
    switch (selector) {
        .texture, .heightmap => {
            if (!std.mem.eql(u8, ".png", std.fs.path.extension(path))) {
                std.log.debug("File name must end with .png extension!", .{});
                return;
            }
            const write_path = std.fmt.allocPrintZ(pixi.editor.arena.allocator(), "{s}", .{path}) catch unreachable;

            switch (selector) {
                .texture => if (atlas.texture) |*texture| try texture.stbi_image().writeToFile(write_path, .png),
                .heightmap => if (atlas.heightmap) |*heightmap| try heightmap.stbi_image().writeToFile(write_path, .png),
                else => unreachable,
            }
        },
        .data => {
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
