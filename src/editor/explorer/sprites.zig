const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("root");

pub fn draw() void {
    zgui.spacing();
    zgui.text("Sprites", .{});
    zgui.separator();
    zgui.spacing();

    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
        if (zgui.beginChild("Sprites", .{
            .h = @intToFloat(f32, std.math.min(file.sprites.items.len + 1, 12)) * zgui.getTextLineHeightWithSpacing(),
        })) {
            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text_secondary.toSlice() });
            defer zgui.popStyleColor(.{ .count = 1 });
            for (file.sprites.items) |sprite| {
                if (zgui.selectable(zgui.formatZ("{s} - Index: {d}", .{ sprite.name, sprite.index }), .{})) {
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
            for (file.animations.items) |animation| {
                if (zgui.collapsingHeader(zgui.formatZ(" {s}  {s}", .{ pixi.fa.film, animation.name }), .{})) {
                    zgui.indent(.{});
                    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text_secondary.toSlice() });
                    defer zgui.popStyleColor(.{ .count = 1 });
                    var i: usize = animation.start;
                    while (i < animation.start + animation.length) : (i += 1) {
                        for (file.sprites.items) |sprite| {
                            if (i == sprite.index) {
                                if (zgui.selectable(zgui.formatZ("{s} - Index: {d}", .{ sprite.name, sprite.index }), .{})) {}
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
