const std = @import("std");
const pixi = @import("../../pixi.zig");
const Editor = pixi.Editor;

const tools = @import("tools.zig");
const imgui = @import("zig-imgui");

pub fn draw(editor: *Editor) !void {
    if (editor.getFile(editor.open_file_index)) |file| {
        imgui.pushStyleColorImVec4(imgui.Col_Header, editor.theme.background.toImguiVec4());
        imgui.pushStyleColorImVec4(imgui.Col_HeaderHovered, editor.theme.background.toImguiVec4());
        imgui.pushStyleColorImVec4(imgui.Col_HeaderActive, editor.theme.background.toImguiVec4());
        defer imgui.popStyleColorEx(3);

        imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0, .y = 4.0 });
        imgui.pushStyleVarImVec2(imgui.StyleVar_SelectableTextAlign, .{ .x = 0.5, .y = 0.8 });
        imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 6.0, .y = 6.0 });
        defer imgui.popStyleVarEx(3);

        // Make sure we can see the canvas for animation previews
        file.flipbook_view = .canvas;

        if (imgui.collapsingHeader(pixi.fa.screwdriver ++ "  Tools", imgui.TreeNodeFlags_DefaultOpen)) {
            imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0, .y = 5.0 });
            defer imgui.popStyleVar();

            imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 8.0, .y = 4.0 });
            imgui.pushStyleVarImVec2(imgui.StyleVar_SelectableTextAlign, .{ .x = 0.5, .y = 0.8 });
            defer imgui.popStyleVarEx(2);

            imgui.pushStyleColorImVec4(imgui.Col_Header, editor.theme.foreground.toImguiVec4());
            imgui.pushStyleColorImVec4(imgui.Col_HeaderHovered, editor.theme.foreground.toImguiVec4());
            imgui.pushStyleColorImVec4(imgui.Col_HeaderActive, editor.theme.foreground.toImguiVec4());
            defer imgui.popStyleColorEx(3);
            if (imgui.beginChild("AnimationTools", .{
                .x = imgui.getWindowWidth(),
                .y = editor.settings.animation_edit_height,
            }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
                defer imgui.endChild();

                const style = imgui.getStyle();
                const window_size = imgui.getWindowSize();

                const button_width = window_size.x / 4.0;
                const button_height = button_width / 2.0;

                { // Draw tools for animation editing
                    imgui.setCursorPosX(style.item_spacing.x * 2.0);
                    try tools.drawTool(editor, pixi.fa.mouse_pointer, button_width, button_height, .pointer);

                    imgui.sameLine();
                    try tools.drawTool(editor, "[]", button_width, button_height, .animation);
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
                imgui.pushStyleVar(imgui.StyleVar_IndentSpacing, 2.0);
                imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0, .y = 10.0 });
                defer imgui.popStyleVarEx(4);
                var animation_index: usize = 0;
                while (animation_index < file.animations.slice().len) : (animation_index += 1) {
                    const animation = file.animations.slice().get(animation_index);
                    const header_color = if (file.selected_animation_index == animation_index) editor.theme.text.toImguiVec4() else editor.theme.text_secondary.toImguiVec4();
                    imgui.pushStyleColorImVec4(imgui.Col_Text, header_color);
                    defer imgui.popStyleColor();
                    const animation_name = try std.fmt.allocPrintZ(editor.arena.allocator(), " {s}  {s}", .{ pixi.fa.film, animation.name });

                    if (imgui.treeNode(animation_name)) {
                        imgui.pushID(animation.name);
                        try contextMenu(animation_index, file, editor);
                        imgui.popID();

                        imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text_secondary.toImguiVec4());
                        defer imgui.popStyleColor();
                        var i: usize = animation.start;
                        while (i < animation.start + animation.length) : (i += 1) {
                            var sprite_index: usize = 0;
                            while (sprite_index < file.sprites.slice().len) : (sprite_index += 1) {
                                if (i == sprite_index) {
                                    const color = if (file.selected_sprite_index == sprite_index) editor.theme.text.toImguiVec4() else editor.theme.text_secondary.toImguiVec4();
                                    imgui.pushStyleColorImVec4(imgui.Col_Text, color);
                                    defer imgui.popStyleColor();

                                    const sprite_name = try file.calculateSpriteName(editor.arena.allocator(), sprite_index);

                                    if (imgui.selectable(sprite_name)) {
                                        file.flipbook_scroll_request = .{
                                            .from = file.flipbook_scroll,
                                            .to = file.flipbookScrollFromSpriteIndex(sprite_index),
                                            .state = file.selected_animation_state,
                                        };
                                    }
                                }
                            }
                        }
                        imgui.treePop();
                    } else {
                        imgui.pushID(animation.name);
                        try contextMenu(animation_index, file, editor);
                        imgui.popID();
                    }
                }
            }
        }
    } else {
        imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text_background.toImguiVec4());
        imgui.textWrapped("Open a file to begin editing.");
        imgui.popStyleColor();
    }
}

fn contextMenu(animation_index: usize, file: *pixi.Internal.File, editor: *Editor) !void {
    if (imgui.beginPopupContextItem()) {
        defer imgui.endPopup();

        if (imgui.menuItem("Rename...")) {
            const animation = file.animations.slice().get(animation_index);
            editor.popups.animation_name = [_:0]u8{0} ** 128;
            @memcpy(editor.popups.animation_name[0..animation.name.len], animation.name);
            editor.popups.animation_index = animation_index;
            editor.popups.animation_fps = animation.fps;
            editor.popups.animation_state = .edit;
            editor.popups.animation = true;
        }

        imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text_red.toImguiVec4());
        defer imgui.popStyleColor();
        if (imgui.menuItem("Delete")) {
            try file.deleteAnimation(animation_index);
            if (animation_index == file.selected_animation_index)
                file.selected_animation_index = 0;
        }
    }
}
