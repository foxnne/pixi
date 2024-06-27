const std = @import("std");
const pixi = @import("../../../pixi.zig");
const mach = @import("mach");
const core = mach.core;
const imgui = @import("zig-imgui");
const zmath = @import("zmath");

var selected_transform_index: usize = 0;

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
            const min_position: [2]f32 = .{ canvas_center_offset[0] - view_width / 2.0, -(canvas_center_offset[1] + view_height) };
            const max_position: [2]f32 = .{ canvas_center_offset[0] + view_width, canvas_center_offset[1] + view_height };

            // var scroll_delta: f32 = 0.0;
            // if (file.selected_animation_state != .play) {
            //     if (file.flipbook_camera.position[0] < min_position[0]) scroll_delta = file.flipbook_camera.position[0] - min_position[0];
            //     if (file.flipbook_camera.position[0] > max_position[0]) scroll_delta = file.flipbook_camera.position[0] - max_position[0];
            // }
            //file.flipbook_scroll = std.math.clamp(file.flipbook_scroll - scroll_delta, file.flipbookScrollFromSpriteIndex(file.sprites.items.len - 1), 0.0);

            file.flipbook_camera.position[0] = std.math.clamp(file.flipbook_camera.position[0], min_position[0], max_position[0]);
            file.flipbook_camera.position[1] = std.math.clamp(file.flipbook_camera.position[1], min_position[1], max_position[1]);
        }

        // Draw tile outline for reference
        file.flipbook_camera.drawRect(.{ canvas_center_offset[0], canvas_center_offset[1], tile_width, tile_height }, 1.0, pixi.state.theme.text_background.toU32());

        if (pixi.state.hotkeys.hotkey(.{ .proc = .play_pause })) |hk| {
            if (hk.pressed()) {
                if (file.transform_animations.items.len == 0) {
                    const image = file.spriteToImage(file.selected_sprite_index, false) catch unreachable;

                    const transform_position = .{ 0.0, 0.0 };
                    const transform_width: f32 = @floatFromInt(image.width);
                    const transform_height: f32 = @floatFromInt(image.height);

                    const transform_texture = .{
                        .vertices = .{
                            .{ .position = zmath.loadArr2(transform_position) }, // TL
                            .{ .position = zmath.loadArr2(.{ transform_position[0] + transform_width, transform_position[1] }) }, // TR
                            .{ .position = zmath.f32x4(transform_position[0] + transform_width, transform_position[1] + transform_height, 0.0, 0.0) }, //BR
                            .{ .position = zmath.f32x4(transform_position[0], transform_position[1] + transform_height, 0.0, 0.0) }, // BL
                        },
                        .texture = pixi.gfx.Texture.create(image, .{}),
                        .rotation_grip_height = transform_height / 4.0,
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
                                    mach.gpu.BindGroup.Entry.textureView(1, transform_texture.texture.view_handle),
                                    mach.gpu.BindGroup.Entry.sampler(2, transform_texture.texture.sampler_handle),
                                },
                            }),
                        ),
                        .time = 0.0,
                    };
                    transforms.append(transform) catch unreachable;
                    file.transform_animations.append(.{ .name = "New Transform", .transforms = transforms }) catch unreachable;
                } else {
                    const image = file.spriteToImage(file.selected_sprite_index, false) catch unreachable;

                    const transform_position = .{ 0.0, 0.0 };
                    const transform_width: f32 = @floatFromInt(image.width);
                    const transform_height: f32 = @floatFromInt(image.height);

                    const transform_texture = .{
                        .vertices = .{
                            .{ .position = zmath.loadArr2(transform_position) }, // TL
                            .{ .position = zmath.loadArr2(.{ transform_position[0] + transform_width, transform_position[1] }) }, // TR
                            .{ .position = zmath.f32x4(transform_position[0] + transform_width, transform_position[1] + transform_height, 0.0, 0.0) }, //BR
                            .{ .position = zmath.f32x4(transform_position[0], transform_position[1] + transform_height, 0.0, 0.0) }, // BL
                        },
                        .texture = pixi.gfx.Texture.create(image, .{}),
                        .rotation_grip_height = transform_height / 4.0,
                    };

                    const pipeline_layout_default = pixi.state.pipeline_default.getBindGroupLayout(0);
                    defer pipeline_layout_default.release();

                    var transforms = &file.transform_animations.items[0].transforms;
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
                                    mach.gpu.BindGroup.Entry.textureView(1, transform_texture.texture.view_handle),
                                    mach.gpu.BindGroup.Entry.sampler(2, transform_texture.texture.sampler_handle),
                                },
                            }),
                        ),
                        .time = 0.0,
                    };
                    transforms.append(transform) catch unreachable;
                }
            }
        }

        if (file.transform_animations.items.len > 0) {
            const selected_transform_animation: pixi.storage.Internal.TransformAnimation = file.transform_animations.items[file.selected_transform_animation_index];
            for (selected_transform_animation.transforms.items) |*sprite_transform| {
                file.processTransformTextureControls(&sprite_transform.transform_texture, .flipbook);
            }

            // Draw transform texture on gpu to temporary texture
            {
                const width: f32 = @floatFromInt(file.width);
                const height: f32 = @floatFromInt(file.height);

                const uniforms = pixi.gfx.UniformBufferObject{ .mvp = zmath.transpose(
                    zmath.orthographicLh(width, height, -100, 100),
                ) };

                for (selected_transform_animation.transforms.items) |transform| {
                    pixi.state.batcher.begin(.{
                        .pipeline_handle = pixi.state.pipeline_default,
                        .bind_group_handle = transform.transform_bindgroup,
                        .output_texture = &file.transform_animation_texture,
                        .clear_color = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 },
                    }) catch unreachable;

                    const transform_texture = &transform.transform_texture;
                    var pivot = if (transform_texture.pivot) |pivot| pivot.position else zmath.f32x4s(0.0);
                    if (transform_texture.pivot == null) {
                        for (&transform_texture.vertices) |*vertex| {
                            pivot += vertex.position; // Collect centroid
                        }
                        pivot /= zmath.f32x4s(4.0); // Average position
                    }

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
        //file.flipbook_camera.drawRectFilled(.{ file.canvasCenterOffset(.primary)[0], file.canvasCenterOffset(.primary)[1], @floatFromInt(file.transform_animation_texture.image.width), @floatFromInt(file.transform_animation_texture.image.width) }, 0xFFFFFFFF);
        file.flipbook_camera.drawTexture(file.transform_animation_texture.view_handle, file.transform_animation_texture.image.width, file.transform_animation_texture.image.height, file.canvasCenterOffset(.primary), 0xFFFFFFFF);
    }

    // if (imgui.getWindowDrawList()) |draw_list|
    //     draw_list.addImageEx(
    //         file.transform_animation_texture.view_handle,
    //         .{ .x = offset[0], .y = offset[1] },
    //         .{ .x = offset[0] + @as(f32, @floatFromInt(file.transform_animation_texture.image.width)), .y = offset[1] + @as(f32, @floatFromInt(file.transform_animation_texture.image.height)) },
    //         .{ .x = 0.0, .y = 0.0 },
    //         .{ .x = 1.0, .y = 1.0 },
    //         0xFFFFFFFF,
    //     );
}
