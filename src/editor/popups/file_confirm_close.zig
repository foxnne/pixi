const std = @import("std");
const pixi = @import("../../pixi.zig");
const Editor = pixi.Editor;

pub fn draw(editor: *Editor) !void {
    if (editor.popups.file_confirm_close) {
        imgui.openPopup("Confirm close...", imgui.PopupFlags_None);
    } else return;

    const popup_width: f32 = 350;
    const popup_height: f32 = if (editor.popups.file_confirm_close_state == .one) 120 else 250;

    const window_size = pixi.app.window_size;
    const window_center: [2]f32 = .{ window_size[0] / 2.0, window_size[1] / 2.0 };

    imgui.setNextWindowPos(.{
        .x = window_center[0] - popup_width / 2.0,
        .y = window_center[1] - popup_height / 2.0,
    }, imgui.Cond_None);
    imgui.setNextWindowSize(.{
        .x = popup_width,
        .y = popup_height,
    }, imgui.Cond_None);

    var modal_flags: imgui.WindowFlags = 0;
    modal_flags |= imgui.WindowFlags_NoResize;
    modal_flags |= imgui.WindowFlags_NoCollapse;

    if (imgui.beginPopupModal(
        "Confirm close...",
        &editor.popups.file_confirm_close,
        modal_flags,
    )) {
        defer imgui.endPopup();
        imgui.spacing();

        const style = imgui.getStyle();
        const spacing = style.item_spacing.x;
        const full_width = popup_width - (style.frame_padding.x * 2.0) - imgui.calcTextSize("Name").x;
        const third_width = (popup_width - (style.frame_padding.x * 2.0) - spacing * 2.0) / 3.0;

        switch (pixi.editor.popups.file_confirm_close_state) {
            .one => {
                if (editor.getFile(editor.popups.file_confirm_close_index)) |file| {
                    const base_name = std.fs.path.basename(file.path);
                    const file_name = try std.fmt.allocPrintZ(pixi.app.allocator, "The file {s} has unsaved changes, are you sure you want to close?", .{base_name});
                    defer pixi.app.allocator.free(file_name);
                    imgui.textWrapped(file_name);
                }
            },
            .all => {
                imgui.textWrapped("The following files have unsaved changes, are you sure you want to close?");
                imgui.spacing();
                if (imgui.beginChild(
                    "OpenFileArea",
                    .{ .x = 0.0, .y = 120 },
                    imgui.ChildFlags_None,
                    imgui.WindowFlags_None,
                )) {
                    defer imgui.endChild();
                    for (editor.open_files.items) |file| {
                        const base_name = std.fs.path.basename(file.path);

                        const base_name_z = try std.fmt.allocPrintZ(pixi.app.allocator, "{s}", .{base_name});
                        defer pixi.app.allocator.free(base_name_z);

                        if (file.dirty()) imgui.bulletText(base_name_z);
                    }
                }
            },
            else => unreachable,
        }

        imgui.separator();

        imgui.setCursorPosY(popup_height - imgui.getTextLineHeightWithSpacing() * 2.0);

        imgui.pushItemWidth(full_width);
        if (imgui.buttonEx("Cancel", .{ .x = third_width, .y = 0.0 })) {
            pixi.editor.popups.file_confirm_close = false;
            if (editor.popups.file_confirm_close_exit)
                editor.popups.file_confirm_close_exit = false;
        }
        imgui.sameLine();
        if (imgui.buttonEx(if (pixi.editor.popups.file_confirm_close_state == .one) "Close" else "Close All", .{ .x = third_width, .y = 0.0 })) {
            switch (pixi.editor.popups.file_confirm_close_state) {
                .one => {
                    try editor.forceCloseFile(editor.popups.file_confirm_close_index);
                },
                .all => {
                    const len = editor.open_files.items.len;
                    var i: usize = 0;
                    while (i < len) : (i += 1) {
                        try editor.forceCloseFile(0);
                    }
                },
                else => unreachable,
            }
            editor.popups.file_confirm_close = false;
        }
        imgui.sameLine();
        if (imgui.buttonEx(if (pixi.editor.popups.file_confirm_close_state == .one) "Save & Close" else "Save & Close All", .{ .x = third_width, .y = 0.0 })) {
            switch (pixi.editor.popups.file_confirm_close_state) {
                .one => {
                    try editor.save();
                    try editor.closeFile(editor.popups.file_confirm_close_index);
                },
                .all => {
                    try editor.saveAllFiles();
                    try editor.forceCloseAllFiles();
                },
                else => unreachable,
            }

            pixi.editor.popups.file_confirm_close = false;
        }

        if (editor.popups.file_confirm_close_exit and !editor.popups.file_confirm_close) {
            editor.popups.file_confirm_close_exit = false;
            pixi.app.should_close = true;
        }

        imgui.popItemWidth();
    }
    if (!editor.popups.file_confirm_close)
        editor.popups.file_confirm_close_exit = false;
}
