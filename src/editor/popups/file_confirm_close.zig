const std = @import("std");
const pixi = @import("../../pixi.zig");
const core = @import("mach-core");
const imgui = @import("zig-imgui");

pub fn draw() void {
    if (pixi.state.popups.file_confirm_close) {
        imgui.openPopup("Confirm close...", imgui.PopupFlags_None);
    } else return;

    const popup_width = 350 * pixi.content_scale[0];
    const popup_height = if (pixi.state.popups.file_confirm_close_state == .one) 120 * pixi.content_scale[1] else 250 * pixi.content_scale[1];

    var window_size = pixi.window_size;
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
        &pixi.state.popups.file_confirm_close,
        modal_flags,
    )) {
        defer imgui.endPopup();
        imgui.spacing();

        const style = imgui.getStyle();
        const spacing = style.item_spacing.x;
        const full_width = popup_width - (style.frame_padding.x * 2.0 * pixi.content_scale[0]) - imgui.calcTextSize("Name").x;
        const third_width = (popup_width - (style.frame_padding.x * 2.0 * pixi.content_scale[0]) - spacing * 2.0) / 3.0;

        switch (pixi.state.popups.file_confirm_close_state) {
            .one => {
                if (pixi.editor.getFile(pixi.state.popups.file_confirm_close_index)) |file| {
                    const base_name = std.fs.path.basename(file.path);
                    const file_name = std.fmt.allocPrintZ(pixi.state.allocator, "The file {s} has unsaved changes, are you sure you want to close?", .{base_name}) catch unreachable;
                    defer pixi.state.allocator.free(file_name);
                    imgui.textWrapped(file_name);
                }
            },
            .all => {
                imgui.textWrapped("The following files have unsaved changes, are you sure you want to close?");
                imgui.spacing();
                if (imgui.beginChild("OpenFileArea", .{ .x = 0.0, .y = 120 * pixi.content_scale[1] }, false, imgui.WindowFlags_None)) {
                    defer imgui.endChild();
                    for (pixi.state.open_files.items) |file| {
                        const base_name = std.fs.path.basename(file.path);

                        const base_name_z = std.fmt.allocPrintZ(pixi.state.allocator, "{s}", .{base_name}) catch unreachable;
                        pixi.state.allocator.free(base_name_z);

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
            pixi.state.popups.file_confirm_close = false;
            if (pixi.state.popups.file_confirm_close_exit)
                pixi.state.popups.file_confirm_close_exit = false;
        }
        imgui.sameLine();
        if (imgui.buttonEx(if (pixi.state.popups.file_confirm_close_state == .one) "Close" else "Close All", .{ .x = third_width, .y = 0.0 })) {
            switch (pixi.state.popups.file_confirm_close_state) {
                .one => {
                    pixi.editor.forceCloseFile(pixi.state.popups.file_confirm_close_index) catch unreachable;
                },
                .all => {
                    var len = pixi.state.open_files.items.len;
                    var i: usize = 0;
                    while (i < len) : (i += 1) {
                        pixi.editor.forceCloseFile(0) catch unreachable;
                    }
                },
                else => unreachable,
            }
            pixi.state.popups.file_confirm_close = false;
        }
        imgui.sameLine();
        if (imgui.buttonEx(if (pixi.state.popups.file_confirm_close_state == .one) "Save & Close" else "Save & Close All", .{ .x = third_width, .y = 0.0 })) {
            switch (pixi.state.popups.file_confirm_close_state) {
                .one => {
                    if (pixi.editor.getFile(pixi.state.popups.file_confirm_close_index)) |file| {
                        _ = file.save() catch unreachable;
                    }
                    pixi.editor.closeFile(pixi.state.popups.file_confirm_close_index) catch unreachable;
                },
                .all => {
                    pixi.editor.saveAllFiles() catch unreachable;
                    pixi.editor.forceCloseAllFiles() catch unreachable;
                },
                else => unreachable,
            }

            pixi.state.popups.file_confirm_close = false;
        }

        if (pixi.state.popups.file_confirm_close_exit and !pixi.state.popups.file_confirm_close) {
            pixi.state.popups.file_confirm_close_exit = false;
            pixi.state.should_close = true;
        }

        imgui.popItemWidth();
    }
    if (!pixi.state.popups.file_confirm_close)
        pixi.state.popups.file_confirm_close_exit = false;
}
