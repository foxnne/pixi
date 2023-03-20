const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("root");

pub fn draw() void {
    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
        const selection = file.selected_sprites.items.len > 0;

        zgui.spacing();
        zgui.text("Edit", .{});
        zgui.separator();
        zgui.spacing();
        if (zgui.beginChild("Edit Sprites", .{
            .h = pixi.state.settings.sprite_edit_height * pixi.state.window.scale[1],
        })) {
            defer zgui.endChild();

            if (!selection) {
                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text_background.toSlice() });
                defer zgui.popStyleColor(.{ .count = 1 });
                zgui.textWrapped("Make a selection to begin editing sprites.", .{});
            } else {}
        }

        zgui.spacing();
        zgui.text("Sprites", .{});
        zgui.separator();
        zgui.spacing();

        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 2.0 * pixi.state.window.scale[0], 5.0 * pixi.state.window.scale[1] } });
        defer zgui.popStyleVar(.{ .count = 1 });
        if (zgui.beginChild("Sprites", .{})) {
            defer zgui.endChild();

            for (file.sprites.items) |sprite| {
                const selected_sprite_index = file.spriteSelectionIndex(sprite.index);
                const contains = selected_sprite_index != null;
                const color = if (contains) pixi.state.style.text.toSlice() else pixi.state.style.text_secondary.toSlice();
                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = color });
                defer zgui.popStyleColor(.{ .count = 1 });
                if (zgui.selectable(zgui.formatZ("{s} - Index: {d}", .{ sprite.name, sprite.index }), .{ .selected = contains })) {
                    file.makeSpriteSelection(sprite.index);
                }
            }
        }
    }
}
