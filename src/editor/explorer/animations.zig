const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("root");
const tools = @import("tools.zig");

pub fn draw() void {
    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 2.0 * pixi.state.window.scale[0], 5.0 * pixi.state.window.scale[1] } });
        defer zgui.popStyleVar(.{ .count = 1 });
        zgui.spacing();
        zgui.text("Tools", .{});
        zgui.separator();
        zgui.spacing();
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 8.0 * pixi.state.window.scale[0], 8.0 * pixi.state.window.scale[1] } });
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.selectable_text_align, .v = .{ 0.5, 0.8 } });
        defer zgui.popStyleVar(.{ .count = 2 });

        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.header, .c = pixi.state.style.foreground.toSlice() });
        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.header_hovered, .c = pixi.state.style.foreground.toSlice() });
        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.header_active, .c = pixi.state.style.foreground.toSlice() });
        defer zgui.popStyleColor(.{ .count = 3 });
        if (zgui.beginChild("AnimationTools", .{
            .h = pixi.state.settings.animation_edit_height * pixi.state.window.scale[1],
        })) {
            defer zgui.endChild();

            const style = zgui.getStyle();
            const window_size = zgui.getWindowSize();

            const button_width = window_size[0] / 4.0;
            const button_height = button_width / 2.0;

            { // Draw tools for animation editing
                zgui.setCursorPosX(style.item_spacing[0]);
                tools.drawTool(pixi.fa.mouse_pointer, button_width, button_height, .pointer);
                
                zgui.sameLine(.{});
                tools.drawTool("[]", button_width, button_height, .animation);
                
            }
        }

        zgui.spacing();
        zgui.text("Animations", .{});
        zgui.separator();
        zgui.spacing();

        if (zgui.beginChild("Animations", .{})) {
            defer zgui.endChild();

            zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 2.0 * pixi.state.window.scale[0], 2.0 * pixi.state.window.scale[1] } });
            zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 4.0 * pixi.state.window.scale[0], 6.0 * pixi.state.window.scale[1] } });
            zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.indent_spacing, .v = 16.0 * pixi.state.window.scale[0] });
            zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.window_padding, .v = .{ 10.0 * pixi.state.window.scale[0], 10.0 * pixi.state.window.scale[1] } });
            defer zgui.popStyleVar(.{ .count = 4 });
            for (file.animations.items, 0..) |animation, animation_index| {
                const header_color = if (file.selected_animation_index == animation_index) pixi.state.style.text.toSlice() else pixi.state.style.text_secondary.toSlice();
                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = header_color });
                defer zgui.popStyleColor(.{ .count = 1 });
                if (zgui.treeNode(zgui.formatZ(" {s}  {s}", .{ pixi.fa.film, animation.name }))) {
                    zgui.pushStrId(animation.name);
                    contextMenu(animation_index, file);
                    zgui.popId();

                    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text_secondary.toSlice() });
                    defer zgui.popStyleColor(.{ .count = 1 });
                    var i: usize = animation.start;
                    while (i < animation.start + animation.length) : (i += 1) {
                        for (file.sprites.items) |sprite| {
                            if (i == sprite.index) {
                                const color = if (file.selected_sprite_index == sprite.index) pixi.state.style.text.toSlice() else pixi.state.style.text_secondary.toSlice();
                                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = color });
                                defer zgui.popStyleColor(.{ .count = 1 });

                                if (zgui.selectable(zgui.formatZ("{s} - Index: {d}", .{ sprite.name, sprite.index }), .{})) {
                                    file.flipbook_scroll_request = .{ .from = file.flipbook_scroll, .to = file.flipbookScrollFromSpriteIndex(sprite.index), .state = file.selected_animation_state };
                                }
                            }
                        }
                    }
                    zgui.treePop();
                } else {
                    zgui.pushStrId(animation.name);
                    contextMenu(animation_index, file);
                    zgui.popId();
                }
            }
        }
    }
}

fn contextMenu(animation_index: usize, file: *pixi.storage.Internal.Pixi) void {
    if (zgui.beginPopupContextItem()) {
        defer zgui.endPopup();

        if (zgui.menuItem("Rename...", .{})) {
            const animation = file.animations.items[animation_index];
            pixi.state.popups.animation_name = [_:0]u8{0} ** 128;
            @memcpy(pixi.state.popups.animation_name[0..animation.name.len], animation.name);
            pixi.state.popups.animation_index = animation_index;
            pixi.state.popups.animation_fps = animation.fps;
            pixi.state.popups.animation_state = .edit;
            pixi.state.popups.animation = true;
        }

        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text_red.toSlice() });
        defer zgui.popStyleColor(.{ .count = 1 });
        if (zgui.menuItem("Delete", .{})) {
            file.deleteAnimation(animation_index) catch unreachable;
            if (animation_index == file.selected_animation_index)
                file.selected_animation_index = 0;
        }
    }
}
