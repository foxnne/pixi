const std = @import("std");
const pixi = @import("../../pixi.zig");
const core = @import("mach-core");
const zgui = @import("zgui").MachImgui(core);
const settings = pixi.settings;
const zstbi = @import("zstbi");
const nfd = @import("nfd");

pub fn draw() void {
    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.window_padding, .v = .{ 10.0 * pixi.content_scale[0], 10.0 * pixi.content_scale[1] } });
    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 6.0 * pixi.content_scale[0], 6.0 * pixi.content_scale[1] } });
    defer zgui.popStyleVar(.{ .count = 2 });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.theme.text_secondary.toSlice() });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.popup_bg, .c = pixi.state.theme.foreground.toSlice() });
    defer zgui.popStyleColor(.{ .count = 2 });
    if (zgui.beginMenuBar()) {
        defer zgui.endMenuBar();
        if (zgui.beginMenu("File", true)) {
            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.theme.text.toSlice() });
            if (zgui.menuItem("Open Folder...", .{
                .shortcut = if (pixi.state.hotkeys.hotkey(.{ .proc = .folder })) |hotkey| hotkey.shortcut else "",
            })) {
                pixi.state.popups.file_dialog_request = .{
                    .state = .folder,
                    .type = .project,
                };
            }
            if (pixi.state.popups.file_dialog_response) |response| {
                if (response.type == .project) {
                    pixi.editor.setProjectFolder(response.path);
                    nfd.freePath(response.path);
                    pixi.state.popups.file_dialog_response = null;
                }
            }

            if (zgui.beginMenu("Recents", true)) {
                defer zgui.endMenu();

                for (pixi.state.recents.folders.items) |folder| {
                    if (zgui.menuItem(folder, .{})) {
                        pixi.editor.setProjectFolder(folder);
                    }
                }
            }

            zgui.separator();

            const file = pixi.editor.getFile(pixi.state.open_file_index);

            if (zgui.menuItem("Export as .png...", .{
                .shortcut = if (pixi.state.hotkeys.hotkey(.{ .proc = .export_png })) |hotkey| hotkey.shortcut else "",
                .enabled = file != null,
            })) {
                pixi.state.popups.export_to_png = true;
            }

            if (zgui.menuItem("Save", .{
                .shortcut = if (pixi.state.hotkeys.hotkey(.{ .proc = .save })) |hotkey| hotkey.shortcut else "",
                .enabled = file != null and file.?.dirty(),
            })) {
                if (file) |f| {
                    f.save() catch unreachable;
                }
            }

            zgui.popStyleColor(.{ .count = 1 });
            zgui.endMenu();
        }
        if (zgui.beginMenu("Edit", true)) {
            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.theme.text.toSlice() });
            zgui.popStyleColor(.{ .count = 1 });

            if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
                if (zgui.menuItem("Undo", .{
                    .shortcut = if (pixi.state.hotkeys.hotkey(.{ .proc = .undo })) |hotkey| hotkey.shortcut else "",
                    .enabled = file.history.undo_stack.items.len > 0,
                }))
                    file.undo() catch unreachable;

                if (zgui.menuItem("Redo", .{
                    .shortcut = if (pixi.state.hotkeys.hotkey(.{ .proc = .redo })) |hotkey| hotkey.shortcut else "",
                    .enabled = file.history.redo_stack.items.len > 0,
                }))
                    file.redo() catch unreachable;
            }

            zgui.endMenu();
        }
        if (zgui.beginMenu("Tools", true)) {
            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.theme.text.toSlice() });
            zgui.popStyleColor(.{ .count = 1 });
            zgui.endMenu();
        }
        if (zgui.menuItem("About", .{})) {
            pixi.state.popups.about = true;
        }
    }
}
