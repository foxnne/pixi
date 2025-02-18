const std = @import("std");
const pixi = @import("../../../pixi.zig");
const mach = @import("mach");

const Core = mach.Core;
const App = pixi.App;
const Editor = pixi.Editor;

const imgui = @import("zig-imgui");
const zmath = @import("zmath");

const node_size: f32 = 10.0;
const node_radius = node_size / 2.0;

const frame_node_radius: f32 = 5.0;
const frame_node_spacing: f32 = 4.0;

const work_area_offset: f32 = 12.0;

//var animation_opt: ?* pixi.Internal.KeyframeAnimation = null;

var animation_index: ?usize = null;

var frame_node_dragging: ?u32 = null;
var frame_node_hovered: ?u32 = null;
var ms_hovered: ?usize = null;
var keyframe_dragging: ?u32 = null;
var mouse_scroll_delta_y: f32 = 0.0;

pub fn draw(file: *pixi.Internal.File, editor: *Editor) !void {
    const window_height = imgui.getWindowHeight();
    const window_width = imgui.getWindowWidth();
    const tile_width = @as(f32, @floatFromInt(file.tile_width));
    const tile_height = @as(f32, @floatFromInt(file.tile_height));
    const canvas_center_offset: [2]f32 = file.canvasCenterOffset(.flipbook);
    const window_position = imgui.getWindowPos();
    const file_width: f32 = @floatFromInt(file.width);
    const file_height: f32 = @floatFromInt(file.height);

    const uniforms = pixi.gfx.UniformBufferObject{ .mvp = zmath.transpose(
        zmath.orthographicLh(file_width, file_height, -100, 100),
    ) };

    // Clear hovered between each call
    defer {
        frame_node_hovered = null;
        ms_hovered = null;
    }

    const scaled_node_size = node_size / file.flipbook_camera.zoom;

    const timeline_height = imgui.getWindowHeight() * 0.25;
    const text_area_height: f32 = imgui.getTextLineHeight();

    var latest_time: f32 = 0.0;

    if (file.keyframe_animations.slice().len > 0) {
        latest_time = file.keyframe_animations.slice().get(file.selected_keyframe_animation_index).length();

        if (file.selected_keyframe_animation_state == .play) {
            file.keyframe_animations.items(.elapsed_time)[file.selected_keyframe_animation_index] += pixi.app.delta_time;

            if (file.keyframe_animations.items(.elapsed_time)[file.selected_keyframe_animation_index] > file.keyframe_animations.slice().get(file.selected_keyframe_animation_index).length()) {
                file.keyframe_animations.items(.elapsed_time)[file.selected_keyframe_animation_index] = 0.0;
                if (!file.selected_keyframe_animation_loop) {
                    file.selected_keyframe_animation_state = .pause;
                }
            }
        }
    }

    const timeline_length: f32 = latest_time + 2.0;
    const animation_ms: usize = @intFromFloat(timeline_length * 1000.0);
    const zoom: f32 = 1.0;
    _ = zoom; // autofix

    const scroll_bar_height: f32 = imgui.getStyle().scrollbar_size;

    {
        imgui.pushStyleColorImVec4(imgui.Col_ChildBg, pixi.editor.theme.foreground.toImguiVec4());
        defer imgui.popStyleColor();

        imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 0.0, .y = 0.0 });
        defer imgui.popStyleVar();

        if (imgui.beginChild("FlipbookTimeline", .{ .x = 0.0, .y = timeline_height + (scroll_bar_height / 2.0) }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow | imgui.WindowFlags_AlwaysHorizontalScrollbar)) {
            defer imgui.endChild();

            const work_area_width: f32 = timeline_length * 1000.0 + work_area_offset;

            const scroll_x: f32 = imgui.getScrollX();
            const scroll_y: f32 = imgui.getScrollY();

            const window_hovered: bool = imgui.isWindowHovered(imgui.HoveredFlags_ChildWindows);

            var rel_mouse_x: ?f32 = null;
            var rel_mouse_y: ?f32 = null;

            if (window_hovered) {
                const mouse_position = pixi.app.mouse.position;
                rel_mouse_x = mouse_position[0] - window_position.x + scroll_x;
                rel_mouse_y = mouse_position[1] - window_position.y + scroll_y;
            }

            if (imgui.beginChild("FlipbookTimelineWorkArea", .{ .x = work_area_width, .y = timeline_height - text_area_height - scroll_bar_height }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow | imgui.WindowFlags_NoScrollWithMouse)) {
                defer imgui.endChild();

                // Set the y scroll manually as allowing default scroll blocks x scroll on the parent window
                if (window_hovered) {
                    if (pixi.app.mouse.scroll_y) |scroll_delta_y| {
                        imgui.setScrollY(imgui.getScrollY() - scroll_delta_y * if (pixi.editor.settings.input_scheme == .trackpad) @as(f32, 10.0) else @as(f32, 1.0));
                    }
                }

                const max_nodes: f32 = if (animation_index) |index| @floatFromInt(file.keyframe_animations.slice().get(index).maxNodes()) else 0.0;
                const node_area_height = @max(max_nodes * (frame_node_radius * 2.0 + frame_node_spacing) + work_area_offset, imgui.getWindowHeight());

                try drawVerticalLines(file, animation_ms, .{ 0.0, scroll_y });

                {
                    imgui.pushStyleColor(imgui.Col_ChildBg, 0x00000000);
                    defer imgui.popStyleColor();

                    if (imgui.beginChild("FlipbookTimelineNodeArea", .{ .x = work_area_width, .y = node_area_height }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
                        defer imgui.endChild();

                        try drawNodeArea(file, animation_ms, .{ 0.0, scroll_y });
                    }
                }
            }

            if (imgui.beginChild("FlipbookTimelineTextArea", .{ .x = work_area_width, .y = text_area_height }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow | imgui.WindowFlags_NoScrollWithMouse)) {
                defer imgui.endChild();

                if (imgui.getWindowDrawList()) |draw_list| {
                    for (0..animation_ms) |ms| {
                        var x: f32 = @floatFromInt(ms);
                        x += work_area_offset - scroll_x + window_position.x;

                        const y: f32 = imgui.getWindowPos().y;

                        if (@mod(ms, 100) == 0) {
                            const unit = if (@mod(ms, 1000) == 0) "s" else "ms";
                            const value = if (@mod(ms, 1000) == 0) @divExact(ms, 1000) else ms;

                            const text = try std.fmt.allocPrintZ(editor.arena.allocator(), "{d} {s}", .{ value, unit });

                            draw_list.addText(.{ .x = x, .y = y }, editor.theme.text_background.toU32(), text);
                        }
                    }
                }
            }
        }
    }

    if (imgui.beginChild("FlipbookCanvas", .{ .x = window_width, .y = 0.0 }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
        defer imgui.endChild();

        // Handle zooming, panning and extents
        {
            var sprite_camera: pixi.gfx.Camera = .{
                .zoom = window_height / tile_height,
            };
            const zoom_index = sprite_camera.nearestZoomIndex();
            const max_zoom_index = if (zoom_index < pixi.editor.settings.zoom_steps.len - 2) zoom_index + 2 else zoom_index;
            const max_zoom = pixi.editor.settings.zoom_steps[max_zoom_index];
            sprite_camera.setNearZoomFloor();
            const min_zoom = 1.0;

            file.flipbook_camera.processPanZoom(.flipbook);

            // Lock camera from zooming in or out too far for the flipbook
            file.flipbook_camera.zoom = std.math.clamp(file.flipbook_camera.zoom, min_zoom, max_zoom);

            const view_width: f32 = tile_width * 4.0;
            const view_height: f32 = tile_height * 4.0;

            // Lock camera from moving too far away from canvas
            const min_position: [2]f32 = .{ canvas_center_offset[0] - view_width / 2.0, canvas_center_offset[1] - view_height / 2.0 };
            const max_position: [2]f32 = .{ canvas_center_offset[0] + view_width, canvas_center_offset[1] + view_height };

            file.flipbook_camera.position[0] = std.math.clamp(file.flipbook_camera.position[0], min_position[0], max_position[0]);
            file.flipbook_camera.position[1] = std.math.clamp(file.flipbook_camera.position[1], min_position[1], max_position[1]);
        }

        const grid_columns: f32 = 20;
        const grid_rows: f32 = 20;
        const grid_width: f32 = tile_width * grid_columns;
        const grid_height: f32 = tile_height * grid_rows;

        file.flipbook_camera.drawGrid(.{ -grid_width / 2.0, -grid_height / 2.0 }, grid_width, grid_height, @intFromFloat(grid_columns), @intFromFloat(grid_rows), pixi.editor.theme.text_background.toU32(), true);
        file.flipbook_camera.drawCircleFilled(.{ 0.0, 0.0 }, node_radius, pixi.editor.theme.text_background.toU32());

        const l: f32 = 2000;
        file.flipbook_camera.drawLine(.{ 0.0, l / 2.0 }, .{ 0.0, -l / 2.0 }, 0x5500FF00, 1.0);
        file.flipbook_camera.drawLine(.{ -l / 2.0, 0.0 }, .{ l / 2.0, 0.0 }, 0x550000FF, 1.0);

        file.flipbook_camera.drawTexture(
            file.keyframe_animation_texture.view_handle,
            file.keyframe_animation_texture.width,
            file.keyframe_animation_texture.height,
            file.canvasCenterOffset(.primary),
            0xFFFFFFFF,
        );

        if (file.keyframe_animations.slice().len > 0) {
            const animation = file.keyframe_animations.slice().get(file.selected_keyframe_animation_index);

            if (animation.keyframes.items.len > 0) {
                //const current_ms: usize = if (ms_hovered) |ms| ms else @intFromFloat(animation.elapsed_time * 1000.0);
                const current_ms: usize = if (ms_hovered) |current| current else @intFromFloat(animation.elapsed_time * 1000.0);
                // If we have a keyframe for this time, go ahead and draw it normally
                if (animation.getKeyframeMilliseconds(current_ms)) |selected_keyframe| {
                    for (selected_keyframe.frames.items) |*frame| {
                        const color = animation.getFrameNodeColor(frame.id);

                        if (file.layer(frame.layer_id)) |layer| {
                            if (layer.transform_bindgroup) |transform_bindgroup| {
                                try pixi.app.batcher.begin(.{
                                    .pipeline_handle = pixi.app.pipeline_default,
                                    .bind_group_handle = transform_bindgroup,
                                    .output_texture = &file.keyframe_animation_texture,
                                    .clear_color = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 },
                                });

                                if (file.flipbook_camera.isHovered(.{
                                    frame.pivot.position[0] - scaled_node_size / 2.0,
                                    frame.pivot.position[1] - scaled_node_size / 2.0,
                                    scaled_node_size,
                                    scaled_node_size,
                                })) {
                                    if (frame.id != selected_keyframe.active_frame_id) {
                                        if (pixi.app.mouse.button(.primary)) |bt| {
                                            if (bt.pressed()) {
                                                var change: bool = true;

                                                if (pixi.editor.hotkeys.hotkey(.{ .proc = .secondary })) |hk| {
                                                    if (hk.down()) {
                                                        frame.parent_id = null;
                                                        change = false;
                                                    }
                                                }

                                                if (frame.id != selected_keyframe.active_frame_id) {
                                                    if (pixi.editor.hotkeys.hotkey(.{ .proc = .primary })) |hk| {
                                                        if (hk.down()) {
                                                            if (selected_keyframe.frame(selected_keyframe.active_frame_id)) |active_frame| {
                                                                active_frame.parent_id = frame.id;
                                                            }

                                                            change = false;
                                                        }
                                                    }
                                                    if (change) {
                                                        selected_keyframe.active_frame_id = frame.id;
                                                    }
                                                }
                                            }
                                        }
                                        file.flipbook_camera.drawCircleFilled(
                                            .{ frame.pivot.position[0], frame.pivot.position[1] },
                                            node_radius * 1.5,
                                            color,
                                        );
                                        file.flipbook_camera.drawCircle(
                                            .{ frame.pivot.position[0], frame.pivot.position[1] },
                                            node_radius * 1.5 + 1.0,
                                            1.0,
                                            pixi.editor.theme.text_background.toU32(),
                                        );
                                    }
                                } else {
                                    file.flipbook_camera.drawCircleFilled(
                                        .{ frame.pivot.position[0], frame.pivot.position[1] },
                                        node_radius,
                                        color,
                                    );
                                    file.flipbook_camera.drawCircle(
                                        .{ frame.pivot.position[0], frame.pivot.position[1] },
                                        node_radius + 1.0,
                                        1.0,
                                        pixi.editor.theme.text_background.toU32(),
                                    );
                                }

                                const tiles_wide = @divExact(file.width, file.tile_width);

                                const src_col = @mod(@as(u32, @intCast(frame.sprite_index)), tiles_wide);
                                const src_row = @divTrunc(@as(u32, @intCast(frame.sprite_index)), tiles_wide);

                                const src_x = src_col * file.tile_width;
                                const src_y = src_row * file.tile_height;

                                const sprite: pixi.Sprite = .{
                                    .origin = .{ 0, 0 },
                                    .source = .{
                                        src_x,
                                        src_y,
                                        file.tile_width,
                                        file.tile_height,
                                    },
                                };

                                var rotation = -frame.rotation;

                                if (frame.parent_id) |parent_id| {
                                    for (selected_keyframe.frames.items) |parent_frame| {
                                        if (parent_frame.id == parent_id) {
                                            const diff = parent_frame.pivot.position - frame.pivot.position;

                                            const angle = std.math.atan2(diff[1], diff[0]);

                                            rotation -= std.math.radiansToDegrees(angle) - 90.0;

                                            file.flipbook_camera.drawLine(
                                                .{ frame.pivot.position[0], frame.pivot.position[1] },
                                                .{ parent_frame.pivot.position[0], parent_frame.pivot.position[1] },
                                                color,
                                                1.0,
                                            );
                                        }
                                    }
                                }

                                try pixi.app.batcher.transformSprite(
                                    &layer.texture,
                                    sprite,
                                    frame.vertices,
                                    .{ 0.0, 0.0 },
                                    .{ frame.pivot.position[0], -frame.pivot.position[1] },
                                    .{
                                        .rotation = rotation,
                                    },
                                );

                                try pixi.app.batcher.end(uniforms, pixi.app.uniform_buffer_default);
                            }

                            if (selected_keyframe.active_frame_id == frame.id and file.selected_keyframe_animation_state == .pause) {
                                // Write from the frame to the transform texture
                                @memcpy(&file.keyframe_transform_texture.vertices, &frame.vertices);
                                file.keyframe_transform_texture.pivot = frame.pivot;
                                file.keyframe_transform_texture.rotation = frame.rotation;

                                // Write parent id
                                if (frame.parent_id) |parent_id| {
                                    file.keyframe_transform_texture.keyframe_parent_id = parent_id;
                                }

                                // Process transform texture controls
                                try file.processTransformTextureControls(&file.keyframe_transform_texture, .{
                                    .canvas = .flipbook,
                                    .allow_pivot_move = false,
                                    .allow_vert_move = false,
                                    .color = color,
                                });

                                // Clear the parent
                                file.keyframe_transform_texture.keyframe_parent_id = null;

                                // Write back to the frame
                                @memcpy(&frame.vertices, &file.keyframe_transform_texture.vertices);
                                frame.pivot = file.keyframe_transform_texture.pivot.?;
                                frame.rotation = file.keyframe_transform_texture.rotation;
                            }

                            // We are using a load on the gpu texture, so we need to clear this texture on the gpu after we are done
                            @memset(file.keyframe_animation_texture.pixels, 0.0);
                            file.keyframe_animation_texture.update(pixi.core.windows.get(pixi.app.window, .device));
                        }
                    }
                }

                {
                    // We dont have a keyframe for this time, so we need to search the keyframes for tweens and blend
                    const current_time: f32 = @as(f32, @floatFromInt(current_ms)) / 1000.0;

                    // Find the "from" keyframe, which will have the highest time while still being less than hovered time
                    for (animation.keyframes.items) |*keyframe| {
                        if (keyframe.time <= current_time) {
                            for (keyframe.frames.items) |from_frame| {
                                var from_tween_id_opt: ?u32 = if (from_frame.tween_id) |from_tween_id| from_tween_id else null;

                                if (from_tween_id_opt == null) {
                                    for (animation.keyframes.items) |kf| {
                                        for (kf.frames.items) |f| {
                                            if (f.tween_id == from_frame.id) {
                                                from_tween_id_opt = f.tween_id;
                                            }
                                        }
                                    }
                                }

                                if (from_tween_id_opt) |from_tween_id| {
                                    if (animation.getKeyframeFromFrame(from_tween_id)) |to_keyframe| {
                                        if (to_keyframe.time < current_time) continue;
                                        if (to_keyframe.frame(from_tween_id)) |to_frame| {
                                            const begin_time = keyframe.time;
                                            const end_time = to_keyframe.time;

                                            const progress = current_time - begin_time;
                                            const total = end_time - begin_time;

                                            const t: f32 = progress / total;

                                            const tween_vertices: [4]pixi.Internal.File.TransformVertex = .{
                                                .{ .position = zmath.lerp(from_frame.vertices[0].position, to_frame.vertices[0].position, t) },
                                                .{ .position = zmath.lerp(from_frame.vertices[1].position, to_frame.vertices[1].position, t) },
                                                .{ .position = zmath.lerp(from_frame.vertices[2].position, to_frame.vertices[2].position, t) },
                                                .{ .position = zmath.lerp(from_frame.vertices[3].position, to_frame.vertices[3].position, t) },
                                            };

                                            const tween_pivot: pixi.Internal.File.TransformVertex = .{ .position = zmath.lerp(from_frame.pivot.position, to_frame.pivot.position, t) };

                                            var from_rotation: f32 = from_frame.rotation;

                                            if (from_frame.parent_id) |parent_id| {
                                                if (keyframe.frame(parent_id)) |parent_frame| {
                                                    const diff = parent_frame.pivot.position - from_frame.pivot.position;
                                                    const angle = std.math.atan2(diff[1], diff[0]);

                                                    const rotation = std.math.radiansToDegrees(angle) - 90.0;

                                                    from_rotation += rotation;
                                                }
                                            }

                                            var to_rotation: f32 = to_frame.rotation;

                                            if (to_frame.parent_id) |parent_id| {
                                                if (to_keyframe.frame(parent_id)) |parent_frame| {
                                                    const diff = parent_frame.pivot.position - to_frame.pivot.position;
                                                    const angle = std.math.atan2(diff[1], diff[0]);

                                                    const rotation = std.math.radiansToDegrees(angle) - 90.0;

                                                    to_rotation += rotation;
                                                }
                                            }

                                            const tween_rotation = pixi.math.lerp(from_rotation, to_rotation, t);

                                            if (file.layer(from_frame.layer_id)) |layer| {
                                                if (layer.transform_bindgroup) |transform_bindgroup| {
                                                    try pixi.app.batcher.begin(.{
                                                        .pipeline_handle = pixi.app.pipeline_default,
                                                        .bind_group_handle = transform_bindgroup,
                                                        .output_texture = &file.keyframe_animation_texture,
                                                        .clear_color = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 },
                                                    });

                                                    const tiles_wide = @divExact(file.width, file.tile_width);

                                                    const src_col = @mod(@as(u32, @intCast(from_frame.sprite_index)), tiles_wide);
                                                    const src_row = @divTrunc(@as(u32, @intCast(from_frame.sprite_index)), tiles_wide);

                                                    const src_x = src_col * file.tile_width;
                                                    const src_y = src_row * file.tile_height;

                                                    const sprite: pixi.Sprite = .{
                                                        .origin = .{ 0, 0 },
                                                        .source = .{
                                                            src_x,
                                                            src_y,
                                                            file.tile_width,
                                                            file.tile_height,
                                                        },
                                                    };

                                                    try pixi.app.batcher.transformSprite(
                                                        &layer.texture,
                                                        sprite,
                                                        tween_vertices,
                                                        .{ 0.0, 0.0 },
                                                        .{ tween_pivot.position[0], -tween_pivot.position[1] },
                                                        .{
                                                            .rotation = -tween_rotation,
                                                        },
                                                    );

                                                    try pixi.app.batcher.end(uniforms, pixi.app.uniform_buffer_default);
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // We are using a load on the gpu texture, so we need to clear this texture on the gpu after we are done
                            @memset(file.keyframe_animation_texture.pixels, 0);
                            file.keyframe_animation_texture.update(pixi.core.windows.get(pixi.app.window, .device));
                        }
                    }
                }
            }
        }
    }
}

pub fn drawVerticalLines(file: *pixi.Internal.File, animation_length: usize, scroll: [2]f32) !void {
    const tile_width = @as(f32, @floatFromInt(file.tile_width));
    const tile_height = @as(f32, @floatFromInt(file.tile_height));

    const window_position = imgui.getWindowPos();
    const window_hovered: bool = imgui.isWindowHovered(imgui.HoveredFlags_ChildWindows);

    var rel_mouse_x: ?f32 = null;
    var rel_mouse_y: ?f32 = null;

    if (window_hovered) {
        const mouse_position = pixi.app.mouse.position;
        rel_mouse_x = mouse_position[0] - window_position.x + scroll[0];
        rel_mouse_y = mouse_position[1] - window_position.y + scroll[1];
    }

    if (imgui.getWindowDrawList()) |draw_list| {
        for (0..animation_length) |ms| {
            const ms_float: f32 = @floatFromInt(ms);
            const x: f32 = ms_float + work_area_offset - scroll[0] + window_position.x;
            const y: f32 = imgui.getWindowPos().y;

            if (@mod(ms, 10) == 0) {
                const thickness: f32 = if (@mod(ms, 1000) == 0) 3.0 else if (@mod(ms, 100) == 0) 2.0 else 1.0;

                const line_hovered: bool = if (rel_mouse_x) |mouse_x| @abs(mouse_x - (ms_float + work_area_offset)) < frame_node_radius else false;
                const color: u32 = if (line_hovered) pixi.editor.theme.highlight_primary.toU32() else pixi.editor.theme.text_background.toU32();
                draw_list.addLineEx(.{ .x = x, .y = y }, .{ .x = x, .y = y + imgui.getWindowHeight() }, color, thickness);

                if (line_hovered) {
                    ms_hovered = ms;

                    const hovered_time = ms_float / 1000.0;
                    if (pixi.app.mouse.button(.primary)) |bt| {
                        if (bt.released()) {
                            const primary_hotkey_down: bool = if (pixi.editor.hotkeys.hotkey(.{ .proc = .primary })) |hk| hk.down() else false;

                            if (primary_hotkey_down) {
                                if (animation_index == null) {
                                    const new_animation: pixi.Internal.KeyframeAnimation = .{
                                        .name = "New Keyframe Animation",
                                        .keyframes = std.ArrayList(pixi.Internal.Keyframe).init(pixi.app.allocator),
                                        .active_keyframe_id = 0,
                                        .id = file.newId(),
                                    };

                                    try file.keyframe_animations.append(pixi.app.allocator, new_animation);
                                    animation_index = file.keyframe_animations.slice().len - 1;
                                }

                                if (animation_index) |index| {
                                    // add node to map, either create a new keyframe or add to existing keyframe
                                    for (file.selected_sprites.items) |sprite_index| {
                                        const sprite = file.sprites.slice().get(sprite_index);
                                        const origin = zmath.loadArr2(sprite.origin);

                                        const new_frame: pixi.Internal.Frame = .{
                                            .id = file.newFrameId(),
                                            .layer_id = file.layers.items(.id)[file.selected_layer_index],
                                            .sprite_index = sprite_index,
                                            .pivot = .{ .position = zmath.f32x4s(0.0) },
                                            .vertices = .{
                                                .{ .position = -origin }, // TL
                                                .{ .position = zmath.loadArr2(.{ tile_width, 0.0 }) - origin }, // TR
                                                .{ .position = zmath.loadArr2(.{ tile_width, tile_height }) - origin }, //BR
                                                .{ .position = zmath.loadArr2(.{ 0.0, tile_height }) - origin }, // BL
                                            },
                                        };

                                        if (file.keyframe_animations.get(index).getKeyframeMilliseconds(ms)) |kf| {
                                            try kf.frames.append(new_frame);

                                            file.keyframe_animations.items(.active_keyframe_id)[index] = kf.id;
                                        } else {
                                            var new_keyframe: pixi.Internal.Keyframe = .{
                                                .id = file.newKeyframeId(),
                                                .time = hovered_time,
                                                .frames = std.ArrayList(pixi.Internal.Frame).init(pixi.app.allocator),
                                                .active_frame_id = new_frame.id,
                                            };

                                            try new_keyframe.frames.append(new_frame);
                                            try file.keyframe_animations.items(.keyframes)[index].append(new_keyframe);
                                            file.keyframe_animations.items(.active_keyframe_id)[index] = new_keyframe.id;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

pub fn drawNodeArea(file: *pixi.Internal.File, animation_length: usize, scroll: [2]f32) !void {
    const window_position = imgui.getWindowPos();
    const window_hovered: bool = imgui.isWindowHovered(imgui.HoveredFlags_ChildWindows);

    var rel_mouse_x: ?f32 = null;
    var rel_mouse_y: ?f32 = null;

    if (window_hovered) {
        const mouse_position = pixi.app.mouse.position;
        rel_mouse_x = mouse_position[0] - window_position.x + scroll[0];
        rel_mouse_y = mouse_position[1] - window_position.y + scroll[1];
    }

    const secondary_down: bool = if (pixi.editor.hotkeys.hotkey(.{ .proc = .secondary })) |hk| hk.down() else false;

    if (animation_index) |index| {
        var animation = file.keyframe_animations.slice().get(index);
        if (imgui.getWindowDrawList()) |draw_list| {
            defer {
                if (pixi.app.mouse.button(.primary)) |bt| {
                    if (bt.released()) {
                        keyframe_dragging = null;
                        frame_node_dragging = null;
                    }
                }
            }

            for (0..animation_length) |ms| {
                const ms_float: f32 = @floatFromInt(ms);

                const line_hovered: bool = if (rel_mouse_x) |mouse_x| @abs(mouse_x - (ms_float + work_area_offset)) < frame_node_radius else false;

                var x: f32 = @floatFromInt(ms);
                x += work_area_offset - scroll[0] + window_position.x;

                // Draw temporary line from the node we are dragging to the mouse position
                if (frame_node_dragging) |frame_dragging_id| {
                    if (secondary_down and line_hovered) { // Shift is pressed, so we need to link the dragged node to the target node
                        if (animation.getKeyframeFromFrame(frame_dragging_id)) |dragging_kf| {
                            if (dragging_kf.frameIndex(frame_dragging_id)) |start_index| {
                                const color = animation.getFrameNodeColor(frame_dragging_id);
                                const start_index_float: f32 = @floatFromInt(start_index);
                                const start_x = (dragging_kf.time * 1000.0) + work_area_offset - scroll[0] + window_position.x;
                                const start_y: f32 = imgui.getWindowPos().y + (start_index_float * ((frame_node_radius * 2.0) + frame_node_spacing)) + work_area_offset;
                                const end_y: f32 = if (rel_mouse_y) |y| imgui.getWindowPos().y + y else start_y;
                                draw_list.addLine(.{ .x = start_x, .y = start_y }, .{ .x = x, .y = end_y }, color);
                            }
                        }
                    }
                }

                if (animation.getKeyframeMilliseconds(ms)) |hovered_kf| {
                    if (hovered_kf.id != keyframe_dragging or secondary_down) {
                        for (hovered_kf.frames.items, 0..) |fr, fr_index| {

                            // Check if the currently dragged keyframe
                            // only contains a single frame, if so, drag that node
                            // and not the keyframe so it can be added to other keyframes
                            if (keyframe_dragging) |drag_kf_id| {
                                if (hovered_kf.id == keyframe_dragging) {
                                    if (animation.keyframe(drag_kf_id)) |drag_kf| {
                                        if (drag_kf.frames.items.len == 1) {
                                            keyframe_dragging = null;
                                            frame_node_dragging = drag_kf.frames.items[0].id;
                                        }
                                    }
                                }
                            }

                            // If the current frame is the one being dragged, we don't need to draw its normal node
                            if (fr.id == frame_node_dragging and !line_hovered and !secondary_down)
                                continue;

                            const color = animation.getFrameNodeColor(fr.id);

                            // Find the scale of the node based on mouse position
                            const index_float: f32 = @floatFromInt(fr_index);
                            const y: f32 = imgui.getWindowPos().y + (index_float * ((frame_node_radius * 2.0) + frame_node_spacing)) + work_area_offset;

                            var frame_node_scale: f32 = if (hovered_kf.active_frame_id == fr.id and animation.active_keyframe_id == hovered_kf.id) 2.0 else 1.0;
                            if (rel_mouse_x) |mouse_x| {
                                if (rel_mouse_y) |mouse_y| {
                                    if (@abs(mouse_x - (ms_float + work_area_offset)) < frame_node_radius) {
                                        const diff_y = @abs(mouse_y + window_position.y - y);
                                        const diff_radius = diff_y - frame_node_radius;

                                        if (diff_y < frame_node_radius)
                                            frame_node_hovered = fr.id;

                                        frame_node_scale = std.math.clamp(2.0 - diff_radius / 4.0, 1.0, 2.0);
                                    }
                                }
                            }

                            // Make changes to the current active frame id and elapsed time
                            if (pixi.app.mouse.button(.primary)) |bt| {
                                if (bt.pressed() and line_hovered and window_hovered) {
                                    file.keyframe_animations.items(.active_keyframe_id)[index] = hovered_kf.id;
                                    file.keyframe_animations.items(.elapsed_time)[index] = @as(f32, @floatFromInt(ms)) / 1000.0;

                                    if (frame_node_hovered) |frame_hovered| {
                                        frame_node_dragging = frame_hovered;
                                        hovered_kf.active_frame_id = frame_hovered;
                                        keyframe_dragging = null;
                                    } else {
                                        if (frame_node_dragging == null)
                                            keyframe_dragging = hovered_kf.id;
                                    }
                                }

                                if (frame_node_dragging) |frame_dragging_id| {
                                    if (secondary_down) { // Shift is pressed, so we need to link the dragged node to the target node
                                        if (animation.getKeyframeFromFrame(frame_dragging_id)) |dragging_kf| {
                                            if (bt.released() and line_hovered and window_hovered) {
                                                file.keyframe_animations.items(.active_keyframe_id)[index] = hovered_kf.id;
                                                file.keyframe_animations.items(.elapsed_time)[index] = @as(f32, @floatFromInt(ms)) / 1000.0;
                                                if (dragging_kf.frame(frame_dragging_id)) |dragging_frame| {
                                                    if (frame_node_hovered) |hovered_frame_id| {
                                                        if (hovered_kf.frame(hovered_frame_id)) |hovered_frame| {
                                                            dragging_frame.tween_id = hovered_frame.id;
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Draw connecting tween lines and then draw the scaled frame nodes
                            if (fr.tween_id) |tween_id| {
                                const from_x = x;
                                const from_y = y;

                                if (animation.getKeyframeFromFrame(tween_id)) |tween_kf| {
                                    if (tween_kf.frameIndex(tween_id)) |tween_index| {
                                        const tween_index_float: f32 = @floatFromInt(tween_index);
                                        const to_x: f32 = imgui.getWindowPos().x + tween_kf.time * 1000.0 + work_area_offset - scroll[0];
                                        const to_y: f32 = imgui.getWindowPos().y + (tween_index_float * ((frame_node_radius * 2.0) + frame_node_spacing)) + work_area_offset;

                                        draw_list.addLine(.{ .x = from_x, .y = from_y }, .{ .x = to_x, .y = to_y }, color);
                                    }
                                }
                            }

                            draw_list.addCircleFilled(.{ .x = x, .y = y }, frame_node_radius * frame_node_scale, color, 20);
                            draw_list.addCircle(.{ .x = x, .y = y }, frame_node_radius * frame_node_scale + 1.0, pixi.editor.theme.text_background.toU32());
                        }
                    }
                }

                if (@mod(ms, 10) == 0 and line_hovered and window_hovered) {
                    if (frame_node_dragging) |dragging_frame_id| {
                        if (pixi.app.mouse.button(.primary)) |bt| {
                            if (bt.released()) {
                                if (!secondary_down) {
                                    if (animation.getKeyframeFromFrame(dragging_frame_id)) |dragging_keyframe| {
                                        if (animation.getKeyframeMilliseconds(ms)) |target_keyframe| {
                                            if (target_keyframe.id != dragging_keyframe.id) {
                                                if (dragging_keyframe.frameIndex(dragging_frame_id)) |frame_index| {
                                                    const drag_frame = dragging_keyframe.frames.orderedRemove(frame_index);

                                                    try target_keyframe.frames.append(drag_frame);

                                                    if (dragging_keyframe.frames.items.len == 0) {
                                                        if (animation.keyframeIndex(dragging_keyframe.id)) |empty_kf_index| {
                                                            var empty_kf = animation.keyframes.orderedRemove(empty_kf_index);
                                                            empty_kf.frames.clearAndFree();
                                                        }
                                                    }
                                                }
                                            }
                                        } else {
                                            if (dragging_keyframe.frames.items.len > 1) {
                                                var new_keyframe: pixi.Internal.Keyframe = .{
                                                    .active_frame_id = dragging_frame_id,
                                                    .id = file.newKeyframeId(),
                                                    .frames = std.ArrayList(pixi.Internal.Frame).init(pixi.app.allocator),
                                                    .time = ms_float / 1000.0,
                                                };

                                                if (dragging_keyframe.frameIndex(dragging_frame_id)) |frame_index| {
                                                    const drag_frame = dragging_keyframe.frames.orderedRemove(frame_index);

                                                    if (dragging_keyframe.frames.items.len == 0) {
                                                        if (animation.keyframeIndex(dragging_keyframe.id)) |empty_kf_index| {
                                                            var empty_kf = animation.keyframes.orderedRemove(empty_kf_index);
                                                            empty_kf.frames.clearAndFree();
                                                        }
                                                    }

                                                    try new_keyframe.frames.append(drag_frame);
                                                }

                                                try animation.keyframes.append(new_keyframe);
                                            }
                                        }
                                    }
                                }
                            }

                            var draw_temp_node: bool = !secondary_down;

                            if (animation.getKeyframeFromFrame(dragging_frame_id)) |dragging_keyframe| {
                                if (animation.getKeyframeMilliseconds(ms)) |hovered_keyframe| {
                                    if (hovered_keyframe.id == dragging_keyframe.id)
                                        draw_temp_node = false;
                                }
                            }

                            if (draw_temp_node) {
                                const index_float: f32 = @floatFromInt(if (animation.getKeyframeMilliseconds(ms)) |kf| kf.frames.items.len else 0);

                                const y: f32 = imgui.getWindowPos().y + (index_float * ((frame_node_radius * 2.0) + frame_node_spacing)) + work_area_offset;

                                const color = animation.getFrameNodeColor(dragging_frame_id);

                                draw_list.addCircleFilled(.{ .x = x, .y = y }, frame_node_radius * 2.0, color, 20);
                                draw_list.addCircle(.{ .x = x, .y = y }, frame_node_radius * 2.0 + 1.0, pixi.editor.theme.text_background.toU32());
                            }
                        }
                    }

                    // Draw temporary nodes at the mouse position for keyframes
                    // Also handle creating
                    if (keyframe_dragging) |dragging_keyframe_id| {
                        if (animation.keyframe(dragging_keyframe_id)) |dragging_keyframe| {
                            if (pixi.app.mouse.button(.primary)) |bt| {
                                if (bt.released()) {
                                    if (line_hovered and window_hovered and animation.getKeyframeMilliseconds(ms) == null) {
                                        var dragged_keyframe = dragging_keyframe;

                                        if (secondary_down) {
                                            try animation.keyframes.append(.{
                                                .frames = std.ArrayList(pixi.Internal.Frame).init(pixi.app.allocator),
                                                .id = file.newKeyframeId(),
                                                .time = ms_float / 1000.0,
                                                .active_frame_id = dragging_keyframe.active_frame_id,
                                            });

                                            const new_keyframe = &animation.keyframes.items[animation.keyframes.items.len - 1];

                                            for (dragging_keyframe.frames.items) |fr| {
                                                try new_keyframe.frames.append(fr);
                                            }

                                            for (new_keyframe.frames.items) |*fr| {
                                                fr.id = file.newFrameId();
                                            }

                                            for (dragging_keyframe.frames.items, 0..) |*fr, fr_i| {
                                                fr.tween_id = new_keyframe.frames.items[fr_i].id;
                                            }

                                            dragged_keyframe = &animation.keyframes.items[animation.keyframes.items.len - 1];
                                        }

                                        dragged_keyframe.time = ms_float / 1000.0;
                                    }
                                }
                            }

                            if (line_hovered and window_hovered and frame_node_dragging == null) {
                                for (dragging_keyframe.frames.items, 0..) |fr, fr_i| {
                                    const index_float: f32 = @floatFromInt(fr_i);

                                    const y: f32 = imgui.getWindowPos().y + (index_float * ((frame_node_radius * 2.0) + frame_node_spacing)) + work_area_offset;

                                    const color = animation.getFrameNodeColor(fr.id);

                                    draw_list.addCircleFilled(.{ .x = x, .y = y }, frame_node_radius * 2.0, color, 20);
                                    draw_list.addCircle(.{ .x = x, .y = y }, frame_node_radius * 2.0 + 1.0, pixi.editor.theme.text_background.toU32());
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
