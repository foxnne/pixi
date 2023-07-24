const std = @import("std");
const pixi = @import("../../pixi.zig");
const mach = @import("core");
const zgui = @import("zgui").MachImgui(mach);

pub fn draw() void {
    if (pixi.state.popups.about) {
        zgui.openPopup("About", .{});
    } else return;

    const popup_width = 450 * pixi.content_scale[0];
    const popup_height = 450 * pixi.content_scale[1];

    var window_size = pixi.framebuffer_size;
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

        const w = @as(f32, @floatFromInt(pixi.state.fox_logo.image.width / 4)) * pixi.content_scale[0];
        const h = @as(f32, @floatFromInt(pixi.state.fox_logo.image.height / 4)) * pixi.content_scale[1];
        const window_position = zgui.getWindowPos();
        const center: [2]f32 = .{ zgui.getWindowWidth() / 2.0, zgui.getWindowHeight() / 2.0 };
        zgui.setCursorPosX(center[0] - w / 2.0);
        zgui.setCursorPosY(center[1] - h / 2.0);
        const draw_list = zgui.getWindowDrawList();
        draw_list.addCircleFilled(.{
            .p = .{ window_position[0] + center[0], window_position[1] + center[1] },
            .r = w / 2.5,
            .col = pixi.state.style.foreground.toU32(),
        });
        zgui.image(pixi.state.fox_logo.view_handle, .{
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
