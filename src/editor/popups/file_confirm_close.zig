const std = @import("std");
const pixi = @import("root");
const zgui = @import("zgui");

pub fn draw() void {
    if (pixi.state.popups.file_confirm_close) {
        zgui.openPopup("Confirm close...", .{});
    } else return;

    const popup_width = 350 * pixi.state.window.scale[0];
    const popup_height = if (pixi.state.popups.file_confirm_close_state == .one) 120 * pixi.state.window.scale[1] else 250 * pixi.state.window.scale[1];

    const window_size = pixi.state.window.size * pixi.state.window.scale;
    const window_center: [2]f32 = .{ window_size[0] / 2.0, window_size[1] / 2.0 };

    zgui.setNextWindowPos(.{
        .x = window_center[0] - popup_width / 2.0,
        .y = window_center[1] - popup_height / 2.0,
    });
    zgui.setNextWindowSize(.{
        .w = popup_width,
        .h = popup_height,
    });

    if (zgui.beginPopupModal("Confirm close...", .{
        .popen = &pixi.state.popups.file_confirm_close,
        .flags = .{
            .no_resize = true,
            .no_collapse = true,
        },
    })) {
        defer zgui.endPopup();
        zgui.spacing();

        const style = zgui.getStyle();
        const spacing = 5.0 * pixi.state.window.scale[0];
        const full_width = popup_width - (style.frame_padding[0] * 2.5 * pixi.state.window.scale[0]) - zgui.calcTextSize("Name", .{})[0];
        const third_width = (popup_width - (style.frame_padding[0] * 2.5 * pixi.state.window.scale[0]) - spacing * 2.0) / 3.0;

        switch (pixi.state.popups.file_confirm_close_state) {
            .one => {
                if (pixi.editor.getFile(pixi.state.popups.file_confirm_close_index)) |file| {
                    const base_name = std.fs.path.basename(file.path);
                    zgui.textWrapped("The file {s} has unsaved changes, are you sure you want to close?", .{base_name});
                }
            },
            .all => {
                zgui.textWrapped("The following files have unsaved changes, are you sure you want to close?", .{});
                zgui.spacing();
                if (zgui.beginChild("OpenFileArea", .{ .h = 120 * pixi.state.window.scale[1] })) {
                    defer zgui.endChild();
                    for (pixi.state.open_files.items) |file| {
                        const base_name = std.fs.path.basename(file.path);
                        if (file.dirty) zgui.bulletText("{s}", .{base_name});
                    }
                }
            },
            else => unreachable,
        }

        zgui.separator();



        zgui.setCursorPosY(popup_height - zgui.getTextLineHeightWithSpacing() * 2.0);

        zgui.pushItemWidth(full_width);
        if (zgui.button("Cancel", .{ .w = third_width })) {
            pixi.state.popups.file_confirm_close = false;
            if (pixi.state.popups.file_confirm_close_exit)
                pixi.state.popups.file_confirm_close_exit = false;
        }
        zgui.sameLine(.{});
        if (zgui.button(if (pixi.state.popups.file_confirm_close_state == .one) "Close" else "Close All", .{ .w = third_width })) {
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
        zgui.sameLine(.{});
        if (zgui.button(if (pixi.state.popups.file_confirm_close_state == .one) "Save & Close" else "Save & Close All", .{ .w = third_width })) {
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

        zgui.popItemWidth();
    }
    if (!pixi.state.popups.file_confirm_close)
        pixi.state.popups.file_confirm_close_exit = false;
}
