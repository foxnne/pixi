const std = @import("std");
const Pixi = @import("Pixi.zig");

const Recents = @This();

folders: std.ArrayList([:0]const u8),
exports: std.ArrayList([:0]const u8),

pub fn init(allocator: std.mem.Allocator) !Recents {
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

pub fn indexOfFolder(recents: *Recents, path: [:0]const u8) ?usize {
    if (recents.folders.items.len == 0) return null;

    for (recents.folders.items, 0..) |folder, i| {
        if (std.mem.eql(u8, folder, path))
            return i;
    }
    return null;
}

pub fn indexOfExport(recents: *Recents, path: [:0]const u8) ?usize {
    if (recents.exports.items.len == 0) return null;

    for (recents.exports.items, 0..) |exp, i| {
        if (std.mem.eql(u8, exp, path))
            return i;
    }
    return null;
}

pub fn appendFolder(recents: *Recents, path: [:0]const u8) !void {
    if (recents.indexOfFolder(path)) |index| {
        Pixi.state.allocator.free(path);
        const folder = recents.folders.swapRemove(index);
        try recents.folders.append(folder);
    } else {
        if (recents.folders.items.len >= Pixi.state.settings.max_recents) {
            const folder = recents.folders.swapRemove(0);
            Pixi.state.allocator.free(folder);
        }

        try recents.folders.append(path);
    }
}

pub fn appendExport(recents: *Recents, path: [:0]const u8) !void {
    if (recents.indexOfExport(path)) |index| {
        const exp = recents.exports.swapRemove(index);
        try recents.exports.append(exp);
    } else {
        if (recents.exports.items.len >= Pixi.state.settings.max_recents) {
            const exp = recents.folders.swapRemove(0);
            Pixi.state.allocator.free(exp);
        }
        try recents.exports.append(path);
    }
}

pub fn save(recents: *Recents) !void {
    var handle = try std.fs.cwd().createFile("recents.json", .{});
    defer handle.close();

    const out_stream = handle.writer();
    const options = std.json.StringifyOptions{};

    try std.json.stringify(RecentsJson{ .folders = recents.folders.items, .exports = recents.exports.items }, options, out_stream);
}

pub fn deinit(recents: *Recents) void {
    for (recents.folders.items) |folder| {
        Pixi.state.allocator.free(folder);
    }

    for (recents.exports.items) |exp| {
        Pixi.state.allocator.free(exp);
    }

    recents.folders.clearAndFree();
    recents.folders.deinit();

    recents.exports.clearAndFree();
    recents.exports.deinit();
}

const RecentsJson = struct {
    folders: [][:0]const u8,
    exports: [][:0]const u8,
};
