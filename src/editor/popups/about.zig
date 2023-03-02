const std = @import("std");
const pixi = @import("root");
const zgui = @import("zgui");

pub fn draw() void {
    if (pixi.state.popups.about) {
        zgui.openPopup("About", .{});
    } else return;

    const popup_width = 450 * pixi.state.window.scale[0];
    const popup_height = 450 * pixi.state.window.scale[1];

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

    if (zgui.beginPopupModal("About", .{
        .popen = &pixi.state.popups.about,
        .flags = .{
            .no_resize = true,
            .no_collapse = true,
        },
    })) {
        defer zgui.endPopup();
        zgui.spacing();

        const w = @intToFloat(f32, pixi.state.fox_logo.width / 4) * pixi.state.window.scale[0];
        const h = @intToFloat(f32, pixi.state.fox_logo.height / 4) * pixi.state.window.scale[1];
        zgui.setCursorPosX((zgui.getWindowWidth() - w) / 2.0);
        zgui.setCursorPosY((zgui.getWindowHeight() - h) / 2.5);
        zgui.image(pixi.state.gctx.lookupResource(pixi.state.fox_logo.view_handle).?, .{
            .w = w,
            .h = h,
        });

        centerText("Pixi Editor", .{});
        centerText("https://github.com/foxnne/pixi", .{});
        centerText("Version: {s}", .{pixi.version});
    }
}

fn centerText(comptime text: []const u8, args: anytype) void {
    const center = zgui.getWindowWidth() / 2.0;
    const text_width = zgui.calcTextSize(zgui.format(text, args), .{})[0];
    zgui.setCursorPosX(center - text_width / 2.0);
    zgui.text(text, args);
}
