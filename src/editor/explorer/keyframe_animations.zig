const std = @import("std");

const pixi = @import("../../pixi.zig");
const Editor = pixi.Editor;

const core = @import("mach").core;
const tools = @import("tools.zig");
const imgui = @import("zig-imgui");

pub fn draw(editor: *Editor) !void {
    if (editor.getFile(editor.open_file_index)) |file| {
        // Make sure we can see the timeline for animation previews
        file.flipbook_view = .timeline;

        imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0, .y = 4.0 });
        imgui.pushStyleVarImVec2(imgui.StyleVar_SelectableTextAlign, .{ .x = 0.5, .y = 0.8 });
        imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 6.0, .y = 6.0 });
        defer imgui.popStyleVarEx(3);

        imgui.pushStyleColorImVec4(imgui.Col_Header, editor.theme.background.toImguiVec4());
        imgui.pushStyleColorImVec4(imgui.Col_HeaderHovered, editor.theme.background.toImguiVec4());
        imgui.pushStyleColorImVec4(imgui.Col_HeaderActive, editor.theme.background.toImguiVec4());
        defer imgui.popStyleColorEx(3);
        if (imgui.beginChild("SelectedFrame", .{
            .x = imgui.getWindowWidth(),
            .y = 100,
        }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
            defer imgui.endChild();

            imgui.pushItemWidth(imgui.getWindowWidth() / 2.0);
            defer imgui.popItemWidth();

            if (file.keyframe_animations.slice().len > 0) {
                const animation = &file.keyframe_animations.slice().get(file.selected_keyframe_animation_index);

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
                                    frame.sprite_index = @intCast(std.math.clamp(sprite_index, 0, @as(c_int, @intCast(file.sprites.slice().len - 1))));
                                }
                            }
                        }
                    }
                }
            }
        }

        if (imgui.collapsingHeader(pixi.fa.film ++ "  Animations", imgui.TreeNodeFlags_DefaultOpen)) {
            imgui.indent();
            defer imgui.unindent();

            if (imgui.beginChild("Animations", .{
                .x = imgui.getWindowWidth() - editor.settings.explorer_grip,
                .y = 0.0,
            }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
                defer imgui.endChild();

                imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0, .y = 2.0 });
                imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0, .y = 6.0 });
                imgui.pushStyleVarImVec2(imgui.StyleVar_SelectableTextAlign, .{ .x = 0.0, .y = 0.5 });
                imgui.pushStyleVar(imgui.StyleVar_IndentSpacing, 2.0);
                imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0, .y = 10.0 });
                defer imgui.popStyleVarEx(5);
                var animation_index: usize = 0;
                while (animation_index < file.keyframe_animations.slice().len) : (animation_index += 1) {
                    const animation = file.keyframe_animations.slice().get(animation_index);
                    const animation_color = if (file.selected_keyframe_animation_index == animation_index) editor.theme.text.toImguiVec4() else editor.theme.text_secondary.toImguiVec4();

                    const animation_name = try std.fmt.allocPrintZ(pixi.app.allocator, " {s}  {s}##{d}", .{ pixi.fa.film, animation.name, animation.id });
                    defer pixi.app.allocator.free(animation_name);

                    imgui.pushStyleColorImVec4(imgui.Col_Text, animation_color);
                    defer imgui.popStyleColor();

                    if (imgui.treeNodeEx(animation_name, imgui.TreeNodeFlags_DefaultOpen)) {
                        defer imgui.treePop();

                        imgui.indentEx(20.0);
                        defer imgui.unindentEx(20.0);

                        for (animation.keyframes.items) |*keyframe| {
                            const keyframe_name = try std.fmt.allocPrintZ(pixi.app.allocator, "Keyframe ID:{d}", .{keyframe.id});
                            defer pixi.app.allocator.free(keyframe_name);

                            const keyframe_color = if (animation.active_keyframe_id == keyframe.id) editor.theme.text.toImguiVec4() else editor.theme.text_secondary.toImguiVec4();

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

                                    const sprite_name = try std.fmt.allocPrintZ(editor.arena.allocator(), "{s}##{d}{d}{d}", .{
                                        try file.calculateSpriteName(editor.arena.allocator(), frame.sprite_index),
                                        frame.id,
                                        keyframe.id,
                                        animation.id,
                                    });

                                    imgui.pushStyleColor(imgui.Col_Text, color);
                                    imgui.bullet();

                                    if (keyframe.active_frame_id == frame.id and animation.active_keyframe_id == keyframe.id) {
                                        imgui.pushStyleColor(imgui.Col_Text, editor.theme.text.toU32());
                                    } else {
                                        imgui.pushStyleColor(imgui.Col_Text, editor.theme.text_secondary.toU32());
                                    }
                                    defer imgui.popStyleColorEx(2);

                                    imgui.sameLine();

                                    if (imgui.selectable(sprite_name)) {
                                        for (file.selected_sprites.items, 0..) |selected_sprite, sprite_index| {
                                            if (selected_sprite != sprite_index or file.selected_sprites.items.len > 1) {
                                                file.selected_sprites.clearAndFree();
                                                try file.selected_sprites.append(sprite_index);
                                            }
                                        }
                                        file.selected_keyframe_animation_index = animation_index;
                                        file.keyframe_animations.items(.active_keyframe_id)[animation_index] = keyframe.id;
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

                    try contextMenu(editor, animation_index, file);
                }
            }
        }
    } else {
        imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text_background.toImguiVec4());
        imgui.textWrapped("Open a file to begin editing.");
        imgui.popStyleColor();
    }
}

fn contextMenu(editor: *Editor, animation_index: usize, file: *pixi.Internal.File) !void {
    if (imgui.beginPopupContextItem()) {
        defer imgui.endPopup();

        // if (imgui.menuItem("Rename...")) {
        //     const animation = file.transform_animations.items[animation_index];
        //     pixi.editor.popups.animation_name = [_:0]u8{0} ** 128;
        //     @memcpy(pixi.editor.popups.animation_name[0..animation.name.len], animation.name);
        //     pixi.editor.popups.animation_index = animation_index;
        //     pixi.editor.popups.animation_fps = animation.fps;
        //     pixi.editor.popups.animation_state = .edit;
        //     pixi.editor.popups.animation = true;
        // }

        imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text_red.toImguiVec4());
        defer imgui.popStyleColor();
        if (imgui.menuItem("Delete")) {
            try file.deleteTransformAnimation(animation_index);
            if (animation_index == file.selected_keyframe_animation_index)
                file.selected_keyframe_animation_index = 0;
        }
    }
}
