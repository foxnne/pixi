const std = @import("std");
const pixi = @import("../../pixi.zig");
const core = @import("mach-core");
const imgui = @import("zig-imgui");

pub fn draw() void {
    if (pixi.state.popups.about) {
        imgui.openPopup("About", imgui.PopupFlags_None);
    } else return;

    const popup_width = 450 * pixi.content_scale[0];
    const popup_height = 450 * pixi.content_scale[1];

    const window_size = pixi.window_size;
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
        "About",
        &pixi.state.popups.about,
        modal_flags,
    )) {
        defer imgui.endPopup();
        imgui.spacing();

        const fox_sprite = pixi.state.assets.atlas.sprites[pixi.assets.pixi_atlas.fox_0_default];

        const src: [4]f32 = .{
            @floatFromInt(fox_sprite.source[0]),
            @floatFromInt(fox_sprite.source[1]),
            @floatFromInt(fox_sprite.source[2]),
            @floatFromInt(fox_sprite.source[3]),
        };

        const w = src[2] * 4.0 * pixi.content_scale[0];
        const h = src[3] * 4.0 * pixi.content_scale[1];
        const center: [2]f32 = .{ imgui.getWindowWidth() / 2.0, imgui.getWindowHeight() / 4.0 };

        imgui.setCursorPosX(center[0] - w / 2.0);
        imgui.setCursorPosY(center[1] - h / 2.0);
        imgui.dummy(.{ .x = w, .y = h });

        const dummy_pos = imgui.getItemRectMin();

        const draw_list_opt = imgui.getWindowDrawList();

        if (draw_list_opt) |draw_list| {
            draw_list.addCircleFilled(
                .{ .x = dummy_pos.x + w / 2, .y = dummy_pos.y + w / 2 },
                w / 1.5,
                pixi.state.theme.foreground.toU32(),
                32,
            );
        }

        const inv_w = 1.0 / @as(f32, @floatFromInt(pixi.state.assets.atlas_png.image.width));
        const inv_h = 1.0 / @as(f32, @floatFromInt(pixi.state.assets.atlas_png.image.height));

        imgui.setCursorPosX(center[0] - w / 2.0);
        imgui.setCursorPosY(center[1] - h / 6.0);
        imgui.imageEx(
            pixi.state.assets.atlas_png.view_handle,
            .{ .x = w, .y = h },
            .{ .x = src[0] * inv_w, .y = src[1] * inv_h },
            .{ .x = (src[0] + src[2]) * inv_w, .y = (src[1] + src[3]) * inv_h },
            .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 },
            .{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 0.0 },
        );

        imgui.dummy(.{ .x = w, .y = h });

        centerText("Pixi Editor");
        centerText("https://github.com/foxnne/pixi");

        const version = std.fmt.allocPrintZ(pixi.state.allocator, "Version {d}.{d}.{d}", .{ pixi.version.major, pixi.version.minor, pixi.version.patch }) catch unreachable;
        defer pixi.state.allocator.free(version);

        centerText(version);

        imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_background.toImguiVec4());
        defer imgui.popStyleColor();

        imgui.spacing();
        imgui.spacing();
        imgui.spacing();
        imgui.spacing();
        imgui.spacing();
        imgui.spacing();
        centerText("Credits");
        centerText("__________________");
        imgui.spacing();
        imgui.spacing();

        centerText("mach-core");
        centerText("https://github.com/hexops/mach-core");

        imgui.spacing();
        imgui.spacing();

        centerText("zig-gamedev");
        centerText("https://github.com/michal-z/zig-gamedev");

        imgui.spacing();
        imgui.spacing();

        centerText("zip");
        centerText("https://github.com/kuba--/zip");

        imgui.spacing();
        imgui.spacing();

        centerText("nfd-zig");
        centerText("https://github.com/fabioarnold/nfd-zig");
    }
}

fn centerText(text: [:0]const u8) void {
    const center = imgui.getWindowWidth() / 2.0;
    const text_width = imgui.calcTextSize(text).x;
    imgui.setCursorPosX(center - text_width / 2.0);
    imgui.text(text);
}
