const std = @import("std");
const builtin = @import("builtin");

const pixi = @import("../pixi.zig");
const dvui = @import("dvui");

pub const Keybinds = @This();

pub fn register() !void {
    const window = dvui.currentWindow();

    if (builtin.os.tag.isDarwin()) {
        try window.keybinds.putNoClobber(window.gpa, "open_folder", .{ .key = .f, .command = true });
        try window.keybinds.putNoClobber(window.gpa, "undo", .{ .key = .z, .command = true, .shift = false });
        try window.keybinds.putNoClobber(window.gpa, "redo", .{ .key = .z, .command = true, .shift = true });
        try window.keybinds.putNoClobber(window.gpa, "zoom", .{ .command = true });
        try window.keybinds.putNoClobber(window.gpa, "save", .{ .command = true, .key = .s });
        try window.keybinds.putNoClobber(window.gpa, "sample", .{ .control = true });
    } else {
        try window.keybinds.putNoClobber(window.gpa, "open_folder", .{ .key = .f, .control = true });
        try window.keybinds.putNoClobber(window.gpa, "undo", .{ .key = .z, .control = true, .shift = false });
        try window.keybinds.putNoClobber(window.gpa, "redo", .{ .key = .z, .control = true, .shift = true });
        try window.keybinds.putNoClobber(window.gpa, "zoom", .{ .control = true });
        try window.keybinds.putNoClobber(window.gpa, "save", .{ .control = true, .key = .s });
        try window.keybinds.putNoClobber(window.gpa, "sample", .{ .alt = true });
    }

    try window.keybinds.putNoClobber(window.gpa, "shift", .{ .shift = true });
    try window.keybinds.putNoClobber(window.gpa, "increase_stroke_size", .{ .key = .right_bracket });
    try window.keybinds.putNoClobber(window.gpa, "decrease_stroke_size", .{ .key = .left_bracket });
    try window.keybinds.putNoClobber(window.gpa, "quick_tools", .{ .key = .space });

    try window.keybinds.putNoClobber(window.gpa, "pencil", .{ .key = .d });
    try window.keybinds.putNoClobber(window.gpa, "eraser", .{ .key = .e });
    try window.keybinds.putNoClobber(window.gpa, "bucket", .{ .key = .b });
}

// These keybinds are available regardless of the currently focused widget.
// Any binds that need to be consumed by a specific widget do not need to trigger here.
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

                if (ke.matchBind("quick_tools")) {
                    pixi.editor.tools.radial_menu.visible = switch (ke.action) {
                        .down, .repeat => true,
                        .up => false,
                    };
                }

                // if (ke.matchBind("pencil") and ke.action == .down) pixi.editor.tools.set(.pencil);
                // if (ke.matchBind("eraser") and ke.action == .down) pixi.editor.tools.set(.eraser);
                // if (ke.matchBind("bucket") and ke.action == .down) pixi.editor.tools.set(.bucket);
            },
            else => {},
        }
    }
}
