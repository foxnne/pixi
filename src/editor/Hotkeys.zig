const std = @import("std");
const builtin = @import("builtin");

const pixi = @import("../pixi.zig");
const dvui = @import("dvui");

pub const Hotkeys = @This();

pub fn register() !void {
    const window = dvui.currentWindow();

    if (builtin.os.tag.isDarwin()) {
        try window.keybinds.putNoClobber(window.gpa, "open_folder", .{ .key = .f, .command = true });
        try window.keybinds.putNoClobber(window.gpa, "undo", .{ .key = .z, .command = true, .shift = false });
        try window.keybinds.putNoClobber(window.gpa, "redo", .{ .key = .z, .command = true, .shift = true });
        try window.keybinds.putNoClobber(window.gpa, "zoom", .{ .command = true });
    } else {
        try window.keybinds.putNoClobber(window.gpa, "open_folder", .{ .key = .f, .control = true });
        try window.keybinds.putNoClobber(window.gpa, "undo", .{ .key = .z, .control = true, .shift = false });
        try window.keybinds.putNoClobber(window.gpa, "redo", .{ .key = .z, .control = true, .shift = true });
        try window.keybinds.putNoClobber(window.gpa, "zoom", .{ .control = true });
    }

    try window.keybinds.putNoClobber(window.gpa, "shift", .{ .shift = true });
    try window.keybinds.putNoClobber(window.gpa, "increase_stroke_size", .{ .key = .right_bracket });
    try window.keybinds.putNoClobber(window.gpa, "decrease_stroke_size", .{ .key = .left_bracket });
}

pub fn tick() !void {
    for (dvui.events()) |e| {
        switch (e.evt) {
            .key => |ke| {
                if (ke.matchBind("open_folder") and ke.action == .down) {
                    if (try dvui.dialogNativeFolderSelect(dvui.currentWindow().arena(), .{
                        .title = "Open Project Folder",
                    })) |folder| {
                        try pixi.editor.setProjectFolder(folder);
                    }
                }

                if (ke.matchBind("undo") and ke.action == .down) {
                    if (pixi.editor.getFile(pixi.editor.open_file_index)) |file| {
                        file.history.undoRedo(file, .undo) catch {
                            std.log.err("Failed to undo", .{});
                        };
                    }
                }

                if (ke.matchBind("redo") and ke.action == .down) {
                    if (pixi.editor.getFile(pixi.editor.open_file_index)) |file| {
                        file.history.undoRedo(file, .redo) catch {
                            std.log.err("Failed to undo", .{});
                        };
                    }
                }

                
            },
            else => {},
        }
    }
}
