const std = @import("std");
const pixi = @import("root");

const Self = @This();

primary: [4]u8 = .{ 255, 255, 255, 255 },
secondary: [4]u8 = .{ 0, 0, 0, 255 },
height: u8 = 0,
palettes: std.ArrayList(pixi.storage.Internal.Palette),
selected_palette_index: usize = 0,

pub fn load() !Self {
    var palettes = std.ArrayList(pixi.storage.Internal.Palette).init(pixi.state.allocator);
    var dir = std.fs.cwd().openIterableDir(pixi.assets.palettes, .{ .access_sub_paths = false }) catch unreachable;
    defer dir.close();
    var iter = dir.iterate();
    while (iter.next() catch unreachable) |entry| {
        if (entry.kind == .file) {
            const ext = std.fs.path.extension(entry.name);
            if (std.mem.eql(u8, ext, ".hex")) {
                const abs_path = try std.fs.path.joinZ(pixi.state.allocator, &.{ pixi.assets.palettes, entry.name });
                defer pixi.state.allocator.free(abs_path);
                try palettes.append(try pixi.storage.Internal.Palette.loadFromFile(abs_path));
            }
        }
    }
    return .{
        .palettes = palettes,
    };
}

pub fn deinit(self: *Self) void {
    for (self.palettes.items) |*palette| {
        pixi.state.allocator.free(palette.name);
        pixi.state.allocator.free(palette.colors);
    }
    self.palettes.deinit();
}
