const std = @import("std");
const pixi = @import("pixi");
const zgui = @import("zgui");

pub fn draw() void {
    const popup_width = 300;
    const popup_height = 100;

    const window_size = pixi.state.window.size;
    const window_center: [2]f32 = .{ window_size[0] / 2.0, window_size[1] / 2.0 };

    zgui.setNextWindowPos(.{
        .x = window_center[0] - popup_width / 2.0,
        .y = window_center[1] - popup_height / 2.0,
    });
    zgui.setNextWindowSize(.{
        .w = popup_width,
        .h = popup_height,
    });

    if (pixi.state.popups.rename)
        zgui.openPopup("Rename file...", .{});

    if (zgui.beginPopupModal("Rename file...", .{
        .popen = &pixi.state.popups.rename,
        .flags = .{
            .no_resize = true,
            .no_collapse = true,
        },
    })) {
        defer zgui.endPopup();

        if (zgui.button("Cancel", .{})) {
            pixi.state.popups.rename = false;
        }
    }
}
