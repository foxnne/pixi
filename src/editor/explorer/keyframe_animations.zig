const std = @import("std");
const Pixi = @import("../../Pixi.zig");
const core = @import("mach").core;
const tools = @import("tools.zig");
const imgui = @import("zig-imgui");

pub fn draw() !void {
    if (Pixi.Editor.getFile(Pixi.state.open_file_index)) |file| {
        // Make sure we can see the timeline for animation previews
        file.flipbook_view = .timeline;

        imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0, .y = 4.0 });
        imgui.pushStyleVarImVec2(imgui.StyleVar_SelectableTextAlign, .{ .x = 0.5, .y = 0.8 });
        imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 6.0, .y = 6.0 });
        defer imgui.popStyleVarEx(3);

        imgui.pushStyleColorImVec4(imgui.Col_Header, Pixi.editor.theme.background.toImguiVec4());
        imgui.pushStyleColorImVec4(imgui.Col_HeaderHovered, Pixi.editor.theme.background.toImguiVec4());
        imgui.pushStyleColorImVec4(imgui.Col_HeaderActive, Pixi.editor.theme.background.toImguiVec4());
        defer imgui.popStyleColorEx(3);
        if (imgui.beginChild("SelectedFrame", .{
            .x = imgui.getWindowWidth(),
            .y = 100,
        }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
            defer imgui.endChild();

            imgui.pushItemWidth(imgui.getWindowWidth() / 2.0);
            defer imgui.popItemWidth();

            if (file.keyframe_animations.items.len > 0) {
                const animation = &file.keyframe_animations.items[file.selected_keyframe_animation_index];

                if (animation.keyframes.items.len > 0) {
                    if (animation.keyframe(animation.active_keyframe_id)) |keyframe| {
                        if (keyframe.frames.items.len > 0) {
                            if (keyframe.frame(keyframe.active_frame_id)) |frame| {
                                var time: f32 = keyframe.time;
                                if (imgui.inputFloatEx("Keyframe time (s)", &time, 0.01, 0.01, "%.2f", imgui.InputTextFlags_CharsDecimal)) {
                                    keyframe.time = std.math.clamp(time, 0.0, std.math.floatMax(f32));
                                }

                                var sprite_index: c_int = @intCast(frame.sprite_index);

                                if (imgui.inputInt("Frame Sprite Index", &sprite_index)) {
                                    frame.sprite_index = @intCast(std.math.clamp(sprite_index, 0, @as(c_int, @intCast(file.sprites.items.len - 1))));
                                }
                            }
                        }
                    }
                }
            }
        }

        if (imgui.collapsingHeader(Pixi.fa.film ++ "  Animations", imgui.TreeNodeFlags_DefaultOpen)) {
            imgui.indent();
            defer imgui.unindent();

            if (imgui.beginChild("Animations", .{
                .x = imgui.getWindowWidth() - Pixi.state.settings.explorer_grip * Pixi.state.content_scale[0],
                .y = 0.0,
            }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
                defer imgui.endChild();

                imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0 * Pixi.state.content_scale[0], .y = 2.0 * Pixi.state.content_scale[1] });
                imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0 * Pixi.state.content_scale[0], .y = 6.0 * Pixi.state.content_scale[1] });
                imgui.pushStyleVarImVec2(imgui.StyleVar_SelectableTextAlign, .{ .x = 0.0, .y = 0.5 });
                imgui.pushStyleVar(imgui.StyleVar_IndentSpacing, 2.0 * Pixi.state.content_scale[0]);
                imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0 * Pixi.state.content_scale[0], .y = 10.0 * Pixi.state.content_scale[1] });
                defer imgui.popStyleVarEx(5);
                for (file.keyframe_animations.items, 0..) |*animation, animation_index| {
                    const animation_color = if (file.selected_keyframe_animation_index == animation_index) Pixi.editor.theme.text.toImguiVec4() else Pixi.editor.theme.text_secondary.toImguiVec4();

                    const animation_name = try std.fmt.allocPrintZ(Pixi.state.allocator, " {s}  {s}##{d}", .{ Pixi.fa.film, animation.name, animation.id });
                    defer Pixi.state.allocator.free(animation_name);

                    imgui.pushStyleColorImVec4(imgui.Col_Text, animation_color);
                    defer imgui.popStyleColor();

                    if (imgui.treeNodeEx(animation_name, imgui.TreeNodeFlags_DefaultOpen)) {
                        defer imgui.treePop();

                        imgui.indentEx(20.0);
                        defer imgui.unindentEx(20.0);

                        for (animation.keyframes.items) |*keyframe| {
                            const keyframe_name = try std.fmt.allocPrintZ(Pixi.state.allocator, "Keyframe ID:{d}", .{keyframe.id});
                            defer Pixi.state.allocator.free(keyframe_name);

                            const keyframe_color = if (animation.active_keyframe_id == keyframe.id) Pixi.editor.theme.text.toImguiVec4() else Pixi.editor.theme.text_secondary.toImguiVec4();

                            imgui.pushStyleColorImVec4(imgui.Col_Text, keyframe_color);
                            defer imgui.popStyleColor();

                            if (imgui.treeNodeEx(keyframe_name, imgui.TreeNodeFlags_DefaultOpen)) {
                                defer imgui.treePop();

                                imgui.indentEx(30.0);
                                defer imgui.unindentEx(30.0);

                                var i: usize = 0;
                                while (i < keyframe.frames.items.len) : (i += 1) {
                                    const frame = keyframe.frames.items[i];

                                    const color = animation.getFrameNodeColor(frame.id);
                                    const sprite = file.sprites.items[frame.sprite_index];

                                    const sprite_name = try std.fmt.allocPrintZ(Pixi.state.allocator, "{s}##{d}{d}{d}", .{ sprite.name, frame.id, keyframe.id, animation.id });
                                    defer Pixi.state.allocator.free(sprite_name);

                                    imgui.pushStyleColor(imgui.Col_Text, color);
                                    imgui.bullet();

                                    if (keyframe.active_frame_id == frame.id and animation.active_keyframe_id == keyframe.id) {
                                        imgui.pushStyleColor(imgui.Col_Text, Pixi.editor.theme.text.toU32());
                                    } else {
                                        imgui.pushStyleColor(imgui.Col_Text, Pixi.editor.theme.text_secondary.toU32());
                                    }
                                    defer imgui.popStyleColorEx(2);

                                    imgui.sameLine();

                                    if (imgui.selectable(sprite_name)) {
                                        for (file.selected_sprites.items) |selected_sprite| {
                                            if (selected_sprite != sprite.index or file.selected_sprites.items.len > 1) {
                                                file.selected_sprites.clearAndFree();
                                                try file.selected_sprites.append(sprite.index);
                                            }
                                        }
                                        file.selected_keyframe_animation_index = animation_index;
                                        animation.active_keyframe_id = keyframe.id;
                                        keyframe.active_frame_id = frame.id;
                                    }

                                    if (imgui.isItemActive() and !imgui.isItemHovered(imgui.HoveredFlags_None) and imgui.isAnyItemHovered()) {
                                        const i_next = @as(usize, @intCast(std.math.clamp(@as(i32, @intCast(i)) + (if (imgui.getMouseDragDelta(imgui.MouseButton_Left, 0.0).y < 0.0) @as(i32, -1) else @as(i32, 1)), 0, std.math.maxInt(i32))));
                                        if (i_next >= 0 and i_next < keyframe.frames.items.len) {
                                            keyframe.frames.items[i] = keyframe.frames.items[i_next];
                                            keyframe.frames.items[i_next] = frame;
                                            keyframe.active_frame_id = keyframe.frames.items[i_next].id;
                                        }
                                        imgui.resetMouseDragDeltaEx(imgui.MouseButton_Left);
                                    }
                                }
                            }
                        }
                    }

                    if (imgui.isItemClicked()) {
                        file.selected_keyframe_animation_index = animation_index;
                    }

                    try contextMenu(animation_index, file);
                }
            }
        }
    } else {
        imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_background.toImguiVec4());
        imgui.textWrapped("Open a file to begin editing.");
        imgui.popStyleColor();
    }
}

fn contextMenu(animation_index: usize, file: *Pixi.storage.Internal.PixiFile) !void {
    if (imgui.beginPopupContextItem()) {
        defer imgui.endPopup();

        // if (imgui.menuItem("Rename...")) {
        //     const animation = file.transform_animations.items[animation_index];
        //     pixi.state.popups.animation_name = [_:0]u8{0} ** 128;
        //     @memcpy(pixi.state.popups.animation_name[0..animation.name.len], animation.name);
        //     pixi.state.popups.animation_index = animation_index;
        //     pixi.state.popups.animation_fps = animation.fps;
        //     pixi.state.popups.animation_state = .edit;
        //     pixi.state.popups.animation = true;
        // }

        imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_red.toImguiVec4());
        defer imgui.popStyleColor();
        if (imgui.menuItem("Delete")) {
            try file.deleteTransformAnimation(animation_index);
            if (animation_index == file.selected_keyframe_animation_index)
                file.selected_keyframe_animation_index = 0;
        }
    }
}
