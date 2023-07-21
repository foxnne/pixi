const std = @import("std");
const pixi = @import("../../../pixi.zig");
const mach = @import("core");
const zgui = @import("zgui").MachImgui(mach);
const nfd = @import("nfd");

const History = pixi.storage.Internal.Pixi.History;

pub fn draw(file: *pixi.storage.Internal.Pixi, mouse_ratio: f32) void {
    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.window_padding, .v = .{ 10.0 * pixi.content_scale[0], 10.0 * pixi.content_scale[1] } });
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

            var animation = &file.animations.items[file.selected_animation_index];

            { // Animation Selection
                zgui.setNextItemWidth(zgui.calcTextSize(animation.name, .{})[0] + 40 * pixi.content_scale[0]);
                if (zgui.beginCombo("Animation  ", .{ .preview_value = animation.name, .flags = .{ .height_largest = true } })) {
                    defer zgui.endCombo();
                    for (file.animations.items, 0..) |a, i| {
                        if (zgui.selectable(a.name, .{ .selected = i == file.selected_animation_index })) {
                            file.selected_animation_index = i;
                            file.flipbook_scroll_request = .{ .from = file.flipbook_scroll, .to = file.flipbookScrollFromSpriteIndex(a.start), .state = file.selected_animation_state };
                        }
                    }
                }
            }

            { // Frame Selection
                const current_frame = if (file.selected_sprite_index > animation.start) file.selected_sprite_index - animation.start else 0;
                const frame = zgui.formatZ("{d}/{d}", .{ current_frame + 1, animation.length });

                zgui.setNextItemWidth(zgui.calcTextSize(frame, .{})[0] + 40 * pixi.content_scale[0]);
                if (zgui.beginCombo("Frame  ", .{ .preview_value = frame })) {
                    defer zgui.endCombo();
                    for (0..animation.length) |i| {
                        if (zgui.selectable(zgui.formatZ("{d}/{d}", .{ i + 1, animation.length }), .{ .selected = animation.start + i == file.selected_animation_index })) {
                            file.flipbook_scroll_request = .{ .from = file.flipbook_scroll, .to = file.flipbookScrollFromSpriteIndex(animation.start + i), .state = file.selected_animation_state };
                        }
                    }
                }
            }

            { // FPS Selection
                zgui.setNextItemWidth(100 * pixi.content_scale[0]);
                var fps = @as(i32, @intCast(animation.fps));
                var changed: bool = false;
                if (zgui.sliderInt("FPS", .{
                    .v = &fps,
                    .min = 1,
                    .max = 60,
                })) {
                    changed = true;
                }

                if (zgui.isItemActivated()) {
                    // Apply history of animation state
                    var change: History.Change = .{ .animation = .{
                        .index = file.selected_animation_index,
                        .name = [_:0]u8{0} ** 128,
                        .fps = animation.fps,
                        .start = animation.start,
                        .length = animation.length,
                    } };
                    @memcpy(change.animation.name[0..animation.name.len], animation.name);
                    file.history.append(change) catch unreachable;
                }

                if (changed) {
                    animation.fps = @as(usize, @intCast(fps));
                }
            }
        }

        _ = zgui.invisibleButton("FlipbookGrip", .{
            .w = -1.0,
            .h = 12 * pixi.content_scale[1],
        });

        if (zgui.isItemHovered(.{})) {
            pixi.application.core.setCursorShape(.resize_ns);
            zgui.setMouseCursor(.resize_ns);
        }

        if (zgui.isItemActive()) {
            zgui.setMouseCursor(.resize_ns);
            pixi.application.core.setCursorShape(.resize_ns);
            pixi.state.settings.flipbook_height = std.math.clamp(1.0 - mouse_ratio, 0.25, 0.85);
        }
    }
}
