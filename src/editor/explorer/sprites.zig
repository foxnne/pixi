const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("root");

pub fn draw() void {
    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
        const selection = file.selected_sprites.items.len > 0;

        zgui.spacing();
        zgui.text("Origin", .{});
        zgui.separator();
        zgui.spacing();
        if (zgui.beginChild("Origin", .{
            .h = pixi.state.settings.sprite_edit_height * pixi.state.window.scale[1],
        })) {
            defer zgui.endChild();

            if (!selection) {
                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text_background.toSlice() });
                defer zgui.popStyleColor(.{ .count = 1 });
                zgui.textWrapped("Make a selection to begin editing sprite origins.", .{});
            } else {
                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button, .c = pixi.state.style.background.toSlice() });
                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button_hovered, .c = pixi.state.style.foreground.toSlice() });
                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button_active, .c = pixi.state.style.background.toSlice() });
                defer zgui.popStyleColor(.{ .count = 3 });
                var x_same: bool = true;
                var y_same: bool = true;
                const first_sprite = file.sprites.items[file.selected_sprites.items[0]];
                var origin_x: f32 = first_sprite.origin_x;
                var origin_y: f32 = first_sprite.origin_y;
                const tile_width = @intToFloat(f32, file.tile_width);
                const tile_height = @intToFloat(f32, file.tile_height);

                for (file.selected_sprites.items) |selected_index| {
                    const sprite = file.sprites.items[selected_index];
                    if (origin_x != sprite.origin_x) {
                        x_same = false;
                    }
                    if (origin_y != sprite.origin_y) {
                        y_same = false;
                    }

                    if (!x_same and !y_same) {
                        break;
                    }
                }

                const label_origin_x = "X  " ++ if (x_same) pixi.fa.link else pixi.fa.unlink;
                var changed_origin_x: bool = false;
                if (zgui.sliderFloat(label_origin_x, .{
                    .v = &origin_x,
                    .min = 0.0,
                    .max = tile_width,
                    .cfmt = "%.0f",
                })) {
                    changed_origin_x = true;
                }

                if (zgui.isItemActivated()) {
                    file.historyPushOrigin() catch unreachable;
                }

                if (changed_origin_x)
                    file.setSelectedSpritesOriginX(origin_x);

                const label_origin_y = "Y  " ++ if (y_same) pixi.fa.link else pixi.fa.unlink;
                var changed_origin_y: bool = false;
                if (zgui.sliderFloat(label_origin_y, .{
                    .v = &origin_y,
                    .min = 0.0,
                    .max = tile_height,
                    .cfmt = "%.0f",
                })) {
                    changed_origin_y = true;
                }

                if (zgui.isItemActivated()) {
                    file.historyPushOrigin() catch unreachable;
                }

                if (changed_origin_y) {
                    file.setSelectedSpritesOriginY(origin_y);
                }

                if (zgui.button(" Center ", .{ .w = -1.0 })) {
                    file.historyPushOrigin() catch unreachable;
                    file.setSelectedSpritesOrigin(.{ tile_width / 2.0, tile_height / 2.0 });
                }
            }
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
