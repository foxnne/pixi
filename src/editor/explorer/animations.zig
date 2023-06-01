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

            // if (file.animations.items.len == 0) {
            //     zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text_background.toSlice() });
            //     defer zgui.popStyleColor(.{ .count = 1 });
            //     zgui.textWrapped("Add an animation to begin editing.", .{});
            // } else {
            //     zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button, .c = pixi.state.style.background.toSlice() });
            //     zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button_hovered, .c = pixi.state.style.foreground.toSlice() });
            //     zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button_active, .c = pixi.state.style.background.toSlice() });
            //     defer zgui.popStyleColor(.{ .count = 3 });

            //     var animation = &file.animations.items[file.selected_animation_index];

            //     { // FPS
            //         var fps = @intCast(i32, animation.fps);
            //         if (zgui.sliderInt("FPS", .{
            //             .v = &fps,
            //             .min = 1,
            //             .max = 60,
            //         })) {
            //             const new_fps = @intCast(usize, fps);
            //             if (new_fps != animation.fps) {
            //                 animation.fps = new_fps;
            //                 file.dirty = true;
            //             }
            //         }
            //     }

            //     { // Start/Length
            //         var start = @intCast(i32, animation.start);
            //         _ = start;
            //         var length = @intCast(i32, animation.length);
            //         _ = length;
            //     }
            // }
        }

        zgui.spacing();
        zgui.text("Animations", .{});
        zgui.separator();
        zgui.spacing();

        if (zgui.beginChild("Animations", .{})) {
            defer zgui.endChild();
            for (file.animations.items, 0..) |animation, a| {
                const header_color = if (file.selected_animation_index == a) pixi.state.style.text.toSlice() else pixi.state.style.text_secondary.toSlice();
                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = header_color });
                defer zgui.popStyleColor(.{ .count = 1 });
                if (zgui.treeNode(zgui.formatZ(" {s}  {s}", .{ pixi.fa.film, animation.name }))) {
                    zgui.indent(.{});
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
                    zgui.unindent(.{});
                    zgui.treePop();
                }
            }
        }
    }
}
