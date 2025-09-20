const std = @import("std");
const pixi = @import("../pixi.zig");

const Recents = @This();

folders: std.array_list.Managed([:0]const u8),
exports: std.array_list.Managed([:0]const u8),

pub fn load(allocator: std.mem.Allocator) !Recents {
    var folders = std.array_list.Managed([:0]const u8).init(allocator);
    var exports = std.array_list.Managed([:0]const u8).init(allocator);

    if (pixi.fs.read(allocator, "recents.json") catch null) |read| {
        defer allocator.free(read);

        const options = std.json.ParseOptions{ .duplicate_field_behavior = .use_first, .ignore_unknown_fields = true };
        if (std.json.parseFromSlice(RecentsJson, allocator, read, options) catch null) |parsed| {
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
        pixi.app.allocator.free(path);
        const folder = recents.folders.swapRemove(index);
        try recents.folders.append(folder);
    } else {
        if (recents.folders.items.len >= pixi.editor.settings.max_recents) {
            const folder = recents.folders.swapRemove(0);
            pixi.app.allocator.free(folder);
        }

        try recents.folders.append(path);
    }
}

pub fn appendExport(recents: *Recents, path: [:0]const u8) !void {
    if (recents.indexOfExport(path)) |index| {
        const exp = recents.exports.swapRemove(index);
        try recents.exports.append(exp);
    } else {
        if (recents.exports.items.len >= pixi.editor.settings.max_recents) {
            const exp = recents.folders.swapRemove(0);
            pixi.app.allocator.free(exp);
        }
        try recents.exports.append(path);
    }
}

pub fn save(recents: *Recents, allocator: std.mem.Allocator) !void {
    const recents_json = RecentsJson{ .folders = recents.folders.items, .exports = recents.exports.items };

    const str = try std.json.Stringify.valueAlloc(allocator, recents_json, .{});
    defer allocator.free(str);

    var file = try std.fs.cwd().createFile("recents.json", .{});
    defer file.close();

    try file.writeAll(str);
}

pub fn deinit(recents: *Recents) void {
    for (recents.folders.items) |folder| {
        pixi.app.allocator.free(folder);
    }

    for (recents.exports.items) |exp| {
        pixi.app.allocator.free(exp);
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
