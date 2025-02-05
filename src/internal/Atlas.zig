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

pub fn save(self: Atlas, path: []const u8, selector: Selector) !void {
    switch (selector) {
        .texture, .heightmap => {
            if (!std.mem.eql(u8, ".png", std.fs.path.extension(path))) {
                std.log.debug("File name must end with .png extension!", .{});
                return;
            }
            const write_path = std.fmt.allocPrintZ(pixi.editor.arena.allocator(), "{s}", .{path}) catch unreachable;

            switch (selector) {
                .texture => if (self.texture) |texture| try texture.image.writeToFile(write_path, .png),
                .heightmap => if (self.heightmap) |heightmap| try heightmap.image.writeToFile(write_path, .png),
                else => unreachable,
            }
        },
        .data => {
            if (!std.mem.eql(u8, ".atlas", std.fs.path.extension(path))) {
                std.log.debug("File name must end with .atlas extension!", .{});
                return;
            }
            if (self.data) |atlas| {
                var handle = try std.fs.cwd().createFile(path, .{});
                defer handle.close();

                const out_stream = handle.writer();
                const options: std.json.StringifyOptions = .{};

                try std.json.stringify(atlas, options, out_stream);
            }
        },
    }
}
