const std = @import("std");
const Pixi = @import("../../../Pixi.zig");
const core = @import("mach").core;
const nfd = @import("nfd");
const imgui = @import("zig-imgui");

const History = Pixi.storage.Internal.PixiFile.History;

pub fn draw(file: *Pixi.storage.Internal.PixiFile, mouse_ratio: f32) !void {
    imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0 * Pixi.state.content_scale[0], .y = 10.0 * Pixi.state.content_scale[1] });
    defer imgui.popStyleVar();
    imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_PopupBg, Pixi.editor.theme.foreground.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_ButtonHovered, Pixi.editor.theme.foreground.toImguiVec4());
    defer imgui.popStyleColorEx(3);
    if (imgui.beginMenuBar()) {
        defer imgui.endMenuBar();

        if (file.flipbook_view == .canvas) {
            if (file.animations.slice().len > 0) {
                if (imgui.button(if (file.selected_animation_state == .play) " " ++ Pixi.fa.pause ++ " " else " " ++ Pixi.fa.play ++ " ")) {
                    file.selected_animation_state = switch (file.selected_animation_state) {
                        .play => .pause,
                        .pause => .play,
                    };
                }

                imgui.pushStyleColorImVec4(imgui.Col_FrameBgHovered, Pixi.editor.theme.background.toImguiVec4());
                imgui.pushStyleColorImVec4(imgui.Col_FrameBg, Pixi.editor.theme.background.toImguiVec4());
                defer imgui.popStyleColorEx(2);

                const animation = &file.animations.slice().get(file.selected_animation_index);

                { // Animation Selection
                    imgui.setNextItemWidth(imgui.calcTextSize(animation.name).x + 40 * Pixi.state.content_scale[0]);
                    if (imgui.beginCombo("Animation  ", animation.name, imgui.ComboFlags_HeightLargest)) {
                        defer imgui.endCombo();
                        var animation_index: usize = 0;
                        while (animation_index < file.animations.slice().len) : (animation_index += 1) {
                            const a = &file.animations.slice().get(animation_index);
                            if (imgui.selectableEx(a.name, animation_index == file.selected_animation_index, imgui.SelectableFlags_None, .{ .x = 0.0, .y = 0.0 })) {
                                file.selected_animation_index = animation_index;
                                file.flipbook_scroll_request = .{ .from = file.flipbook_scroll, .to = file.flipbookScrollFromSpriteIndex(a.start), .state = file.selected_animation_state };
                            }
                        }
                    }
                }

                { // Frame Selection
                    const current_frame = if (file.selected_sprite_index > animation.start) file.selected_sprite_index - animation.start else 0;
                    const frame = try std.fmt.allocPrintZ(Pixi.state.allocator, "{d}/{d}", .{ current_frame + 1, animation.length });
                    defer Pixi.state.allocator.free(frame);

                    imgui.setNextItemWidth(imgui.calcTextSize(frame).x + 40 * Pixi.state.content_scale[0]);
                    if (imgui.beginCombo("Frame  ", frame, imgui.ComboFlags_None)) {
                        defer imgui.endCombo();
                        for (0..animation.length) |i| {
                            const other_frame = try std.fmt.allocPrintZ(Pixi.state.allocator, "{d}/{d}", .{ i + 1, animation.length });
                            defer Pixi.state.allocator.free(other_frame);

                            if (imgui.selectableEx(other_frame, animation.start + i == file.selected_animation_index, imgui.SelectableFlags_None, .{ .x = 0.0, .y = 0.0 })) {
                                file.flipbook_scroll_request = .{ .from = file.flipbook_scroll, .to = file.flipbookScrollFromSpriteIndex(animation.start + i), .state = file.selected_animation_state };
                            }
                        }
                    }
                }

                { // FPS Selection
                    imgui.setNextItemWidth(100 * Pixi.state.content_scale[0]);
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
                        try file.history.append(change);
                    }

                    if (changed) {
                        file.animations.items(.fps)[file.selected_animation_index] = @as(usize, @intCast(fps));
                    }
                }
            }
        } else {
            if (file.keyframe_animations.slice().len > 0) {
                if (imgui.button(if (file.selected_keyframe_animation_state == .play) " " ++ Pixi.fa.pause ++ " " else " " ++ Pixi.fa.play ++ " ")) {
                    file.selected_keyframe_animation_state = switch (file.selected_keyframe_animation_state) {
                        .play => .pause,
                        .pause => .play,
                    };
                }

                imgui.pushStyleColorImVec4(imgui.Col_FrameBgHovered, Pixi.editor.theme.background.toImguiVec4());
                imgui.pushStyleColorImVec4(imgui.Col_FrameBg, Pixi.editor.theme.background.toImguiVec4());
                defer imgui.popStyleColorEx(2);

                const animation = &file.keyframe_animations.slice().get(file.selected_keyframe_animation_index);

                { // Animation Selection
                    imgui.setNextItemWidth(imgui.calcTextSize(animation.name).x + 40 * Pixi.state.content_scale[0]);
                    if (imgui.beginCombo("Animation  ", animation.name, imgui.ComboFlags_HeightLargest)) {
                        defer imgui.endCombo();
                        var keyframe_animation_index: usize = 0;
                        while (keyframe_animation_index < file.keyframe_animations.slice().len) : (keyframe_animation_index += 1) {
                            const a = &file.keyframe_animations.slice().get(keyframe_animation_index);
                            if (imgui.selectableEx(a.name, keyframe_animation_index == file.selected_keyframe_animation_index, imgui.SelectableFlags_None, .{ .x = 0.0, .y = 0.0 })) {
                                file.selected_keyframe_animation_index = keyframe_animation_index;
                            }
                        }
                    }
                }

                {
                    _ = imgui.checkbox("Loop", &file.selected_keyframe_animation_loop);
                }
            }
        }

        {
            // Draw horizontal grip with remaining menu space
            const cursor_x = imgui.getCursorPosX();
            const avail = imgui.getContentRegionAvail();
            var color = Pixi.editor.theme.text_background.toImguiVec4();

            _ = imgui.invisibleButton("FlipbookGrip", .{
                .x = -1.0,
                .y = -1.0,
            }, imgui.ButtonFlags_None);

            if (imgui.isItemHovered(imgui.HoveredFlags_None)) {
                imgui.setMouseCursor(imgui.MouseCursor_ResizeNS);
                color = Pixi.editor.theme.text.toImguiVec4();
            }

            if (imgui.isItemActive()) {
                color = Pixi.editor.theme.text.toImguiVec4();
                imgui.setMouseCursor(imgui.MouseCursor_ResizeNS);
                Pixi.state.settings.flipbook_height = std.math.clamp(1.0 - mouse_ratio, 0.25, 0.85);
            }

            imgui.setCursorPosX(cursor_x + (avail.x / 2.0));
            imgui.textColored(color, Pixi.fa.grip_lines);
        }
    }
}
