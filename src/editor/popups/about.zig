const std = @import("std");
const pixi = @import("../../pixi.zig");
const core = @import("mach-core");
const zgui = @import("zgui").MachImgui(core);

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
        _ = window_position;
        const center: [2]f32 = .{ zgui.getWindowWidth() / 2.0, zgui.getWindowHeight() / 2.0 };
        zgui.setCursorPosX(center[0] - w / 2.0);
        zgui.setCursorPosY(center[1] - h / 2.0);
        zgui.dummy(.{ .w = w, .h = h });

        const dummy_pos = zgui.getItemRectMin();

        const draw_list = zgui.getWindowDrawList();
        draw_list.addCircleFilled(.{
            .p = .{ dummy_pos[0] + w / 2, dummy_pos[1] + w / 2 },
            .r = w / 2.5,
            .col = pixi.state.theme.foreground.toU32(),
        });

        zgui.setCursorPosX(center[0] - w / 2.0);
        zgui.setCursorPosY(center[1] - h / 2.0);
        zgui.image(pixi.state.fox_logo.view_handle, .{
            .w = w,
            .h = h,
        });

        centerText("Pixi Editor", .{});
        centerText("https://github.com/foxnne/pixi", .{});
        centerText("Version: {any}", .{pixi.version});

        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.theme.text_background.toSlice() });
        defer zgui.popStyleColor(.{ .count = 1 });

        zgui.spacing();
        zgui.spacing();
        zgui.spacing();
        zgui.spacing();
        zgui.spacing();
        zgui.spacing();
        centerText("Credits", .{});
        centerText("__________________", .{});
        zgui.spacing();
        zgui.spacing();

        centerText("mach-core", .{});
        centerText("https://github.com/hexops/mach-core", .{});

        zgui.spacing();
        zgui.spacing();

        centerText("zig-gamedev", .{});
        centerText("https://github.com/michal-z/zig-gamedev", .{});

        zgui.spacing();
        zgui.spacing();

        centerText("zip", .{});
        centerText("https://github.com/kuba--/zip", .{});

        zgui.spacing();
        zgui.spacing();

        centerText("nfd-zig", .{});
        centerText("https://github.com/fabioarnold/nfd-zig", .{});
    }
}

fn centerText(comptime text: []const u8, args: anytype) void {
    const center = zgui.getWindowWidth() / 2.0;
    const text_width = zgui.calcTextSize(zgui.format(text, args), .{})[0];
    zgui.setCursorPosX(center - text_width / 2.0);
    zgui.text(text, args);
}
