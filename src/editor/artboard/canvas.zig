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

    const layer_position: [2]f32 = .{
        -file_width / 2,
        -file_height / 2,
    };

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
        file.camera.position[0] = std.math.clamp(file.camera.position[0], -(layer_position[0] + file_width), layer_position[0] + file_width);
        file.camera.position[1] = std.math.clamp(file.camera.position[1], -(layer_position[1] + file_height), layer_position[1] + file_height);

        file.camera.processTooltip(file.camera.zoom);
    }

    if (zgui.isWindowHovered(.{})) {
        var mouse_position = pixi.state.controls.mouse.position.toSlice();

        if (file.camera.pixelCoordinates(layer_position, file.width, file.height, mouse_position)) |pixel_coord| {
            var tile_column = @divTrunc(@floatToInt(usize, pixel_coord[0]), @intCast(usize, file.tile_width));
            var tile_row = @divTrunc(@floatToInt(usize, pixel_coord[1]), @intCast(usize, file.tile_height));

            const x = @intToFloat(f32, tile_column) * tile_width + layer_position[0];
            const y = @intToFloat(f32, tile_row) * tile_height + layer_position[1];

            file.camera.drawTexture(file.background_texture_view_handle, file.tile_width, file.tile_height, .{ x, y }, 0x88FFFFFF);

            if (pixi.state.controls.mouse.primary.down()) {
                var tiles_wide = @divExact(@intCast(usize, file.width), @intCast(usize, file.tile_width));
                var tile_index = tile_column + tile_row * tiles_wide;
                // Ensure we only set the request state on the first set.
                if (file.flipbook_scroll_request) |*request| {
                    request.elapsed = 0.0;
                    request.from = file.flipbook_scroll;
                    request.to = -@intToFloat(f32, tile_index) * tile_width * 1.1;
                } else {
                    file.flipbook_scroll_request = .{ .from = file.flipbook_scroll, .to = file.flipbookScrollFromSpriteIndex(tile_index), .state = file.selected_animation_state };
                }
            }
        }
    }

    if (file.flipbook_scroll_request) |*request| {
        if (request.elapsed < 1.0) {
            file.selected_animation_state = .pause;
            request.elapsed += pixi.state.gctx.stats.delta_time * 2.0;
            file.flipbook_scroll = pixi.math.ease(request.from, request.to, request.elapsed, .ease_out);
        } else {
            file.flipbook_scroll = request.to;
            file.selected_animation_state = request.state;
            file.flipbook_scroll_request = null;
        }
    }

    // Draw all layers in reverse order
    var i: usize = file.layers.items.len;
    while (i > 0) {
        i -= 1;
        file.camera.drawLayer(file.layers.items[i], layer_position);
    }

    // Draw grid
    file.camera.drawGrid(layer_position, file_width, file_height, @floatToInt(usize, file_width / tile_width), @floatToInt(usize, file_height / tile_height), pixi.state.style.text_secondary.toU32());

    // Draw selection
    {
        const tiles_wide = @divExact(file.width, file.tile_width);
        const column = @mod(@intCast(u32, file.selected_sprite_index), tiles_wide);
        const row = @divTrunc(@intCast(u32, file.selected_sprite_index), tiles_wide);
        const x = @intToFloat(f32, column) * tile_width + layer_position[0];
        const y = @intToFloat(f32, row) * tile_height + layer_position[1];
        const rect: [4]f32 = .{ x, y, tile_width, tile_height };

        file.camera.drawRect(rect, 3.0, pixi.state.style.text.toU32());
    }
}
