const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("root");
const filebrowser = @import("filebrowser");
const nfd = @import("nfd");

pub fn draw(file: *pixi.storage.Internal.Pixi, mouse_ratio: f32) void {
    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.window_padding, .v = .{ 10.0 * pixi.state.window.scale[0], 10.0 * pixi.state.window.scale[1] } });
    defer zgui.popStyleVar(.{ .count = 1 });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text.toSlice() });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.popup_bg, .c = pixi.state.style.foreground.toSlice() });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button_hovered, .c = pixi.state.style.foreground.toSlice() });
    defer zgui.popStyleColor(.{ .count = 3 });
    if (zgui.beginMenuBar()) {
        defer zgui.endMenuBar();
        if (file.animations.items.len > 0) {
            if (zgui.button(if (file.selected_animation_state == .play) " " ++ pixi.fa.pause ++ " " else " " ++ pixi.fa.play ++ " ", .{})) {
                file.selected_animation_state = switch (file.selected_animation_state) {
                    .play => .pause,
                    .pause => .play,
                };
            }

            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.frame_bg_hovered, .c = pixi.state.style.background.toSlice() });
            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.frame_bg, .c = pixi.state.style.background.toSlice() });
            defer zgui.popStyleColor(.{ .count = 2 });
            const animation = file.animations.items[file.selected_animation_index];
            zgui.setNextItemWidth(zgui.calcTextSize(animation.name, .{})[0] + 40 * pixi.state.window.scale[0]);

            if (zgui.beginCombo("Animation  ", .{ .preview_value = animation.name, .flags = .{ .height_largest = true } })) {
                defer zgui.endCombo();
                for (file.animations.items, 0..) |a, i| {
                    if (zgui.selectable(a.name, .{ .selected = i == file.selected_animation_index })) {
                        file.selected_animation_index = i;
                        file.flipbook_scroll_request = .{ .from = file.flipbook_scroll, .to = file.flipbookScrollFromSpriteIndex(a.start), .state = file.selected_animation_state };
                    }
                }
            }
            const current_frame = if (file.selected_sprite_index > animation.start) file.selected_sprite_index - animation.start else 0;
            const frame = zgui.formatZ("{d}/{d}", .{ current_frame + 1, animation.length });
            zgui.setNextItemWidth(zgui.calcTextSize(frame, .{})[0] + 40 * pixi.state.window.scale[0]);
            if (zgui.beginCombo("Frame  ", .{ .preview_value = frame })) {
                defer zgui.endCombo();
                for (0..animation.length) |i| {
                    if (zgui.selectable(zgui.formatZ("{d}/{d}", .{ i + 1, animation.length }), .{ .selected = animation.start + i == file.selected_animation_index })) {
                        file.flipbook_scroll_request = .{ .from = file.flipbook_scroll, .to = file.flipbookScrollFromSpriteIndex(animation.start + i), .state = file.selected_animation_state };
                    }
                }
            }
        }

        _ = zgui.invisibleButton("FlipbookGrip", .{
            .w = -1.0,
            .h = -1.0,
        });

        if (zgui.isItemActive()) {
            pixi.state.settings.flipbook_height = std.math.clamp(1.0 - mouse_ratio, 0.25, 0.85);
        }
    }
}
