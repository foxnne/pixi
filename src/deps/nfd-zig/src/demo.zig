const std = @import("std");
const nfd = @import("nfd");

pub fn main() !void {
    const file_path = try nfd.saveFileDialog("txt", null);
    if (file_path) |path| {
        defer nfd.freePath(path);
        std.debug.print("saveFileDialog result: {s}\n", .{path});

        const open_path = try nfd.openFileDialog("txt", path);
        if (open_path) |path2| {
            defer nfd.freePath(path2);
            std.debug.print("openFileDialog result: {s}\n", .{path2});
        }
    }
}
