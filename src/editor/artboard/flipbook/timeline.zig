const std = @import("std");
const pixi = @import("../../../pixi.zig");
const mach = @import("mach");
const core = mach.core;
const imgui = @import("zig-imgui");
const zmath = @import("zmath");

pub fn draw(file: *pixi.storage.Internal.Pixi) void {
    const window_height = imgui.getWindowHeight();
    const window_width = imgui.getWindowWidth();
    const tile_width = @as(f32, @floatFromInt(file.tile_width));
    const tile_height = @as(f32, @floatFromInt(file.tile_height));
    const canvas_center_offset: [2]f32 = file.canvasCenterOffset(.flipbook);
    const window_position = imgui.getWindowPos();

    imgui.pushStyleColorImVec4(imgui.Col_ChildBg, pixi.state.theme.foreground.toImguiVec4());

    const timeline_height = imgui.getWindowHeight() * 0.25;

    const test_animation_length: f32 = 1.37;

    const length: f32 = test_animation_length;
    const animation_ms: usize = @intFromFloat(length * 1000.0);
    const zoom: f32 = 1.0;

    if (imgui.beginChild("FlipbookTimeline", .{ .x = -1.0, .y = timeline_height }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow | imgui.WindowFlags_HorizontalScrollbar)) {
        defer imgui.endChild();

        const scroll_x = imgui.getScrollX();

        if (imgui.beginChild("FlipbookTimelineScroll", .{ .x = animation_ms * zoom, .y = timeline_height }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
            defer imgui.endChild();

            if (imgui.getWindowDrawList()) |draw_list| {
                var rel_mouse_x: ?f32 = null;
                if (imgui.isWindowHovered(imgui.HoveredFlags_ChildWindows)) {
                    const mouse_position = pixi.state.mouse.position;
                    rel_mouse_x = mouse_position[0] - window_position.x + scroll_x;
                }
                for (0..animation_ms) |index_ms| {
                    var thickness: f32 = 1.0;

                    var width: f32 = @floatFromInt(index_ms);
                    const color = if (rel_mouse_x) |mouse_x| if (@abs(width - (mouse_x / zoom)) < 5.0) pixi.state.theme.highlight_primary.toU32() else pixi.state.theme.background.toU32() else pixi.state.theme.background.toU32();

                    width *= zoom;

                    if (@mod(index_ms, 100) == 0) thickness = 2.0;
                    if (@mod(index_ms, 1000) == 0) thickness = 4.0;

                    if (@mod(index_ms, 10) == 0) {
                        draw_list.addLineEx(.{ .x = window_position.x + width - scroll_x, .y = window_position.y }, .{ .x = window_position.x + width - scroll_x, .y = window_position.y + timeline_height - imgui.getTextLineHeight() }, color, thickness);
                    }

                    if (@mod(index_ms, 1000) == 0) {
                        const fmt = std.fmt.allocPrintZ(pixi.state.allocator, "{d} s", .{@divTrunc(index_ms, 1000)}) catch unreachable;
                        defer pixi.state.allocator.free(fmt);

                        draw_list.addText(.{ .x = window_position.x + width - scroll_x, .y = window_position.y + timeline_height - imgui.getTextLineHeight() }, pixi.state.theme.text.toU32(), fmt.ptr);
                    } else if (@mod(index_ms, 100) == 0) {
                        const fmt = std.fmt.allocPrintZ(pixi.state.allocator, "{d} ms", .{index_ms}) catch unreachable;
                        defer pixi.state.allocator.free(fmt);

                        draw_list.addText(.{ .x = window_position.x + width - scroll_x, .y = window_position.y + timeline_height - imgui.getTextLineHeight() }, pixi.state.theme.text.toU32(), fmt.ptr);
                    }
                }
            }
        }
    }

    imgui.popStyleColor();

    if (imgui.beginChild("FlipbookCanvas", .{ .x = window_width, .y = 0.0 }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
        defer imgui.endChild();

        // Progress flipbook scroll request
        if (file.flipbook_scroll_request) |*request| {
            if (request.elapsed < 0.5) {
                file.selected_animation_state = .pause;
                request.elapsed += pixi.state.delta_time;
                file.flipbook_scroll = pixi.math.ease(request.from, request.to, request.elapsed / 0.5, .ease_in_out);
            } else {
                file.flipbook_scroll = request.to;
                file.selected_animation_state = request.state;
                file.flipbook_scroll_request = null;
            }
        }

        for (file.sprites.items, 0..) |_, i| {
            const sprite_scale = std.math.clamp(0.4 / @abs(@as(f32, @floatFromInt(i)) / 1.2 + (file.flipbook_scroll / tile_width / 1.2)), 0.4, 1.0);

            if (sprite_scale >= 1.0) {
                file.selected_sprite_index = i;
                if (!file.setAnimationFromSpriteIndex()) {
                    file.selected_animation_state = .pause;
                }
            }
        }

        // Handle zooming, panning and extents
        {
            var sprite_camera: pixi.gfx.Camera = .{
                .zoom = window_height / tile_height,
            };
            const zoom_index = sprite_camera.nearestZoomIndex();
            const max_zoom_index = if (zoom_index < pixi.state.settings.zoom_steps.len - 2) zoom_index + 2 else zoom_index;
            const max_zoom = pixi.state.settings.zoom_steps[max_zoom_index];
            sprite_camera.setNearZoomFloor();
            const min_zoom = sprite_camera.zoom;

            file.flipbook_camera.processPanZoom();

            // Lock camera from zooming in or out too far for the flipbook
            file.flipbook_camera.zoom = std.math.clamp(file.flipbook_camera.zoom, min_zoom, max_zoom);

            const view_width: f32 = tile_width * 2.0;
            const view_height: f32 = tile_height * 2.0;

            // Lock camera from moving too far away from canvas
            const min_position: [2]f32 = .{ canvas_center_offset[0] - view_width / 2.0, canvas_center_offset[1] - view_height / 2.0 };
            const max_position: [2]f32 = .{ canvas_center_offset[0] + view_width, canvas_center_offset[1] + view_height };

            file.flipbook_camera.position[0] = std.math.clamp(file.flipbook_camera.position[0], min_position[0], max_position[0]);
            file.flipbook_camera.position[1] = std.math.clamp(file.flipbook_camera.position[1], min_position[1], max_position[1]);
        }

        // Draw tile outline for reference
        //file.flipbook_camera.drawRect(.{ canvas_center_offset[0], canvas_center_offset[1], tile_width, tile_height }, 1.0, pixi.state.theme.text_background.toU32());

        file.flipbook_camera.drawGrid(file.canvasCenterOffset(.primary), @floatFromInt(file.width), @floatFromInt(file.height), @intCast(@divTrunc(file.width, file.tile_width)), @intCast(@divTrunc(file.height, file.tile_height)), pixi.state.theme.text_background.toU32());

        const l: f32 = 2000;
        file.flipbook_camera.drawLine(.{ 0.0, l / 2.0 }, .{ 0.0, -l / 2.0 }, 0x5500FF00, 1.0);
        file.flipbook_camera.drawLine(.{ -l / 2.0, 0.0 }, .{ l / 2.0, 0.0 }, 0x550000FF, 1.0);

        if (pixi.state.hotkeys.hotkey(.{ .proc = .play_pause })) |hk| {
            if (hk.pressed()) {
                if (file.transform_animations.items.len == 0) {
                    //const image = file.spriteToImage(file.selected_sprite_index, false) catch unreachable;

                    const transform_position = .{ 0.0, 0.0 };
                    const transform_width: f32 = @floatFromInt(file.tile_width);
                    const transform_height: f32 = @floatFromInt(file.tile_height);

                    const transform_texture = .{
                        .vertices = .{
                            .{ .position = zmath.loadArr2(transform_position) }, // TL
                            .{ .position = zmath.loadArr2(.{ transform_position[0] + transform_width, transform_position[1] }) }, // TR
                            .{ .position = zmath.f32x4(transform_position[0] + transform_width, transform_position[1] + transform_height, 0.0, 0.0) }, //BR
                            .{ .position = zmath.f32x4(transform_position[0], transform_position[1] + transform_height, 0.0, 0.0) }, // BL
                        },
                        .texture = file.layers.items[file.selected_layer_index].texture,
                        .rotation_grip_height = transform_height / 4.0,
                        .pivot = .{ .position = zmath.loadArr2(.{ file.sprites.items[file.selected_sprite_index].origin_x, file.sprites.items[file.selected_sprite_index].origin_y }) },
                    };
                    const pipeline_layout_default = pixi.state.pipeline_default.getBindGroupLayout(0);
                    defer pipeline_layout_default.release();

                    var transforms = std.ArrayList(pixi.storage.Internal.SpriteTransform).init(pixi.state.allocator);
                    const transform: pixi.storage.Internal.SpriteTransform = .{
                        .sprite_index = file.selected_sprite_index,
                        .layer_index = file.selected_layer_index,
                        .transform_texture = transform_texture,
                        .transform_bindgroup = core.device.createBindGroup(
                            &mach.gpu.BindGroup.Descriptor.init(.{
                                .layout = pipeline_layout_default,
                                .entries = &.{
                                    if (pixi.build_options.use_sysgpu)
                                        mach.gpu.BindGroup.Entry.buffer(0, pixi.state.uniform_buffer_default, 0, @sizeOf(pixi.gfx.UniformBufferObject), 0)
                                    else
                                        mach.gpu.BindGroup.Entry.buffer(0, pixi.state.uniform_buffer_default, 0, @sizeOf(pixi.gfx.UniformBufferObject)),
                                    mach.gpu.BindGroup.Entry.textureView(1, file.layers.items[file.selected_layer_index].texture.view_handle),
                                    mach.gpu.BindGroup.Entry.sampler(2, file.layers.items[file.selected_layer_index].texture.sampler_handle),
                                },
                            }),
                        ),
                        .time = 0.0,
                    };
                    transforms.append(transform) catch unreachable;
                    file.transform_animations.append(.{ .name = "New Transform", .transforms = transforms }) catch unreachable;
                } else {
                    //const image = file.spriteToImage(file.selected_sprite_index, false) catch unreachable;

                    var transforms = &file.transform_animations.items[0].transforms;

                    const transform_position = .{ 0.0, 0.0 };
                    const transform_width: f32 = @floatFromInt(file.tile_width);
                    const transform_height: f32 = @floatFromInt(file.tile_height);

                    const transform_texture: pixi.storage.Internal.Pixi.TransformTexture = .{
                        .vertices = .{
                            .{ .position = zmath.loadArr2(transform_position) }, // TL
                            .{ .position = zmath.loadArr2(.{ transform_position[0] + transform_width, transform_position[1] }) }, // TR
                            .{ .position = zmath.f32x4(transform_position[0] + transform_width, transform_position[1] + transform_height, 0.0, 0.0) }, //BR
                            .{ .position = zmath.f32x4(transform_position[0], transform_position[1] + transform_height, 0.0, 0.0) }, // BL
                        },
                        .texture = file.layers.items[file.selected_layer_index].texture,
                        .rotation_grip_height = transform_height / 4.0,
                        .pivot = .{ .position = zmath.loadArr2(.{ file.sprites.items[file.selected_sprite_index].origin_x, file.sprites.items[file.selected_sprite_index].origin_y }) },
                    };

                    const pipeline_layout_default = pixi.state.pipeline_default.getBindGroupLayout(0);
                    defer pipeline_layout_default.release();

                    const transform: pixi.storage.Internal.SpriteTransform = .{
                        .sprite_index = file.selected_sprite_index,
                        .layer_index = file.selected_layer_index,
                        .transform_texture = transform_texture,
                        .transform_bindgroup = core.device.createBindGroup(
                            &mach.gpu.BindGroup.Descriptor.init(.{
                                .layout = pipeline_layout_default,
                                .entries = &.{
                                    if (pixi.build_options.use_sysgpu)
                                        mach.gpu.BindGroup.Entry.buffer(0, pixi.state.uniform_buffer_default, 0, @sizeOf(pixi.gfx.UniformBufferObject), 0)
                                    else
                                        mach.gpu.BindGroup.Entry.buffer(0, pixi.state.uniform_buffer_default, 0, @sizeOf(pixi.gfx.UniformBufferObject)),
                                    mach.gpu.BindGroup.Entry.textureView(1, file.layers.items[file.selected_layer_index].texture.view_handle),
                                    mach.gpu.BindGroup.Entry.sampler(2, file.layers.items[file.selected_layer_index].texture.sampler_handle),
                                },
                            }),
                        ),
                        .time = 0.0,
                    };
                    transforms.append(transform) catch unreachable;
                }
            }
        }

        file.flipbook_camera.drawTexture(file.transform_animation_texture.view_handle, file.transform_animation_texture.image.width, file.transform_animation_texture.image.height, file.canvasCenterOffset(.primary), 0xFFFFFFFF);

        if (file.transform_animations.items.len > 0) {
            const selected_transform_animation = file.transform_animations.items[file.selected_transform_animation_index];

            // Draw transform texture on gpu to temporary texture
            {
                const width: f32 = @floatFromInt(file.width);
                const height: f32 = @floatFromInt(file.height);

                const uniforms = pixi.gfx.UniformBufferObject{ .mvp = zmath.transpose(
                    zmath.orthographicLh(width, height, -100, 100),
                ) };

                for (selected_transform_animation.transforms.items, 0..) |*transform, i| {
                    pixi.state.batcher.begin(.{
                        .pipeline_handle = pixi.state.pipeline_default,
                        .bind_group_handle = transform.transform_bindgroup,
                        .output_texture = &file.transform_animation_texture,
                        .clear_color = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 },
                    }) catch unreachable;

                    const transform_texture: *pixi.storage.Internal.Pixi.TransformTexture = &transform.transform_texture;
                    var pivot = if (transform_texture.pivot) |pivot| pivot.position else zmath.f32x4s(0.0);
                    if (transform_texture.pivot == null) {
                        for (&transform_texture.vertices) |*vertex| {
                            pivot += vertex.position; // Collect centroid
                        }
                        pivot /= zmath.f32x4s(4.0); // Average position
                    }

                    if (i != file.selected_transform_index) {
                        const grip_size: f32 = 10.0;
                        const half_grip_size = grip_size / 2.0;
                        const scaled_grip_size = grip_size / file.flipbook_camera.zoom;

                        if (file.flipbook_camera.isHovered(.{ pivot[0] + canvas_center_offset[0] - scaled_grip_size / 2.0, pivot[1] + canvas_center_offset[1] - scaled_grip_size / 2.0, scaled_grip_size, scaled_grip_size })) {
                            if (pixi.state.mouse.button(.primary)) |bt| {
                                if (bt.pressed()) {
                                    var change: bool = true;
                                    if (pixi.state.hotkeys.hotkey(.{ .proc = .primary })) |hk| {
                                        if (hk.down()) {
                                            selected_transform_animation.transforms.items[file.selected_transform_index].transform_texture.parent = transform_texture;
                                            change = false;
                                        }
                                    }

                                    if (pixi.state.hotkeys.hotkey(.{ .proc = .secondary })) |hk| {
                                        if (hk.down()) {
                                            selected_transform_animation.transforms.items[file.selected_transform_index].transform_texture.parent = null;
                                            change = false;
                                        }
                                    }

                                    if (change) {
                                        file.selected_transform_index = i;
                                    }
                                }
                            }
                            file.flipbook_camera.drawCircleFilled(.{ pivot[0] + canvas_center_offset[0], pivot[1] + canvas_center_offset[1] }, half_grip_size, pixi.state.theme.highlight_primary.toU32());
                        } else {
                            file.flipbook_camera.drawCircleFilled(.{ pivot[0] + canvas_center_offset[0], pivot[1] + canvas_center_offset[1] }, half_grip_size, pixi.state.theme.text.toU32());
                        }
                    }

                    const tiles_wide = @divExact(file.width, file.tile_width);

                    const src_col = @mod(@as(u32, @intCast(transform.sprite_index)), tiles_wide);
                    const src_row = @divTrunc(@as(u32, @intCast(transform.sprite_index)), tiles_wide);

                    const src_x = src_col * file.tile_width;
                    const src_y = src_row * file.tile_height;

                    const sprite: pixi.gfx.Sprite = .{
                        .name = "",
                        .origin = .{ 0, 0 },
                        .source = .{
                            src_x,
                            src_y,
                            file.tile_width,
                            file.tile_height,
                        },
                    };

                    var rotation = -transform_texture.rotation;

                    if (transform_texture.parent) |parent| {
                        var parent_pivot = if (parent.pivot) |p| p.position else zmath.f32x4s(0.0);
                        if (parent.pivot == null) {
                            for (&parent.vertices) |*vertex| {
                                parent_pivot += vertex.position; // Collect centroid
                            }
                            parent_pivot /= zmath.f32x4s(4.0); // Average position
                        }

                        const diff = parent_pivot - pivot;

                        const angle = std.math.atan2(diff[1], diff[0]);

                        rotation -= std.math.radiansToDegrees(angle) - 90.0;

                        file.flipbook_camera.drawLine(.{ pivot[0] + canvas_center_offset[0], pivot[1] + canvas_center_offset[1] }, .{ parent_pivot[0] + canvas_center_offset[0], parent_pivot[1] + canvas_center_offset[1] }, pixi.state.theme.text.toU32(), 1.0);
                    }

                    pixi.state.batcher.transformSprite(
                        &file.layers.items[transform.layer_index].texture,
                        sprite,
                        transform_texture.vertices,
                        .{ 0.0, 0.0 },
                        .{ pivot[0], -pivot[1] },
                        .{
                            .rotation = rotation,
                        },
                    ) catch unreachable;

                    pixi.state.batcher.end(uniforms, pixi.state.uniform_buffer_default) catch unreachable;
                }
            }

            if (selected_transform_animation.transforms.items.len > 0) {
                const active_transform = &selected_transform_animation.transforms.items[file.selected_transform_index];
                file.processTransformTextureControls(&active_transform.transform_texture, .{
                    .canvas = .flipbook,
                    .allow_pivot_move = false,
                    .allow_vert_move = false,
                });
            }

            // We are using a load on the gpu texture, so we need to clear this texture on the gpu after we are done
            @memset(file.transform_animation_texture.image.data, 0.0);
            file.transform_animation_texture.update(core.device);
        }
    }
}
