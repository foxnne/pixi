const std = @import("std");

const pixi = @import("../../../pixi.zig");

const Core = @import("mach").Core;
const App = pixi.App;
const Editor = pixi.Editor;

const imgui = @import("zig-imgui");

pub fn draw(file: *pixi.Internal.File, app: *App, editor: *Editor) !void {
    const window_height = imgui.getWindowHeight();
    const tile_width = @as(f32, @floatFromInt(file.tile_width));
    const tile_height = @as(f32, @floatFromInt(file.tile_height));

    const canvas_center_offset = file.canvasCenterOffset(.flipbook);

    // Progress flipbook scroll request
    if (file.flipbook_scroll_request) |*request| {
        if (request.elapsed < editor.settings.editor_animation_time) {
            file.selected_animation_state = .pause;
            request.elapsed += app.delta_time;
            file.flipbook_scroll = pixi.math.ease(request.from, request.to, request.elapsed / editor.settings.editor_animation_time, .ease_in_out);
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

        if (editor.settings.flipbook_view == .sequential) sprite_camera.setNearestZoomFloor() else sprite_camera.setNearZoomFloor();
        file.flipbook_camera.min_zoom = sprite_camera.zoom;

        file.flipbook_camera.processPanZoom(.flipbook);
    }

    // Handle playing animations and locking the current extents
    if (file.selected_animation_state == .play and file.animations.slice().len > 0) {
        const animation: pixi.Internal.Animation = file.animations.slice().get(file.selected_animation_index);
        file.selected_animation_elapsed += app.delta_time;
        if (file.selected_animation_elapsed > 1.0 / @as(f32, @floatFromInt(animation.fps))) {
            file.selected_animation_elapsed = 0.0;

            if (file.selected_sprite_index + 1 >= animation.start + animation.length or file.selected_sprite_index < animation.start) {
                file.selected_sprite_index = animation.start;
            } else {
                file.selected_sprite_index += 1;
            }
        }

        file.flipbook_scroll = file.flipbookScrollFromSpriteIndex(file.selected_sprite_index);
    }

    switch (editor.settings.flipbook_view) {
        .sequential => {
            // Draw all sprites sequentially
            const tiles_wide = @divExact(file.width, file.tile_width);
            var sprite_index: usize = 0;
            while (sprite_index < file.sprites.slice().len) : (sprite_index += 1) {
                const column = @as(f32, @floatFromInt(@mod(@as(u32, @intCast(sprite_index)), tiles_wide)));
                const row = @as(f32, @floatFromInt(@divTrunc(@as(u32, @intCast(sprite_index)), tiles_wide)));

                const src_x = column * tile_width;
                const src_y = row * tile_height;
                const src_rect: [4]f32 = .{ src_x, src_y, tile_width, tile_height };

                const sprite_scale = std.math.clamp(0.4 / @abs(@as(f32, @floatFromInt(sprite_index)) / 1.2 + (file.flipbook_scroll / tile_width / 1.2)), 0.4, 1.0);
                var dst_x: f32 = canvas_center_offset[0] + file.flipbook_scroll + (@as(f32, @floatFromInt(sprite_index)) / 1.2 * tile_width * 1.2) - (tile_width * sprite_scale / 1.2) - (1.0 - sprite_scale) * (tile_width * 0.5);
                var dst_y: f32 = canvas_center_offset[1];
                var dst_width: f32 = tile_width * sprite_scale;
                var dst_height: f32 = tile_height;

                if (file.selected_animation_state == .play) {
                    dst_x = @round(dst_x);
                    dst_y = @round(dst_y);
                    dst_width = @round(dst_width);
                    dst_height = @round(dst_height);
                }
                const offset_y = (1.0 - sprite_scale) * (dst_height / 5.0);
                const offset_x = (1.0 - sprite_scale) * (dst_width * 0.5);
                const flip = if (dst_x + dst_width > 0) false else true;
                const dst_rect: [4]f32 = .{ dst_x + offset_x, dst_y + offset_y, dst_width, dst_height };
                const dst_p1: [2]f32 = if (flip) .{ dst_x + offset_x, dst_y } else .{ dst_x + offset_x, dst_y + offset_y };
                const dst_p2: [2]f32 = if (flip) .{ dst_x + dst_width + offset_x, dst_y + offset_y } else .{ dst_x + dst_width + offset_x, dst_y };
                const dst_p3: [2]f32 = if (flip) .{ dst_x + dst_width + offset_x, dst_y + dst_height - offset_y } else .{ dst_x + dst_width + offset_x, dst_y + dst_height };
                const dst_p4: [2]f32 = if (flip) .{ dst_x + offset_x, dst_y + dst_height } else .{ dst_x + offset_x, dst_y + dst_height - offset_y };

                if (sprite_scale >= 1.0) {
                    // TODO: Make background texture opacity available through settings.
                    file.flipbook_camera.drawQuadFilled(
                        dst_p1,
                        dst_p2,
                        dst_p3,
                        dst_p4,
                        pixi.editor.theme.background.toU32(),
                    );
                    // Draw background
                    file.flipbook_camera.drawTexture(&file.background, dst_rect, 0x88FFFFFF);
                    file.selected_sprite_index = sprite_index;
                    if (!file.setAnimationFromSpriteIndex()) {
                        file.selected_animation_state = .pause;
                    }
                }

                if (dst_rect[0] > -imgui.getWindowWidth() / 2 and dst_rect[0] + dst_rect[2] < imgui.getWindowWidth()) {
                    // Draw all layers in reverse order
                    var layer_index: usize = file.layers.slice().len;
                    while (layer_index > 0) {
                        layer_index -= 1;
                        if (!file.layers.items(.visible)[layer_index]) continue;

                        var layer = file.layers.slice().get(layer_index);

                        file.flipbook_camera.drawSpriteQuad(
                            &layer,
                            src_rect,
                            dst_p1,
                            dst_p2,
                            dst_p3,
                            dst_p4,
                        );
                    }

                    if (file.heightmap.visible) {
                        //file.flipbook_camera.drawRectFilled(dst_rect, 0x50FFFFFF);
                        //file.flipbook_camera.drawSprite(file.heightmap.layer.?, src_rect, dst_rect);
                    }

                    if (sprite_index == file.selected_sprite_index)
                        file.flipbook_camera.drawSprite(&file.temporary_layer, src_rect, dst_rect);

                    if (file.flipbook_camera.isHovered(dst_rect) and !imgui.isAnyItemHovered()) {
                        if (sprite_index != file.selected_sprite_index) {
                            file.flipbook_camera.drawQuad(dst_p1, dst_p2, dst_p3, dst_p4, pixi.editor.theme.text.toU32(), 2.0);
                            if (if (editor.mouse.button(.primary)) |primary| primary.pressed() else false and file.selected_sprite_index != sprite_index) {
                                file.flipbook_scroll_request = .{ .from = file.flipbook_scroll, .to = file.flipbookScrollFromSpriteIndex(sprite_index), .state = file.selected_animation_state };
                            }
                        } else {
                            file.flipbook_camera.drawRect(dst_rect, 1, pixi.editor.theme.text.toU32());

                            try file.processStrokeTool(.flipbook, .{});
                            try file.processFillTool(.flipbook, .{});
                            try file.processSampleTool(.flipbook, .{});
                        }
                    } else {
                        if (sprite_index != file.selected_sprite_index) {
                            file.flipbook_camera.drawQuad(
                                dst_p1,
                                dst_p2,
                                dst_p3,
                                dst_p4,
                                pixi.editor.theme.text_secondary.toU32(),
                                1.0,
                            );
                        } else {
                            file.flipbook_camera.drawQuad(
                                dst_p1,
                                dst_p2,
                                dst_p3,
                                dst_p4,
                                pixi.editor.theme.text.toU32(),
                                1.0,
                            );
                        }
                    }
                }
            }
        },
        .grid => {
            // Draw current sprite in 3x3 grid
            const tiles_wide = @divExact(file.width, file.tile_width);
            var sprite_index: usize = 0;
            while (sprite_index < file.sprites.slice().len) : (sprite_index += 1) {
                const column = @as(f32, @floatFromInt(@mod(@as(u32, @intCast(sprite_index)), tiles_wide)));
                const row = @as(f32, @floatFromInt(@divTrunc(@as(u32, @intCast(sprite_index)), tiles_wide)));

                const src_x = column * tile_width;
                const src_y = row * tile_height;
                const src_rect: [4]f32 = .{ src_x, src_y, tile_width, tile_height };

                const sprite_scale = std.math.clamp(0.4 / @abs(@as(f32, @floatFromInt(sprite_index)) / 1.2 + (file.flipbook_scroll / tile_width / 1.2)), 0.4, 1.0);

                if (sprite_scale >= 1.0) {
                    var dst_col: i32 = -1;

                    var dst_x: f32 = canvas_center_offset[0] + file.flipbook_scroll + (@as(f32, @floatFromInt(sprite_index)) / 1.2 * tile_width * 1.2) - (tile_width * sprite_scale / 1.2) - (1.0 - sprite_scale) * (tile_width * 0.5);
                    var dst_y: f32 = canvas_center_offset[1];
                    var dst_width: f32 = tile_width;
                    var dst_height: f32 = tile_height;

                    while (dst_col < 2) : (dst_col += 1) {
                        var dst_row: i32 = -1;

                        while (dst_row < 2) : (dst_row += 1) {
                            const offset_x: f32 = @as(f32, @floatFromInt(dst_col)) * dst_width;
                            const offset_y: f32 = @as(f32, @floatFromInt(dst_row)) * dst_height;

                            if (file.selected_animation_state == .play) {
                                dst_x = @round(dst_x);
                                dst_y = @round(dst_y);
                                dst_width = @round(dst_width);
                                dst_height = @round(dst_height);
                            }
                            const dst_rect: [4]f32 = .{ dst_x + offset_x, dst_y + offset_y, dst_width, dst_height };

                            // Draw background
                            file.flipbook_camera.drawTexture(&file.background, dst_rect, 0x88FFFFFF);
                            file.selected_sprite_index = sprite_index;
                            if (!file.setAnimationFromSpriteIndex()) {
                                file.selected_animation_state = .pause;
                            }

                            // Draw all layers in reverse order
                            var layer_index: usize = file.layers.slice().len;
                            while (layer_index > 0) {
                                layer_index -= 1;
                                if (!file.layers.items(.visible)[layer_index]) continue;

                                var layer = file.layers.slice().get(layer_index);

                                file.flipbook_camera.drawSprite(&layer, src_rect, dst_rect);
                            }

                            if (sprite_index == file.selected_sprite_index)
                                file.flipbook_camera.drawSprite(&file.temporary_layer, src_rect, dst_rect);

                            if (file.flipbook_camera.isHovered(dst_rect) and !imgui.isAnyItemHovered()) {
                                file.flipbook_camera.drawRect(dst_rect, 1, pixi.editor.theme.text.toU32());

                                try file.processStrokeTool(.flipbook, .{ .texture_position_offset = .{ offset_x, offset_y } });
                                try file.processFillTool(.flipbook, .{ .texture_position_offset = .{ offset_x, offset_y } });
                                try file.processSampleTool(.flipbook, .{ .texture_position_offset = .{ offset_x, offset_y } });
                            }
                        }
                    }

                    file.flipbook_camera.drawRect(.{ dst_x - tile_width, dst_y - tile_height, dst_width * 3.0, dst_height * 3.0 }, 1.0, pixi.editor.theme.text_background.toU32());
                }
            }
        },
    }

    if (imgui.isWindowHovered(imgui.HoveredFlags_None)) {
        if (editor.mouse.button(.primary)) |primary| {
            if (primary.released()) {
                if (file.buffers.stroke.values.items.len > 0) {
                    const change = try file.buffers.stroke.toChange(if (file.heightmap.visible) -1 else @intCast(file.selected_layer_index));
                    try file.history.append(change);
                }
            }
        }
    }

    if (file.selected_animation_state == .play) {
        const animation: pixi.Internal.Animation = file.animations.slice().get(file.selected_animation_index);
        // Draw progress bar
        {
            const window_position = imgui.getWindowPos();
            const window_width = imgui.getWindowWidth();

            const progress_start: imgui.Vec2 = .{ .x = window_position.x, .y = window_position.y + 2 };
            const animation_length = @as(f32, @floatFromInt(animation.length)) / @as(f32, @floatFromInt(animation.fps));
            const current_frame = if (file.selected_sprite_index > animation.start) file.selected_sprite_index - animation.start else 0;
            const progress_end: imgui.Vec2 = .{ .x = window_position.x + window_width * ((@as(f32, @floatFromInt(current_frame)) / @as(f32, @floatFromInt(animation.length))) + (file.selected_animation_elapsed / animation_length)), .y = window_position.y + 2 };

            const draw_list_opt = imgui.getWindowDrawList();

            if (draw_list_opt) |draw_list| {
                draw_list.addLineEx(
                    progress_start,
                    progress_end,
                    pixi.editor.theme.text_background.toU32(),
                    3.0,
                );
            }
        }
    }
}
