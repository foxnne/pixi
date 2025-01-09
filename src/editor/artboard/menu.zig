const std = @import("std");
const Pixi = @import("../../Pixi.zig");
const settings = Pixi.settings;
const zstbi = @import("zstbi");
const nfd = @import("nfd");
const imgui = @import("zig-imgui");

pub fn draw() !void {
    imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0 * Pixi.app.content_scale[0], .y = 10.0 * Pixi.app.content_scale[1] });
    imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 6.0 * Pixi.app.content_scale[0], .y = 6.0 * Pixi.app.content_scale[1] });
    defer imgui.popStyleVarEx(2);
    imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_secondary.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_PopupBg, Pixi.editor.theme.foreground.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_HeaderHovered, Pixi.editor.theme.background.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_HeaderActive, Pixi.editor.theme.background.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_Header, Pixi.editor.theme.background.toImguiVec4());
    defer imgui.popStyleColorEx(5);
    if (imgui.beginMenuBar()) {
        defer imgui.endMenuBar();
        if (imgui.beginMenu("File")) {
            imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text.toImguiVec4());
            if (imgui.menuItemEx("Open Folder...", if (Pixi.app.hotkeys.hotkey(.{ .proc = .folder })) |hotkey| hotkey.shortcut else "", false, true)) {
                Pixi.app.popups.file_dialog_request = .{
                    .state = .folder,
                    .type = .project,
                };
            }
            if (Pixi.app.popups.file_dialog_response) |response| {
                if (response.type == .project) {
                    try Pixi.Editor.setProjectFolder(response.path);
                    nfd.freePath(response.path);
                    Pixi.app.popups.file_dialog_response = null;
                }
            }

            if (imgui.beginMenu("Recents")) {
                defer imgui.endMenu();

                for (Pixi.app.recents.folders.items) |folder| {
                    if (imgui.menuItem(folder)) {
                        try Pixi.Editor.setProjectFolder(folder);
                    }
                }
            }

            imgui.separator();

            const file = Pixi.Editor.getFile(Pixi.app.open_file_index);

            if (imgui.menuItemEx(
                "Export as .png...",
                if (Pixi.app.hotkeys.hotkey(.{ .proc = .export_png })) |hotkey| hotkey.shortcut else "",
                false,
                file != null,
            )) {
                Pixi.app.popups.export_to_png = true;
            }

            if (imgui.menuItemEx(
                "Save",
                if (Pixi.app.hotkeys.hotkey(.{ .proc = .save })) |hotkey| hotkey.shortcut else "",
                false,
                file != null and file.?.dirty(),
            )) {
                if (file) |f| {
                    try f.save();
                }
            }

            imgui.popStyleColor();
            imgui.endMenu();
        }
        if (imgui.beginMenu("View")) {
            defer imgui.endMenu();

            imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text.toImguiVec4());
            defer imgui.popStyleColor();

            if (imgui.menuItemEx("Split Artboard", null, Pixi.app.settings.split_artboard, true)) {
                Pixi.app.settings.split_artboard = !Pixi.app.settings.split_artboard;
            }

            if (imgui.beginMenu("Flipbook")) {
                defer imgui.endMenu();

                if (Pixi.Editor.getFile(Pixi.app.open_file_index)) |file| {
                    if (imgui.beginCombo("Flipbook View", switch (file.flipbook_view) {
                        .canvas => "Canvas",
                        .timeline => "Timeline",
                    }, imgui.ComboFlags_None)) {
                        defer imgui.endCombo();

                        if (imgui.selectableEx("Canvas", file.flipbook_view == .canvas, imgui.SelectableFlags_None, .{ .x = 0.0, .y = 0.0 })) {
                            file.flipbook_view = .canvas;
                        }

                        if (imgui.selectableEx("Timeline", file.flipbook_view == .timeline, imgui.SelectableFlags_None, .{ .x = 0.0, .y = 0.0 })) {
                            file.flipbook_view = .timeline;
                        }
                    }

                    if (file.flipbook_view == .canvas) {
                        if (imgui.beginMenu("Flipbook Canvas View")) {
                            defer imgui.endMenu();
                            if (imgui.menuItemEx("Sequential", null, Pixi.app.settings.flipbook_view == .sequential, true)) {
                                Pixi.app.settings.flipbook_view = .sequential;
                            }

                            if (imgui.menuItemEx("Grid", null, Pixi.app.settings.flipbook_view == .grid, true)) {
                                Pixi.app.settings.flipbook_view = .grid;
                            }
                        }
                    }
                }
            }

            if (imgui.menuItemEx("References", "r", Pixi.app.popups.references, true)) {
                Pixi.app.popups.references = !Pixi.app.popups.references;
            }
        }
        if (imgui.beginMenu("Edit")) {
            defer imgui.endMenu();

            imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text.toImguiVec4());
            defer imgui.popStyleColor();

            if (Pixi.Editor.getFile(Pixi.app.open_file_index)) |file| {
                if (imgui.menuItemEx(
                    "Undo",
                    if (Pixi.app.hotkeys.hotkey(.{ .proc = .undo })) |hotkey| hotkey.shortcut else "",
                    false,
                    file.history.undo_stack.items.len > 0,
                ))
                    try file.undo();

                if (imgui.menuItemEx(
                    "Redo",
                    if (Pixi.app.hotkeys.hotkey(.{ .proc = .redo })) |hotkey| hotkey.shortcut else "",
                    false,
                    file.history.redo_stack.items.len > 0,
                ))
                    try file.redo();
            }
        }
        if (imgui.beginMenu("Tools")) {
            imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text.toImguiVec4());
            imgui.popStyleColor();
            imgui.endMenu();
        }
        if (imgui.menuItem("About")) {
            Pixi.app.popups.about = true;
        }
    }
}
