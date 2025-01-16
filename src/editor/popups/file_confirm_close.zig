const std = @import("std");
const Pixi = @import("../../Pixi.zig");
const core = @import("mach").core;
const imgui = @import("zig-imgui");

pub fn draw() !void {
    if (Pixi.editor.popups.file_confirm_close) {
        imgui.openPopup("Confirm close...", imgui.PopupFlags_None);
    } else return;

    const popup_width = 350 * Pixi.app.content_scale[0];
    const popup_height = if (Pixi.editor.popups.file_confirm_close_state == .one) 120 * Pixi.app.content_scale[1] else 250 * Pixi.app.content_scale[1];

    const window_size = Pixi.app.window_size;
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
        &Pixi.editor.popups.file_confirm_close,
        modal_flags,
    )) {
        defer imgui.endPopup();
        imgui.spacing();

        const style = imgui.getStyle();
        const spacing = style.item_spacing.x;
        const full_width = popup_width - (style.frame_padding.x * 2.0 * Pixi.app.content_scale[0]) - imgui.calcTextSize("Name").x;
        const third_width = (popup_width - (style.frame_padding.x * 2.0 * Pixi.app.content_scale[0]) - spacing * 2.0) / 3.0;

        switch (Pixi.editor.popups.file_confirm_close_state) {
            .one => {
                if (Pixi.Editor.getFile(Pixi.editor.popups.file_confirm_close_index)) |file| {
                    const base_name = std.fs.path.basename(file.path);
                    const file_name = try std.fmt.allocPrintZ(Pixi.app.allocator, "The file {s} has unsaved changes, are you sure you want to close?", .{base_name});
                    defer Pixi.app.allocator.free(file_name);
                    imgui.textWrapped(file_name);
                }
            },
            .all => {
                imgui.textWrapped("The following files have unsaved changes, are you sure you want to close?");
                imgui.spacing();
                if (imgui.beginChild(
                    "OpenFileArea",
                    .{ .x = 0.0, .y = 120 * Pixi.app.content_scale[1] },
                    imgui.ChildFlags_None,
                    imgui.WindowFlags_None,
                )) {
                    defer imgui.endChild();
                    for (Pixi.app.open_files.items) |file| {
                        const base_name = std.fs.path.basename(file.path);

                        const base_name_z = try std.fmt.allocPrintZ(Pixi.app.allocator, "{s}", .{base_name});
                        defer Pixi.app.allocator.free(base_name_z);

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
            Pixi.editor.popups.file_confirm_close = false;
            if (Pixi.editor.popups.file_confirm_close_exit)
                Pixi.editor.popups.file_confirm_close_exit = false;
        }
        imgui.sameLine();
        if (imgui.buttonEx(if (Pixi.editor.popups.file_confirm_close_state == .one) "Close" else "Close All", .{ .x = third_width, .y = 0.0 })) {
            switch (Pixi.editor.popups.file_confirm_close_state) {
                .one => {
                    try Pixi.Editor.forceCloseFile(Pixi.editor.popups.file_confirm_close_index);
                },
                .all => {
                    const len = Pixi.app.open_files.items.len;
                    var i: usize = 0;
                    while (i < len) : (i += 1) {
                        try Pixi.Editor.forceCloseFile(0);
                    }
                },
                else => unreachable,
            }
            Pixi.editor.popups.file_confirm_close = false;
        }
        imgui.sameLine();
        if (imgui.buttonEx(if (Pixi.editor.popups.file_confirm_close_state == .one) "Save & Close" else "Save & Close All", .{ .x = third_width, .y = 0.0 })) {
            switch (Pixi.editor.popups.file_confirm_close_state) {
                .one => {
                    if (Pixi.Editor.getFile(Pixi.editor.popups.file_confirm_close_index)) |file| {
                        _ = try file.save();
                    }
                    try Pixi.Editor.closeFile(Pixi.editor.popups.file_confirm_close_index);
                },
                .all => {
                    try Pixi.Editor.saveAllFiles();
                    try Pixi.Editor.forceCloseAllFiles();
                },
                else => unreachable,
            }

            Pixi.editor.popups.file_confirm_close = false;
        }

        if (Pixi.editor.popups.file_confirm_close_exit and !Pixi.editor.popups.file_confirm_close) {
            Pixi.editor.popups.file_confirm_close_exit = false;
            Pixi.app.should_close = true;
        }

        imgui.popItemWidth();
    }
    if (!Pixi.editor.popups.file_confirm_close)
        Pixi.editor.popups.file_confirm_close_exit = false;
}
