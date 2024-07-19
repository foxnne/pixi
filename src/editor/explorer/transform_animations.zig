const std = @import("std");
const pixi = @import("../../pixi.zig");
const core = @import("mach").core;
const tools = @import("tools.zig");
const imgui = @import("zig-imgui");

pub fn draw() void {
    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
        // Make sure we can see the timeline for animation previews
        file.flipbook_view = .timeline;

        // imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0 * pixi.content_scale[0], .y = 5.0 * pixi.content_scale[1] });
        // defer imgui.popStyleVar();
        // imgui.spacing();
        // imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_secondary.toImguiVec4());
        // imgui.separatorText("Tools  " ++ pixi.fa.screwdriver);
        // imgui.popStyleColor();
        // imgui.spacing();
        imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 8.0 * pixi.content_scale[0], .y = 4.0 * pixi.content_scale[1] });
        imgui.pushStyleVarImVec2(imgui.StyleVar_SelectableTextAlign, .{ .x = 0.5, .y = 0.8 });
        defer imgui.popStyleVarEx(2);

        // imgui.pushStyleColorImVec4(imgui.Col_Header, pixi.state.theme.foreground.toImguiVec4());
        // imgui.pushStyleColorImVec4(imgui.Col_HeaderHovered, pixi.state.theme.foreground.toImguiVec4());
        // imgui.pushStyleColorImVec4(imgui.Col_HeaderActive, pixi.state.theme.foreground.toImguiVec4());
        // defer imgui.popStyleColorEx(3);
        // if (imgui.beginChild("AnimationTools", .{
        //     .x = imgui.getWindowWidth(),
        //     .y = pixi.state.settings.animation_edit_height * pixi.content_scale[1],
        // }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
        //     defer imgui.endChild();

        //     const style = imgui.getStyle();
        //     const window_size = imgui.getWindowSize();

        //     const button_width = window_size.x / 4.0;
        //     const button_height = button_width / 2.0;

        //     { // Draw tools for animation editing
        //         imgui.setCursorPosX(style.item_spacing.x);
        //         tools.drawTool(pixi.fa.mouse_pointer, button_width, button_height, .pointer);

        //         imgui.sameLine();
        //         tools.drawTool("[]", button_width, button_height, .animation);
        //     }
        // }

        imgui.spacing();
        imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_secondary.toImguiVec4());
        imgui.separatorText("Animations  " ++ pixi.fa.film);
        imgui.popStyleColor();
        imgui.spacing();

        if (imgui.beginChild("Animations", .{
            .x = imgui.getWindowWidth() - pixi.state.settings.explorer_grip * pixi.content_scale[0],
            .y = 0.0,
        }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
            defer imgui.endChild();

            imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0 * pixi.content_scale[0], .y = 2.0 * pixi.content_scale[1] });
            imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0 * pixi.content_scale[0], .y = 6.0 * pixi.content_scale[1] });
            imgui.pushStyleVarImVec2(imgui.StyleVar_SelectableTextAlign, .{ .x = 0.0, .y = 0.5 });
            imgui.pushStyleVar(imgui.StyleVar_IndentSpacing, 2.0 * pixi.content_scale[0]);
            imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0 * pixi.content_scale[0], .y = 10.0 * pixi.content_scale[1] });
            defer imgui.popStyleVarEx(5);
            for (file.keyframe_animations.items, 0..) |animation, animation_index| {
                const header_color = if (file.selected_keyframe_animation_index == animation_index) pixi.state.theme.text.toImguiVec4() else pixi.state.theme.text_secondary.toImguiVec4();

                const animation_name = std.fmt.allocPrintZ(pixi.state.allocator, " {s}  {s}", .{ pixi.fa.film, animation.name }) catch unreachable;
                defer pixi.state.allocator.free(animation_name);

                imgui.pushStyleColorImVec4(imgui.Col_Text, header_color);
                defer imgui.popStyleColor();

                if (imgui.treeNode(animation_name)) {
                    defer imgui.treePop();

                    imgui.indentEx(20.0);
                    defer imgui.unindentEx(20.0);

                    imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_secondary.toImguiVec4());
                    defer imgui.popStyleColor();
                    for (animation.keyframes.items, 0..) |*keyframe, keyframe_i| {
                        const keyframe_name = std.fmt.allocPrintZ(pixi.state.allocator, "{s}_Keyframe_{d}", .{ animation.name, keyframe_i }) catch unreachable;
                        defer pixi.state.allocator.free(keyframe_name);

                        if (imgui.treeNode(keyframe_name)) {
                            defer imgui.treePop();

                            imgui.indentEx(30.0);
                            defer imgui.unindentEx(30.0);

                            var i: usize = 0;
                            while (i < keyframe.frames.items.len) : (i += 1) {
                                const frame = keyframe.frames.items[i];
                                const color_index: usize = @mod(frame.id * 2, 35);

                                const color = if (pixi.state.colors.keyframe_palette) |palette| pixi.math.Color.initBytes(
                                    palette.colors[color_index][0],
                                    palette.colors[color_index][1],
                                    palette.colors[color_index][2],
                                    palette.colors[color_index][3],
                                ).toU32() else pixi.state.theme.text.toU32();

                                const sprite = file.sprites.items[frame.sprite_index];

                                const sprite_name = std.fmt.allocPrintZ(pixi.state.allocator, "{s}##{d}", .{ sprite.name, frame.id }) catch unreachable;
                                defer pixi.state.allocator.free(sprite_name);

                                imgui.pushStyleColor(imgui.Col_Text, color);
                                imgui.bullet();

                                if (keyframe.active_frame_id == frame.id) {
                                    imgui.pushStyleColor(imgui.Col_Text, pixi.state.theme.text.toU32());
                                } else {
                                    imgui.pushStyleColor(imgui.Col_Text, pixi.state.theme.text_secondary.toU32());
                                }
                                defer imgui.popStyleColorEx(2);

                                imgui.sameLine();

                                if (imgui.selectable(sprite_name)) {
                                    file.flipbook_scroll_request = .{ .from = file.flipbook_scroll, .to = file.flipbookScrollFromSpriteIndex(sprite.index), .state = file.selected_animation_state };
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
                imgui.pushID(animation.name);
                contextMenu(animation_index, file);
                imgui.popID();
            }
        }
    } else {
        imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_background.toImguiVec4());
        imgui.textWrapped("Open a file to begin editing.");
        imgui.popStyleColor();
    }
}

fn contextMenu(animation_index: usize, file: *pixi.storage.Internal.Pixi) void {
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

        imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_red.toImguiVec4());
        defer imgui.popStyleColor();
        if (imgui.menuItem("Delete")) {
            file.deleteTransformAnimation(animation_index) catch unreachable;
            if (animation_index == file.selected_keyframe_animation_index)
                file.selected_keyframe_animation_index = 0;
        }
    }
}
