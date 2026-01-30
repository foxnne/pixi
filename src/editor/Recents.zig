const std = @import("std");
const pixi = @import("../pixi.zig");

const Recents = @This();

const RecentsJson = struct {
    last_save_folder: []const u8,
    last_open_folder: []const u8,
    folders: [][]const u8,
};

last_save_folder: ?[]const u8 = null,
last_open_folder: ?[]const u8 = null,
folders: std.array_list.Managed([]const u8),

pub fn load(allocator: std.mem.Allocator, path: []const u8) !Recents {
    var folders = std.array_list.Managed([]const u8).init(allocator);

    if (pixi.fs.read(allocator, path) catch null) |read| {
        defer allocator.free(read);

        const options = std.json.ParseOptions{ .duplicate_field_behavior = .use_first, .ignore_unknown_fields = true };
        if (std.json.parseFromSlice(RecentsJson, allocator, read, options) catch null) |parsed| {
            defer parsed.deinit();

            for (parsed.value.folders) |folder| {
                // Check if the folder exists
                const dir_opt = std.fs.openDirAbsolute(folder, .{}) catch null;
                if (dir_opt != null)
                    try folders.append(try allocator.dupe(u8, folder));
            }

            return .{
                .folders = folders,
                .last_open_folder = if (parsed.value.last_open_folder.len > 0) try allocator.dupe(u8, parsed.value.last_open_folder) else null,
                .last_save_folder = if (parsed.value.last_save_folder.len > 0) try allocator.dupe(u8, parsed.value.last_save_folder) else null,
            };
        }
    }

    return .{
        .folders = folders,
    };
}

pub fn indexOfFolder(recents: *Recents, path: []const u8) ?usize {
    if (recents.folders.items.len == 0) return null;

    for (recents.folders.items, 0..) |folder, i| {
        if (std.mem.eql(u8, folder, path))
            return i;
    }
    return null;
}

pub fn appendFolder(recents: *Recents, path: []const u8) !void {
    if (recents.indexOfFolder(path)) |index| {
        pixi.app.allocator.free(path);
        const folder = recents.folders.orderedRemove(index);
        try recents.folders.append(folder);
    } else {
        if (recents.folders.items.len >= pixi.editor.settings.max_recents) {
            const folder = recents.folders.orderedRemove(0);
            pixi.app.allocator.free(folder);
        }

        try recents.folders.append(path);
    }
}

pub fn save(recents: *Recents, allocator: std.mem.Allocator, path: []const u8) !void {
    const recents_json = RecentsJson{
        .folders = recents.folders.items,
        .last_save_folder = recents.last_save_folder orelse "",
        .last_open_folder = recents.last_open_folder orelse "",
    };

    const str = try std.json.Stringify.valueAlloc(allocator, recents_json, .{});
    defer allocator.free(str);

    var file = try std.fs.createFileAbsolute(path, .{});
    defer file.close();

    try file.writeAll(str);
}

pub fn deinit(recents: *Recents) void {
    for (recents.folders.items) |folder| {
        pixi.app.allocator.free(folder);
    }

    recents.folders.clearAndFree();
    recents.folders.deinit();
}
