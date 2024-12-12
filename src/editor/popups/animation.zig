const std = @import("std");
const pixi = @import("../../Pixi.zig");
const core = @import("mach").core;
const imgui = @import("zig-imgui");
const History = pixi.storage.Internal.PixiFile.History;

pub fn draw() void {
    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
        const dialog_name = switch (pixi.state.popups.animation_state) {
            .none => "None...",
            .create => "Create animation...",
            .edit => "Edit animation...",
        };

        if (pixi.state.popups.animation) {
            imgui.openPopup(dialog_name, imgui.PopupFlags_None);
        } else return;

        const popup_width = 350 * pixi.content_scale[0];
        const popup_height = 115 * pixi.content_scale[1];

        const window_size = pixi.window_size;
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
            &pixi.state.popups.animation,
            modal_flags,
        )) {
            defer imgui.endPopup();
            imgui.spacing();

            const style = imgui.getStyle();
            const spacing = style.item_spacing.x;
            const full_width = popup_width - (style.frame_padding.x * 2.0 * pixi.content_scale[0]) - imgui.calcTextSize("Name").x;
            const half_width = (popup_width - (style.frame_padding.x * 2.0 * pixi.content_scale[0]) - spacing) / 2.0;

            var input_text_flags: imgui.InputTextFlags = 0;
            input_text_flags |= imgui.InputTextFlags_AutoSelectAll;
            input_text_flags |= imgui.InputTextFlags_EnterReturnsTrue;

            imgui.pushItemWidth(full_width);
            const enter = imgui.inputText(
                "Name",
                pixi.state.popups.animation_name[0.. :0],
                pixi.state.popups.animation_name[0.. :0].len,
                input_text_flags,
            );

            imgui.spacing();
            if (pixi.state.popups.animation_state == .create) {
                var fps = @as(i32, @intCast(pixi.state.popups.animation_fps));
                if (imgui.sliderInt("FPS", &fps, 1, 60)) {
                    pixi.state.popups.animation_fps = @as(usize, @intCast(fps));
                }
                imgui.spacing();
            }

            imgui.separator();
            if (imgui.buttonEx("Cancel", .{ .x = half_width, .y = 0.0 })) {
                pixi.state.popups.animation = false;
            }
            imgui.sameLine();
            if (imgui.buttonEx("Ok", .{ .x = half_width, .y = 0.0 }) or enter) {
                switch (pixi.state.popups.animation_state) {
                    .create => {
                        const name = std.mem.trimRight(u8, &pixi.state.popups.animation_name, "\u{0}");

                        if (std.mem.indexOf(u8, name, "\u{0}")) |index| {
                            file.createAnimation(name[0..index], pixi.state.popups.animation_fps, pixi.state.popups.animation_start, pixi.state.popups.animation_length) catch unreachable;
                        } else {
                            file.createAnimation(name, pixi.state.popups.animation_fps, pixi.state.popups.animation_start, pixi.state.popups.animation_length) catch unreachable;
                        }
                    },
                    .edit => {
                        const name = std.mem.trimRight(u8, &pixi.state.popups.animation_name, "\u{0}");
                        if (std.mem.indexOf(u8, name, "\u{0}")) |index| {
                            file.renameAnimation(name[0..index], pixi.state.popups.animation_index) catch unreachable;
                        } else {
                            file.renameAnimation(name, pixi.state.popups.animation_index) catch unreachable;
                        }
                    },
                    else => unreachable,
                }
                pixi.state.popups.animation_state = .none;
                pixi.state.popups.animation = false;
            }

            imgui.popItemWidth();
        }
    }
}
