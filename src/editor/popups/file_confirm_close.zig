const std = @import("std");
const pixi = @import("root");
const zgui = @import("zgui");

pub fn draw() void {
    if (pixi.state.popups.file_confirm_close) {
        zgui.openPopup("Confirm close...", .{});
    } else return;

    const popup_width = 350 * pixi.state.window.scale[0];
    const popup_height = 120 * pixi.state.window.scale[1];

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
        const half_width = (popup_width - (style.frame_padding[0] * 2.5 * pixi.state.window.scale[0]) - spacing) / 2.0;

        if (pixi.editor.getFile(pixi.state.popups.file_confirm_close_index)) |file| {
            const base_name = std.fs.path.basename(file.path);
            zgui.textWrapped("The file {s} has unsaved changes, are you sure you want to close?", .{base_name});
        }
        zgui.spacing();
        zgui.spacing();
        zgui.spacing();

        zgui.pushItemWidth(full_width);
        if (zgui.button("Cancel", .{ .w = half_width })) {
            pixi.state.popups.file_confirm_close = false;
        }
        zgui.sameLine(.{});
        if (zgui.button("Close", .{ .w = half_width })) {
            pixi.editor.forceCloseFile(pixi.state.popups.file_confirm_close_index) catch unreachable;
            pixi.state.popups.file_confirm_close = false;
        }
        zgui.popItemWidth();
    }
}
