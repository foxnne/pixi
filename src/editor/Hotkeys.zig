const std = @import("std");
const builtin = @import("builtin");

const pixi = @import("../pixi.zig");
const dvui = @import("dvui");

pub const Hotkeys = @This();

pub fn register() !void {
    const window = dvui.currentWindow();

    if (builtin.os.tag.isDarwin()) {
        try window.keybinds.putNoClobber(window.gpa, "open_folder", .{ .key = .f, .command = true });
    } else {
        try window.keybinds.putNoClobber(window.gpa, "open_folder", .{ .key = .f, .control = true });
    }
}

pub fn tick() !void {
    for (dvui.events()) |e| {
        switch (e.evt) {
            .key => |ke| {
                if (ke.matchBind("open_folder") and ke.action == .down) {
                    if (try dvui.dialogNativeFolderSelect(dvui.currentWindow().arena(), .{ .title = "Open Project Folder" })) |folder| {
                        try pixi.editor.setProjectFolder(folder);
                    }
                }
            },
            else => {},
        }
    }
}
