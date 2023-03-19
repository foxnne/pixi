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

        if (zgui.button(if (file.selected_animation_state == .play) " " ++ pixi.fa.pause ++ " " else " " ++ pixi.fa.play ++ " ", .{})) {
            file.selected_animation_state = switch (file.selected_animation_state) {
                .play => .pause,
                .pause => .play,
            };
        }
        if (file.animations.items.len > 0) {
            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.frame_bg_hovered, .c = pixi.state.style.background.toSlice() });
            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.frame_bg, .c = pixi.state.style.background.toSlice() });
            defer zgui.popStyleColor(.{ .count = 2 });
            const animation_name = file.animations.items[file.selected_animation_index].name;
            zgui.setNextItemWidth(zgui.calcTextSize(animation_name, .{})[0] + 40 * pixi.state.window.scale[0]);

            if (zgui.beginCombo("Animation", .{ .preview_value = animation_name, .flags = .{ .height_small = true } })) {
                defer zgui.endCombo();
                for (file.animations.items, 0..) |animation, index| {
                    if (zgui.selectable(animation.name, .{ .selected = index == file.selected_animation_index })) {
                        file.selected_animation_index = index;
                        file.flipbook_scroll_request = .{ .from = file.flipbook_scroll, .to = file.flipbookScrollFromSpriteIndex(animation.start), .state = file.selected_animation_state };
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
