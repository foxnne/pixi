const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("root");

pub fn draw() void {
    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
        if (zgui.beginChild("Sprites", .{
            .h = @intToFloat(f32, std.math.min(file.sprites.items.len + 1, 12)) * zgui.getTextLineHeightWithSpacing(),
        })) {
            zgui.spacing();
            zgui.text("Sprites", .{});
            zgui.separator();
            zgui.spacing();
            for (file.sprites.items) |sprite| {
                const color = if (file.selected_sprite_index == sprite.index) pixi.state.style.text.toSlice() else pixi.state.style.text_secondary.toSlice();
                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = color });
                defer zgui.popStyleColor(.{ .count = 1 });
                if (zgui.selectable(zgui.formatZ("{s} - Index: {d}", .{ sprite.name, sprite.index }), .{ .selected = sprite.index == file.selected_sprite_index })) {
                    file.flipbook_scroll_request = .{ .from = file.flipbook_scroll, .to = file.flipbookScrollFromSpriteIndex(sprite.index), .state = file.selected_animation_state };
                }
            }
        }
        zgui.endChild();

        zgui.spacing();
        zgui.text("Animations", .{});
        zgui.separator();
        zgui.spacing();

        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 2.0 * pixi.state.window.scale[0], 5.0 * pixi.state.window.scale[1] } });
        defer zgui.popStyleVar(.{ .count = 1 });
        if (zgui.beginChild("Animations", .{})) {
            for (file.animations.items, 0..) |animation, a| {
                const header_color = if (file.selected_animation_index == a) pixi.state.style.text.toSlice() else pixi.state.style.text_secondary.toSlice();
                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = header_color });
                defer zgui.popStyleColor(.{ .count = 1 });
                if (zgui.collapsingHeader(zgui.formatZ(" {s}  {s}", .{ pixi.fa.film, animation.name }), .{})) {
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
                }
            }
        }

        zgui.endChild();
    }
}
