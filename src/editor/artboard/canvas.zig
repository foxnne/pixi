const std = @import("std");
const pixi = @import("../../pixi.zig");

const App = pixi.App;
const Core = @import("mach").Core;
const Editor = pixi.Editor;
const imgui = @import("zig-imgui");
const zmath = @import("zmath");

pub fn draw(file: *pixi.Internal.File, core: *Core, app: *App, editor: *Editor) !void {
    const transforming = file.transform_texture != null;

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

            imgui.pushStyleColorImVec4(imgui.Col_WindowBg, pixi.editor.theme.foreground.toImguiVec4());
            imgui.pushStyleColorImVec4(imgui.Col_Button, pixi.editor.theme.background.toImguiVec4());
            defer imgui.popStyleColorEx(2);

            var open: bool = true;
            if (imgui.begin(file.path, &open, flags)) {
                defer imgui.end();

                imgui.text("Transformation");
                imgui.separator();
                if (imgui.button("Confirm") or (core.keyPressed(Core.Key.enter) and editor.open_file_index == editor.getFileIndex(file.path).?)) {
                    transform_texture.confirm = true;
                }
                imgui.sameLine();
                if (imgui.button("Cancel") or (core.keyPressed(Core.Key.escape) and editor.open_file_index == editor.getFileIndex(file.path).?)) {
                    var change = try file.buffers.stroke.toChange(@intCast(file.selected_layer_index));
                    change.pixels.temporary = true;
                    try file.history.append(change);
                    try file.undo();

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
        file.camera.min_zoom = @min(sprite_camera.zoom, 1.0);

        file.camera.processPanZoom(.primary);
    }

    // TODO: Only clear and update if we need to?
    //if (file.transform_texture == null)
    file.temporary_layer.clear(true);

    editor.selection_time += app.delta_time;
    if (editor.selection_time >= 0.3) {
        for (file.selection_layer.pixels()) |*pixel| {
            if (pixel[3] != 0) {
                if (pixel[0] != 0) pixel[0] = 0 else pixel[0] = 255;
                if (pixel[1] != 0) pixel[1] = 0 else pixel[1] = 255;
                if (pixel[2] != 0) pixel[2] = 0 else pixel[2] = 255;
            }
        }
        file.selection_layer.texture.update(core.windows.get(app.window, .device));
        editor.selection_time = 0.0;
        editor.selection_invert = !editor.selection_invert;
    }

    if (imgui.isWindowHovered(imgui.HoveredFlags_None)) {
        const mouse_position = app.mouse.position;

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

            if (editor.explorer.pane != .pack)
                file.camera.drawTexture(file.background.view_handle, file.tile_width, file.tile_height, .{ x, y }, 0x88FFFFFF);

            try file.processStrokeTool(.primary, .{});
            try file.processFillTool(.primary, .{});
            try file.processAnimationTool();
            try file.processSampleTool(.primary, .{});
            try file.processSelectionTool(.primary, .{});

            if (app.mouse.button(.primary)) |primary| {
                if (primary.pressed()) {
                    const tiles_wide = @divExact(@as(usize, @intCast(file.width)), @as(usize, @intCast(file.tile_width)));
                    const tile_index = tile_column + tile_row * tiles_wide;

                    if (editor.explorer.pane == .sprites or file.flipbook_view == .timeline) {
                        try file.makeSpriteSelection(tile_index);
                    } else if (editor.tools.current != .animation) {
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
            if (app.mouse.button(.primary)) |primary| {
                if (primary.released()) {
                    if (editor.explorer.pane == .sprites or file.flipbook_view == .timeline) {
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

                            try app.batcher.begin(.{
                                .pipeline_handle = app.pipeline_default,
                                .compute_pipeline_handle = app.pipeline_compute,
                                .bind_group_handle = transform_bindgroup,
                                .compute_bind_group_handle = compute_bindgroup,
                                .output_texture = &file.temporary_layer.texture,
                                .compute_buffer = compute_buffer,
                                .staging_buffer = staging_buffer,
                                .buffer_size = buffer_size,
                                .clear_color = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 },
                            });

                            var pivot = if (transform_texture.pivot) |pivot| pivot.position else zmath.f32x4s(0.0);
                            if (transform_texture.pivot == null) {
                                for (&transform_texture.vertices) |*vertex| {
                                    pivot += vertex.position; // Collect centroid
                                }
                                pivot /= zmath.f32x4s(4.0); // Average position
                            }
                            //pivot += zmath.loadArr2(.{ canvas_center_offset[0], canvas_center_offset[1] });

                            try app.batcher.transformTexture(
                                transform_texture.vertices,
                                .{ canvas_center_offset[0], -canvas_center_offset[1] },
                                .{ pivot[0], -pivot[1] },
                                .{
                                    .rotation = -transform_texture.rotation,
                                },
                            );

                            try app.batcher.end(uniforms, app.uniform_buffer_default);
                        }
                    }
                }
            }
        }
    }

    // Draw all layers in reverse order
    {
        var i: usize = file.layers.slice().len;
        while (i > 0) {
            i -= 1;

            if (file.layers.items(.visible)[i])
                file.camera.drawLayer(file.layers.slice().get(i), canvas_center_offset);
        }

        // Draw the temporary layer
        file.camera.drawLayer(file.temporary_layer, canvas_center_offset);

        // Draw grid
        file.camera.drawGrid(canvas_center_offset, file_width, file_height, @as(usize, @intFromFloat(file_width / tile_width)), @as(usize, @intFromFloat(file_height / tile_height)), pixi.editor.theme.text_secondary.toU32(), false);

        if (file.transform_texture) |*transform_texture|
            try file.processTransformTextureControls(transform_texture, .{});

        if (file.heightmap.visible) {
            file.camera.drawRectFilled(.{ canvas_center_offset[0], canvas_center_offset[1], file_width, file_height }, 0x60FFFFFF);
            if (file.heightmap.layer) |layer| {
                file.camera.drawLayer(layer, canvas_center_offset);
            }
        }
    }

    if (editor.tools.current == .selection) {
        file.camera.drawLayer(file.selection_layer, canvas_center_offset);
    }

    // Draw height in pixels if currently editing heightmap and zoom is sufficient
    {
        if (file.heightmap.visible) {
            if (file.camera.zoom >= 30.0) {
                if (file.camera.pixelCoordinates(.{
                    .texture_position = canvas_center_offset,
                    .position = app.mouse.position,
                    .width = file.width,
                    .height = file.height,
                })) |pixel_coord| {
                    const temp_x = @as(usize, @intFromFloat(pixel_coord[0]));
                    const temp_y = @as(usize, @intFromFloat(pixel_coord[1]));
                    const position = .{ pixel_coord[0] + canvas_center_offset[0] + 0.2, pixel_coord[1] + canvas_center_offset[1] + 0.25 };
                    try file.camera.drawText("{d}", .{editor.colors.height}, position, 0xFFFFFFFF);

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
                                try file.camera.drawText("{d}", .{pixel_color[0]}, pixel_position, 0xFFFFFFFF);
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

        if (editor.explorer.pane == .sprites and !transforming or file.flipbook_view == .timeline) {
            if (file.selected_sprites.items.len > 0) {
                for (file.selected_sprites.items) |sprite_index| {
                    const column = @mod(@as(u32, @intCast(sprite_index)), tiles_wide);
                    const row = @divTrunc(@as(u32, @intCast(sprite_index)), tiles_wide);
                    const x = @as(f32, @floatFromInt(column)) * tile_width + canvas_center_offset[0];
                    const y = @as(f32, @floatFromInt(row)) * tile_height + canvas_center_offset[1];
                    const rect: [4]f32 = .{ x, y, tile_width, tile_height };

                    file.camera.drawRect(rect, 3.0, editor.theme.text.toU32());

                    // Draw the origin
                    const sprite: pixi.Internal.Sprite = file.sprites.slice().get(sprite_index);
                    file.camera.drawLine(
                        .{ x + sprite.origin[0], y },
                        .{ x + sprite.origin[0], y + tile_height },
                        editor.theme.text_red.toU32(),
                        2.0,
                    );
                    file.camera.drawLine(
                        .{ x, y + sprite.origin[1] },
                        .{ x + tile_width, y + sprite.origin[1] },
                        editor.theme.text_red.toU32(),
                        2.0,
                    );
                }
            }
        } else if (editor.explorer.pane != .pack and !transforming) {
            const column = @mod(@as(u32, @intCast(file.selected_sprite_index)), tiles_wide);
            const row = @divTrunc(@as(u32, @intCast(file.selected_sprite_index)), tiles_wide);
            const x = @as(f32, @floatFromInt(column)) * tile_width + canvas_center_offset[0];
            const y = @as(f32, @floatFromInt(row)) * tile_height + canvas_center_offset[1];
            const rect: [4]f32 = .{ x, y, tile_width, tile_height };

            file.camera.drawRect(rect, 3.0, editor.theme.text.toU32());
        }

        if (editor.popups.animation_length > 0 and editor.tools.current == .animation and !transforming) {
            if (app.mouse.button(.primary)) |primary| {
                if (primary.down() or editor.popups.animation) {
                    const start_column = @mod(@as(u32, @intCast(editor.popups.animation_start)), tiles_wide);
                    const start_row = @divTrunc(@as(u32, @intCast(editor.popups.animation_start)), tiles_wide);
                    const start_x = @as(f32, @floatFromInt(start_column)) * tile_width + canvas_center_offset[0];
                    const start_y = @as(f32, @floatFromInt(start_row)) * tile_height + canvas_center_offset[1];
                    const start_rect: [4]f32 = .{ start_x, start_y, tile_width, tile_height };

                    const end_column = @mod(@as(u32, @intCast(editor.popups.animation_start + editor.popups.animation_length - 1)), tiles_wide);
                    const end_row = @divTrunc(@as(u32, @intCast(editor.popups.animation_start + editor.popups.animation_length - 1)), tiles_wide);
                    const end_x = @as(f32, @floatFromInt(end_column)) * tile_width + canvas_center_offset[0];
                    const end_y = @as(f32, @floatFromInt(end_row)) * tile_height + canvas_center_offset[1];
                    const end_rect: [4]f32 = .{ end_x, end_y, tile_width, tile_height };

                    file.camera.drawAnimationRect(start_rect, end_rect, 6.0, editor.theme.highlight_primary.toU32(), editor.theme.text_red.toU32());
                }
            }
        }

        if (file.animations.slice().len > 0) {
            if (editor.tools.current == .animation and !transforming) {
                var i: usize = 0;
                while (i < file.animations.slice().len) : (i += 1) {
                    const animation = &file.animations.slice().get(i);
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

                    const thickness: f32 = if (i == file.selected_animation_index and (if (app.mouse.button(.primary)) |primary| primary.up() else false and !app.popups.animation)) 4.0 else 2.0;
                    file.camera.drawAnimationRect(start_rect, end_rect, thickness, pixi.editor.theme.highlight_primary.toU32(), pixi.editor.theme.text_red.toU32());
                }
            } else if (editor.explorer.pane != .pack and !transforming and editor.explorer.pane != .keyframe_animations) {
                const animation = file.animations.slice().get(file.selected_animation_index);

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

                file.camera.drawAnimationRect(start_rect, end_rect, 4.0, pixi.editor.theme.highlight_primary.toU32(), pixi.editor.theme.text_red.toU32());
            }
        }
    }
}
