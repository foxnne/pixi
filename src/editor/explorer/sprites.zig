const std = @import("std");
const pixi = @import("../../pixi.zig");
const core = @import("mach-core");
const imgui = @import("zig-imgui");

pub fn draw() void {
    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
        const selection = file.selected_sprites.items.len > 0;

        imgui.spacing();
        imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_secondary.toImguiVec4());
        imgui.separatorText("Edit  " ++ pixi.fa.wrench);
        imgui.popStyleColor();
        imgui.spacing();
        if (imgui.beginChild("Sprite", .{
            .x = imgui.getWindowWidth(),
            .y = pixi.state.settings.sprite_edit_height * pixi.content_scale[1],
        }, false, imgui.WindowFlags_ChildWindow)) {
            defer imgui.endChild();

            if (!selection) {
                imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_background.toImguiVec4());
                defer imgui.popStyleColor();
                imgui.textWrapped("Make a selection to begin editing sprite origins.");
            } else {
                imgui.pushStyleColorImVec4(imgui.Col_Button, pixi.state.theme.background.toImguiVec4());
                imgui.pushStyleColorImVec4(imgui.Col_ButtonHovered, pixi.state.theme.foreground.toImguiVec4());
                imgui.pushStyleColorImVec4(imgui.Col_ButtonActive, pixi.state.theme.background.toImguiVec4());
                defer imgui.popStyleColorEx(3);
                var x_same: bool = true;
                var y_same: bool = true;
                const first_sprite = file.sprites.items[file.selected_sprites.items[0]];
                var origin_x: f32 = first_sprite.origin_x;
                var origin_y: f32 = first_sprite.origin_y;
                const tile_width = @as(f32, @floatFromInt(file.tile_width));
                const tile_height = @as(f32, @floatFromInt(file.tile_height));

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
                if (imgui.sliderFloatEx(label_origin_x, &origin_x, 0.0, tile_width, "%.0f", imgui.SliderFlags_None)) {
                    changed_origin_x = true;
                }

                if (imgui.isItemActivated()) {
                    file.newHistorySelectedSprites(.origins) catch unreachable;
                }

                if (changed_origin_x)
                    file.setSelectedSpritesOriginX(origin_x);

                const label_origin_y = "Y  " ++ if (y_same) pixi.fa.link else pixi.fa.unlink;
                var changed_origin_y: bool = false;
                if (imgui.sliderFloatEx(label_origin_y, &origin_y, 0.0, tile_height, "%.0f", imgui.SliderFlags_None)) {
                    changed_origin_y = true;
                }

                if (imgui.isItemActivated()) {
                    file.newHistorySelectedSprites(.origins) catch unreachable;
                }

                if (changed_origin_y) {
                    file.setSelectedSpritesOriginY(origin_y);
                }

                if (imgui.buttonEx(" Center ", .{ .x = -1.0, .y = 0.0 })) {
                    file.newHistorySelectedSprites(.origins) catch unreachable;
                    file.setSelectedSpritesOrigin(.{ tile_width / 2.0, tile_height / 2.0 });
                }
            }
        }

        imgui.spacing();
        imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_secondary.toImguiVec4());
        imgui.separatorText("Sprites  " ++ pixi.fa.atlas);
        imgui.popStyleColor();
        imgui.spacing();

        imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0 * pixi.content_scale[0], .y = 5.0 * pixi.content_scale[1] });
        defer imgui.popStyleVar();
        if (imgui.beginChild("Sprites", .{ .x = imgui.getWindowWidth() - pixi.state.settings.explorer_grip * pixi.content_scale[0], .y = 0.0 }, false, imgui.WindowFlags_ChildWindow)) {
            defer imgui.endChild();

            for (file.sprites.items) |sprite| {
                const selected_sprite_index = file.spriteSelectionIndex(sprite.index);
                const contains = selected_sprite_index != null;
                const color = if (contains) pixi.state.theme.text.toImguiVec4() else pixi.state.theme.text_secondary.toImguiVec4();
                imgui.pushStyleColorImVec4(imgui.Col_Text, color);
                defer imgui.popStyleColor();

                const name = std.fmt.allocPrintZ(pixi.state.allocator, "{s} - Index: {d}", .{ sprite.name, sprite.index }) catch unreachable;
                defer pixi.state.allocator.free(name);

                if (imgui.selectableEx(name, contains, imgui.SelectableFlags_None, .{ .x = 0.0, .y = 0.0 })) {
                    file.makeSpriteSelection(sprite.index);
                }
            }
        }
    } else {
        imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_background.toImguiVec4());
        imgui.textWrapped("Open a file to begin editing.");
        imgui.popStyleColor();
    }
}
