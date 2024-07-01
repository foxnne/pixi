const std = @import("std");
const pixi = @import("../../pixi.zig");
const core = @import("mach").core;
const imgui = @import("zig-imgui");
const zmath = @import("zmath");

pub fn draw(file: *pixi.storage.Internal.Pixi) void {
    const transforming = file.transform_texture != null;

    {
        const shadow_color = pixi.math.Color.initFloats(0.0, 0.0, 0.0, pixi.state.settings.shadow_opacity).toU32();
        // Draw a shadow fading from bottom to top
        const pos = imgui.getWindowPos();
        const height = imgui.getWindowHeight();
        const width = imgui.getWindowWidth();

        if (imgui.getWindowDrawList()) |draw_list| {
            draw_list.addRectFilledMultiColor(
                .{ .x = pos.x, .y = (pos.y + height) - pixi.state.settings.shadow_length * pixi.content_scale[1] },
                .{ .x = pos.x + width, .y = pos.y + height },
                0x0,
                0x0,
                shadow_color,
                shadow_color,
            );
        }
    }

    const window_width = imgui.getWindowWidth();
    const window_height = imgui.getWindowHeight();
    const file_width = @as(f32, @floatFromInt(file.width));
    const file_height = @as(f32, @floatFromInt(file.height));
    const tile_width = @as(f32, @floatFromInt(file.tile_width));
    const tile_height = @as(f32, @floatFromInt(file.tile_height));

    const canvas_center_offset = file.canvasCenterOffset(.primary);

    // Draw transform window at top
    {
        if (file.transform_texture) |*transform_texture| {
            var flags: imgui.WindowFlags = 0;
            flags |= imgui.WindowFlags_NoDecoration;
            flags |= imgui.WindowFlags_AlwaysAutoResize;
            flags |= imgui.WindowFlags_NoMove;
            flags |= imgui.WindowFlags_NoNavInputs;
            flags |= imgui.WindowFlags_NoResize;

            var pos = imgui.getWindowPos();
            pos.x += 5.0;
            pos.y += 5.0;

            imgui.setNextWindowPos(pos, imgui.Cond_Always);
            imgui.setNextWindowSize(.{ .x = 0.0, .y = 54.0 }, imgui.Cond_Always);

            imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 5.0, .y = 5.0 });
            imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 5.0, .y = 5.0 });
            imgui.pushStyleVar(imgui.StyleVar_WindowRounding, 8.0);
            defer imgui.popStyleVarEx(3);

            imgui.pushStyleColorImVec4(imgui.Col_WindowBg, pixi.state.theme.foreground.toImguiVec4());
            imgui.pushStyleColorImVec4(imgui.Col_Button, pixi.state.theme.background.toImguiVec4());
            defer imgui.popStyleColorEx(2);

            var open: bool = true;
            if (imgui.begin(file.path, &open, flags)) {
                defer imgui.end();

                imgui.text("Transformation");
                imgui.separator();
                if (imgui.button("Confirm") or (core.keyPressed(core.Key.enter) and pixi.state.open_file_index == pixi.editor.getFileIndex(file.path).?)) {
                    transform_texture.confirm = true;
                }
                imgui.sameLine();
                if (imgui.button("Cancel") or (core.keyPressed(core.Key.escape) and pixi.state.open_file_index == pixi.editor.getFileIndex(file.path).?)) {
                    var change = file.buffers.stroke.toChange(@intCast(file.selected_layer_index)) catch unreachable;
                    change.pixels.temporary = true;
                    file.history.append(change) catch unreachable;
                    file.undo() catch unreachable;

                    file.transform_texture.?.texture.deinit();
                    file.transform_texture = null;
                }
            }
        }
    }

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
    //if (file.transform_texture == null)
    file.temporary_layer.clear(true);

    if (imgui.isWindowHovered(imgui.HoveredFlags_None)) {
        const mouse_position = pixi.state.mouse.position;

        if (file.camera.pixelCoordinates(.{
            .texture_position = canvas_center_offset,
            .position = mouse_position,
            .width = file.width,
            .height = file.height,
        })) |pixel_coord| {
            const pixel = .{ @as(usize, @intFromFloat(pixel_coord[0])), @as(usize, @intFromFloat(pixel_coord[1])) };

            const tile_column = @divTrunc(pixel[0], @as(usize, @intCast(file.tile_width)));
            const tile_row = @divTrunc(pixel[1], @as(usize, @intCast(file.tile_height)));

            const x = @as(f32, @floatFromInt(tile_column)) * tile_width + canvas_center_offset[0];
            const y = @as(f32, @floatFromInt(tile_row)) * tile_height + canvas_center_offset[1];

            if (pixi.state.sidebar != .pack)
                file.camera.drawTexture(file.background.view_handle, file.tile_width, file.tile_height, .{ x, y }, 0x88FFFFFF);

            file.processStrokeTool(.primary, .{}) catch unreachable;
            file.processFillTool(.primary, .{}) catch unreachable;
            file.processAnimationTool() catch unreachable;
            file.processSampleTool(.primary, .{});

            if (pixi.state.mouse.button(.primary)) |primary| {
                if (primary.pressed()) {
                    const tiles_wide = @divExact(@as(usize, @intCast(file.width)), @as(usize, @intCast(file.tile_width)));
                    const tile_index = tile_column + tile_row * tiles_wide;

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
            }
        } else {
            if (pixi.state.mouse.button(.primary)) |primary| {
                if (primary.released()) {
                    if (pixi.state.sidebar == .sprites) {
                        file.selected_sprites.clearAndFree();
                    }
                }
            }
        }
    }

    // Draw transform texture on gpu to temporary texture
    {
        if (file.transform_texture) |*transform_texture| {
            if (file.transform_bindgroup) |transform_bindgroup| {
                if (file.transform_compute_bindgroup) |compute_bindgroup| {
                    if (file.transform_compute_buffer) |compute_buffer| {
                        if (file.transform_staging_buffer) |staging_buffer| {
                            const width: f32 = @floatFromInt(file.width);
                            const height: f32 = @floatFromInt(file.height);

                            const buffer_size: usize = @as(usize, @intCast(file.width * file.height * @sizeOf([4]f32)));

                            const uniforms = pixi.gfx.UniformBufferObject{ .mvp = zmath.transpose(
                                zmath.orthographicLh(width, height, -100, 100),
                            ) };

                            pixi.state.batcher.begin(.{
                                .pipeline_handle = pixi.state.pipeline_default,
                                .compute_pipeline_handle = pixi.state.pipeline_compute,
                                .bind_group_handle = transform_bindgroup,
                                .compute_bind_group_handle = compute_bindgroup,
                                .output_texture = &file.temporary_layer.texture,
                                .compute_buffer = compute_buffer,
                                .staging_buffer = staging_buffer,
                                .buffer_size = buffer_size,
                                .clear_color = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 },
                            }) catch unreachable;

                            var pivot = if (transform_texture.pivot) |pivot| pivot.position else zmath.f32x4s(0.0);
                            if (transform_texture.pivot == null) {
                                for (&transform_texture.vertices) |*vertex| {
                                    pivot += vertex.position; // Collect centroid
                                }
                                pivot /= zmath.f32x4s(4.0); // Average position
                            }
                            //pivot += zmath.loadArr2(.{ canvas_center_offset[0], canvas_center_offset[1] });

                            pixi.state.batcher.transformTexture(
                                transform_texture.vertices,
                                .{ canvas_center_offset[0], -canvas_center_offset[1] },
                                .{ pivot[0], -pivot[1] },
                                .{
                                    .rotation = -transform_texture.rotation,
                                },
                            ) catch unreachable;

                            pixi.state.batcher.end(uniforms, pixi.state.uniform_buffer_default) catch unreachable;
                        }
                    }
                }
            }
        }
    }

    // Draw all layers in reverse order
    {
        var i: usize = file.layers.items.len;
        while (i > 0) {
            i -= 1;

            if (file.layers.items[i].visible)
                file.camera.drawLayer(file.layers.items[i], canvas_center_offset);
        }

        // Draw the temporary layer
        file.camera.drawLayer(file.temporary_layer, canvas_center_offset);

        // Draw grid
        file.camera.drawGrid(canvas_center_offset, file_width, file_height, @as(usize, @intFromFloat(file_width / tile_width)), @as(usize, @intFromFloat(file_height / tile_height)), pixi.state.theme.text_secondary.toU32());

        if (file.transform_texture) |*transform_texture|
            file.processTransformTextureControls(transform_texture, .primary);

        if (file.heightmap.visible) {
            file.camera.drawRectFilled(.{ canvas_center_offset[0], canvas_center_offset[1], file_width, file_height }, 0x60FFFFFF);
            if (file.heightmap.layer) |layer| {
                file.camera.drawLayer(layer, canvas_center_offset);
            }
        }
    }

    // Draw height in pixels if currently editing heightmap and zoom is sufficient
    {
        if (file.heightmap.visible) {
            if (file.camera.zoom >= 30.0) {
                if (file.camera.pixelCoordinates(.{
                    .texture_position = canvas_center_offset,
                    .position = pixi.state.mouse.position,
                    .width = file.width,
                    .height = file.height,
                })) |pixel_coord| {
                    const temp_x = @as(usize, @intFromFloat(pixel_coord[0]));
                    const temp_y = @as(usize, @intFromFloat(pixel_coord[1]));
                    const position = .{ pixel_coord[0] + canvas_center_offset[0] + 0.2, pixel_coord[1] + canvas_center_offset[1] + 0.25 };
                    file.camera.drawText("{d}", .{pixi.state.colors.height}, position, 0xFFFFFFFF);

                    const min: [2]u32 = .{
                        @intCast(@max(@as(i32, @intCast(temp_x)) - 5, 0)),
                        @intCast(@max(@as(i32, @intCast(temp_y)) - 5, 0)),
                    };

                    const max: [2]u32 = .{
                        @intCast(@min(temp_x + 5, file.width)),
                        @intCast(@min(temp_y + 5, file.height)),
                    };

                    var x: u32 = min[0];
                    while (x < max[0]) : (x += 1) {
                        var y: u32 = min[1];
                        while (y < max[1]) : (y += 1) {
                            const pixel = .{ @as(usize, @intCast(x)), @as(usize, @intCast(y)) };
                            const pixel_color = file.heightmap.layer.?.getPixel(pixel);
                            if (pixel_color[3] != 0 and (pixel[0] != temp_x or pixel[1] != temp_y)) {
                                const pixel_position = .{ canvas_center_offset[0] + @as(f32, @floatFromInt(x)) + 0.2, canvas_center_offset[1] + @as(f32, @floatFromInt(y)) + 0.25 };
                                file.camera.drawText("{d}", .{pixel_color[0]}, pixel_position, 0xFFFFFFFF);
                            }
                        }
                    }
                }
            }
        }
    }

    // Draw box around selected sprite or origin selection if on sprites tab, as well as animation start and end
    {
        const tiles_wide = @divExact(file.width, file.tile_width);

        if (pixi.state.sidebar == .sprites and !transforming) {
            if (file.selected_sprites.items.len > 0) {
                for (file.selected_sprites.items) |sprite_index| {
                    const column = @mod(@as(u32, @intCast(sprite_index)), tiles_wide);
                    const row = @divTrunc(@as(u32, @intCast(sprite_index)), tiles_wide);
                    const x = @as(f32, @floatFromInt(column)) * tile_width + canvas_center_offset[0];
                    const y = @as(f32, @floatFromInt(row)) * tile_height + canvas_center_offset[1];
                    const rect: [4]f32 = .{ x, y, tile_width, tile_height };

                    file.camera.drawRect(rect, 3.0, pixi.state.theme.text.toU32());

                    // Draw the origin
                    const sprite: pixi.storage.Internal.Sprite = file.sprites.items[sprite_index];
                    file.camera.drawLine(
                        .{ x + sprite.origin_x, y },
                        .{ x + sprite.origin_x, y + tile_height },
                        pixi.state.theme.text_red.toU32(),
                        2.0,
                    );
                    file.camera.drawLine(
                        .{ x, y + sprite.origin_y },
                        .{ x + tile_width, y + sprite.origin_y },
                        pixi.state.theme.text_red.toU32(),
                        2.0,
                    );
                }
            }
        } else if (pixi.state.sidebar != .pack and !transforming) {
            const column = @mod(@as(u32, @intCast(file.selected_sprite_index)), tiles_wide);
            const row = @divTrunc(@as(u32, @intCast(file.selected_sprite_index)), tiles_wide);
            const x = @as(f32, @floatFromInt(column)) * tile_width + canvas_center_offset[0];
            const y = @as(f32, @floatFromInt(row)) * tile_height + canvas_center_offset[1];
            const rect: [4]f32 = .{ x, y, tile_width, tile_height };

            file.camera.drawRect(rect, 3.0, pixi.state.theme.text.toU32());
        }

        if (pixi.state.popups.animation_length > 0 and pixi.state.tools.current == .animation and !transforming) {
            if (pixi.state.mouse.button(.primary)) |primary| {
                if (primary.down() or pixi.state.popups.animation) {
                    const start_column = @mod(@as(u32, @intCast(pixi.state.popups.animation_start)), tiles_wide);
                    const start_row = @divTrunc(@as(u32, @intCast(pixi.state.popups.animation_start)), tiles_wide);
                    const start_x = @as(f32, @floatFromInt(start_column)) * tile_width + canvas_center_offset[0];
                    const start_y = @as(f32, @floatFromInt(start_row)) * tile_height + canvas_center_offset[1];
                    const start_rect: [4]f32 = .{ start_x, start_y, tile_width, tile_height };

                    const end_column = @mod(@as(u32, @intCast(pixi.state.popups.animation_start + pixi.state.popups.animation_length - 1)), tiles_wide);
                    const end_row = @divTrunc(@as(u32, @intCast(pixi.state.popups.animation_start + pixi.state.popups.animation_length - 1)), tiles_wide);
                    const end_x = @as(f32, @floatFromInt(end_column)) * tile_width + canvas_center_offset[0];
                    const end_y = @as(f32, @floatFromInt(end_row)) * tile_height + canvas_center_offset[1];
                    const end_rect: [4]f32 = .{ end_x, end_y, tile_width, tile_height };

                    file.camera.drawAnimationRect(start_rect, end_rect, 6.0, pixi.state.theme.highlight_primary.toU32(), pixi.state.theme.text_red.toU32());
                }
            }
        }

        if (file.animations.items.len > 0) {
            if (pixi.state.tools.current == .animation and !transforming) {
                for (file.animations.items, 0..) |animation, i| {
                    const start_column = @mod(@as(u32, @intCast(animation.start)), tiles_wide);
                    const start_row = @divTrunc(@as(u32, @intCast(animation.start)), tiles_wide);
                    const start_x = @as(f32, @floatFromInt(start_column)) * tile_width + canvas_center_offset[0];
                    const start_y = @as(f32, @floatFromInt(start_row)) * tile_height + canvas_center_offset[1];
                    const start_rect: [4]f32 = .{ start_x, start_y, tile_width, tile_height };

                    const end_column = @mod(@as(u32, @intCast(animation.start + animation.length - 1)), tiles_wide);
                    const end_row = @divTrunc(@as(u32, @intCast(animation.start + animation.length - 1)), tiles_wide);
                    const end_x = @as(f32, @floatFromInt(end_column)) * tile_width + canvas_center_offset[0];
                    const end_y = @as(f32, @floatFromInt(end_row)) * tile_height + canvas_center_offset[1];
                    const end_rect: [4]f32 = .{ end_x, end_y, tile_width, tile_height };

                    const thickness: f32 = if (i == file.selected_animation_index and (if (pixi.state.mouse.button(.primary)) |primary| primary.up() else false and !pixi.state.popups.animation)) 4.0 else 2.0;
                    file.camera.drawAnimationRect(start_rect, end_rect, thickness, pixi.state.theme.highlight_primary.toU32(), pixi.state.theme.text_red.toU32());
                }
            } else if (pixi.state.sidebar != .pack and !transforming) {
                const animation = file.animations.items[file.selected_animation_index];

                const start_column = @mod(@as(u32, @intCast(animation.start)), tiles_wide);
                const start_row = @divTrunc(@as(u32, @intCast(animation.start)), tiles_wide);
                const start_x = @as(f32, @floatFromInt(start_column)) * tile_width + canvas_center_offset[0];
                const start_y = @as(f32, @floatFromInt(start_row)) * tile_height + canvas_center_offset[1];
                const start_rect: [4]f32 = .{ start_x, start_y, tile_width, tile_height };

                const end_column = @mod(@as(u32, @intCast(animation.start + animation.length - 1)), tiles_wide);
                const end_row = @divTrunc(@as(u32, @intCast(animation.start + animation.length - 1)), tiles_wide);
                const end_x = @as(f32, @floatFromInt(end_column)) * tile_width + canvas_center_offset[0];
                const end_y = @as(f32, @floatFromInt(end_row)) * tile_height + canvas_center_offset[1];
                const end_rect: [4]f32 = .{ end_x, end_y, tile_width, tile_height };

                file.camera.drawAnimationRect(start_rect, end_rect, 4.0, pixi.state.theme.highlight_primary.toU32(), pixi.state.theme.text_red.toU32());
            }
        }
    }
}
