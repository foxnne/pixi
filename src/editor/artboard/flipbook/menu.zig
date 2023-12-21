const std = @import("std");
const pixi = @import("../../../pixi.zig");
const core = @import("mach-core");
const nfd = @import("nfd");
const imgui = @import("zig-imgui");

const History = pixi.storage.Internal.Pixi.History;

pub fn draw(file: *pixi.storage.Internal.Pixi, mouse_ratio: f32) void {
    imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0 * pixi.content_scale[0], .y = 10.0 * pixi.content_scale[1] });
    defer imgui.popStyleVar();
    imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_PopupBg, pixi.state.theme.foreground.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_ButtonHovered, pixi.state.theme.foreground.toImguiVec4());
    defer imgui.popStyleColorEx(3);
    if (imgui.beginMenuBar()) {
        defer imgui.endMenuBar();
        if (file.animations.items.len > 0) {
            if (imgui.button(if (file.selected_animation_state == .play) " " ++ pixi.fa.pause ++ " " else " " ++ pixi.fa.play ++ " ")) {
                file.selected_animation_state = switch (file.selected_animation_state) {
                    .play => .pause,
                    .pause => .play,
                };
            }

            imgui.pushStyleColorImVec4(imgui.Col_FrameBgHovered, pixi.state.theme.background.toImguiVec4());
            imgui.pushStyleColorImVec4(imgui.Col_FrameBg, pixi.state.theme.background.toImguiVec4());
            defer imgui.popStyleColorEx(2);

            var animation = &file.animations.items[file.selected_animation_index];

            { // Animation Selection
                imgui.setNextItemWidth(imgui.calcTextSize(animation.name).x + 40 * pixi.content_scale[0]);
                if (imgui.beginCombo("Animation  ", animation.name, imgui.ComboFlags_HeightLargest)) {
                    defer imgui.endCombo();
                    for (file.animations.items, 0..) |a, i| {
                        if (imgui.selectableEx(a.name, i == file.selected_animation_index, imgui.SelectableFlags_None, .{ .x = 0.0, .y = 0.0 })) {
                            file.selected_animation_index = i;
                            file.flipbook_scroll_request = .{ .from = file.flipbook_scroll, .to = file.flipbookScrollFromSpriteIndex(a.start), .state = file.selected_animation_state };
                        }
                    }
                }
            }

            { // Frame Selection
                const current_frame = if (file.selected_sprite_index > animation.start) file.selected_sprite_index - animation.start else 0;
                const frame = std.fmt.allocPrintZ(pixi.state.allocator, "{d}/{d}", .{ current_frame + 1, animation.length }) catch unreachable;
                defer pixi.state.allocator.free(frame);

                imgui.setNextItemWidth(imgui.calcTextSize(frame).x + 40 * pixi.content_scale[0]);
                if (imgui.beginCombo("Frame  ", frame, imgui.ComboFlags_None)) {
                    defer imgui.endCombo();
                    for (0..animation.length) |i| {
                        const other_frame = std.fmt.allocPrintZ(pixi.state.allocator, "{d}/{d}", .{ i + 1, animation.length }) catch unreachable;
                        pixi.state.allocator.free(other_frame);

                        if (imgui.selectableEx(other_frame, animation.start + i == file.selected_animation_index, imgui.SelectableFlags_None, .{ .x = 0.0, .y = 0.0 })) {
                            file.flipbook_scroll_request = .{ .from = file.flipbook_scroll, .to = file.flipbookScrollFromSpriteIndex(animation.start + i), .state = file.selected_animation_state };
                        }
                    }
                }
            }

            { // FPS Selection
                imgui.setNextItemWidth(100 * pixi.content_scale[0]);
                var fps = @as(i32, @intCast(animation.fps));
                var changed: bool = false;
                if (imgui.sliderInt(
                    "FPS",
                    &fps,
                    1,
                    60,
                )) {
                    changed = true;
                }

                if (imgui.isItemActivated()) {
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

        _ = imgui.invisibleButton("FlipbookGrip", .{
            .x = -1.0,
            .y = 12.0 * pixi.content_scale[1],
        }, imgui.ButtonFlags_None);

        if (imgui.isItemHovered(imgui.HoveredFlags_None)) {
            pixi.state.cursors.current = .resize_ns;
        }

        if (imgui.isItemActive()) {
            pixi.state.cursors.current = .resize_ns;
            pixi.state.settings.flipbook_height = std.math.clamp(1.0 - mouse_ratio, 0.25, 0.85);
        }
    }
}
