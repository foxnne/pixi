const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("pixi");

pub fn draw(file: *pixi.storage.Internal.Pixi) void {
    const window_height = zgui.getWindowHeight();
    const tile_width = @intToFloat(f32, file.tile_width);
    const tile_height = @intToFloat(f32, file.tile_height);

    const example_sprite_index: u32 = 0;

    const tiles_wide = @divExact(file.width, file.tile_width);

    const column = @intToFloat(f32, @mod(example_sprite_index, tiles_wide));
    const row = @intToFloat(f32, @divTrunc(example_sprite_index, tiles_wide));

    const src_x = column * tile_width;
    const src_y = row * tile_height;

    const sprite_rect: [4]f32 = .{ src_x, src_y, tile_width, tile_height };

    const sprite_position: [2]f32 = .{
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
        file.flipbook_camera.position[0] = std.math.clamp(file.flipbook_camera.position[0], -(sprite_position[0] + tile_width), sprite_position[0] + tile_width);
        file.flipbook_camera.position[1] = std.math.clamp(file.flipbook_camera.position[1], -(sprite_position[1] + tile_height), sprite_position[1] + tile_height);

        file.flipbook_camera.processTooltip(file.flipbook_camera.zoom);
    }

    // TODO: Make background texture opacity available through settings.
    // Draw background
    file.flipbook_camera.drawTexture(file.background_texture_view_handle, file.tile_width, file.tile_height, sprite_position, 0x88FFFFFF);

    // Draw all layers in reverse order
    var i: usize = file.layers.items.len;
    while (i > 0) {
        i -= 1;
        file.flipbook_camera.drawSprite(file.layers.items[i], sprite_rect, sprite_position, pixi.state.style.text_secondary.toU32());
    }
}
