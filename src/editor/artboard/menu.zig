const std = @import("std");
const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");
const Editor = pixi.Editor;
const settings = pixi.settings;
const zstbi = @import("zstbi");

pub var mouse_distance: f32 = std.math.floatMax(f32);

pub fn draw() !dvui.App.Result {
    var m = dvui.menu(@src(), .horizontal, .{});
    defer m.deinit();

    if (menuItem(@src(), "File", .{ .submenu = true }, .{
        .expand = .horizontal,
        //.color_accent = .fill,
    })) |r| {
        var animator = dvui.animate(@src(), .{
            .kind = .alpha,
            .duration = 250_000,
        }, .{
            .expand = .both,
        });
        defer animator.deinit();

        var fw = dvui.floatingMenu(@src(), .{ .from = r }, .{});
        defer fw.deinit();

        if (menuItem(@src(), "Dialog", .{}, .{ .expand = .horizontal, .color_accent = .fill }) != null) {
            fw.close();
        }

        if (menuItem(@src(), "Close Menu", .{}, .{ .expand = .horizontal, .color_accent = .fill }) != null) {
            fw.close();
        }
    }

    if (menuItem(
        @src(),
        "Edit",
        .{ .submenu = true },
        .{
            .expand = .horizontal,
            .color_accent = .fill,
        },
    )) |r| {
        var animator = dvui.animate(@src(), .{
            .kind = .alpha,
            .duration = 250_000,
        }, .{
            .expand = .both,
        });
        defer animator.deinit();

        var fw = dvui.floatingMenu(@src(), .{ .from = r }, .{});
        defer fw.deinit();
        _ = menuItem(@src(), "Dummy", .{}, .{ .expand = .horizontal, .color_accent = .fill });
        _ = menuItem(@src(), "Dummy Long", .{}, .{ .expand = .horizontal, .color_accent = .fill });
        _ = menuItem(@src(), "Dummy Super Long", .{}, .{ .expand = .horizontal, .color_accent = .fill });
    }

    return .ok;
}

pub fn menuItem(src: std.builtin.SourceLocation, label_str: []const u8, init_opts: dvui.MenuItemWidget.InitOptions, opts: dvui.Options) ?dvui.Rect.Natural {
    var mi = dvui.menuItem(src, init_opts, opts);

    var ret: ?dvui.Rect.Natural = null;
    if (mi.activeRect()) |r| {
        ret = r;
    }

    dvui.labelNoFmt(@src(), label_str, .{}, opts.strip());

    mi.deinit();

    return ret;
}

// pub fn draw(editor: *Editor) !void {
//     imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0, .y = 10.0 });
//     imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 6.0, .y = 6.0 });
//     defer imgui.popStyleVarEx(2);
//     imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text_secondary.toImguiVec4());
//     imgui.pushStyleColorImVec4(imgui.Col_PopupBg, editor.theme.foreground.toImguiVec4());
//     imgui.pushStyleColorImVec4(imgui.Col_HeaderHovered, editor.theme.background.toImguiVec4());
//     imgui.pushStyleColorImVec4(imgui.Col_HeaderActive, editor.theme.background.toImguiVec4());
//     imgui.pushStyleColorImVec4(imgui.Col_Header, editor.theme.background.toImguiVec4());
//     defer imgui.popStyleColorEx(5);
//     if (imgui.beginMenuBar()) {
//         defer imgui.endMenuBar();
//         if (imgui.beginMenu("File")) {
//             imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text.toImguiVec4());
//             if (imgui.menuItemEx("Open Folder...", if (editor.hotkeys.hotkey(.{ .procedure = .open_folder })) |hotkey| hotkey.shortcut else "", false, true)) {
//                 editor.popups.file_dialog_request = .{
//                     .state = .folder,
//                     .type = .project,
//                 };
//             }
//             if (editor.popups.file_dialog_response) |response| {
//                 if (response.type == .project) {
//                     try editor.setProjectFolder(response.path);
//                     nfd.freePath(response.path);
//                     editor.popups.file_dialog_response = null;
//                 }
//             }

//             if (imgui.beginMenu("Recents")) {
//                 defer imgui.endMenu();

//                 for (editor.recents.folders.items) |folder| {
//                     if (imgui.menuItem(folder)) {
//                         try editor.setProjectFolder(folder);
//                     }
//                 }
//             }

//             imgui.separator();

//             const file = editor.getFile(editor.open_file_index);

//             if (imgui.menuItemEx(
//                 "Export as .png...",
//                 if (editor.hotkeys.hotkey(.{ .procedure = .export_png })) |hotkey| hotkey.shortcut else "",
//                 false,
//                 file != null,
//             )) {
//                 editor.popups.print = true;
//             }

//             if (imgui.menuItemEx(
//                 "Save",
//                 if (editor.hotkeys.hotkey(.{ .procedure = .save })) |hotkey| hotkey.shortcut else "",
//                 false,
//                 file != null and file.?.dirty(),
//             )) {
//                 if (file) |f| {
//                     try f.save();
//                 }
//             }

//             imgui.popStyleColor();
//             imgui.endMenu();
//         }
//         if (imgui.beginMenu("View")) {
//             defer imgui.endMenu();

//             imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text.toImguiVec4());
//             defer imgui.popStyleColor();

//             if (imgui.menuItemEx("Split Artboard", null, editor.settings.split_artboard, true)) {
//                 editor.settings.split_artboard = !editor.settings.split_artboard;
//             }

//             if (imgui.beginMenu("Flipbook")) {
//                 defer imgui.endMenu();

//                 if (editor.getFile(editor.open_file_index)) |file| {
//                     if (imgui.beginCombo("Flipbook View", switch (file.flipbook_view) {
//                         .canvas => "Canvas",
//                         .timeline => "Timeline",
//                     }, imgui.ComboFlags_None)) {
//                         defer imgui.endCombo();

//                         if (imgui.selectableEx("Canvas", file.flipbook_view == .canvas, imgui.SelectableFlags_None, .{ .x = 0.0, .y = 0.0 })) {
//                             file.flipbook_view = .canvas;
//                         }

//                         if (imgui.selectableEx("Timeline", file.flipbook_view == .timeline, imgui.SelectableFlags_None, .{ .x = 0.0, .y = 0.0 })) {
//                             file.flipbook_view = .timeline;
//                         }
//                     }

//                     if (file.flipbook_view == .canvas) {
//                         if (imgui.beginMenu("Flipbook Canvas View")) {
//                             defer imgui.endMenu();
//                             if (imgui.menuItemEx("Sequential", null, editor.settings.flipbook_view == .sequential, true)) {
//                                 editor.settings.flipbook_view = .sequential;
//                             }

//                             if (imgui.menuItemEx("Grid", null, editor.settings.flipbook_view == .grid, true)) {
//                                 editor.settings.flipbook_view = .grid;
//                             }
//                         }
//                     }
//                 }
//             }

//             if (imgui.menuItemEx("References", "r", editor.popups.references, true)) {
//                 editor.popups.references = !editor.popups.references;
//             }
//         }
//         if (imgui.beginMenu("Edit")) {
//             defer imgui.endMenu();

//             imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text.toImguiVec4());
//             defer imgui.popStyleColor();

//             if (editor.getFile(editor.open_file_index)) |file| {
//                 if (imgui.menuItemEx(
//                     "Undo",
//                     if (editor.hotkeys.hotkey(.{ .procedure = .undo })) |hotkey| hotkey.shortcut else "",
//                     false,
//                     file.history.undo_stack.items.len > 0,
//                 ))
//                     try file.undo();

//                 if (imgui.menuItemEx(
//                     "Redo",
//                     if (editor.hotkeys.hotkey(.{ .procedure = .redo })) |hotkey| hotkey.shortcut else "",
//                     false,
//                     file.history.redo_stack.items.len > 0,
//                 ))
//                     try file.redo();
//             }
//         }
//         if (imgui.menuItem("About")) {
//             editor.popups.about = true;
//         }
//     }
// }
