const std = @import("std");
const Pixi = @import("../../Pixi.zig");
const core = @import("mach").core;
const imgui = @import("zig-imgui");
const History = Pixi.storage.Internal.PixiFile.History;

pub fn draw() void {
    if (Pixi.Editor.getFile(Pixi.state.open_file_index)) |file| {
        const dialog_name = switch (Pixi.state.popups.animation_state) {
            .none => "None...",
            .create => "Create animation...",
            .edit => "Edit animation...",
        };

        if (Pixi.state.popups.animation) {
            imgui.openPopup(dialog_name, imgui.PopupFlags_None);
        } else return;

        const popup_width = 350 * Pixi.content_scale[0];
        const popup_height = 115 * Pixi.content_scale[1];

        const window_size = Pixi.window_size;
        const window_center: [2]f32 = .{ window_size[0] / 2.0, window_size[1] / 2.0 };

        imgui.setNextWindowPos(.{
            .x = window_center[0] - popup_width / 2.0,
            .y = window_center[1] - popup_height / 2.0,
        }, imgui.Cond_None);
        imgui.setNextWindowSize(.{
            .x = popup_width,
            .y = 0.0,
        }, imgui.Cond_None);

        var modal_flags: imgui.WindowFlags = 0;
        modal_flags |= imgui.WindowFlags_NoResize;
        modal_flags |= imgui.WindowFlags_NoCollapse;

        if (imgui.beginPopupModal(
            dialog_name,
            &Pixi.state.popups.animation,
            modal_flags,
        )) {
            defer imgui.endPopup();
            imgui.spacing();

            const style = imgui.getStyle();
            const spacing = style.item_spacing.x;
            const full_width = popup_width - (style.frame_padding.x * 2.0 * Pixi.content_scale[0]) - imgui.calcTextSize("Name").x;
            const half_width = (popup_width - (style.frame_padding.x * 2.0 * Pixi.content_scale[0]) - spacing) / 2.0;

            var input_text_flags: imgui.InputTextFlags = 0;
            input_text_flags |= imgui.InputTextFlags_AutoSelectAll;
            input_text_flags |= imgui.InputTextFlags_EnterReturnsTrue;

            imgui.pushItemWidth(full_width);
            const enter = imgui.inputText(
                "Name",
                Pixi.state.popups.animation_name[0.. :0],
                Pixi.state.popups.animation_name[0.. :0].len,
                input_text_flags,
            );

            imgui.spacing();
            if (Pixi.state.popups.animation_state == .create) {
                var fps = @as(i32, @intCast(Pixi.state.popups.animation_fps));
                if (imgui.sliderInt("FPS", &fps, 1, 60)) {
                    Pixi.state.popups.animation_fps = @as(usize, @intCast(fps));
                }
                imgui.spacing();
            }

            imgui.separator();
            if (imgui.buttonEx("Cancel", .{ .x = half_width, .y = 0.0 })) {
                Pixi.state.popups.animation = false;
            }
            imgui.sameLine();
            if (imgui.buttonEx("Ok", .{ .x = half_width, .y = 0.0 }) or enter) {
                switch (Pixi.state.popups.animation_state) {
                    .create => {
                        const name = std.mem.trimRight(u8, &Pixi.state.popups.animation_name, "\u{0}");

                        if (std.mem.indexOf(u8, name, "\u{0}")) |index| {
                            file.createAnimation(name[0..index], Pixi.state.popups.animation_fps, Pixi.state.popups.animation_start, Pixi.state.popups.animation_length) catch unreachable;
                        } else {
                            file.createAnimation(name, Pixi.state.popups.animation_fps, Pixi.state.popups.animation_start, Pixi.state.popups.animation_length) catch unreachable;
                        }
                    },
                    .edit => {
                        const name = std.mem.trimRight(u8, &Pixi.state.popups.animation_name, "\u{0}");
                        if (std.mem.indexOf(u8, name, "\u{0}")) |index| {
                            file.renameAnimation(name[0..index], Pixi.state.popups.animation_index) catch unreachable;
                        } else {
                            file.renameAnimation(name, Pixi.state.popups.animation_index) catch unreachable;
                        }
                    },
                    else => unreachable,
                }
                Pixi.state.popups.animation_state = .none;
                Pixi.state.popups.animation = false;
            }

            imgui.popItemWidth();
        }
    }
}
