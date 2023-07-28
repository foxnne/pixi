const std = @import("std");
const pixi = @import("root");

const Self = @This();

folders: std.ArrayList([:0]const u8),

pub fn init(allocator: std.mem.Allocator) !Self {
    var folders = std.ArrayList([:0]const u8).init(allocator);

    var read_opt: ?[]const u8 = pixi.fs.read(allocator, "recents.json") catch null;
    if (read_opt) |read| {
        defer allocator.free(read);

        const options = std.json.ParseOptions{ .duplicate_field_behavior = .use_first, .ignore_unknown_fields = true };
        const parsed = try std.json.parseFromSlice(RecentsJson, allocator, read, options);
        defer parsed.deinit();

        for (parsed.value.folders) |folder| {
            const dir_opt = std.fs.openDirAbsoluteZ(folder, .{}) catch null;
            if (dir_opt != null)
                try folders.append(try allocator.dupeZ(u8, folder));
        }
    }

    return .{ .folders = folders };
}

pub fn contains(self: *Self, path: [:0]const u8) bool {
    if (self.folders.items.len == 0) return false;

    for (self.folders.items) |folder| {
        if (std.mem.eql(u8, folder, path))
            return true;
    }
    return false;
}

pub fn save(self: *Self) !void {
    var handle = try std.fs.cwd().createFile("recents.json", .{});
    defer handle.close();

    const out_stream = handle.writer();
    const options = std.json.StringifyOptions{ .whitespace = .{} };

    try std.json.stringify(RecentsJson{ .folders = self.folders.items }, options, out_stream);
}

pub fn deinit(self: *Self) void {
    for (self.folders.items) |folder| {
        pixi.state.allocator.free(folder);
    }

    self.folders.clearAndFree();
    self.folders.deinit();
}

const RecentsJson = struct {
    folders: [][:0]const u8,
};
