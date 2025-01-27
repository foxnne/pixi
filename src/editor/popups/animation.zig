const std = @import("std");

const pixi = @import("../../pixi.zig");
const Editor = pixi.Editor;

const imgui = @import("zig-imgui");

const History = pixi.Internal.File.History;

pub fn draw(editor: *Editor) !void {
    if (editor.getFile(editor.open_file_index)) |file| {
        const dialog_name = switch (editor.popups.animation_state) {
            .none => "None...",
            .create => "Create animation...",
            .edit => "Edit animation...",
        };

        if (editor.popups.animation) {
            imgui.openPopup(dialog_name, imgui.PopupFlags_None);
        } else return;

        const popup_width: f32 = 350;
        const popup_height: f32 = 115;

        const window_size = pixi.app.window_size;
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
            &editor.popups.animation,
            modal_flags,
        )) {
            defer imgui.endPopup();
            imgui.spacing();

            const style = imgui.getStyle();
            const spacing = style.item_spacing.x;
            const full_width = popup_width - (style.frame_padding.x * 2.0) - imgui.calcTextSize("Name").x;
            const half_width = (popup_width - (style.frame_padding.x * 2.0) - spacing) / 2.0;

            var input_text_flags: imgui.InputTextFlags = 0;
            input_text_flags |= imgui.InputTextFlags_AutoSelectAll;
            input_text_flags |= imgui.InputTextFlags_EnterReturnsTrue;

            imgui.pushItemWidth(full_width);
            const enter = imgui.inputText(
                "Name",
                editor.popups.animation_name[0.. :0],
                editor.popups.animation_name[0.. :0].len,
                input_text_flags,
            );

            imgui.spacing();
            if (editor.popups.animation_state == .create) {
                var fps = @as(i32, @intCast(editor.popups.animation_fps));
                if (imgui.sliderInt("FPS", &fps, 1, 60)) {
                    editor.popups.animation_fps = @as(usize, @intCast(fps));
                }
                imgui.spacing();
            }

            imgui.separator();
            if (imgui.buttonEx("Cancel", .{ .x = half_width, .y = 0.0 })) {
                editor.popups.animation = false;
            }
            imgui.sameLine();
            if (imgui.buttonEx("Ok", .{ .x = half_width, .y = 0.0 }) or enter) {
                switch (editor.popups.animation_state) {
                    .create => {
                        const name = std.mem.trimRight(u8, &editor.popups.animation_name, "\u{0}");

                        if (std.mem.indexOf(u8, name, "\u{0}")) |index| {
                            try file.createAnimation(name[0..index], editor.popups.animation_fps, editor.popups.animation_start, editor.popups.animation_length);
                        } else {
                            try file.createAnimation(name, editor.popups.animation_fps, editor.popups.animation_start, editor.popups.animation_length);
                        }
                    },
                    .edit => {
                        const name = std.mem.trimRight(u8, &editor.popups.animation_name, "\u{0}");
                        if (std.mem.indexOf(u8, name, "\u{0}")) |index| {
                            try file.renameAnimation(name[0..index], editor.popups.animation_index);
                        } else {
                            try file.renameAnimation(name, editor.popups.animation_index);
                        }
                    },
                    else => unreachable,
                }
                editor.popups.animation_state = .none;
                editor.popups.animation = false;
            }

            imgui.popItemWidth();
        }
    }
}
