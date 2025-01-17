const std = @import("std");

const Pixi = @import("../../Pixi.zig");
const Editor = Pixi.Editor;

const imgui = @import("zig-imgui");

pub fn draw(editor: *Editor) !void {
    if (editor.getFile(editor.open_file_index)) |file| {
        const dialog_name = switch (editor.popups.layer_setup_state) {
            .none => "New Layer...",
            .rename => "Rename Layer...",
            .duplicate => "Duplicate Layer...",
        };

        if (editor.popups.layer_setup) {
            imgui.openPopup(dialog_name, imgui.PopupFlags_None);
        } else return;

        const popup_width: f32 = 350;
        const popup_height: f32 = 115;

        const window_size = Pixi.app.window_size;
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
            dialog_name,
            &editor.popups.layer_setup,
            modal_flags,
        )) {
            defer imgui.endPopup();
            imgui.spacing();

            const style = imgui.getStyle();
            const spacing = style.item_spacing.x;
            const full_width = popup_width - (style.frame_padding.x * 2.0) - imgui.calcTextSize("Name").x;
            const half_width = (popup_width - (style.frame_padding.x * 2.0) - spacing) / 2.0;

            imgui.pushItemWidth(full_width);

            var input_text_flags: imgui.InputTextFlags = 0;
            input_text_flags |= imgui.InputTextFlags_AutoSelectAll;
            input_text_flags |= imgui.InputTextFlags_EnterReturnsTrue;

            const enter = imgui.inputText(
                "Name",
                editor.popups.layer_setup_name[0.. :0],
                editor.popups.layer_setup_name[0.. :0].len,
                input_text_flags,
            );

            imgui.setCursorPosY(popup_height - imgui.getTextLineHeightWithSpacing() * 2.0);

            if (imgui.buttonEx("Cancel", .{ .x = half_width, .y = 0.0 })) {
                editor.popups.layer_setup = false;
            }
            imgui.sameLine();
            if (imgui.buttonEx("Ok", .{ .x = half_width, .y = 0.0 }) or enter) {
                switch (Pixi.editor.popups.layer_setup_state) {
                    .none => {
                        const new_name = std.mem.trimRight(u8, editor.popups.layer_setup_name[0..], "\u{0}");
                        if (std.mem.indexOf(u8, new_name, "\u{0}")) |index| {
                            try file.createLayer(editor.popups.layer_setup_name[0..index :0]);
                        } else {
                            try file.createLayer(editor.popups.layer_setup_name[0..new_name.len :0]);
                        }
                    },
                    .rename => {
                        const new_name = std.mem.trimRight(u8, Pixi.editor.popups.layer_setup_name[0..], "\u{0}");
                        if (std.mem.indexOf(u8, new_name, "\u{0}")) |index| {
                            try file.renameLayer(editor.popups.layer_setup_name[0..index :0], editor.popups.layer_setup_index);
                        } else {
                            try file.renameLayer(editor.popups.layer_setup_name[0..new_name.len :0], editor.popups.layer_setup_index);
                        }
                    },
                    .duplicate => {
                        const new_name = std.mem.trimRight(u8, Pixi.editor.popups.layer_setup_name[0.. :0], "\u{0}");
                        if (std.mem.indexOf(u8, new_name, "\u{0}")) |index| {
                            try file.duplicateLayer(editor.popups.layer_setup_name[0..index :0], editor.popups.layer_setup_index);
                        } else {
                            try file.duplicateLayer(editor.popups.layer_setup_name[0..new_name.len :0], editor.popups.layer_setup_index);
                        }
                    },
                }
                editor.popups.layer_setup_state = .none;
                editor.popups.layer_setup = false;
            }

            imgui.popItemWidth();
        }
    }
}
