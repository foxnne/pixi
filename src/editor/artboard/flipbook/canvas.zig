const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("root");

pub fn draw(file: *pixi.storage.Internal.Pixi) void {
    const window_height = zgui.getWindowHeight();
    const tile_width = @intToFloat(f32, file.tile_width);
    const tile_height = @intToFloat(f32, file.tile_height);

    const center: [2]f32 = .{
        -tile_width / 2.0,
        -tile_height / 2.0,
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
        if (file.selected_animation_state != .play) {
            if (file.flipbook_camera.position[0] < min_position[0]) scroll_delta = file.flipbook_camera.position[0] - min_position[0];
            if (file.flipbook_camera.position[0] > max_position[0]) scroll_delta = file.flipbook_camera.position[0] - max_position[0];
        }
        file.flipbook_scroll = std.math.clamp(file.flipbook_scroll - scroll_delta, -@intToFloat(f32, file.sprites.items.len - 1) * tile_width * 1.1, 0.0);

        file.flipbook_camera.position[0] = std.math.clamp(file.flipbook_camera.position[0], min_position[0], max_position[0]);
        file.flipbook_camera.position[1] = std.math.clamp(file.flipbook_camera.position[1], min_position[1], max_position[1]);

        file.flipbook_camera.processTooltip(file.flipbook_camera.zoom);
    }

    if (file.selected_animation_state == .play) {
        const animation: pixi.storage.Internal.Animation = file.animations.items[file.selected_animation_index];
        file.selected_animation_elapsed += pixi.state.gctx.stats.delta_time;
        if (file.selected_animation_elapsed > 1.0 / @intToFloat(f32, animation.fps)) {
            file.selected_animation_elapsed = 0.0;

            if (file.selected_sprite_index + 1 >= animation.start + animation.length or file.selected_sprite_index < animation.start) {
                file.selected_sprite_index = animation.start;
            } else {
                file.selected_sprite_index += 1;
            }
        }

        file.flipbook_scroll = -@intToFloat(f32, file.selected_sprite_index) * tile_width * 1.1;
    }

    const tiles_wide = @divExact(file.width, file.tile_width);

    for (file.sprites.items, 0..) |_, i| {
        const column = @intToFloat(f32, @mod(@intCast(u32, i), tiles_wide));
        const row = @intToFloat(f32, @divTrunc(@intCast(u32, i), tiles_wide));

        const src_x = column * tile_width;
        const src_y = row * tile_height;

        const sprite_scale = std.math.clamp(0.5 / @fabs(@intToFloat(f32, i) + (file.flipbook_scroll / tile_width / 1.1)), 0.5, 1.0);
        const src_rect: [4]f32 = .{ src_x, src_y, tile_width, tile_height };
        var dst_x: f32 = center[0] + file.flipbook_scroll + @intToFloat(f32, i) * tile_width * 1.1 - (tile_width * sprite_scale / 2.0);
        var dst_y: f32 = center[1] + ((1.0 - sprite_scale) * (tile_height / 2.0));
        var dst_width: f32 = tile_width * sprite_scale;
        var dst_height: f32 = tile_height * sprite_scale;

        if (file.selected_animation_state == .play) {
            dst_x = @round(dst_x);
            dst_y = @round(dst_y);
            dst_width = @round(dst_width);
            dst_height = @round(dst_height);
        }
        const dst_rect: [4]f32 = .{ dst_x, dst_y, dst_width, dst_height };

        if (sprite_scale >= 1.0) {
            // TODO: Make background texture opacity available through settings.
            // Draw background
            file.flipbook_camera.drawTexture(file.background_texture_view_handle, file.tile_width, file.tile_height, .{ dst_rect[0], dst_rect[1] }, 0x88FFFFFF);
            file.selected_sprite_index = i;
            if (!file.setAnimationFromSpriteIndex()) {
                file.selected_animation_state = .pause;
            }
        }

        if (dst_rect[0] > -zgui.getWindowWidth() / 2 and dst_rect[0] + dst_rect[2] < zgui.getWindowWidth()) {
            // Draw all layers in reverse order
            var j: usize = file.layers.items.len;
            while (j > 0) {
                j -= 1;
                file.flipbook_camera.drawSprite(file.layers.items[j], src_rect, dst_rect, pixi.state.style.text_secondary.toU32());
            }
        }
    }
}
