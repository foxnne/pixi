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
    if (file.transform_texture == null)
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
                if (file.compute_bindgroup) |compute_bindgroup| {
                    if (file.compute_buffer) |compute_buffer| {
                        if (file.staging_buffer) |staging_buffer| {
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

                            var centroid = zmath.f32x4(0.0, 0.0, 0.0, 0.0);
                            for (transform_texture.vertices) |v| {
                                centroid += v.position;
                            }
                            centroid = centroid / zmath.f32x4s(4.0);
                            centroid += zmath.loadArr2(.{ canvas_center_offset[0], canvas_center_offset[1] });

                            pixi.state.batcher.transformTexture(
                                transform_texture.vertices,
                                .{ canvas_center_offset[0], -canvas_center_offset[1] },
                                .{ centroid[0], -centroid[1] },
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

        drawTransformTextureControls(file);

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

pub const TransformControls = struct {
    corners: [4][2]f32,
};

pub fn drawTransformTextureControls(file: *pixi.storage.Internal.Pixi) void {
    if (file.transform_texture) |*transform_texture| {
        const modifier_primary: bool = if (pixi.state.hotkeys.hotkey(.{ .proc = .primary })) |hk| hk.down() else false;
        const modifier_secondary: bool = if (pixi.state.hotkeys.hotkey(.{ .proc = .secondary })) |hk| hk.down() else false;

        var cursor: imgui.MouseCursor = imgui.MouseCursor_Arrow;

        const default_color = pixi.state.theme.text.toU32();
        const highlight_color = pixi.state.theme.highlight_primary.toU32();

        const offset = zmath.loadArr2(file.canvasCenterOffset(.primary));

        if (pixi.state.mouse.button(.primary)) |bt| {
            if (bt.released()) {
                transform_texture.control = null;
                transform_texture.pan = false;
                transform_texture.rotate = false;
            }
        }

        const grip_size: f32 = 10.0 / file.camera.zoom;
        const half_grip_size = grip_size / 2.0;

        var hovered_index: ?usize = null;
        var centroid = zmath.f32x4s(0.0);

        const radians = std.math.degreesToRadians(transform_texture.rotation);
        const rotation_matrix = zmath.rotationZ(radians);

        for (&transform_texture.vertices) |*vertex| {
            centroid += vertex.position; // Collect centroid
        }
        centroid /= zmath.f32x4s(4.0); // Average position

        var rotated_vertices: [4]pixi.storage.Internal.Pixi.TransformVertex = .{
            .{ .position = zmath.mul(transform_texture.vertices[0].position - centroid, rotation_matrix) + centroid },
            .{ .position = zmath.mul(transform_texture.vertices[1].position - centroid, rotation_matrix) + centroid },
            .{ .position = zmath.mul(transform_texture.vertices[2].position - centroid, rotation_matrix) + centroid },
            .{ .position = zmath.mul(transform_texture.vertices[3].position - centroid, rotation_matrix) + centroid },
        };

        // Draw bounding lines from vertices
        for (&rotated_vertices, 0..) |*vertex, vertex_index| {
            const previous_position = switch (vertex_index) {
                0 => rotated_vertices[3].position,
                1, 2, 3 => rotated_vertices[vertex_index - 1].position,
                else => unreachable,
            };

            file.camera.drawLine(.{ offset[0] + previous_position[0], offset[1] + previous_position[1] }, .{ offset[0] + vertex.position[0], offset[1] + vertex.position[1] }, default_color, 3.0);
        }

        { // Draw controls for rotating
            const rotation_control_height = transform_texture.rotation_grip_height;
            var control_offset = zmath.loadArr2(.{ 0.0, rotation_control_height });
            control_offset = zmath.mul(control_offset, rotation_matrix);

            const midpoint = (rotated_vertices[0].position + rotated_vertices[1].position) / zmath.f32x4s(2.0);
            const control_center = midpoint - control_offset;

            file.camera.drawLine(.{ midpoint[0] + offset[0], midpoint[1] + offset[1] }, .{ control_center[0] + offset[0], control_center[1] + offset[1] }, default_color, 1.0);

            var hovered: bool = false;
            var control_color: u32 = default_color;
            if (file.camera.isHovered(.{ control_center[0] + offset[0] - half_grip_size, control_center[1] + offset[1] - half_grip_size, grip_size, grip_size })) {
                hovered = true;
                cursor = imgui.MouseCursor_Hand;
                if (pixi.state.mouse.button(.primary)) |bt| {
                    if (bt.pressed()) {
                        transform_texture.rotate = true;
                    }
                }
            }

            if (transform_texture.rotate or hovered) {
                control_color = highlight_color;

                const dist = @sqrt(std.math.pow(f32, control_center[0] - centroid[0], 2) + std.math.pow(f32, control_center[1] - centroid[1], 2));
                file.camera.drawCircle(.{ centroid[0] + offset[0], centroid[1] + offset[1] }, dist * file.camera.zoom, 1.0, default_color);
            }

            file.camera.drawCircleFilled(.{ control_center[0] + offset[0], control_center[1] + offset[1] }, half_grip_size * file.camera.zoom, control_color);
        }

        // Draw controls for moving vertices
        for (&rotated_vertices, 0..) |*vertex, vertex_index| {
            const grip_rect: [4]f32 = .{ offset[0] + vertex.position[0] - half_grip_size, offset[1] + vertex.position[1] - half_grip_size, grip_size, grip_size };

            if (file.camera.isHovered(grip_rect)) {
                hovered_index = vertex_index;
                if (pixi.state.mouse.button(.primary)) |bt| {
                    if (bt.pressed()) {
                        transform_texture.control = .{
                            .index = vertex_index,
                            .mode = if (modifier_primary) .free else if (modifier_secondary) .locked_aspect else .free_aspect,
                        };
                    }
                }
            }

            const grip_color = if (hovered_index == vertex_index or if (transform_texture.control) |control| control.index == vertex_index else false) highlight_color else default_color;
            file.camera.drawRectFilled(grip_rect, grip_color);
        }

        { // Handle hovering over transform texture
            const triangle_a: [3]zmath.F32x4 = .{
                rotated_vertices[0].position + offset,
                rotated_vertices[1].position + offset,
                rotated_vertices[2].position + offset,
            };
            const triangle_b: [3]zmath.F32x4 = .{
                rotated_vertices[2].position + offset,
                rotated_vertices[3].position + offset,
                rotated_vertices[0].position + offset,
            };

            const hovered: bool = hovered_index == null and transform_texture.control == null and (file.camera.isHoveredTriangle(triangle_a) or file.camera.isHoveredTriangle(triangle_b));
            const mouse_pressed = if (pixi.state.mouse.button(.primary)) |bt| bt.pressed() else false;

            if (hovered) {
                cursor = imgui.MouseCursor_Hand;
            }

            if (hovered and mouse_pressed) {
                transform_texture.pan = true;
            }
            const centroid_color = if (hovered or transform_texture.pan) highlight_color else default_color;
            file.camera.drawCircleFilled(.{ centroid[0] + offset[0], centroid[1] + offset[1] }, half_grip_size * file.camera.zoom, centroid_color);
        }

        { // Handle setting the mouse cursor based on controls

            if (transform_texture.control) |c| {
                switch (c.index) {
                    0, 2 => cursor = imgui.MouseCursor_ResizeNWSE,
                    1, 3 => cursor = imgui.MouseCursor_ResizeNESW,
                    else => unreachable,
                }
            }

            if (hovered_index) |i| {
                switch (i) {
                    0, 2 => cursor = imgui.MouseCursor_ResizeNWSE,
                    1, 3 => cursor = imgui.MouseCursor_ResizeNESW,
                    else => unreachable,
                }
            }

            if (transform_texture.pan or transform_texture.rotate)
                cursor = imgui.MouseCursor_ResizeAll;

            imgui.setMouseCursor(cursor);
        }

        { // Handle moving the vertices when panning
            if (transform_texture.pan) {
                if (imgui.isWindowHovered(imgui.HoveredFlags_ChildWindows)) {
                    const mouse_position = pixi.state.mouse.position;
                    const prev_mouse_position = pixi.state.mouse.previous_position;
                    const current_pixel_coords = file.camera.pixelCoordinatesRaw(.{
                        .texture_position = .{ offset[0], offset[1] },
                        .position = mouse_position,
                        .width = file.width,
                        .height = file.height,
                    });

                    const previous_pixel_coords = file.camera.pixelCoordinatesRaw(.{
                        .texture_position = .{ offset[0], offset[1] },
                        .position = prev_mouse_position,
                        .width = file.width,
                        .height = file.height,
                    });

                    const delta: [2]f32 = .{
                        current_pixel_coords[0] - previous_pixel_coords[0],
                        current_pixel_coords[1] - previous_pixel_coords[1],
                    };

                    for (&transform_texture.vertices) |*v| {
                        v.position[0] += delta[0];
                        v.position[1] += delta[1];
                    }
                }
            }
        }

        { // Handle changing the rotation when rotating
            if (transform_texture.rotate) {
                if (imgui.isWindowHovered(imgui.HoveredFlags_ChildWindows)) {
                    const mouse_position = pixi.state.mouse.position;
                    const current_pixel_coords = file.camera.pixelCoordinatesRaw(.{
                        .texture_position = .{ offset[0], offset[1] },
                        .position = mouse_position,
                        .width = file.width,
                        .height = file.height,
                    });

                    const diff = zmath.loadArr2(current_pixel_coords) - centroid;
                    const angle = std.math.atan2(diff[1], diff[0]);

                    transform_texture.rotation = @trunc(std.math.radiansToDegrees(angle) + 90.0);
                }
            }
        }

        blk_vert: { // Handle moving the vertices when moving a single control
            if (transform_texture.control) |control| {
                if (imgui.isWindowHovered(imgui.HoveredFlags_ChildWindows)) {
                    const mouse_position = pixi.state.mouse.position;
                    const current_pixel_coords = file.camera.pixelCoordinatesRaw(.{
                        .texture_position = .{ offset[0], offset[1] },
                        .position = mouse_position,
                        .width = file.width,
                        .height = file.height,
                    });

                    switch (control.mode) {
                        .locked_aspect, .free_aspect => { // TODO: implement locked aspect

                            // First, move the selected vertex to the mouse position
                            const control_vert = &rotated_vertices[control.index];
                            const position = @trunc(zmath.loadArr2(current_pixel_coords));
                            control_vert.position = position;

                            // Find adjacent verts
                            const adjacent_index_cw = if (control.index < 3) control.index + 1 else 0;
                            const adjacent_index_ccw = if (control.index > 0) control.index - 1 else 3;

                            const opposite_index: usize = switch (control.index) {
                                0 => 2,
                                1 => 3,
                                2 => 0,
                                3 => 1,
                                else => unreachable,
                            };

                            const adjacent_vert_cw = &rotated_vertices[adjacent_index_cw];
                            const adjacent_vert_ccw = &rotated_vertices[adjacent_index_ccw];
                            const opposite_vert = &rotated_vertices[opposite_index];

                            // Get rotation directions to apply to adjacent vertex
                            const rotation_direction = zmath.mul(zmath.loadArr2(.{ 0.0, 1.0 }), rotation_matrix);
                            const rotation_perp = zmath.mul(zmath.loadArr2(.{ 1.0, 0.0 }), rotation_matrix);

                            { // Calculate intersection point to set adjacent vert
                                const as = control_vert.position;
                                const bs = opposite_vert.position;
                                const ad = -rotation_direction;
                                const bd = rotation_perp;
                                const dx = bs[0] - as[0];
                                const dy = bs[1] - as[1];
                                const det = bd[0] * ad[1] - bd[1] * ad[0];
                                if (det == 0.0) break :blk_vert;
                                const u = (dy * bd[0] - dx * bd[1]) / det;
                                switch (control.index) {
                                    1, 3 => adjacent_vert_cw.position = as + ad * zmath.f32x4s(u),
                                    0, 2 => adjacent_vert_ccw.position = as + ad * zmath.f32x4s(u),
                                    else => unreachable,
                                }
                            }

                            { // Calculate intersection point to set adjacent vert
                                const as = control_vert.position;
                                const bs = opposite_vert.position;
                                const ad = -rotation_perp;
                                const bd = rotation_direction;
                                const dx = bs[0] - as[0];
                                const dy = bs[1] - as[1];
                                const det = bd[0] * ad[1] - bd[1] * ad[0];
                                if (det == 0.0) break :blk_vert;
                                const u = (dy * bd[0] - dx * bd[1]) / det;
                                switch (control.index) {
                                    1, 3 => adjacent_vert_ccw.position = as + ad * zmath.f32x4s(u),
                                    0, 2 => adjacent_vert_cw.position = as + ad * zmath.f32x4s(u),
                                    else => unreachable,
                                }
                            }

                            // Recalculate the centroid with new vertex positions
                            var rotated_centroid = zmath.f32x4s(0.0);
                            for (rotated_vertices) |vert| {
                                rotated_centroid += vert.position;
                            }
                            rotated_centroid /= zmath.f32x4s(4.0);

                            // Reverse the rotation, then finalize the changes
                            for (&rotated_vertices, 0..) |*vert, i| {
                                vert.position -= rotated_centroid;
                                vert.position = zmath.mul(vert.position, zmath.inverse(rotation_matrix));
                                vert.position += rotated_centroid;

                                transform_texture.vertices[i].position = vert.position;
                            }
                        },
                        .free => {
                            const control_vert = &rotated_vertices[control.index];

                            const position = @trunc(zmath.loadArr2(current_pixel_coords));
                            control_vert.position = position;

                            var rotated_centroid = zmath.f32x4s(0.0);
                            for (rotated_vertices) |vert| {
                                rotated_centroid += vert.position;
                            }
                            rotated_centroid /= zmath.f32x4s(4.0);

                            for (&rotated_vertices, 0..) |*vert, i| {
                                vert.position -= rotated_centroid;
                                vert.position = zmath.mul(vert.position, zmath.inverse(rotation_matrix));
                                vert.position += rotated_centroid;

                                transform_texture.vertices[i].position = vert.position;
                            }
                        },
                    }
                }
            }
        }
    }
}
