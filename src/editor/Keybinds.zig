const std = @import("std");
const builtin = @import("builtin");

const pixi = @import("../pixi.zig");
const dvui = @import("dvui");

pub const Keybinds = @This();

pub fn register() !void {
    const window = dvui.currentWindow();

    if (builtin.os.tag.isDarwin()) {
        try window.keybinds.putNoClobber(window.gpa, "open_folder", .{ .key = .f, .command = true });
        try window.keybinds.putNoClobber(window.gpa, "open_files", .{ .key = .o, .command = true });
        try window.keybinds.putNoClobber(window.gpa, "undo", .{ .key = .z, .command = true, .shift = false });
        try window.keybinds.putNoClobber(window.gpa, "redo", .{ .key = .z, .command = true, .shift = true });
        try window.keybinds.putNoClobber(window.gpa, "zoom", .{ .command = true });
        try window.keybinds.putNoClobber(window.gpa, "save", .{ .command = true, .key = .s });
        try window.keybinds.putNoClobber(window.gpa, "sample", .{ .control = true });
        try window.keybinds.putNoClobber(window.gpa, "transform", .{ .command = true, .key = .t });
        try window.keybinds.putNoClobber(window.gpa, "explorer", .{ .command = true, .key = .e });
    } else {
        try window.keybinds.putNoClobber(window.gpa, "open_folder", .{ .key = .f, .control = true });
        try window.keybinds.putNoClobber(window.gpa, "open_files", .{ .key = .o, .control = true });
        try window.keybinds.putNoClobber(window.gpa, "undo", .{ .key = .z, .control = true, .shift = false });
        try window.keybinds.putNoClobber(window.gpa, "redo", .{ .key = .z, .control = true, .shift = true });
        try window.keybinds.putNoClobber(window.gpa, "zoom", .{ .control = true });
        try window.keybinds.putNoClobber(window.gpa, "save", .{ .control = true, .key = .s });
        try window.keybinds.putNoClobber(window.gpa, "sample", .{ .alt = true });
        try window.keybinds.putNoClobber(window.gpa, "transform", .{ .control = true, .key = .t });
        try window.keybinds.putNoClobber(window.gpa, "explorer", .{ .control = true, .key = .e });
    }

    try window.keybinds.putNoClobber(window.gpa, "shift", .{ .shift = true });
    try window.keybinds.putNoClobber(window.gpa, "increase_stroke_size", .{ .key = .right_bracket });
    try window.keybinds.putNoClobber(window.gpa, "decrease_stroke_size", .{ .key = .left_bracket });
    try window.keybinds.putNoClobber(window.gpa, "quick_tools", .{ .key = .space });

    try window.keybinds.putNoClobber(window.gpa, "pencil", .{ .key = .d, .command = false, .control = false, .alt = false, .shift = false });
    try window.keybinds.putNoClobber(window.gpa, "eraser", .{ .key = .e, .command = false, .control = false, .alt = false, .shift = false });
    try window.keybinds.putNoClobber(window.gpa, "bucket", .{ .key = .b, .command = false, .control = false, .alt = false, .shift = false });
    try window.keybinds.putNoClobber(window.gpa, "selection", .{ .key = .s, .command = false, .control = false, .alt = false, .shift = false });
    try window.keybinds.putNoClobber(window.gpa, "pointer", .{ .key = .escape });

    try window.keybinds.putNoClobber(window.gpa, "up", .{ .key = .up });
    try window.keybinds.putNoClobber(window.gpa, "down", .{ .key = .down });
    try window.keybinds.putNoClobber(window.gpa, "left", .{ .key = .left });
    try window.keybinds.putNoClobber(window.gpa, "right", .{ .key = .right });

    try window.keybinds.putNoClobber(window.gpa, "cancel", .{ .key = .escape });
}

// These keybinds are available regardless of the currently focused widget.
// Any binds that need to be consumed by a specific widget do not need to trigger here.
pub fn tick() !void {
    for (dvui.events()) |e| {
        if (e.handled) continue;

        switch (e.evt) {
            .key => |ke| {
                if (ke.matchBind("open_folder") and ke.action == .down) {
                    if (try dvui.dialogNativeFolderSelect(dvui.currentWindow().arena(), .{
                        .title = "Open Project Folder",
                    })) |folder| {
                        try pixi.editor.setProjectFolder(folder);
                    }
                }

                if (ke.matchBind("open_files") and ke.action == .down) {
                    if (try dvui.dialogNativeFileOpenMultiple(
                        dvui.currentWindow().arena(),
                        .{ .title = "Open Files...", .filter_description = ".pixi, .png", .filters = &.{ "*.pixi", "*.png" } },
                    )) |files| {
                        for (files) |file| {
                            _ = pixi.editor.openFilePath(file, pixi.editor.open_workspace_grouping) catch {
                                std.log.err("Failed to open file: {s}", .{file});
                            };
                        }
                    }
                }

                if (ke.matchBind("quick_tools")) {
                    pixi.editor.tools.radial_menu.visible = switch (ke.action) {
                        .down, .repeat => true,
                        .up => false,
                    };
                    // If we include a refresh here, the underlying gui has a chance to reset the cursor
                    dvui.refresh(null, @src(), dvui.currentWindow().data().id);
                }

                if (ke.matchBind("explorer") and ke.action == .down) {
                    if (pixi.editor.explorer.closed) {
                        pixi.editor.explorer.open();
                    } else {
                        pixi.editor.explorer.close();
                    }
                }

                if (ke.matchBind("activate") and ke.action == .down) {
                    pixi.editor.accept() catch {
                        std.log.err("Failed to accept", .{});
                    };
                }

                if (ke.matchBind("cancel") and ke.action == .down) {
                    pixi.editor.cancel() catch {
                        std.log.err("Failed to cancel", .{});
                    };
                }

                if (ke.matchBind("undo") and (ke.action == .down or ke.action == .repeat)) {
                    pixi.editor.undo() catch {
                        std.log.err("Failed to undo", .{});
                    };
                }

                if (ke.matchBind("copy") and ke.action == .down) {
                    pixi.editor.copy() catch {
                        std.log.err("Failed to copy", .{});
                    };
                }

                if (ke.matchBind("paste") and ke.action == .down) {
                    pixi.editor.paste() catch {
                        std.log.err("Failed to paste", .{});
                    };
                }

                if (ke.matchBind("redo") and (ke.action == .down or ke.action == .repeat)) {
                    pixi.editor.redo() catch {
                        std.log.err("Failed to redo", .{});
                    };
                }

                if (ke.matchBind("save") and ke.action == .down) {
                    pixi.editor.save() catch {
                        std.log.err("Failed to save", .{});
                    };
                }

                if (ke.matchBind("transform") and ke.action == .down) {
                    pixi.editor.transform() catch {
                        std.log.err("Failed to transform", .{});
                    };
                }

                if (ke.matchBind("pencil") and ke.action == .down) {
                    pixi.editor.tools.set(.pencil);
                }
                if (ke.matchBind("eraser") and ke.action == .down) {
                    pixi.editor.tools.set(.eraser);
                }
                if (ke.matchBind("bucket") and ke.action == .down) {
                    pixi.editor.tools.set(.bucket);
                }
                if (ke.matchBind("pointer") and ke.action == .down) {
                    pixi.editor.tools.set(.pointer);
                }
                if (ke.matchBind("selection") and ke.action == .down) {
                    pixi.editor.tools.set(.selection);
                }
            },
            else => {},
        }
    }
}
