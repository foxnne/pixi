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
            .zoom = std.math.min(window_width / file_width, window_height / file_height),
        };
        sprite_camera.setNearestZoomFloor();
        if (!file.camera.zoom_initialized) {
            file.camera.zoom_initialized = true;
            file.camera.zoom = sprite_camera.zoom;
        }
        sprite_camera.setNearestZoomFloor();
        const min_zoom = std.math.min(sprite_camera.zoom, 1.0);

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

            switch (pixi.state.tools.current) {
                .pencil => file.temporary_layer.setPixel(pixel, file.tools.primary_color, true),
                .eraser => file.temporary_layer.setPixel(pixel, .{ 255, 255, 255, 255 }, true),
                else => {},
            }

            // Check inputs for sampling conditions and show tooltips
            file.processSample(.primary);
            // Check inputs for stroke condition and complete strokes if necessary
            file.processStroke(.primary);

            if (pixi.state.controls.mouse.primary.pressed()) {
                var tiles_wide = @divExact(@intCast(usize, file.width), @intCast(usize, file.tile_width));
                var tile_index = tile_column + tile_row * tiles_wide;

                if (pixi.state.sidebar == .sprites) {
                    file.makeSpriteSelection(tile_index);
                } else {
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

    // Submit the stroke change buffer
    if (file.buffers.stroke.indices.items.len > 0 and pixi.state.controls.mouse.primary.released()) {
        const change = file.buffers.stroke.toChange(file.selected_layer_index) catch unreachable;
        file.history.append(change) catch unreachable;
    }

    // Draw all layers in reverse order
    {
        var i: usize = file.layers.items.len;
        while (i > 0) {
            i -= 1;
            file.camera.drawLayer(file.layers.items[i], canvas_center_offset);
        }
    }

    // Draw the temporary layer
    file.camera.drawLayer(file.temporary_layer, canvas_center_offset);

    // Draw grid
    file.camera.drawGrid(canvas_center_offset, file_width, file_height, @floatToInt(usize, file_width / tile_width), @floatToInt(usize, file_height / tile_height), pixi.state.style.text_secondary.toU32());

    // Draw box around selected sprite or origin selection if on sprites tab
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
    }
}
