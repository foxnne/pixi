const std = @import("std");
const pixi = @import("../../pixi.zig");
const core = @import("mach-core");
const settings = pixi.settings;
const zstbi = @import("zstbi");
const nfd = @import("nfd");
const imgui = @import("zig-imgui");

pub fn draw() void {
    imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0 * pixi.content_scale[0], .y = 10.0 * pixi.content_scale[1] });
    imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 6.0 * pixi.content_scale[0], .y = 6.0 * pixi.content_scale[1] });
    defer imgui.popStyleVarEx(2);
    imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_secondary.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_PopupBg, pixi.state.theme.foreground.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_HeaderHovered, pixi.state.theme.background.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_HeaderActive, pixi.state.theme.background.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_Header, pixi.state.theme.background.toImguiVec4());
    defer imgui.popStyleColorEx(5);
    if (imgui.beginMenuBar()) {
        defer imgui.endMenuBar();
        if (imgui.beginMenu("File")) {
            imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text.toImguiVec4());
            if (imgui.menuItemEx("Open Folder...", if (pixi.state.hotkeys.hotkey(.{ .proc = .folder })) |hotkey| hotkey.shortcut else "", false, true)) {
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

            if (imgui.beginMenu("Recents")) {
                defer imgui.endMenu();

                for (pixi.state.recents.folders.items) |folder| {
                    if (imgui.menuItem(folder)) {
                        pixi.editor.setProjectFolder(folder);
                    }
                }
            }

            imgui.separator();

            const file = pixi.editor.getFile(pixi.state.open_file_index);

            if (imgui.menuItemEx(
                "Export as .png...",
                if (pixi.state.hotkeys.hotkey(.{ .proc = .export_png })) |hotkey| hotkey.shortcut else "",
                false,
                file != null,
            )) {
                pixi.state.popups.export_to_png = true;
            }

            if (imgui.menuItemEx(
                "Save",
                if (pixi.state.hotkeys.hotkey(.{ .proc = .save })) |hotkey| hotkey.shortcut else "",
                false,
                file != null and file.?.dirty(),
            )) {
                if (file) |f| {
                    f.save() catch unreachable;
                }
            }

            imgui.popStyleColor();
            imgui.endMenu();
        }
        if (imgui.beginMenu("Edit")) {
            imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text.toImguiVec4());
            imgui.popStyleColor();

            if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
                if (imgui.menuItemEx(
                    "Undo",
                    if (pixi.state.hotkeys.hotkey(.{ .proc = .undo })) |hotkey| hotkey.shortcut else "",
                    false,
                    file.history.undo_stack.items.len > 0,
                ))
                    file.undo() catch unreachable;

                if (imgui.menuItemEx(
                    "Redo",
                    if (pixi.state.hotkeys.hotkey(.{ .proc = .redo })) |hotkey| hotkey.shortcut else "",
                    false,
                    file.history.redo_stack.items.len > 0,
                ))
                    file.redo() catch unreachable;
            }

            imgui.endMenu();
        }
        if (imgui.beginMenu("Tools")) {
            imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text.toImguiVec4());
            imgui.popStyleColor();
            imgui.endMenu();
        }
        if (imgui.menuItem("About")) {
            pixi.state.popups.about = true;
        }
    }
}
