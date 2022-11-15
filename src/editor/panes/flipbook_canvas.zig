const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("pixi");

pub var selected_animation: usize = 0;
pub var is_playing: bool = true;
pub var current_index: usize = 0;
pub var elapsed_time: f32 = 0.0;

pub fn draw(file: *pixi.storage.Internal.Pixi) void {
    const window_height = zgui.getWindowHeight();
    const tile_width = @intToFloat(f32, file.tile_width);
    const tile_height = @intToFloat(f32, file.tile_height);

    const center: [2]f32 = .{
        -tile_width / 2,
        -tile_height / 2,
    };

    // Handle zooming, panning and extents
    {
        var sprite_camera: pixi.gfx.Camera = .{
            .zoom = window_height / tile_height,
        };
        const zoom_index = sprite_camera.nearestZoomIndex();
        const max_zoom_index = if (zoom_index < pixi.state.settings.zoom_steps.len - 1) zoom_index + 1 else zoom_index;
        const max_zoom = pixi.state.settings.zoom_steps[max_zoom_index];
        sprite_camera.setNearestZoomFloor();
        const min_zoom = sprite_camera.zoom;

        file.flipbook_camera.processPanZoom();

        // Lock camera from zooming in or out too far for the flipbook
        file.flipbook_camera.zoom = std.math.clamp(file.flipbook_camera.zoom, min_zoom, max_zoom);

        // Lock camera from moving too far away from canvas
        const min_position: [2]f32 = .{ -(center[0] + tile_width) - tile_width / 2.0, -(center[1] + tile_height) };
        const max_position: [2]f32 = .{ center[0] + tile_width - tile_width / 2.0, center[1] + tile_height };

        var scroll_delta: f32 = 0.0;
        if (!is_playing) {
            if (file.flipbook_camera.position[0] < min_position[0]) scroll_delta = file.flipbook_camera.position[0] - min_position[0];
            if (file.flipbook_camera.position[0] > max_position[0]) scroll_delta = file.flipbook_camera.position[0] - max_position[0];
        }
        file.flipbook_scroll = std.math.clamp(file.flipbook_scroll - scroll_delta, -@intToFloat(f32, file.sprites.items.len - 1) * tile_width * 1.1, 0.0);

        file.flipbook_camera.position[0] = std.math.clamp(file.flipbook_camera.position[0], min_position[0], max_position[0]);
        file.flipbook_camera.position[1] = std.math.clamp(file.flipbook_camera.position[1], min_position[1], max_position[1]);

        file.flipbook_camera.processTooltip(file.flipbook_camera.zoom);
    }

    if (is_playing) {
        const animation = file.animations.items[0];
        elapsed_time += pixi.state.gctx.stats.delta_time;
        if (elapsed_time > 1.0 / @intToFloat(f32, animation.fps)) {
            elapsed_time = 0.0;

            if (current_index + 1 >= animation.start + animation.length or current_index < animation.start) {
                current_index = animation.start;
            } else {
                current_index += 1;
            }
        }

        file.flipbook_scroll = -@intToFloat(f32, current_index) * tile_width * 1.1;
    }

    const tiles_wide = @divExact(file.width, file.tile_width);

    for (file.sprites.items) |_, i| {
        const column = @intToFloat(f32, @mod(@intCast(u32, i), tiles_wide));
        const row = @intToFloat(f32, @divTrunc(@intCast(u32, i), tiles_wide));

        const src_x = column * tile_width;
        const src_y = row * tile_height;

        const sprite_scale = std.math.clamp(0.5 / @fabs(@intToFloat(f32, i) + (file.flipbook_scroll / tile_width / 1.1)), 0.5, 1.0);
        const src_rect: [4]f32 = .{ src_x, src_y, tile_width, tile_height };
        const dst_rect: [4]f32 = .{ center[0] + file.flipbook_scroll + @intToFloat(f32, i) * tile_width * 1.1 - (tile_width * sprite_scale / 2.0), center[1] + ((1.0 - sprite_scale) * tile_height / 2.0), tile_width * sprite_scale, tile_height * sprite_scale };

        if (sprite_scale >= 1.0) {
            // TODO: Make background texture opacity available through settings.
            // Draw background
            file.flipbook_camera.drawTexture(file.background_texture_view_handle, file.tile_width, file.tile_height, .{ dst_rect[0], dst_rect[1] }, 0x88FFFFFF);
        }

        // Draw all layers in reverse order
        var j: usize = file.layers.items.len;
        while (j > 0) {
            j -= 1;
            file.flipbook_camera.drawSprite(file.layers.items[j], src_rect, dst_rect, pixi.state.style.text_secondary.toU32());
        }
    }
}
