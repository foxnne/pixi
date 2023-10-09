const std = @import("std");
const pixi = @import("../../../pixi.zig");
const core = @import("mach-core");
const zgui = @import("zgui").MachImgui(core);

pub fn draw(file: *pixi.storage.Internal.Pixi) void {
    const window_height = zgui.getWindowHeight();
    const tile_width = @as(f32, @floatFromInt(file.tile_width));
    const tile_height = @as(f32, @floatFromInt(file.tile_height));

    const canvas_center_offset = file.canvasCenterOffset(.flipbook);

    // Progress flipbook scroll request
    if (file.flipbook_scroll_request) |*request| {
        if (request.elapsed < 1.0) {
            file.selected_animation_state = .pause;
            request.elapsed += pixi.state.delta_time * 2.0;
            file.flipbook_scroll = pixi.math.ease(request.from, request.to, request.elapsed, .ease_out);
        } else {
            file.flipbook_scroll = request.to;
            file.selected_animation_state = request.state;
            file.flipbook_scroll_request = null;
        }
    }

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
        const min_position: [2]f32 = .{ -(canvas_center_offset[0] + tile_width) - tile_width / 2.0, -(canvas_center_offset[1] + tile_height) };
        const max_position: [2]f32 = .{ canvas_center_offset[0] + tile_width - tile_width / 2.0, canvas_center_offset[1] + tile_height };

        var scroll_delta: f32 = 0.0;
        if (file.selected_animation_state != .play) {
            if (file.flipbook_camera.position[0] < min_position[0]) scroll_delta = file.flipbook_camera.position[0] - min_position[0];
            if (file.flipbook_camera.position[0] > max_position[0]) scroll_delta = file.flipbook_camera.position[0] - max_position[0];
        }
        file.flipbook_scroll = std.math.clamp(file.flipbook_scroll - scroll_delta, file.flipbookScrollFromSpriteIndex(file.sprites.items.len - 1), 0.0);

        file.flipbook_camera.position[0] = std.math.clamp(file.flipbook_camera.position[0], min_position[0], max_position[0]);
        file.flipbook_camera.position[1] = std.math.clamp(file.flipbook_camera.position[1], min_position[1], max_position[1]);
    }

    // Handle playing animations and locking the current extents
    if (file.selected_animation_state == .play and file.animations.items.len > 0) {
        const animation: pixi.storage.Internal.Animation = file.animations.items[file.selected_animation_index];
        file.selected_animation_elapsed += pixi.state.delta_time;
        if (file.selected_animation_elapsed > 1.0 / @as(f32, @floatFromInt(animation.fps))) {
            file.selected_animation_elapsed = 0.0;

            if (file.selected_sprite_index + 1 >= animation.start + animation.length or file.selected_sprite_index < animation.start) {
                file.selected_sprite_index = animation.start;
            } else {
                file.selected_sprite_index += 1;
            }
        }

        file.flipbook_scroll = file.flipbookScrollFromSpriteIndex(file.selected_sprite_index);

        // Draw progress bar
        {
            const window_position = zgui.getWindowPos();
            const window_width = zgui.getWindowWidth();

            const progress_start: [2]f32 = .{ window_position[0], window_position[1] + 2 };
            const animation_length = @as(f32, @floatFromInt(animation.length)) / @as(f32, @floatFromInt(animation.fps));
            const current_frame = if (file.selected_sprite_index > animation.start) file.selected_sprite_index - animation.start else 0;
            const progress_end: [2]f32 = .{ window_position[0] + window_width * ((@as(f32, @floatFromInt(current_frame)) / @as(f32, @floatFromInt(animation.length))) + (file.selected_animation_elapsed / animation_length)), window_position[1] + 2 };

            const draw_list = zgui.getWindowDrawList();
            draw_list.addLine(.{
                .p1 = progress_start,
                .p2 = progress_end,
                .col = pixi.state.theme.highlight_primary.toU32(),
                .thickness = 3.0,
            });
        }
    }

    // Draw all sprites sequentially
    const tiles_wide = @divExact(file.width, file.tile_width);
    for (file.sprites.items, 0..) |_, i| {
        const column = @as(f32, @floatFromInt(@mod(@as(u32, @intCast(i)), tiles_wide)));
        const row = @as(f32, @floatFromInt(@divTrunc(@as(u32, @intCast(i)), tiles_wide)));

        const src_x = column * tile_width;
        const src_y = row * tile_height;

        const sprite_scale = std.math.clamp(0.5 / @abs(@as(f32, @floatFromInt(i)) + (file.flipbook_scroll / tile_width / 1.1)), 0.5, 1.0);
        const src_rect: [4]f32 = .{ src_x, src_y, tile_width, tile_height };
        var dst_x: f32 = canvas_center_offset[0] + file.flipbook_scroll + @as(f32, @floatFromInt(i)) * tile_width * 1.1 - (tile_width * sprite_scale / 2.0);
        var dst_y: f32 = canvas_center_offset[1] + ((1.0 - sprite_scale) * (tile_height / 2.0));
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
            file.flipbook_camera.drawTexture(file.background.view_handle, file.tile_width, file.tile_height, .{ dst_rect[0], dst_rect[1] }, 0x88FFFFFF);
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
                if (!file.layers.items[j].visible) continue;
                file.flipbook_camera.drawSprite(file.layers.items[j], src_rect, dst_rect);
            }

            if (pixi.state.tools.current == .heightmap) {
                file.flipbook_camera.drawRectFilled(dst_rect, 0x50FFFFFF);
                file.flipbook_camera.drawSprite(file.heightmap_layer.?, src_rect, dst_rect);
            }

            if (i == file.selected_sprite_index)
                file.flipbook_camera.drawSprite(file.temporary_layer, src_rect, dst_rect);

            if (file.flipbook_camera.isHovered(dst_rect) and !zgui.isAnyItemHovered()) {
                if (i != file.selected_sprite_index) {
                    file.flipbook_camera.drawRect(dst_rect, 2, pixi.state.theme.text.toU32());
                    if (if (pixi.state.mouse.button(.primary)) |primary| primary.pressed() else false and file.selected_sprite_index != i) {
                        file.flipbook_scroll_request = .{ .from = file.flipbook_scroll, .to = file.flipbookScrollFromSpriteIndex(i), .state = file.selected_animation_state };
                    }
                } else {
                    file.flipbook_camera.drawRect(dst_rect, 1, pixi.state.theme.text.toU32());

                    file.processSampleTool(.flipbook);
                    file.processStrokeTool(.flipbook) catch unreachable;
                    file.processFillTool(.flipbook) catch unreachable;
                }
            } else {
                if (i != file.selected_sprite_index) {
                    file.flipbook_camera.drawRect(dst_rect, 1, pixi.state.theme.text_secondary.toU32());
                } else {
                    file.flipbook_camera.drawRect(dst_rect, 1, pixi.state.theme.text.toU32());
                }
            }
        }
    }

    if (file.selected_animation_state == .play) {
        const animation: pixi.storage.Internal.Animation = file.animations.items[file.selected_animation_index];
        // Draw progress bar
        {
            const window_position = zgui.getWindowPos();
            const window_width = zgui.getWindowWidth();

            const progress_start: [2]f32 = .{ window_position[0], window_position[1] + 2 };
            const animation_length = @as(f32, @floatFromInt(animation.length)) / @as(f32, @floatFromInt(animation.fps));
            const current_frame = if (file.selected_sprite_index > animation.start) file.selected_sprite_index - animation.start else 0;
            const progress_end: [2]f32 = .{ window_position[0] + window_width * ((@as(f32, @floatFromInt(current_frame)) / @as(f32, @floatFromInt(animation.length))) + (file.selected_animation_elapsed / animation_length)), window_position[1] + 2 };

            const draw_list = zgui.getWindowDrawList();
            draw_list.addLine(.{
                .p1 = progress_start,
                .p2 = progress_end,
                .col = pixi.state.theme.text_background.toU32(),
                .thickness = 3.0,
            });
        }
    }
}
