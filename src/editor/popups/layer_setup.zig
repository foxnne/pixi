const std = @import("std");
const pixi = @import("../../pixi.zig");
const mach = @import("core");
const zgui = @import("zgui").MachImgui(mach);

pub fn draw() void {
    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
        const dialog_name = switch (pixi.state.popups.layer_setup_state) {
            .none => "New Layer...",
            .rename => "Rename Layer...",
            .duplicate => "Duplicate Layer...",
        };

        if (pixi.state.popups.layer_setup) {
            zgui.openPopup(dialog_name, .{});
        } else return;

        const popup_width = 350 * pixi.content_scale[0];
        const popup_height = 115 * pixi.content_scale[1];

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

        if (zgui.beginPopupModal(dialog_name, .{
            .popen = &pixi.state.popups.layer_setup,
            .flags = .{
                .no_resize = true,
                .no_collapse = true,
            },
        })) {
            defer zgui.endPopup();
            zgui.spacing();

            const style = zgui.getStyle();
            const spacing = style.item_spacing[0];
            const full_width = popup_width - (style.frame_padding[0] * 2.0 * pixi.content_scale[0]) - zgui.calcTextSize("Name", .{})[0];
            const half_width = (popup_width - (style.frame_padding[0] * 2.0 * pixi.content_scale[0]) - spacing) / 2.0;

            zgui.pushItemWidth(full_width);
            var enter = zgui.inputText("Name", .{
                .buf = pixi.state.popups.layer_setup_name[0..],
                .flags = .{
                    .auto_select_all = true,
                    .enter_returns_true = true,
                },
            });

            zgui.setCursorPosY(popup_height - zgui.getTextLineHeightWithSpacing() * 2.0);

            if (zgui.button("Cancel", .{ .w = half_width })) {
                pixi.state.popups.layer_setup = false;
            }
            zgui.sameLine(.{});
            if (zgui.button("Ok", .{ .w = half_width }) or enter) {
                switch (pixi.state.popups.layer_setup_state) {
                    .none => {
                        const new_name = std.mem.trimRight(u8, pixi.state.popups.layer_setup_name[0..], "\u{0}");
                        file.createLayer(pixi.state.popups.layer_setup_name[0..new_name.len :0]) catch unreachable;
                    },
                    .rename => {
                        const new_name = std.mem.trimRight(u8, pixi.state.popups.layer_setup_name[0..], "\u{0}");
                        file.renameLayer(pixi.state.popups.layer_setup_name[0..new_name.len :0], pixi.state.popups.layer_setup_index) catch unreachable;
                    },
                    .duplicate => {
                        const new_name = std.mem.trimRight(u8, pixi.state.popups.layer_setup_name[0.. :0], "\u{0}");
                        file.duplicateLayer(pixi.state.popups.layer_setup_name[0..new_name.len :0], pixi.state.popups.layer_setup_index) catch unreachable;
                    },
                }
                pixi.state.popups.layer_setup_state = .none;
                pixi.state.popups.layer_setup = false;
            }

            zgui.popItemWidth();
        }
    }
}
