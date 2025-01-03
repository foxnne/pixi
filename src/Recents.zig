const std = @import("std");
const Pixi = @import("Pixi.zig");

const Self = @This();

folders: std.ArrayList([:0]const u8),
exports: std.ArrayList([:0]const u8),

pub fn init(allocator: std.mem.Allocator) !Self {
    var folders = std.ArrayList([:0]const u8).init(allocator);
    var exports = std.ArrayList([:0]const u8).init(allocator);

    const read_opt: ?[]const u8 = Pixi.fs.read(allocator, "recents.json") catch null;
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

pub fn indexOfFolder(self: *Self, path: [:0]const u8) ?usize {
    if (self.folders.items.len == 0) return null;

    for (self.folders.items, 0..) |folder, i| {
        if (std.mem.eql(u8, folder, path))
            return i;
    }
    return null;
}

pub fn indexOfExport(self: *Self, path: [:0]const u8) ?usize {
    if (self.exports.items.len == 0) return null;

    for (self.exports.items, 0..) |exp, i| {
        if (std.mem.eql(u8, exp, path))
            return i;
    }
    return null;
}

pub fn appendFolder(self: *Self, path: [:0]const u8) !void {
    if (self.indexOfFolder(path)) |index| {
        Pixi.state.allocator.free(path);
        const folder = self.folders.swapRemove(index);
        try self.folders.append(folder);
    } else {
        if (self.folders.items.len >= Pixi.state.settings.max_recents) {
            const folder = self.folders.swapRemove(0);
            Pixi.state.allocator.free(folder);
        }

        try self.folders.append(path);
    }
}

pub fn appendExport(self: *Self, path: [:0]const u8) !void {
    if (self.indexOfExport(path)) |index| {
        const exp = self.exports.swapRemove(index);
        try self.exports.append(exp);
    } else {
        if (self.exports.items.len >= Pixi.state.settings.max_recents) {
            const exp = self.folders.swapRemove(0);
            Pixi.state.allocator.free(exp);
        }
        try self.exports.append(path);
    }
}

pub fn save(self: *Self) !void {
    var handle = try std.fs.cwd().createFile("recents.json", .{});
    defer handle.close();

    const out_stream = handle.writer();
    const options = std.json.StringifyOptions{};

    try std.json.stringify(RecentsJson{ .folders = self.folders.items, .exports = self.exports.items }, options, out_stream);
}

pub fn deinit(self: *Self) void {
    for (self.folders.items) |folder| {
        Pixi.state.allocator.free(folder);
    }

    for (self.exports.items) |exp| {
        Pixi.state.allocator.free(exp);
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
