const std = @import("std");
const pixi = @import("root");
const zgui = @import("zgui");

pub fn draw(file: *pixi.storage.Internal.Pixi) void {
    const window_width = zgui.getWindowWidth();
    const window_height = zgui.getWindowHeight();
    const file_width = @intToFloat(f32, file.width);
    const file_height = @intToFloat(f32, file.height);
    const tile_width = @intToFloat(f32, file.tile_width);
    const tile_height = @intToFloat(f32, file.tile_height);

    const canvas_center_offset = file.canvasCenterOffset(.primary);

    // Handle zooming, panning and extents
    {
        var sprite_camera: pixi.gfx.Camera = .{
            .zoom = @min(window_width / file_width, window_height / file_height),
        };
        sprite_camera.setNearestZoomFloor();
        if (!file.camera.zoom_initialized) {
            file.camera.zoom_initialized = true;
            file.camera.zoom = sprite_camera.zoom;
        }
        sprite_camera.setNearestZoomFloor();
        const min_zoom = @min(sprite_camera.zoom, 1.0);

        file.camera.processPanZoom();

        // Lock camera from zooming in or out too far for the flipbook
        file.camera.zoom = std.math.clamp(file.camera.zoom, min_zoom, pixi.state.settings.zoom_steps[pixi.state.settings.zoom_steps.len - 1]);

        // Lock camera from moving too far away from canvas
        file.camera.position[0] = std.math.clamp(file.camera.position[0], -(canvas_center_offset[0] + file_width), canvas_center_offset[0] + file_width);
        file.camera.position[1] = std.math.clamp(file.camera.position[1], -(canvas_center_offset[1] + file_height), canvas_center_offset[1] + file_height);
    }

    // TODO: Only clear and update if we need to?
    file.temporary_layer.clear(true);

    if (zgui.isWindowHovered(.{})) {
        var mouse_position = pixi.state.controls.mouse.position.toSlice();

        file.camera.processZoomTooltip(file.camera.zoom);

        if (file.camera.pixelCoordinates(.{
            .texture_position = canvas_center_offset,
            .position = mouse_position,
            .width = file.width,
            .height = file.height,
        })) |pixel_coord| {
            const pixel = .{ @floatToInt(usize, pixel_coord[0]), @floatToInt(usize, pixel_coord[1]) };

            var tile_column = @divTrunc(pixel[0], @intCast(usize, file.tile_width));
            var tile_row = @divTrunc(pixel[1], @intCast(usize, file.tile_height));

            const x = @intToFloat(f32, tile_column) * tile_width + canvas_center_offset[0];
            const y = @intToFloat(f32, tile_row) * tile_height + canvas_center_offset[1];

            file.camera.drawTexture(file.background_texture_view_handle, file.tile_width, file.tile_height, .{ x, y }, 0x88FFFFFF);

            file.processSampleTool(.primary);
            file.processStrokeTool(.primary);
            file.processAnimationTool();

            if (pixi.state.controls.mouse.primary.pressed()) {
                var tiles_wide = @divExact(@intCast(usize, file.width), @intCast(usize, file.tile_width));
                var tile_index = tile_column + tile_row * tiles_wide;

                if (pixi.state.sidebar == .sprites) {
                    file.makeSpriteSelection(tile_index);
                } else if (pixi.state.tools.current != .animation) {
                    // Ensure we only set the request state on the first set.
                    if (file.flipbook_scroll_request) |*request| {
                        request.elapsed = 0.0;
                        request.from = file.flipbook_scroll;
                        request.to = file.flipbookScrollFromSpriteIndex(tile_index);
                    } else {
                        file.flipbook_scroll_request = .{ .from = file.flipbook_scroll, .to = file.flipbookScrollFromSpriteIndex(tile_index), .state = file.selected_animation_state };
                    }
                }
            }
        } else {
            if (pixi.state.controls.mouse.primary.released()) {
                if (pixi.state.sidebar == .sprites) {
                    file.selected_sprites.clearAndFree();
                }
            }
        }
    }

    // Draw all layers in reverse order
    {
        var i: usize = file.layers.items.len;
        while (i > 0) {
            i -= 1;
            if (!file.layers.items[i].visible) continue;
            file.camera.drawLayer(file.layers.items[i], canvas_center_offset);
        }
    }

    // Draw the temporary layer
    file.camera.drawLayer(file.temporary_layer, canvas_center_offset);

    // Draw grid
    file.camera.drawGrid(canvas_center_offset, file_width, file_height, @floatToInt(usize, file_width / tile_width), @floatToInt(usize, file_height / tile_height), pixi.state.style.text_secondary.toU32());

    // Draw box around selected sprite or origin selection if on sprites tab, as well as animation start and end
    {
        const tiles_wide = @divExact(file.width, file.tile_width);

        if (pixi.state.sidebar == .sprites) {
            if (file.selected_sprites.items.len > 0) {
                for (file.selected_sprites.items) |sprite_index| {
                    const column = @mod(@intCast(u32, sprite_index), tiles_wide);
                    const row = @divTrunc(@intCast(u32, sprite_index), tiles_wide);
                    const x = @intToFloat(f32, column) * tile_width + canvas_center_offset[0];
                    const y = @intToFloat(f32, row) * tile_height + canvas_center_offset[1];
                    const rect: [4]f32 = .{ x, y, tile_width, tile_height };

                    file.camera.drawRect(rect, 3.0, pixi.state.style.text.toU32());

                    // Draw the origin
                    const sprite: pixi.storage.Internal.Sprite = file.sprites.items[sprite_index];
                    file.camera.drawLine(
                        .{ x + sprite.origin_x, y },
                        .{ x + sprite.origin_x, y + tile_height },
                        pixi.state.style.text_red.toU32(),
                        2.0,
                    );
                    file.camera.drawLine(
                        .{ x, y + sprite.origin_y },
                        .{ x + tile_width, y + sprite.origin_y },
                        pixi.state.style.text_red.toU32(),
                        2.0,
                    );
                }
            }
        } else {
            const column = @mod(@intCast(u32, file.selected_sprite_index), tiles_wide);
            const row = @divTrunc(@intCast(u32, file.selected_sprite_index), tiles_wide);
            const x = @intToFloat(f32, column) * tile_width + canvas_center_offset[0];
            const y = @intToFloat(f32, row) * tile_height + canvas_center_offset[1];
            const rect: [4]f32 = .{ x, y, tile_width, tile_height };

            file.camera.drawRect(rect, 3.0, pixi.state.style.text.toU32());
        }

        if (pixi.state.popups.animation_length > 0 and pixi.state.tools.current == .animation) {
            if (pixi.state.controls.mouse.primary.down() or pixi.state.popups.animation) {
                const start_column = @mod(@intCast(u32, pixi.state.popups.animation_start), tiles_wide);
                const start_row = @divTrunc(@intCast(u32, pixi.state.popups.animation_start), tiles_wide);
                const start_x = @intToFloat(f32, start_column) * tile_width + canvas_center_offset[0];
                const start_y = @intToFloat(f32, start_row) * tile_height + canvas_center_offset[1];
                const start_rect: [4]f32 = .{ start_x, start_y, tile_width, tile_height };

                const end_column = @mod(@intCast(u32, pixi.state.popups.animation_start + pixi.state.popups.animation_length - 1), tiles_wide);
                const end_row = @divTrunc(@intCast(u32, pixi.state.popups.animation_start + pixi.state.popups.animation_length - 1), tiles_wide);
                const end_x = @intToFloat(f32, end_column) * tile_width + canvas_center_offset[0];
                const end_y = @intToFloat(f32, end_row) * tile_height + canvas_center_offset[1];
                const end_rect: [4]f32 = .{ end_x, end_y, tile_width, tile_height };

                file.camera.drawAnimationRect(start_rect, end_rect, 6.0, pixi.state.style.highlight_primary.toU32(), pixi.state.style.text_red.toU32());
            }
        }

        if (file.animations.items.len > 0) {
            if (pixi.state.tools.current == .animation) {
                for (file.animations.items, 0..) |animation, i| {
                    const start_column = @mod(@intCast(u32, animation.start), tiles_wide);
                    const start_row = @divTrunc(@intCast(u32, animation.start), tiles_wide);
                    const start_x = @intToFloat(f32, start_column) * tile_width + canvas_center_offset[0];
                    const start_y = @intToFloat(f32, start_row) * tile_height + canvas_center_offset[1];
                    const start_rect: [4]f32 = .{ start_x, start_y, tile_width, tile_height };

                    const end_column = @mod(@intCast(u32, animation.start + animation.length - 1), tiles_wide);
                    const end_row = @divTrunc(@intCast(u32, animation.start + animation.length - 1), tiles_wide);
                    const end_x = @intToFloat(f32, end_column) * tile_width + canvas_center_offset[0];
                    const end_y = @intToFloat(f32, end_row) * tile_height + canvas_center_offset[1];
                    const end_rect: [4]f32 = .{ end_x, end_y, tile_width, tile_height };

                    const thickness: f32 = if (i == file.selected_animation_index and (!pixi.state.controls.mouse.primary.down() and !pixi.state.popups.animation)) 4.0 else 2.0;
                    file.camera.drawAnimationRect(start_rect, end_rect, thickness, pixi.state.style.highlight_primary.toU32(), pixi.state.style.text_red.toU32());
                }
            } else {
                const animation = file.animations.items[file.selected_animation_index];

                const start_column = @mod(@intCast(u32, animation.start), tiles_wide);
                const start_row = @divTrunc(@intCast(u32, animation.start), tiles_wide);
                const start_x = @intToFloat(f32, start_column) * tile_width + canvas_center_offset[0];
                const start_y = @intToFloat(f32, start_row) * tile_height + canvas_center_offset[1];
                const start_rect: [4]f32 = .{ start_x, start_y, tile_width, tile_height };

                const end_column = @mod(@intCast(u32, animation.start + animation.length - 1), tiles_wide);
                const end_row = @divTrunc(@intCast(u32, animation.start + animation.length - 1), tiles_wide);
                const end_x = @intToFloat(f32, end_column) * tile_width + canvas_center_offset[0];
                const end_y = @intToFloat(f32, end_row) * tile_height + canvas_center_offset[1];
                const end_rect: [4]f32 = .{ end_x, end_y, tile_width, tile_height };

                file.camera.drawAnimationRect(start_rect, end_rect, 4.0, pixi.state.style.highlight_primary.toU32(), pixi.state.style.text_red.toU32());
            }
        }
    }
}
