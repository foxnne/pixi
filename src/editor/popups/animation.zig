const std = @import("std");
const pixi = @import("root");
const zgui = @import("zgui");

pub fn draw() void {
    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
        const dialog_name = switch (pixi.state.popups.animation_state) {
            .none => "None...",
            .create => "Create animation...",
            .edit => "Edit animation...",
        };

        if (pixi.state.popups.animation) {
            zgui.openPopup(dialog_name, .{});
        } else return;

        const popup_width = 350 * pixi.state.window.scale[0];
        const popup_height = 115 * pixi.state.window.scale[1];

        const window_size = pixi.state.window.size * pixi.state.window.scale;
        const window_center: [2]f32 = .{ window_size[0] / 2.0, window_size[1] / 2.0 };

        zgui.setNextWindowPos(.{
            .x = window_center[0] - popup_width / 2.0,
            .y = window_center[1] - popup_height / 2.0,
        });
        zgui.setNextWindowSize(.{
            .w = popup_width,
            .h = 0.0,
        });

        if (zgui.beginPopupModal(dialog_name, .{
            .popen = &pixi.state.popups.animation,
            .flags = .{
                .no_resize = true,
                .no_collapse = true,
            },
        })) {
            defer zgui.endPopup();
            zgui.spacing();

            const style = zgui.getStyle();
            const spacing = style.item_spacing[0];
            const full_width = popup_width - (style.frame_padding[0] * 2.0 * pixi.state.window.scale[0]) - zgui.calcTextSize("Name", .{})[0];
            const half_width = (popup_width - (style.frame_padding[0] * 2.0 * pixi.state.window.scale[0]) - spacing) / 2.0;

            zgui.pushItemWidth(full_width);
            var enter = zgui.inputText("Name", .{
                .buf = pixi.state.popups.animation_name[0..],
                .flags = .{
                    .chars_no_blank = false,
                    .auto_select_all = true,
                    .enter_returns_true = true,
                },
            });

            zgui.spacing();

            var fps = @intCast(i32, pixi.state.popups.animation_fps);
            if (zgui.sliderInt("FPS", .{
                .v = &fps,
                .min = 1,
                .max = 60,
            })) {
                pixi.state.popups.animation_fps = @intCast(usize, fps);
            }
            zgui.spacing();
            zgui.separator();

            if (zgui.button("Cancel", .{ .w = half_width })) {
                pixi.state.popups.animation = false;
            }
            zgui.sameLine(.{});
            if (zgui.button("Ok", .{ .w = half_width }) or enter) {
                switch (pixi.state.popups.animation_state) {
                    .create => {
                        const name = std.mem.trimRight(u8, &pixi.state.popups.animation_name, "\u{0}");
                        file.animations.append(.{
                            .name = pixi.state.allocator.dupeZ(u8, name) catch unreachable,
                            .fps = pixi.state.popups.animation_fps,
                            .start = pixi.state.popups.animation_start,
                            .length = pixi.state.popups.animation_length,
                        }) catch unreachable;
                        file.selected_animation_index = file.animations.items.len - 1;
                    },
                    .edit => {
                        const name = std.mem.trimRight(u8, &pixi.state.popups.animation_name, "\u{0}");
                        file.selected_animation_index = pixi.state.popups.animation_index;
                        var animation = &file.animations.items[file.selected_animation_index];
                        pixi.state.allocator.free(animation.name);
                        animation.name = pixi.state.allocator.dupeZ(u8, name) catch unreachable;
                        animation.fps = pixi.state.popups.animation_fps;
                        animation.start = pixi.state.popups.animation_start;
                        animation.length = pixi.state.popups.animation_length;
                    },
                    else => unreachable,
                }
                pixi.state.popups.animation_state = .none;
                pixi.state.popups.animation = false;
            }

            zgui.popItemWidth();
        }
    }
}
