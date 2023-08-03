const std = @import("std");
const pixi = @import("root");

const Self = @This();

themes: std.ArrayList(pixi.editor.Theme),

pub fn load() !Self {
    var themes = std.ArrayList(pixi.editor.Theme).init(pixi.state.allocator);
    var dir = try std.fs.cwd().openIterableDir(pixi.assets.themes, .{ .access_sub_paths = false });
    defer dir.close();
    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .file) {
            const ext = std.fs.path.extension(entry.name);
            if (std.mem.eql(u8, ext, ".json")) {
                const abs_path = try std.fs.path.joinZ(pixi.state.allocator, &.{ pixi.assets.themes, entry.name });
                defer pixi.state.allocator.free(abs_path);
                try themes.append(try pixi.editor.Theme.loadFromFile(abs_path));
            }
        }
    }
    return .{
        .themes = themes,
    };
}

pub fn deinit(self: *Self) void {
    self.themes.clearAndFree();
    self.themes.deinit();
}
