const std = @import("std");
const pixi = @import("root");

const Self = @This();

folders: std.ArrayList([:0]const u8),
exports: std.ArrayList([:0]const u8),

pub fn init(allocator: std.mem.Allocator) !Self {
    var folders = std.ArrayList([:0]const u8).init(allocator);
    var exports = std.ArrayList([:0]const u8).init(allocator);

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

        for (parsed.value.exports) |exp| {
            if (std.fs.path.dirname(exp)) |path| {
                const dir_opt = std.fs.openDirAbsolute(path, .{}) catch null;
                if (dir_opt != null)
                    try exports.append(try allocator.dupeZ(u8, exp));
            }
        }
    }

    return .{ .folders = folders, .exports = exports };
}

pub fn containsFolder(self: *Self, path: [:0]const u8) bool {
    if (self.folders.items.len == 0) return false;

    for (self.folders.items) |folder| {
        if (std.mem.eql(u8, folder, path))
            return true;
    }
    return false;
}

pub fn containsExport(self: *Self, path: [:0]const u8) bool {
    if (self.exports.items.len == 0) return false;

    for (self.folders.exports) |exp| {
        if (std.mem.eql(u8, exp, path))
            return true;
    }
    return false;
}

pub fn save(self: *Self) !void {
    var handle = try std.fs.cwd().createFile("recents.json", .{});
    defer handle.close();

    const out_stream = handle.writer();
    const options = std.json.StringifyOptions{ .whitespace = .{} };

    try std.json.stringify(RecentsJson{ .folders = self.folders.items, .exports = self.exports.items }, options, out_stream);
}

pub fn deinit(self: *Self) void {
    for (self.folders.items) |folder| {
        pixi.state.allocator.free(folder);
    }

    for (self.exports.items) |exp| {
        pixi.state.allocator.free(exp);
    }

    self.folders.clearAndFree();
    self.folders.deinit();

    self.exports.clearAndFree();
    self.exports.deinit();
}

const RecentsJson = struct {
    folders: [][:0]const u8,
    exports: [][:0]const u8,
};
