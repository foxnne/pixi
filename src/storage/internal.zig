const std = @import("std");
const pixi = @import("../pixi.zig");
const zstbi = @import("zstbi");
const storage = @import("storage.zig");
const zip = @import("zip");
const mach = @import("mach");
const imgui = @import("zig-imgui");
const Core = mach.Core;
const gpu = mach.gpu;
const zmath = @import("zmath");

const external = @import("external.zig");

pub const Pixi = struct {
    path: [:0]const u8,
    width: u32,
    height: u32,
    tile_width: u32,
    tile_height: u32,
    camera: pixi.gfx.Camera = .{},
    layers: std.ArrayList(Layer),
    sprites: std.ArrayList(Sprite),
    animations: std.ArrayList(Animation),
    keyframe_animations: std.ArrayList(KeyframeAnimation),
    keyframe_animation_texture: pixi.gfx.Texture,
    keyframe_transform_texture: TransformTexture,
    deleted_layers: std.ArrayList(Layer),
    deleted_heightmap_layers: std.ArrayList(Layer),
    deleted_animations: std.ArrayList(Animation),
    flipbook_camera: pixi.gfx.Camera = .{},
    flipbook_scroll: f32 = 0.0,
    flipbook_scroll_request: ?ScrollRequest = null,
    flipbook_view: FlipbookView = .canvas,
    selected_layer_index: usize = 0,
    selected_sprite_index: usize = 0,
    selected_sprites: std.ArrayList(usize),
    selected_animation_index: usize = 0,
    selected_animation_state: AnimationState = .pause,
    selected_animation_elapsed: f32 = 0.0,
    selected_keyframe_animation_index: usize = 0,
    selected_keyframe_animation_state: AnimationState = .pause,
    selected_keyframe_animation_elapsed: f32 = 0.0,
    selected_keyframe_animation_loop: bool = false,
    background: pixi.gfx.Texture,
    temporary_layer: Layer,
    selection_layer: Layer,
    transform_texture: ?TransformTexture = null,
    transform_bindgroup: ?*gpu.BindGroup = null,
    transform_compute_buffer: ?*gpu.Buffer = null,
    transform_staging_buffer: ?*gpu.Buffer = null,
    transform_compute_bindgroup: ?*gpu.BindGroup = null,
    heightmap: Heightmap = .{},
    history: History,
    buffers: Buffers,
    counter: u32 = 0,
    layer_counter: u32 = 0,
    keyframe_counter: u32 = 0,
    frame_counter: u32 = 0,
    saving: bool = false,

    pub const ScrollRequest = struct {
        from: f32,
        to: f32,
        elapsed: f32 = 0.0,
        state: AnimationState,
    };

    pub const TransformTexture = struct {
        vertices: [4]TransformVertex,
        pivot: ?TransformVertex = null,
        control: ?TransformControl = null,
        pan: bool = false,
        rotate: bool = false,
        rotation: f32 = 0.0,
        rotation_grip_height: f32 = 8.0,
        texture: pixi.gfx.Texture,
        confirm: bool = false,
        pivot_move: bool = false,
        pivot_offset_angle: f32 = 0.0,
        temporary: bool = false,
        keyframe_parent_id: ?u32 = null,
    };

    pub const TransformVertex = struct {
        position: zmath.F32x4,
    };

    pub const TransformControl = struct {
        index: usize,
        mode: TransformMode,
    };

    pub const TransformMode = enum {
        locked_aspect,
        free_aspect,
        free,
    };

    pub const FlipbookView = enum { canvas, timeline };

    pub const AnimationState = enum { pause, play };
    pub const Canvas = enum { primary, flipbook };

    pub const History = @import("History.zig");
    pub const Buffers = @import("Buffers.zig");

    pub const Heightmap = struct {
        visible: bool = false,
        layer: ?Layer = null,

        pub fn enable(self: *Heightmap) void {
            if (self.layer != null) {
                self.visible = true;
            } else {
                pixi.state.popups.heightmap = true;
            }
        }

        pub fn disable(self: *Heightmap) void {
            self.visible = false;
            if (pixi.state.tools.current == .heightmap) {
                pixi.state.tools.swap();
            }
        }

        pub fn toggle(self: *Heightmap) void {
            if (self.visible) self.disable() else self.enable();
        }
    };

    pub fn dirty(self: Pixi) bool {
        return self.history.bookmark != 0;
    }

    pub fn canvasCenterOffset(self: *Pixi, canvas: Canvas) [2]f32 {
        const width: f32 = switch (canvas) {
            .primary => @floatFromInt(self.width),
            .flipbook => @floatFromInt(self.tile_width),
        };
        const height: f32 = switch (canvas) {
            .primary => @floatFromInt(self.height),
            .flipbook => @floatFromInt(self.tile_height),
        };

        return .{ -width / 2.0, -height / 2.0 };
    }

    pub fn newId(file: *Pixi) u32 {
        file.counter += 1;
        return file.counter;
    }

    pub fn newLayerId(file: *Pixi) u32 {
        file.layer_counter += 1;
        return file.layer_counter;
    }

    pub fn newKeyframeId(file: *Pixi) u32 {
        file.keyframe_counter += 1;
        return file.keyframe_counter;
    }

    pub fn newFrameId(file: *Pixi) u32 {
        file.frame_counter += 1;
        return file.frame_counter;
    }

    pub const SampleToolOptions = struct {
        texture_position_offset: [2]f32 = .{ 0.0, 0.0 },
    };

    pub fn processSampleTool(file: *Pixi, canvas: Canvas, options: SampleToolOptions) void {
        const sample_key = if (pixi.state.hotkeys.hotkey(.{ .proc = .sample })) |hotkey| hotkey.down() else false;
        const sample_button = if (pixi.state.mouse.button(.sample)) |sample| sample.down() else false;

        if (!sample_key and !sample_button) return;

        imgui.setMouseCursor(imgui.MouseCursor_None);
        file.camera.drawCursor(pixi.assets.pixi_atlas.dropper_0_default, 0xFFFFFFFF);

        const mouse_position = pixi.state.mouse.position;
        var camera = switch (canvas) {
            .primary => file.camera,
            .flipbook => file.flipbook_camera,
        };

        var canvas_center_offset = canvasCenterOffset(file, canvas);
        canvas_center_offset[0] += options.texture_position_offset[0];
        canvas_center_offset[1] += options.texture_position_offset[1];

        const pixel_coord_opt = switch (canvas) {
            .primary => camera.pixelCoordinates(.{
                .texture_position = canvas_center_offset,
                .position = mouse_position,
                .width = file.width,
                .height = file.height,
            }),
            .flipbook => camera.flipbookPixelCoordinates(file, .{
                .sprite_position = canvas_center_offset,
                .position = mouse_position,
                .width = file.width,
                .height = file.height,
            }),
        };

        if (pixel_coord_opt) |pixel_coord| {
            const pixel = .{ @as(usize, @intFromFloat(pixel_coord[0])), @as(usize, @intFromFloat(pixel_coord[1])) };

            if (!file.heightmap.visible) {
                var color: [4]u8 = .{ 0, 0, 0, 0 };

                var layer_index: ?usize = null;
                // Go through all layers until we hit an opaque pixel
                for (file.layers.items, 0..) |working_layer, i| {
                    if (!working_layer.visible) continue;

                    const p = working_layer.getPixel(pixel);
                    if (p[3] > 0) {
                        color = p;
                        layer_index = i;
                        if (pixi.state.settings.eyedropper_auto_switch_layer)
                            file.selected_layer_index = i;
                        break;
                    } else continue;
                }

                if (color[3] == 0) {
                    if (pixi.state.settings.eyedropper_auto_switch_layer)
                        pixi.state.tools.set(.eraser);
                } else {
                    if (pixi.state.tools.current == .eraser) {
                        if (pixi.state.settings.eyedropper_auto_switch_layer)
                            pixi.state.tools.set(pixi.state.tools.previous);
                    }
                    pixi.state.colors.primary = color;
                }

                if (layer_index) |index| {
                    camera.drawLayerTooltip(index);
                    camera.drawColorTooltip(color);
                } else {
                    camera.drawColorTooltip(color);
                }
            } else {
                if (file.heightmap.layer) |hml| {
                    const p = hml.getPixel(pixel);
                    if (p[3] > 0) {
                        pixi.state.colors.height = p[0];
                    } else {
                        pixi.state.tools.set(.eraser);
                    }
                }
            }
        }
    }

    pub const StrokeToolOptions = struct {
        texture_position_offset: [2]f32 = .{ 0.0, 0.0 },
    };

    pub fn processStrokeTool(file: *Pixi, canvas: Canvas, options: StrokeToolOptions) !void {
        if (switch (pixi.state.tools.current) {
            .pencil, .eraser, .heightmap => false,
            else => true,
        }) return;

        const sample_key = if (pixi.state.hotkeys.hotkey(.{ .proc = .sample })) |hotkey| hotkey.down() else false;
        const sample_button = if (pixi.state.mouse.button(.sample)) |sample| sample.down() else false;

        if (sample_key or sample_button) return;

        switch (pixi.state.tools.current) {
            .pencil, .heightmap => {
                imgui.setMouseCursor(imgui.MouseCursor_None);
                file.camera.drawCursor(pixi.assets.pixi_atlas.pencil_0_default, 0xFFFFFFFF);
            },
            .eraser => {
                imgui.setMouseCursor(imgui.MouseCursor_None);
                file.camera.drawCursor(pixi.assets.pixi_atlas.eraser_0_default, 0xFFFFFFFF);
            },
            else => {},
        }

        var canvas_center_offset = canvasCenterOffset(file, canvas);
        canvas_center_offset[0] += options.texture_position_offset[0];
        canvas_center_offset[1] += options.texture_position_offset[1];
        const mouse_position = pixi.state.mouse.position;
        const previous_mouse_position = pixi.state.mouse.previous_position;

        var selected_layer: pixi.storage.Internal.Layer = if (file.heightmap.visible) if (file.heightmap.layer) |hml| hml else file.layers.items[file.selected_layer_index] else file.layers.items[file.selected_layer_index];

        const camera = switch (canvas) {
            .primary => file.camera,
            .flipbook => file.flipbook_camera,
        };

        const pixel_coords_opt = switch (canvas) {
            .primary => camera.pixelCoordinates(.{
                .texture_position = canvas_center_offset,
                .position = mouse_position,
                .width = file.width,
                .height = file.height,
            }),

            .flipbook => camera.flipbookPixelCoordinates(file, .{
                .sprite_position = canvas_center_offset,
                .position = mouse_position,
                .width = file.width,
                .height = file.height,
            }),
        };

        if (if (pixi.state.mouse.button(.primary)) |primary| primary.down() else false) {
            const color = switch (pixi.state.tools.current) {
                .pencil => if (file.heightmap.visible) [_]u8{ pixi.state.colors.height, 0, 0, 255 } else pixi.state.colors.primary,
                .eraser => [_]u8{ 0, 0, 0, 0 },
                .heightmap => [_]u8{ pixi.state.colors.height, 0, 0, 255 },
                else => unreachable,
            };

            if (!std.mem.eql(f32, &pixi.state.mouse.position, &pixi.state.mouse.previous_position)) {
                if (pixel_coords_opt) |pixel_coord| {
                    const prev_pixel_coords_opt = switch (canvas) {
                        .primary => camera.pixelCoordinates(.{
                            .texture_position = canvas_center_offset,
                            .position = previous_mouse_position,
                            .width = file.width,
                            .height = file.height,
                        }),

                        .flipbook => camera.flipbookPixelCoordinates(file, .{
                            .sprite_position = canvas_center_offset,
                            .position = previous_mouse_position,
                            .width = file.width,
                            .height = file.height,
                        }),
                    };

                    if (prev_pixel_coords_opt) |prev_pixel_coord| {
                        const pixel_coords = try pixi.algorithms.brezenham.process(prev_pixel_coord, pixel_coord);
                        var previous_pixel_opt: ?[2]usize = null;
                        for (pixel_coords) |p_coord| {
                            const pixel = .{ @as(usize, @intFromFloat(p_coord[0])), @as(usize, @intFromFloat(p_coord[1])) };

                            if (file.heightmap.visible) {
                                if (pixi.state.tools.current == .heightmap) {
                                    const tile_width: usize = @intCast(file.tile_width);
                                    const tile_column = @divTrunc(pixel[0], tile_width);
                                    const min_column = tile_column * tile_width;
                                    const max_column = min_column + tile_width;

                                    defer previous_pixel_opt = pixel;
                                    if (previous_pixel_opt) |previous_pixel| {
                                        if (pixel[1] != previous_pixel[1]) {
                                            if (pixi.state.hotkeys.hotkey(.{ .proc = .primary })) |hk| {
                                                if (hk.down()) {
                                                    const pixel_signed: i32 = @intCast(pixel[1]);
                                                    const previous_pixel_signed: i32 = @intCast(previous_pixel[1]);
                                                    const difference: i32 = pixel_signed - previous_pixel_signed;
                                                    const sign: i32 = @intFromFloat(std.math.sign((pixi.state.mouse.position[1] - pixi.state.mouse.previous_position[1]) * -1.0));
                                                    pixi.state.colors.height = @intCast(std.math.clamp(@as(i32, @intCast(pixi.state.colors.height)) + difference * sign, 0, 255));
                                                }
                                            }
                                        } else {
                                            continue;
                                        }
                                    }
                                    var current_pixel: [2]usize = pixel;

                                    while (current_pixel[0] > min_column) : (current_pixel[0] -= 1) {
                                        var valid: bool = false;
                                        for (file.layers.items) |working_layer| {
                                            if (working_layer.getPixel(current_pixel)[3] != 0) {
                                                valid = true;
                                                break;
                                            }
                                        }
                                        if (valid) {
                                            const current_index: usize = selected_layer.getPixelIndex(current_pixel);
                                            const current_value: [4]u8 = selected_layer.getPixel(current_pixel);

                                            if (!std.mem.containsAtLeast(usize, file.buffers.stroke.indices.items, 1, &.{current_index}))
                                                try file.buffers.stroke.append(current_index, current_value);
                                            selected_layer.setPixel(current_pixel, color, false);
                                        } else break;
                                    }

                                    current_pixel = pixel;

                                    while (current_pixel[0] < max_column) : (current_pixel[0] += 1) {
                                        var valid: bool = false;
                                        for (file.layers.items) |working_layer| {
                                            if (working_layer.getPixel(current_pixel)[3] != 0) {
                                                valid = true;
                                                break;
                                            }
                                        }
                                        if (valid) {
                                            const current_index: usize = selected_layer.getPixelIndex(current_pixel);
                                            const current_value: [4]u8 = selected_layer.getPixel(current_pixel);

                                            if (!std.mem.containsAtLeast(usize, file.buffers.stroke.indices.items, 1, &.{current_index}))
                                                try file.buffers.stroke.append(current_index, current_value);
                                            selected_layer.setPixel(current_pixel, color, false);
                                        } else break;
                                    }
                                } else {
                                    const size: u32 = pixi.state.tools.stroke_size;

                                    for (0..(size * size)) |stroke_index| {
                                        var valid: bool = false;
                                        var i: usize = 0;
                                        var c: [4]u8 = .{ 0, 0, 0, 0 };
                                        for (file.layers.items) |working_layer| {
                                            if (working_layer.getIndexShapeOffset(pixel, stroke_index)) |shape_result| {
                                                if (shape_result.color[3] != 0) {
                                                    valid = true;
                                                    i = shape_result.index;
                                                    c = shape_result.color;
                                                    break;
                                                }
                                            }
                                        }
                                        if (valid) {
                                            if (selected_layer.getIndexShapeOffset(pixel, stroke_index)) |shape_result| {
                                                if (!std.mem.containsAtLeast(usize, file.buffers.stroke.indices.items, 1, &.{shape_result.index}))
                                                    try file.buffers.stroke.append(shape_result.index, shape_result.color);
                                                selected_layer.setPixelIndex(shape_result.index, color, false);
                                            }
                                        }
                                    }
                                }
                            } else {
                                const size: u32 = pixi.state.tools.stroke_size;

                                for (0..(size * size)) |stroke_index| {
                                    if (selected_layer.getIndexShapeOffset(pixel, stroke_index)) |result| {
                                        if (!std.mem.containsAtLeast(usize, file.buffers.stroke.indices.items, 1, &.{result.index}))
                                            try file.buffers.stroke.append(result.index, result.color);
                                        selected_layer.setPixelIndex(result.index, color, false);

                                        // if (color[3] == 0) {
                                        //     if (file.heightmap.layer) |*working_layer| {
                                        //         working_layer.setPixelIndex(result.index, .{ 0, 0, 0, 0 }, false);
                                        //     }
                                        // }
                                    }
                                }

                                selected_layer.texture.update(pixi.state.device);

                                // if (color[3] == 0) {
                                //     if (file.heightmap.layer) |*working_layer| {
                                //         working_layer.texture.update(core.device);
                                //     }
                                // }
                            }
                        }

                        selected_layer.texture.update(pixi.state.device);
                        pixi.state.allocator.free(pixel_coords);
                    }
                }
            } else if (if (pixi.state.mouse.button(.primary)) |primary| primary.pressed() else false) {
                if (pixel_coords_opt) |pixel_coord| {
                    const pixel: [2]usize = .{ @intFromFloat(pixel_coord[0]), @intFromFloat(pixel_coord[1]) };

                    if (file.heightmap.visible) {
                        if (pixi.state.tools.current == .heightmap) {
                            const tile_width: usize = @intCast(file.tile_width);

                            const tile_column = @divTrunc(pixel[0], tile_width);
                            const min_column = tile_column * tile_width;
                            const max_column = min_column + tile_width;

                            var current_pixel: [2]usize = pixel;

                            while (current_pixel[0] > min_column) : (current_pixel[0] -= 1) {
                                var valid: bool = false;
                                for (file.layers.items) |working_layer| {
                                    if (working_layer.getPixel(current_pixel)[3] != 0) {
                                        valid = true;
                                        break;
                                    }
                                }
                                if (valid) {
                                    const current_index: usize = selected_layer.getPixelIndex(current_pixel);
                                    const current_value: [4]u8 = selected_layer.getPixel(current_pixel);

                                    if (!std.mem.containsAtLeast(usize, file.buffers.stroke.indices.items, 1, &.{current_index}))
                                        try file.buffers.stroke.append(current_index, current_value);
                                    selected_layer.setPixel(current_pixel, color, true);
                                } else break;
                            }

                            current_pixel = pixel;

                            while (current_pixel[0] < max_column) : (current_pixel[0] += 1) {
                                var valid: bool = false;
                                for (file.layers.items) |working_layer| {
                                    if (working_layer.getPixel(current_pixel)[3] != 0) {
                                        valid = true;
                                        break;
                                    }
                                }
                                if (valid) {
                                    const current_index: usize = selected_layer.getPixelIndex(current_pixel);
                                    const current_value: [4]u8 = selected_layer.getPixel(current_pixel);

                                    if (!std.mem.containsAtLeast(usize, file.buffers.stroke.indices.items, 1, &.{current_index}))
                                        try file.buffers.stroke.append(current_index, current_value);
                                    selected_layer.setPixel(current_pixel, color, true);
                                } else break;
                            }
                        } else {
                            const size: u32 = pixi.state.tools.stroke_size;

                            for (0..(size * size)) |stroke_index| {
                                var valid: bool = false;
                                var i: usize = 0;
                                var c: [4]u8 = .{ 0, 0, 0, 0 };
                                for (file.layers.items) |working_layer| {
                                    if (working_layer.getIndexShapeOffset(pixel, stroke_index)) |shape_result| {
                                        if (shape_result.color[3] != 0) {
                                            valid = true;
                                            i = shape_result.index;
                                            c = shape_result.color;
                                            break;
                                        }
                                    }
                                }
                                if (valid) {
                                    if (selected_layer.getIndexShapeOffset(pixel, stroke_index)) |shape_result| {
                                        if (!std.mem.containsAtLeast(usize, file.buffers.stroke.indices.items, 1, &.{shape_result.index}))
                                            try file.buffers.stroke.append(shape_result.index, shape_result.color);
                                        selected_layer.setPixelIndex(shape_result.index, color, false);
                                    }
                                }
                            }

                            selected_layer.texture.update(pixi.state.device);
                        }
                    } else {
                        const size: u32 = pixi.state.tools.stroke_size;

                        for (0..(size * size)) |stroke_index| {
                            if (selected_layer.getIndexShapeOffset(pixel, stroke_index)) |result| {
                                try file.buffers.stroke.append(result.index, result.color);
                                selected_layer.setPixelIndex(result.index, color, false);

                                if (color[3] == 0) {
                                    if (file.heightmap.layer) |*working_layer| {
                                        working_layer.setPixelIndex(result.index, .{ 0, 0, 0, 0 }, false);
                                    }
                                }
                            }
                        }

                        selected_layer.texture.update(pixi.state.device);

                        if (color[3] == 0) {
                            if (file.heightmap.layer) |*working_layer| {
                                working_layer.texture.update(pixi.state.device);
                            }
                        }
                    }
                }
            }
        } else { // Not actively drawing, but hovering over canvas
            if (pixel_coords_opt) |pixel_coord| {
                const pixel = .{ @as(usize, @intFromFloat(pixel_coord[0])), @as(usize, @intFromFloat(pixel_coord[1])) };
                const color: [4]u8 = switch (pixi.state.tools.current) {
                    .pencil => if (file.heightmap.visible) .{ pixi.state.colors.height, 0, 0, 255 } else pixi.state.colors.primary,
                    .eraser => .{ 255, 255, 255, 255 },
                    .heightmap => .{ pixi.state.colors.height, 0, 0, 255 },
                    else => unreachable,
                };

                switch (pixi.state.tools.current) {
                    .pencil, .eraser => {
                        const size: u32 = @intCast(pixi.state.tools.stroke_size);
                        for (0..(size * size)) |index| {
                            if (file.temporary_layer.getIndexShapeOffset(pixel, index)) |result| {
                                file.temporary_layer.setPixelIndex(result.index, color, false);
                            }
                        }
                        file.temporary_layer.texture.update(pixi.state.device);
                    },
                    else => {
                        file.temporary_layer.setPixel(pixel, color, true);
                    },
                }
            }

            // Submit the stroke change buffer
            if (file.buffers.stroke.indices.items.len > 0 and if (pixi.state.mouse.button(.primary)) |primary| primary.released() else false) {
                const layer_index: i32 = if (file.heightmap.visible) -1 else @as(i32, @intCast(file.selected_layer_index));
                const change = try file.buffers.stroke.toChange(layer_index);
                try file.history.append(change);
            }
        }
    }

    pub fn processSelectionTool(file: *Pixi, canvas: Canvas, options: StrokeToolOptions) !void {
        if (switch (pixi.state.tools.current) {
            .selection => false,
            else => true,
        }) return;

        const sample_key = if (pixi.state.hotkeys.hotkey(.{ .proc = .sample })) |hotkey| hotkey.down() else false;
        const sample_button = if (pixi.state.mouse.button(.sample)) |sample| sample.down() else false;

        const add: bool = if (pixi.state.hotkeys.hotkey(.{ .proc = .primary })) |hk| hk.down() else false;
        const rem: bool = if (pixi.state.hotkeys.hotkey(.{ .proc = .secondary })) |hk| hk.down() else false;
        const pressed: bool = if (pixi.state.mouse.button(.primary)) |bt| bt.pressed() else false;

        if (sample_key or sample_button) return;

        const cursor_sprite_index: usize = if (add) pixi.assets.pixi_atlas.selection_add_0_default else if (rem) pixi.assets.pixi_atlas.selection_rem_0_default else pixi.assets.pixi_atlas.selection_0_default;
        imgui.setMouseCursor(imgui.MouseCursor_None);
        file.camera.drawCursor(cursor_sprite_index, 0xFFFFFFFF);

        var canvas_center_offset = canvasCenterOffset(file, canvas);
        canvas_center_offset[0] += options.texture_position_offset[0];
        canvas_center_offset[1] += options.texture_position_offset[1];
        const mouse_position = pixi.state.mouse.position;
        const previous_mouse_position = pixi.state.mouse.previous_position;
        _ = previous_mouse_position; // autofix

        const selected_layer: pixi.storage.Internal.Layer = if (file.heightmap.visible) if (file.heightmap.layer) |hml| hml else file.layers.items[file.selected_layer_index] else file.layers.items[file.selected_layer_index];
        _ = selected_layer; // autofix

        const camera = switch (canvas) {
            .primary => file.camera,
            .flipbook => file.flipbook_camera,
        };

        const pixel_coords_opt = switch (canvas) {
            .primary => camera.pixelCoordinates(.{
                .texture_position = canvas_center_offset,
                .position = mouse_position,
                .width = file.width,
                .height = file.height,
            }),

            .flipbook => camera.flipbookPixelCoordinates(file, .{
                .sprite_position = canvas_center_offset,
                .position = mouse_position,
                .width = file.width,
                .height = file.height,
            }),
        };

        if (pixel_coords_opt) |pixel_coord| {
            const pixel = .{ @as(usize, @intFromFloat(pixel_coord[0])), @as(usize, @intFromFloat(pixel_coord[1])) };
            const stroke_size: u32 = @intCast(pixi.state.tools.stroke_size);

            if (!add and !rem and pressed) {
                file.selection_layer.clear(false);
            }

            const selection_opacity: u8 = 200;

            if (if (pixi.state.mouse.button(.primary)) |primary| primary.down() else false) {
                for (0..(stroke_size * stroke_size)) |index| {
                    if (file.selection_layer.getIndexShapeOffset(pixel, index)) |result| {
                        var color: [4]u8 = if (@mod(@divTrunc(result.index, file.width) + result.index, 2) == 0)
                            if (pixi.state.selection_invert) .{ 255, 255, 255, selection_opacity } else .{ 0, 0, 0, selection_opacity }
                        else if (pixi.state.selection_invert) .{ 0, 0, 0, selection_opacity } else .{ 255, 255, 255, selection_opacity };

                        if (rem) @memset(&color, 0);

                        if (file.layers.items[file.selected_layer_index].pixels()[result.index][3] != 0)
                            file.selection_layer.setPixelIndex(result.index, color, false);
                    }
                }
                file.selection_layer.texture.update(pixi.state.device);
            } else {
                for (0..(stroke_size * stroke_size)) |index| {
                    if (file.temporary_layer.getIndexShapeOffset(pixel, index)) |result| {
                        const color: [4]u8 = if (@mod(@divTrunc(result.index, file.width) + result.index, 2) == 0)
                            if (pixi.state.selection_invert) .{ 255, 255, 255, selection_opacity } else .{ 0, 0, 0, selection_opacity }
                        else if (pixi.state.selection_invert) .{ 0, 0, 0, selection_opacity } else .{ 255, 255, 255, selection_opacity };

                        if (file.layers.items[file.selected_layer_index].pixels()[result.index][3] != 0)
                            file.temporary_layer.setPixelIndex(result.index, color, false);
                    }
                }
                file.temporary_layer.texture.update(pixi.state.device);
            }
        }
    }

    pub fn processAnimationTool(file: *Pixi) !void {
        if (pixi.state.sidebar != .animations or pixi.state.tools.current != .animation) return;

        const canvas_center_offset = canvasCenterOffset(file, .primary);
        const mouse_position = pixi.state.mouse.position;

        if (file.camera.pixelCoordinates(.{
            .texture_position = canvas_center_offset,
            .position = mouse_position,
            .width = file.width,
            .height = file.height,
        })) |pixel_coord| {
            const pixel: [2]usize = .{ @intFromFloat(pixel_coord[0]), @intFromFloat(pixel_coord[1]) };

            const tile_column = @divTrunc(pixel[0], @as(usize, @intCast(file.tile_width)));
            const tile_row = @divTrunc(pixel[1], @as(usize, @intCast(file.tile_height)));

            const tiles_wide = @divExact(@as(usize, @intCast(file.width)), @as(usize, @intCast(file.tile_width)));
            const tile_index = tile_column + tile_row * tiles_wide;

            if (tile_index >= pixi.state.popups.animation_start) {
                pixi.state.popups.animation_length = (tile_index - pixi.state.popups.animation_start) + 1;
            } else {
                pixi.state.popups.animation_start = tile_index;
                pixi.state.popups.animation_length = 1;
            }

            if (if (pixi.state.mouse.button(.primary)) |primary| primary.pressed() else false)
                pixi.state.popups.animation_start = tile_index;

            if (if (pixi.state.mouse.button(.primary)) |primary| primary.released() else false) {
                if (pixi.state.hotkeys.hotkey(.{ .proc = .primary })) |primary| {
                    if (primary.down()) {
                        var valid: bool = true;
                        var i: usize = pixi.state.popups.animation_start;
                        while (i < pixi.state.popups.animation_start + pixi.state.popups.animation_length) : (i += 1) {
                            if (file.getAnimationIndexFromSpriteIndex(i)) |_| {
                                valid = false;
                                break;
                            }
                        }
                        if (valid) {
                            // Create new animation
                            pixi.state.popups.animation_name = [_:0]u8{0} ** 128;
                            const new_name = "New_Animation";
                            @memcpy(pixi.state.popups.animation_name[0..new_name.len], new_name);
                            pixi.state.popups.animation_state = .create;
                            pixi.state.popups.animation_fps = pixi.state.popups.animation_length;
                            pixi.state.popups.animation = true;
                        }
                    } else {
                        if (file.animations.items.len > 0) {
                            var animation = &file.animations.items[file.selected_animation_index];
                            var valid: bool = true;
                            var i: usize = pixi.state.popups.animation_start;
                            while (i < pixi.state.popups.animation_start + pixi.state.popups.animation_length) : (i += 1) {
                                if (file.getAnimationIndexFromSpriteIndex(i)) |match_index| {
                                    if (match_index != file.selected_animation_index) {
                                        valid = false;
                                        break;
                                    }
                                }
                            }
                            if (valid) {
                                // Edit existing animation
                                var change: History.Change = .{ .animation = .{
                                    .index = file.selected_animation_index,
                                    .name = [_:0]u8{0} ** 128,
                                    .fps = animation.fps,
                                    .start = animation.start,
                                    .length = animation.length,
                                } };
                                @memcpy(change.animation.name[0..animation.name.len], animation.name);

                                var sprite_index = animation.start;
                                while (sprite_index < animation.start + animation.length) : (sprite_index += 1) {
                                    pixi.state.allocator.free(file.sprites.items[sprite_index].name);
                                    file.sprites.items[sprite_index].name = std.fmt.allocPrintZ(pixi.state.allocator, "Sprite_{d}", .{sprite_index}) catch unreachable;
                                }

                                animation.start = pixi.state.popups.animation_start;
                                animation.length = pixi.state.popups.animation_length;

                                sprite_index = animation.start;
                                var animation_index: usize = 0;
                                while (sprite_index < animation.start + animation.length) : (sprite_index += 1) {
                                    pixi.state.allocator.free(file.sprites.items[sprite_index].name);
                                    file.sprites.items[sprite_index].name = std.fmt.allocPrintZ(pixi.state.allocator, "{s}_{d}", .{ animation.name[0..], animation_index }) catch unreachable;
                                    animation_index += 1;
                                }

                                try file.history.append(change);
                            }
                        }
                    }
                }
            }
        }
    }

    pub const FillToolOptions = struct {
        texture_position_offset: [2]f32 = .{ 0.0, 0.0 },
    };

    // Internal dfs function for flood fill
    fn fillToolDFS(file: *Pixi, fill_layer: Layer, pixels: ([][4]u8), x: usize, y: usize, bounds: [4]usize, original_color: [4]u8, new_color: [4]u8) !void {
        if (x >= bounds[0] + bounds[2] or y >= bounds[1] + bounds[3] or x < bounds[0] or y < bounds[1]) {
            return;
        }
        const pixel_index = fill_layer.getPixelIndex(.{ x, y });
        const color = pixels[pixel_index];
        if (!std.mem.eql(u8, &color, &original_color)) {
            return;
        }

        pixels[pixel_index] = new_color;

        // Recursively fill adjacent pixels
        if (@as(i32, @intCast(x)) - 1 >= 0) try fillToolDFS(file, fill_layer, pixels, x - 1, y, bounds, original_color, new_color);
        try fillToolDFS(file, fill_layer, pixels, x + 1, y, bounds, original_color, new_color);
        if (@as(i32, @intCast(y)) - 1 >= 0) try fillToolDFS(file, fill_layer, pixels, x, y - 1, bounds, original_color, new_color);
        try fillToolDFS(file, fill_layer, pixels, x, y + 1, bounds, original_color, new_color);
        try file.buffers.stroke.append(pixel_index, original_color);
    }

    pub fn processFillTool(file: *Pixi, canvas: Canvas, options: FillToolOptions) !void {
        if (switch (pixi.state.tools.current) {
            .bucket => false,
            else => true,
        }) return;

        const sample_key = if (pixi.state.hotkeys.hotkey(.{ .proc = .sample })) |hotkey| hotkey.down() else false;
        const sample_button = if (pixi.state.mouse.button(.sample)) |sample| sample.down() else false;

        if (sample_key or sample_button) return;

        imgui.setMouseCursor(imgui.MouseCursor_None);
        file.camera.drawCursor(pixi.assets.pixi_atlas.bucket_0_default, 0xFFFFFFFF);

        var canvas_center_offset = canvasCenterOffset(file, canvas);
        canvas_center_offset[0] += options.texture_position_offset[0];
        canvas_center_offset[1] += options.texture_position_offset[1];
        const mouse_position = pixi.state.mouse.position;

        var selected_layer: pixi.storage.Internal.Layer = file.layers.items[file.selected_layer_index];

        const camera = switch (canvas) {
            .primary => file.camera,
            .flipbook => file.flipbook_camera,
        };

        const pixel_coords_opt = switch (canvas) {
            .primary => camera.pixelCoordinates(.{
                .texture_position = canvas_center_offset,
                .position = mouse_position,
                .width = file.width,
                .height = file.height,
            }),

            .flipbook => camera.flipbookPixelCoordinates(file, .{
                .sprite_position = canvas_center_offset,
                .position = mouse_position,
                .width = file.width,
                .height = file.height,
            }),
        };

        if (if (pixi.state.mouse.button(.primary)) |primary| primary.pressed() else false) {
            if (pixel_coords_opt) |pixel_coord| {
                const pixel = .{ @as(usize, @intFromFloat(pixel_coord[0])), @as(usize, @intFromFloat(pixel_coord[1])) };

                const index = selected_layer.getPixelIndex(pixel);
                var pixels = @as([*][4]u8, @ptrCast(selected_layer.texture.image.data.ptr))[0 .. selected_layer.texture.image.data.len / 4];

                const tile_column = @divTrunc(pixel[0], @as(usize, @intCast(file.tile_width)));
                const tile_row = @divTrunc(pixel[1], @as(usize, @intCast(file.tile_height)));

                const bounds_x: usize = tile_column * @as(usize, @intCast(file.tile_width));
                const bounds_y: usize = tile_row * @as(usize, @intCast(file.tile_width));

                const bounds_width: usize = @intCast(file.tile_width);
                const bounds_height: usize = @intCast(file.tile_height);

                const bounds: [4]usize = .{ bounds_x, bounds_y, bounds_width, bounds_height };

                // create a copy of the old color
                var old_color = [_]u8{ 0, 0, 0, 0 };
                std.mem.copyForwards(u8, &old_color, pixels[index][0..4]);

                const new_color = pixi.state.colors.primary;
                if (std.mem.eql(u8, &new_color, &old_color)) {
                    return;
                }

                if (if (pixi.state.hotkeys.hotkey(.{ .proc = .primary })) |hk| hk.down() else false) {
                    for (bounds_x..bounds_x + bounds_width) |x| {
                        for (bounds_y..bounds_y + bounds_height) |y| {
                            if (std.mem.eql(u8, &selected_layer.getPixel(.{ x, y }), &old_color)) {
                                selected_layer.setPixel(.{ x, y }, new_color, false);

                                const pixel_index = selected_layer.getPixelIndex(.{ x, y });

                                try file.buffers.stroke.append(pixel_index, old_color);
                            }
                        }
                    }
                } else {
                    try fillToolDFS(file, selected_layer, pixels, pixel[0], pixel[1], bounds, old_color, new_color);
                }

                selected_layer.texture.update(pixi.state.device);

                if (file.buffers.stroke.indices.items.len > 0) {
                    const change = try file.buffers.stroke.toChange(@intCast(file.selected_layer_index));
                    try file.history.append(change);
                }
            }
        }
    }

    pub const TransformTextureControlsOptions = struct {
        canvas: Canvas = .primary,
        allow_vert_move: bool = true,
        allow_pivot_move: bool = true,
        color: ?u32 = null,
    };

    pub fn processTransformTextureControls(file: *Pixi, transform_texture: *pixi.storage.Internal.Pixi.TransformTexture, options: TransformTextureControlsOptions) void {
        const canvas = options.canvas;

        const window_hovered: bool = imgui.isWindowHovered(imgui.HoveredFlags_ChildWindows);

        const modifier_primary: bool = if (pixi.state.hotkeys.hotkey(.{ .proc = .primary })) |hk| hk.down() else false;
        const modifier_secondary: bool = if (pixi.state.hotkeys.hotkey(.{ .proc = .secondary })) |hk| hk.down() else false;

        if (transform_texture.control) |*control| {
            control.mode = if (modifier_primary) .free else if (modifier_secondary) .locked_aspect else .free_aspect;
        }

        const camera = switch (canvas) {
            .primary => file.camera,
            .flipbook => file.flipbook_camera,
        };

        var cursor: imgui.MouseCursor = imgui.MouseCursor_Arrow;

        const default_color = if (options.color) |color| color else pixi.state.theme.text.toU32();
        const highlight_color = pixi.state.theme.highlight_primary.toU32();

        const offset = zmath.loadArr2(if (canvas == .flipbook) .{ 0.0, 0.0 } else file.canvasCenterOffset(canvas));

        if (pixi.state.mouse.button(.primary)) |bt| {
            if (bt.released()) {
                transform_texture.control = null;
                transform_texture.pan = false;
                transform_texture.rotate = false;
                transform_texture.pivot_move = false;
            }
        }

        const grip_size: f32 = 10.0 / camera.zoom;
        const half_grip_size = grip_size / 2.0;

        var hovered_index: ?usize = null;

        var offset_rotation: f32 = -transform_texture.rotation;

        var pivot = if (transform_texture.pivot) |p| p.position else zmath.f32x4s(0.0);
        if (transform_texture.pivot == null) {
            for (&transform_texture.vertices) |*vertex| {
                pivot += vertex.position; // Collect centroid
            }
            pivot /= zmath.f32x4s(4.0); // Average position
        }

        if (transform_texture.keyframe_parent_id) |parent_id| {
            for (file.keyframe_animations.items) |animation| {
                for (animation.keyframes.items) |keyframe| {
                    for (keyframe.frames.items) |parent_frame| {
                        if (parent_frame.id == parent_id) {
                            const diff = parent_frame.pivot.position - pivot;

                            const angle = std.math.atan2(diff[1], diff[0]);

                            offset_rotation -= std.math.radiansToDegrees(angle) - 90.0;

                            camera.drawLine(
                                .{ pivot[0] + offset[0], pivot[1] + offset[1] },
                                .{ parent_frame.pivot.position[0] + offset[0], parent_frame.pivot.position[1] + offset[1] },
                                default_color,
                                1.0,
                            );
                        }
                    }
                }
            }
        }

        const radians = std.math.degreesToRadians(-offset_rotation);
        const rotation_matrix = zmath.rotationZ(radians);

        var rotated_vertices: [4]pixi.storage.Internal.Pixi.TransformVertex = .{
            .{ .position = zmath.mul(transform_texture.vertices[0].position - pivot, rotation_matrix) + pivot },
            .{ .position = zmath.mul(transform_texture.vertices[1].position - pivot, rotation_matrix) + pivot },
            .{ .position = zmath.mul(transform_texture.vertices[2].position - pivot, rotation_matrix) + pivot },
            .{ .position = zmath.mul(transform_texture.vertices[3].position - pivot, rotation_matrix) + pivot },
        };

        if (transform_texture.pivot_move) {
            if (window_hovered) {
                const mouse_position = pixi.state.mouse.position;

                const current_pixel_coords = camera.pixelCoordinatesRaw(.{
                    .texture_position = .{ offset[0], offset[1] },
                    .position = mouse_position,
                    .width = file.width,
                    .height = file.height,
                });
                const p = .{ .position = zmath.loadArr2(current_pixel_coords) };
                transform_texture.pivot = p;
            }
        }

        if (transform_texture.pivot) |p| {
            const rotation_control_height = transform_texture.rotation_grip_height;
            const control_offset = zmath.loadArr2(.{ 0.0, rotation_control_height });

            const midpoint = (transform_texture.vertices[0].position + transform_texture.vertices[1].position) / zmath.f32x4s(2.0);
            const control_center = midpoint - control_offset;

            const diff = p.position - control_center;

            const direction = pixi.math.Direction.find(8, -diff[0], -diff[1]);
            const angle: f32 = if (modifier_secondary) switch (direction) {
                .n => 180.0,
                .nw => 225.0,
                .w => 270.0,
                .sw => 315.0,
                .s => 0.0,
                .se => 45.0,
                .e => 90.0,
                .ne => 135.0,
                else => 180.0,
            } else @trunc(std.math.radiansToDegrees(std.math.atan2(diff[1], diff[0])) - 90.0);

            transform_texture.pivot_offset_angle = angle;
        }

        // Draw bounding lines from vertices
        for (&rotated_vertices, 0..) |*vertex, vertex_index| {
            const previous_index = switch (vertex_index) {
                0 => 3,
                1, 2, 3 => vertex_index - 1,
                else => unreachable,
            };

            const previous_position = rotated_vertices[previous_index].position;

            camera.drawLine(
                .{ offset[0] + previous_position[0], offset[1] + previous_position[1] },
                .{ offset[0] + vertex.position[0], offset[1] + vertex.position[1] },
                default_color,
                3.0,
            );
        }

        { // Draw controls for rotating
            const rotation_control_height = transform_texture.rotation_grip_height;
            var control_offset = zmath.loadArr2(.{ 0.0, rotation_control_height });
            control_offset = zmath.mul(control_offset, rotation_matrix);

            const midpoint = (rotated_vertices[0].position + rotated_vertices[1].position) / zmath.f32x4s(2.0);

            const control_center = midpoint - control_offset;

            camera.drawLine(.{ midpoint[0] + offset[0], midpoint[1] + offset[1] }, .{ control_center[0] + offset[0], control_center[1] + offset[1] }, default_color, 1.0);

            var hovered: bool = false;

            var control_scale: f32 = 1.0;
            if (camera.isHovered(.{ control_center[0] + offset[0] - half_grip_size, control_center[1] + offset[1] - half_grip_size, grip_size, grip_size }) and window_hovered) {
                hovered = true;
                cursor = imgui.MouseCursor_Hand;
                if (pixi.state.mouse.button(.primary)) |bt| {
                    if (bt.pressed()) {
                        transform_texture.rotate = true;
                    }
                }
            }

            if (transform_texture.rotate or hovered or transform_texture.pivot_move) {
                control_scale = 1.5;

                const dist = @sqrt(std.math.pow(f32, control_center[0] - pivot[0], 2) + std.math.pow(f32, control_center[1] - pivot[1], 2));
                camera.drawCircle(.{ pivot[0] + offset[0], pivot[1] + offset[1] }, dist * camera.zoom, 1.0, default_color);

                camera.drawTextWithShadow("{d}°", .{
                    transform_texture.rotation,
                }, .{
                    pivot[0] + offset[0] + (dist),
                    pivot[1] + offset[1] - (dist),
                }, default_color, 0xFF000000);

                // if (transform_texture.rotate) {
                //     camera.drawLine(.{ control_center[0] + offset[0], control_center[1] + offset[1] }, .{ centroid[0] + offset[0], centroid[1] + offset[1] }, default_color, 1.0);
                // }
            }

            camera.drawCircleFilled(.{ control_center[0] + offset[0], control_center[1] + offset[1] }, half_grip_size * camera.zoom * control_scale, default_color);
        }

        if (options.allow_vert_move) {
            // Draw controls for moving vertices
            for (&rotated_vertices, 0..) |*vertex, vertex_index| {
                const grip_rect: [4]f32 = .{ offset[0] + vertex.position[0] - half_grip_size, offset[1] + vertex.position[1] - half_grip_size, grip_size, grip_size };

                if (camera.isHovered(grip_rect) and options.allow_vert_move and window_hovered) {
                    hovered_index = vertex_index;
                    if (pixi.state.mouse.button(.primary)) |bt| {
                        if (bt.pressed()) {
                            transform_texture.control = .{
                                .index = vertex_index,
                                .mode = if (modifier_primary) .free else if (modifier_secondary) .locked_aspect else .free_aspect,
                            };
                            transform_texture.pivot = null;
                        }
                    }
                }

                const grip_color = if (hovered_index == vertex_index or if (transform_texture.control) |control| control.index == vertex_index else false) highlight_color else default_color;
                camera.drawRectFilled(grip_rect, grip_color);
            }
        }

        // Draw dimensions
        for (&rotated_vertices, 0..) |*vertex, vertex_index| {
            const previous_index = switch (vertex_index) {
                0 => 3,
                1, 2, 3 => vertex_index - 1,
                else => unreachable,
            };

            const previous_position = rotated_vertices[previous_index].position;

            var draw_dimensions: bool = false;
            var control_index: usize = 0;

            if (transform_texture.control) |control| {
                control_index = control.index;
                draw_dimensions = true;
            } else if (hovered_index) |index| {
                control_index = index;
                draw_dimensions = true;
            }
            if ((control_index == vertex_index or control_index == previous_index) and draw_dimensions) {
                const midpoint = ((vertex.position + previous_position) / zmath.f32x4s(2.0)) + zmath.loadArr2(.{ offset[0] + 1.5, offset[1] + 1.5 });

                const dist = @sqrt(std.math.pow(f32, vertex.position[0] - previous_position[0], 2) + std.math.pow(f32, vertex.position[1] - previous_position[1], 2));
                camera.drawTextWithShadow("{d}", .{dist}, .{ midpoint[0], midpoint[1] }, default_color, 0xFF000000);
            }
        }

        { // Handle hovering over transform texture

            const pivot_rect: [4]f32 = .{ pivot[0] + offset[0] - half_grip_size, pivot[1] + offset[1] - half_grip_size, grip_size, grip_size };
            const pivot_hovered = camera.isHovered(pivot_rect);

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

            const pan_hovered: bool = window_hovered and hovered_index == null and transform_texture.control == null and (camera.isHoveredTriangle(triangle_a) or camera.isHoveredTriangle(triangle_b));
            const mouse_pressed = if (pixi.state.mouse.button(.primary)) |bt| bt.pressed() else false;

            if (pan_hovered or pivot_hovered) {
                cursor = imgui.MouseCursor_Hand;
            }

            if (((pan_hovered and !pivot_hovered) or (pan_hovered and !options.allow_pivot_move)) and mouse_pressed) {
                transform_texture.pan = true;
            }
            if (pivot_hovered and mouse_pressed and options.allow_pivot_move) {
                transform_texture.pivot_move = true;
                transform_texture.control = null;
            }

            const centroid_scale: f32 = if (pan_hovered or transform_texture.pan or pivot_hovered or transform_texture.pivot_move) 1.5 else 1.0;
            camera.drawCircleFilled(.{ pivot[0] + offset[0], pivot[1] + offset[1] }, half_grip_size * camera.zoom * centroid_scale, default_color);
        }

        { // Handle setting the mouse cursor based on controls

            if (transform_texture.control) |c| {
                switch (c.index) {
                    0, 2 => cursor = imgui.MouseCursor_ResizeNWSE,
                    1, 3 => cursor = imgui.MouseCursor_ResizeNESW,
                    else => unreachable,
                }
            }

            if (options.allow_pivot_move) {
                if (hovered_index) |i| {
                    switch (i) {
                        0, 2 => cursor = imgui.MouseCursor_ResizeNWSE,
                        1, 3 => cursor = imgui.MouseCursor_ResizeNESW,
                        else => unreachable,
                    }
                }
            }

            if (transform_texture.pan or transform_texture.rotate or transform_texture.pivot_move)
                cursor = imgui.MouseCursor_ResizeAll;

            if (cursor != imgui.MouseCursor_None and cursor != imgui.MouseCursor_Arrow)
                imgui.setMouseCursor(cursor);
        }

        { // Handle moving the vertices when panning
            if (transform_texture.pan) {
                if (imgui.isWindowHovered(imgui.HoveredFlags_ChildWindows)) {
                    const mouse_position = pixi.state.mouse.position;
                    const prev_mouse_position = pixi.state.mouse.previous_position;
                    const current_pixel_coords = camera.pixelCoordinatesRaw(.{
                        .texture_position = .{ offset[0], offset[1] },
                        .position = mouse_position,
                        .width = file.width,
                        .height = file.height,
                    });

                    const previous_pixel_coords = camera.pixelCoordinatesRaw(.{
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

                    if (transform_texture.pivot) |*p|
                        p.position += zmath.loadArr2(delta);
                }
            }
        }

        { // Handle changing the rotation when rotating
            if (transform_texture.rotate) {
                if (imgui.isWindowHovered(imgui.HoveredFlags_ChildWindows)) {
                    const mouse_position = pixi.state.mouse.position;
                    const current_pixel_coords = camera.pixelCoordinatesRaw(.{
                        .texture_position = .{ offset[0], offset[1] },
                        .position = mouse_position,
                        .width = file.width,
                        .height = file.height,
                    });

                    const diff = zmath.loadArr2(current_pixel_coords) - pivot;
                    const direction = pixi.math.Direction.find(8, -diff[0], diff[1]);
                    var angle: f32 = if (modifier_secondary) switch (direction) {
                        .n => 180.0,
                        .ne => 225.0,
                        .e => 270.0,
                        .se => 315.0,
                        .s => 0.0,
                        .sw => 45.0,
                        .w => 90.0,
                        .nw => 135.0,
                        else => 180.0,
                    } else @trunc(std.math.radiansToDegrees(std.math.atan2(diff[1], diff[0])) + 90.0);

                    if (transform_texture.keyframe_parent_id) |parent_id| {
                        for (file.keyframe_animations.items) |animation| {
                            for (animation.keyframes.items) |keyframe| {
                                for (keyframe.frames.items) |parent_frame| {
                                    if (parent_frame.id == parent_id) {
                                        const parent_diff = parent_frame.pivot.position - pivot;

                                        const parent_angle = std.math.atan2(parent_diff[1], parent_diff[0]);

                                        angle -= std.math.radiansToDegrees(parent_angle) - 90.0;
                                    }
                                }
                            }
                        }
                    }

                    var rotation = angle + if (transform_texture.pivot != null) -transform_texture.pivot_offset_angle else 0.0;

                    if (rotation < 0.0) rotation += 360.0;

                    var rotation_diff = rotation - @mod(transform_texture.rotation, 360.0);

                    // TODO: Is there some better way to determine if the angle has crossed the boundary from 359.9 > 0
                    // TODO: without using a separate variable? This will never reach 360.0 and depending on mouse speed
                    // TODO: could be a valid change in rotation at even large numbers, especially when crossing the pivot.
                    if (@abs(rotation_diff) > 300.0) {
                        rotation_diff += 360.0 * -std.math.sign(rotation_diff);
                    }

                    transform_texture.rotation += rotation_diff;
                    transform_texture.rotation = @round(transform_texture.rotation);
                }
            }
        }

        blk_vert: { // Handle moving the vertices when moving a single control
            if (transform_texture.control) |control| {
                if (imgui.isWindowHovered(imgui.HoveredFlags_ChildWindows)) {
                    const mouse_position = pixi.state.mouse.position;
                    const current_pixel_coords = camera.pixelCoordinatesRaw(.{
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
                            var rotated_centroid = if (transform_texture.pivot) |p| p.position else zmath.f32x4s(0.0);
                            if (transform_texture.pivot == null) {
                                for (rotated_vertices) |vertex| {
                                    rotated_centroid += vertex.position; // Collect centroid
                                }
                                rotated_centroid /= zmath.f32x4s(4.0); // Average position
                            }

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

                            var rotated_centroid = if (transform_texture.pivot) |p| p.position else zmath.f32x4s(0.0);
                            if (transform_texture.pivot == null) {
                                for (rotated_vertices) |vertex| {
                                    rotated_centroid += vertex.position; // Collect centroid
                                }
                                rotated_centroid /= zmath.f32x4s(4.0); // Average position
                            }

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

    pub fn external(self: Pixi, allocator: std.mem.Allocator) !storage.External.Pixi {
        const layers = try allocator.alloc(storage.External.Layer, self.layers.items.len);
        const sprites = try allocator.alloc(storage.External.Sprite, self.sprites.items.len);
        const animations = try allocator.alloc(storage.External.Animation, self.animations.items.len);

        for (layers, 0..) |*working_layer, i| {
            working_layer.name = try allocator.dupeZ(u8, self.layers.items[i].name);
            working_layer.visible = self.layers.items[i].visible;
            working_layer.collapse = self.layers.items[i].collapse;
        }

        for (sprites, 0..) |*sprite, i| {
            sprite.name = try allocator.dupeZ(u8, self.sprites.items[i].name);
            sprite.origin = .{ @intFromFloat(@round(self.sprites.items[i].origin_x)), @intFromFloat(@round(self.sprites.items[i].origin_y)) };
        }

        for (animations, 0..) |*animation, i| {
            animation.name = try allocator.dupeZ(u8, self.animations.items[i].name);
            animation.fps = self.animations.items[i].fps;
            animation.start = self.animations.items[i].start;
            animation.length = self.animations.items[i].length;
        }

        return .{
            .version = pixi.version,
            .width = self.width,
            .height = self.height,
            .tile_width = self.tile_width,
            .tile_height = self.tile_height,
            .layers = layers,
            .sprites = sprites,
            .animations = animations,
        };
    }

    fn write(context: ?*anyopaque, data: ?*anyopaque, size: c_int) callconv(.C) void {
        const zip_file = @as(?*zip.struct_zip_t, @ptrCast(context));

        if (zip_file) |z| {
            _ = zip.zip_entry_write(z, data, @as(usize, @intCast(size)));
        }
    }

    pub fn save(self: *Pixi) !void {
        if (self.saving) return;
        self.saving = true;
        self.history.bookmark = 0;
        var ext = try self.external(pixi.state.allocator);
        defer ext.deinit(pixi.state.allocator);
        const zip_file = zip.zip_open(self.path, zip.ZIP_DEFAULT_COMPRESSION_LEVEL, 'w');

        if (zip_file) |z| {
            var json = std.ArrayList(u8).init(pixi.state.allocator);
            const out_stream = json.writer();
            const options = std.json.StringifyOptions{};

            try std.json.stringify(ext, options, out_stream);

            const json_output = try json.toOwnedSlice();
            defer pixi.state.allocator.free(json_output);

            _ = zip.zip_entry_open(z, "pixidata.json");
            _ = zip.zip_entry_write(z, json_output.ptr, json_output.len);
            _ = zip.zip_entry_close(z);

            for (self.layers.items) |working_layer| {
                const layer_name = try std.fmt.allocPrintZ(pixi.state.allocator, "{s}.png", .{working_layer.name});
                defer pixi.state.allocator.free(layer_name);
                _ = zip.zip_entry_open(z, @as([*c]const u8, @ptrCast(layer_name)));
                try working_layer.texture.image.writeToFn(write, z, .png);
                _ = zip.zip_entry_close(z);
            }

            if (self.heightmap.layer) |working_layer| {
                const layer_name = try std.fmt.allocPrintZ(pixi.state.allocator, "{s}.png", .{working_layer.name});
                defer pixi.state.allocator.free(layer_name);
                _ = zip.zip_entry_open(z, @as([*c]const u8, @ptrCast(layer_name)));
                try working_layer.texture.image.writeToFn(write, z, .png);
                _ = zip.zip_entry_close(z);
            }

            zip.zip_close(z);
        }

        self.saving = false;
    }

    pub fn saveLDtk(self: *Pixi) !void {
        if (pixi.state.project_folder) |project_folder_path| {
            const ldtk_path = try std.fs.path.joinZ(pixi.state.allocator, &.{ project_folder_path, "pixi-ldtk" });
            defer pixi.state.allocator.free(ldtk_path);

            const base_name_w_ext = std.fs.path.basename(self.path);
            const ext = std.fs.path.extension(base_name_w_ext);

            const base_name = base_name_w_ext[0 .. base_name_w_ext.len - ext.len];

            if (std.fs.path.dirname(self.path)) |self_dir_path| {
                const file_folder_path = try std.fs.path.joinZ(pixi.state.allocator, &.{ ldtk_path, self_dir_path[project_folder_path.len..] });
                defer pixi.state.allocator.free(file_folder_path);

                for (self.layers.items) |working_layer| {
                    var layer_save_name = try std.fmt.allocPrintZ(pixi.state.allocator, "{s}{c}{s}__{s}.png", .{ file_folder_path, std.fs.path.sep, base_name, working_layer.name });
                    defer pixi.state.allocator.free(layer_save_name);

                    for (layer_save_name, 0..) |c, i| {
                        if (c == ' ') {
                            layer_save_name[i] = '_';
                        }
                    }

                    try std.fs.cwd().makePath(file_folder_path);

                    try working_layer.texture.image.writeToFile(layer_save_name, .png);
                }
            }

            pixi.state.packer.ldtk = true;
            defer pixi.state.packer.ldtk = false;
            try pixi.state.packer.appendProject();

            const ldtk_atlas_save_path = try std.fmt.allocPrintZ(pixi.state.allocator, "{s}{c}pixi-ldtk.json", .{ project_folder_path, std.fs.path.sep });
            defer pixi.state.allocator.free(ldtk_atlas_save_path);

            var handle = try std.fs.cwd().createFile(ldtk_atlas_save_path, .{});
            defer handle.close();

            const out_stream = handle.writer();
            const options: std.json.StringifyOptions = .{};

            const output: pixi.Packer.LDTKTileset.LDTKCompatibility = .{ .tilesets = pixi.state.packer.ldtk_tilesets.items };

            try std.json.stringify(output, options, out_stream);
            pixi.state.packer.clearAndFree();
        }
    }

    pub fn saveAsync(self: *Pixi) !void {
        //if (!self.dirty()) return;
        const thread = try std.Thread.spawn(.{}, save, .{self});
        thread.detach();

        switch (pixi.state.settings.compatibility) {
            .none => {},
            .ldtk => {
                try self.saveLDtk();
            },
        }
    }

    pub fn newHistorySelectedSprites(file: *Pixi, change_type: History.ChangeType) !void {
        switch (change_type) {
            .origins => {
                var change = try pixi.storage.Internal.Pixi.History.Change.create(pixi.state.allocator, change_type, file.selected_sprites.items.len);
                for (file.selected_sprites.items, 0..) |sprite_index, i| {
                    const sprite = file.sprites.items[sprite_index];
                    change.origins.indices[i] = sprite_index;
                    change.origins.values[i] = .{ sprite.origin_x, sprite.origin_y };
                }
                try file.history.append(change);
            },
            else => {},
        }
    }

    pub fn undo(self: *Pixi) !void {
        return self.history.undoRedo(self, .undo);
    }

    pub fn redo(self: *Pixi) !void {
        return self.history.undoRedo(self, .redo);
    }

    pub fn cut(self: *Pixi, append_history: bool) !void {
        if (self.transform_texture == null) {
            if (pixi.state.tools.current == .selection) {
                if (pixi.Packer.reduce(&self.selection_layer.texture, .{ 0, 0, self.width, self.height })) |reduced_rect| {
                    const copy_image = try zstbi.Image.createEmpty(@intCast(reduced_rect[2]), @intCast(reduced_rect[3]), 4, .{});
                    const dst_pixels = @as([*][4]u8, @ptrCast(copy_image.data.ptr))[0 .. copy_image.data.len / 4];

                    const src_layer = &self.layers.items[self.selected_layer_index];
                    const src_pixels = @as([*][4]u8, @ptrCast(src_layer.texture.image.data.ptr))[0 .. src_layer.texture.image.data.len / 4];
                    const mask_pixels = @as([*][4]u8, @ptrCast(self.selection_layer.texture.image.data.ptr))[0 .. self.selection_layer.texture.image.data.len / 4];

                    // Copy pixels to image
                    {
                        var y: usize = reduced_rect[1];
                        while (y < reduced_rect[1] + reduced_rect[3]) : (y += 1) {
                            const start = reduced_rect[0] + y * self.width;
                            const src = src_pixels[start .. start + reduced_rect[2]];
                            const dst = dst_pixels[(y - reduced_rect[1]) * copy_image.width .. (y - reduced_rect[1]) * copy_image.width + copy_image.width];
                            const msk = mask_pixels[start .. start + reduced_rect[2]];

                            for (src, dst, msk, 0..) |*src_pixel, *dst_pixel, msk_pixel, i| {
                                if (msk_pixel[3] != 0) {
                                    @memcpy(dst_pixel, src_pixel);

                                    try self.buffers.stroke.append(start + i, src_pixel.*);
                                    @memset(src_pixel, 0);
                                }
                            }
                        }
                    }

                    src_layer.texture.update(pixi.state.device);
                    self.selection_layer.clear(true);

                    if (append_history) {
                        // Submit the stroke change buffer
                        if (self.buffers.stroke.indices.items.len > 0 and append_history) {
                            const change = try self.buffers.stroke.toChange(@intCast(self.selected_layer_index));
                            try self.history.append(change);
                        }
                    }

                    if (pixi.state.clipboard_image) |*image| {
                        image.deinit();
                    }

                    pixi.state.clipboard_image = copy_image;
                    pixi.state.clipboard_position = .{ @intCast(reduced_rect[0]), @intCast(reduced_rect[1]) };
                }
            } else {
                if (pixi.state.clipboard_image) |*image| {
                    image.deinit();
                }

                pixi.state.clipboard_image = try self.spriteToImage(self.selected_sprite_index, false);

                try self.eraseSprite(self.selected_sprite_index, append_history);
            }
        }
    }

    pub fn copy(self: *Pixi) !void {
        if (self.transform_texture == null) {
            if (pixi.state.tools.current == .selection) {
                if (pixi.Packer.reduce(&self.selection_layer.texture, .{ 0, 0, self.width, self.height })) |reduced_rect| {
                    const copy_image = try zstbi.Image.createEmpty(@intCast(reduced_rect[2]), @intCast(reduced_rect[3]), 4, .{});
                    const dst_pixels = @as([*][4]u8, @ptrCast(copy_image.data.ptr))[0 .. copy_image.data.len / 4];

                    const src_layer = &self.layers.items[self.selected_layer_index];
                    const src_pixels = @as([*][4]u8, @ptrCast(src_layer.texture.image.data.ptr))[0 .. src_layer.texture.image.data.len / 4];
                    const mask_pixels = @as([*][4]u8, @ptrCast(self.selection_layer.texture.image.data.ptr))[0 .. self.selection_layer.texture.image.data.len / 4];

                    // Copy pixels to image
                    {
                        var y: usize = reduced_rect[1];
                        while (y < reduced_rect[1] + reduced_rect[3]) : (y += 1) {
                            const start = reduced_rect[0] + y * self.width;
                            const src = src_pixels[start .. start + reduced_rect[2]];
                            const dst = dst_pixels[(y - reduced_rect[1]) * copy_image.width .. (y - reduced_rect[1]) * copy_image.width + copy_image.width];
                            const msk = mask_pixels[start .. start + reduced_rect[2]];

                            for (src, dst, msk) |*src_pixel, *dst_pixel, msk_pixel| {
                                if (msk_pixel[3] != 0) {
                                    @memcpy(dst_pixel, src_pixel);
                                }
                            }
                        }
                    }

                    if (pixi.state.clipboard_image) |*image| {
                        image.deinit();
                    }

                    pixi.state.clipboard_image = copy_image;
                    pixi.state.clipboard_position = .{ @intCast(reduced_rect[0]), @intCast(reduced_rect[1]) };
                }
            } else {
                if (pixi.state.clipboard_image) |*image| {
                    image.deinit();
                }

                pixi.state.clipboard_image = try self.spriteToImage(self.selected_sprite_index, false);
            }
        }
    }

    pub fn paste(self: *Pixi) !void {
        if (pixi.state.clipboard_image) |image| {
            if (self.transform_texture) |*transform_texture|
                transform_texture.texture.deinit();

            if (self.transform_bindgroup) |bindgroup|
                bindgroup.release();

            if (self.transform_compute_bindgroup) |bindgroup|
                bindgroup.release();

            if (self.transform_compute_buffer == null) {
                self.transform_compute_buffer = pixi.state.device.createBuffer(&.{
                    .usage = .{ .copy_src = true, .storage = true },
                    .size = @sizeOf([4]f32) * (self.width * self.height),
                    .mapped_at_creation = .false,
                });
            }

            if (self.transform_staging_buffer == null) {
                self.transform_staging_buffer = pixi.state.device.createBuffer(&.{
                    .usage = .{ .copy_dst = true, .map_read = true },
                    .size = @sizeOf([4]f32) * (self.width * self.height),
                    .mapped_at_creation = .false,
                });
            }

            const image_copy: zstbi.Image = try zstbi.Image.createEmpty(
                image.width,
                image.height,
                image.num_components,
                .{
                    .bytes_per_component = image.bytes_per_component,
                    .bytes_per_row = image.bytes_per_row,
                },
            );
            @memcpy(image_copy.data, image.data);

            const transform_position: [2]f32 = if (pixi.state.tools.current == .selection) .{ @floatFromInt(pixi.state.clipboard_position[0]), @floatFromInt(pixi.state.clipboard_position[1]) } else self.pixelCoordinatesFromIndex(self.selected_sprite_index);
            const transform_width: f32 = @floatFromInt(image.width);
            const transform_height: f32 = @floatFromInt(image.height);

            self.transform_texture = .{
                .vertices = .{
                    .{ .position = zmath.loadArr2(transform_position) }, // TL
                    .{ .position = zmath.loadArr2(.{ transform_position[0] + transform_width, transform_position[1] }) }, // TR
                    .{ .position = zmath.f32x4(transform_position[0] + transform_width, transform_position[1] + transform_height, 0.0, 0.0) }, //BR
                    .{ .position = zmath.f32x4(transform_position[0], transform_position[1] + transform_height, 0.0, 0.0) }, // BL
                },
                .texture = pixi.gfx.Texture.create(image_copy, .{}),
                .rotation_grip_height = transform_height / 4.0,
            };

            const pipeline_layout_default = pixi.state.pipeline_default.getBindGroupLayout(0);
            defer pipeline_layout_default.release();

            self.transform_bindgroup = pixi.state.device.createBindGroup(
                &gpu.BindGroup.Descriptor.init(.{
                    .layout = pipeline_layout_default,
                    .entries = &.{
                        gpu.BindGroup.Entry.initBuffer(0, pixi.state.uniform_buffer_default, 0, @sizeOf(pixi.gfx.UniformBufferObject), 0),
                        gpu.BindGroup.Entry.initTextureView(1, self.transform_texture.?.texture.view_handle),
                        gpu.BindGroup.Entry.initSampler(2, self.transform_texture.?.texture.sampler_handle),
                    },
                }),
            );

            const compute_layout_default = pixi.state.pipeline_compute.getBindGroupLayout(0);
            defer compute_layout_default.release();

            self.transform_compute_bindgroup = pixi.state.device.createBindGroup(
                &mach.gpu.BindGroup.Descriptor.init(.{
                    .layout = compute_layout_default,
                    .entries = &.{
                        mach.gpu.BindGroup.Entry.initTextureView(0, self.temporary_layer.texture.view_handle),
                        mach.gpu.BindGroup.Entry.initBuffer(1, self.transform_compute_buffer.?, 0, @sizeOf([4]f32) * (self.width * self.height), 0),
                    },
                }),
            );

            pixi.state.tools.set(pixi.Tools.Tool.pointer);
        }
    }

    pub fn createBackground(self: *Pixi) !void {
        var image = try zstbi.Image.createEmpty(self.tile_width * 2, self.tile_height * 2, 4, .{});
        // Set background image data to checkerboard
        {
            var i: usize = 0;
            while (i < @as(usize, @intCast(self.tile_width * 2 * self.tile_height * 2 * 4))) : (i += 4) {
                const r = i;
                const g = i + 1;
                const b = i + 2;
                const a = i + 3;
                const primary = pixi.state.theme.checkerboard_primary.bytes();
                const secondary = pixi.state.theme.checkerboard_secondary.bytes();
                if (i % 3 == 0) {
                    image.data[r] = primary[0];
                    image.data[g] = primary[1];
                    image.data[b] = primary[2];
                    image.data[a] = primary[3];
                } else {
                    image.data[r] = secondary[0];
                    image.data[g] = secondary[1];
                    image.data[b] = secondary[2];
                    image.data[a] = secondary[3];
                }
            }
        }
        self.background = pixi.gfx.Texture.create(image, .{});
    }

    pub fn layer(self: *Pixi, id: u32) ?*Layer {
        for (self.layers.items) |*working_layer| {
            if (working_layer.id == id)
                return working_layer;
        }
        return null;
    }

    pub fn createLayer(self: *Pixi, name: [:0]const u8) !void {
        try self.layers.insert(0, .{
            .name = try pixi.state.allocator.dupeZ(u8, name),
            .texture = try pixi.gfx.Texture.createEmpty(self.width, self.height, .{}),
            .visible = true,
            .id = self.newId(),
        });
        try self.history.append(.{ .layer_restore_delete = .{
            .action = .delete,
            .index = 0,
        } });
    }

    pub fn renameLayer(file: *Pixi, name: [:0]const u8, index: usize) !void {
        var change: History.Change = .{ .layer_name = .{
            .name = [_:0]u8{0} ** 128,
            .index = index,
        } };
        @memcpy(change.layer_name.name[0..file.layers.items[index].name.len], file.layers.items[index].name);
        pixi.state.allocator.free(file.layers.items[index].name);
        file.layers.items[pixi.state.popups.layer_setup_index].name = pixi.state.allocator.dupeZ(u8, name) catch unreachable;
        try file.history.append(change);
    }

    pub fn duplicateLayer(self: *Pixi, name: [:0]const u8, src_index: usize) !void {
        const src = self.layers.items[src_index];
        var texture = try pixi.gfx.Texture.createEmpty(self.width, self.height, .{});
        @memcpy(texture.image.data, src.texture.image.data);
        texture.update(pixi.state.device);
        try self.layers.insert(0, .{
            .name = try pixi.state.allocator.dupeZ(u8, name),
            .texture = texture,
            .visible = true,
            .id = self.newId(),
        });
        try self.history.append(.{ .layer_restore_delete = .{
            .action = .delete,
            .index = 0,
        } });
    }

    pub fn deleteLayer(self: *Pixi, index: usize) !void {
        if (index >= self.layers.items.len) return;
        try self.deleted_layers.append(self.layers.orderedRemove(index));
        try self.history.append(.{ .layer_restore_delete = .{
            .action = .restore,
            .index = index,
        } });
    }

    pub fn createAnimation(self: *Pixi, name: []const u8, fps: usize, start: usize, length: usize) !void {
        const animation = .{
            .name = try pixi.state.allocator.dupeZ(u8, name),
            .fps = fps,
            .start = start,
            .length = length,
        };

        try self.animations.append(animation);
        self.selected_animation_index = self.animations.items.len - 1;

        var i: usize = animation.start;
        while (i < animation.start + animation.length) : (i += 1) {
            pixi.state.allocator.free(self.sprites.items[i].name);
            self.sprites.items[i].name = try std.fmt.allocPrintZ(pixi.state.allocator, "{s}_{d}", .{ name, i - animation.start });
        }

        try self.history.append(.{ .animation_restore_delete = .{
            .index = self.selected_animation_index,
            .action = .delete,
        } });
    }

    pub fn renameAnimation(self: *Pixi, name: []const u8, index: usize) !void {
        var animation = &self.animations.items[index];
        var change: History.Change = .{ .animation = .{
            .index = index,
            .name = [_:0]u8{0} ** 128,
            .fps = animation.fps,
            .start = animation.start,
            .length = animation.length,
        } };
        @memcpy(change.animation.name[0..animation.name.len], animation.name);

        self.selected_animation_index = index;
        pixi.state.allocator.free(animation.name);
        animation.name = try pixi.state.allocator.dupeZ(u8, name);

        var i: usize = animation.start;
        while (i < animation.start + animation.length) : (i += 1) {
            pixi.state.allocator.free(self.sprites.items[i].name);
            self.sprites.items[i].name = try std.fmt.allocPrintZ(pixi.state.allocator, "{s}_{d}", .{ name, i - animation.start });
        }

        try self.history.append(change);
    }

    pub fn deleteAnimation(self: *Pixi, index: usize) !void {
        if (index >= self.animations.items.len) return;
        const animation = self.animations.swapRemove(index);
        try self.deleted_animations.append(animation);
        try self.history.append(.{ .animation_restore_delete = .{
            .action = .restore,
            .index = index,
        } });

        var i: usize = animation.start;
        while (i < animation.start + animation.length) : (i += 1) {
            pixi.state.allocator.free(self.sprites.items[i].name);
            self.sprites.items[i].name = try std.fmt.allocPrintZ(pixi.state.allocator, "Sprite_{d}", .{i});
        }
    }

    pub fn deleteTransformAnimation(self: *Pixi, index: usize) !void {
        if (index >= self.keyframe_animations.items.len) return;
        const animation = self.keyframe_animations.swapRemove(index);
        _ = animation; // autofix
        //pixi.state.allocator.free(animation.name);
    }

    pub fn setSelectedSpritesOriginX(self: *Pixi, origin_x: f32) void {
        for (self.selected_sprites.items) |sprite_index| {
            if (self.sprites.items[sprite_index].origin_x != origin_x) {
                for (self.keyframe_animations.items) |*animation| {
                    for (animation.keyframes.items) |*keyframe| {
                        for (keyframe.frames.items) |*frame| {
                            if (sprite_index == frame.sprite_index) {
                                const diff = origin_x - self.sprites.items[sprite_index].origin_x;
                                frame.pivot.position += zmath.loadArr2(.{ diff, 0.0 });
                            }
                        }
                    }
                }

                self.sprites.items[sprite_index].origin_x = origin_x;
            }
        }
    }

    pub fn setSelectedSpritesOriginY(self: *Pixi, origin_y: f32) void {
        for (self.selected_sprites.items) |sprite_index| {
            if (self.sprites.items[sprite_index].origin_y != origin_y) {
                for (self.keyframe_animations.items) |*animation| {
                    for (animation.keyframes.items) |*keyframe| {
                        for (keyframe.frames.items) |*frame| {
                            if (sprite_index == frame.sprite_index) {
                                const diff = origin_y - self.sprites.items[sprite_index].origin_y;
                                frame.pivot.position += zmath.loadArr2(.{ 0.0, diff });
                            }
                        }
                    }
                }
                self.sprites.items[sprite_index].origin_y = origin_y;
            }
        }
    }

    pub fn getSelectedSpritesOrigin(self: *Pixi) ?[2]f32 {
        if (self.selected_sprites.items.len == 0) return null;
        const first = self.sprites.items[self.selected_sprites.items[0]];
        const origin = .{ first.origin_x, first.origin_y };

        for (self.selected_sprites.items) |sprite_index| {
            const sprite = self.sprites.items[sprite_index];
            if (sprite.origin_x != origin[0] or sprite.origin_y != origin[1])
                return null;
        }

        return origin;
    }

    pub fn setSelectedSpritesOrigin(self: *Pixi, origin: [2]f32) void {
        for (self.selected_sprites.items) |sprite_index| {
            const current_origin = .{ self.sprites.items[sprite_index].origin_x, self.sprites.items[sprite_index].origin_y };
            if (current_origin[0] != origin[0] or current_origin[1] != origin[1]) {
                const diff: [2]f32 = .{ origin[0] - current_origin[0], origin[1] - current_origin[1] };

                for (self.keyframe_animations.items) |*animation| {
                    for (animation.keyframes.items) |*keyframe| {
                        for (keyframe.frames.items) |*frame| {
                            if (sprite_index == frame.sprite_index) {
                                frame.pivot.position += zmath.loadArr2(diff);
                            }
                        }
                    }
                }

                self.sprites.items[sprite_index].origin_x = origin[0];
                self.sprites.items[sprite_index].origin_y = origin[1];
            }
        }
    }

    pub fn getAnimationIndexFromSpriteIndex(self: Pixi, sprite_index: usize) ?usize {
        for (self.animations.items, 0..) |animation, i| {
            if (sprite_index >= animation.start and sprite_index <= animation.start + animation.length - 1) {
                return i;
            }
        }
        return null;
    }

    /// Searches for an animation containing the current selected sprite index
    /// Returns true if one is found and set, false if not
    pub fn setAnimationFromSpriteIndex(self: *Pixi) bool {
        for (self.animations.items, 0..) |animation, i| {
            if (self.selected_sprite_index >= animation.start and self.selected_sprite_index <= animation.start + animation.length - 1) {
                self.selected_animation_index = i;
                return true;
            }
        }
        return false;
    }

    pub fn flipbookScrollFromSpriteIndex(self: Pixi, index: usize) f32 {
        return -(@as(f32, @floatFromInt(index)) / 1.5 * @as(f32, @floatFromInt(self.tile_width)) * 1.5);
    }

    pub fn pixelCoordinatesFromIndex(self: Pixi, index: usize) [2]f32 {
        const tiles_wide: u32 = self.width / self.tile_width;

        const dst_col = @mod(@as(u32, @intCast(index)), tiles_wide);
        const dst_row = @divTrunc(@as(u32, @intCast(index)), tiles_wide);

        const dst_x = dst_col * self.tile_width;
        const dst_y = dst_row * self.tile_height;

        return .{ @floatFromInt(dst_x), @floatFromInt(dst_y) };
    }

    pub fn spriteSelectionIndex(self: Pixi, index: usize) ?usize {
        return std.mem.indexOf(usize, self.selected_sprites.items, &[_]usize{index});
    }

    pub fn makeSpriteSelection(self: *Pixi, selected_sprite: usize) void {
        const selection = self.selected_sprites.items.len > 0;
        const selected_sprite_index = self.spriteSelectionIndex(selected_sprite);
        const contains = selected_sprite_index != null;
        const primary_key = if (pixi.state.hotkeys.hotkey(.{ .proc = .primary })) |hotkey| hotkey.down() else false;
        const secondary_key = if (pixi.state.hotkeys.hotkey(.{ .proc = .secondary })) |hotkey| hotkey.down() else false;
        if (primary_key) {
            if (!contains) {
                self.selected_sprites.append(selected_sprite) catch unreachable;
            } else {
                if (selected_sprite_index) |i| {
                    _ = self.selected_sprites.swapRemove(i);
                }
            }
        } else if (secondary_key) {
            if (selection) {
                const last = self.selected_sprites.getLast();
                if (selected_sprite > last) {
                    for (last..selected_sprite + 1) |i| {
                        if (std.mem.indexOf(usize, self.selected_sprites.items, &[_]usize{i}) == null) {
                            self.selected_sprites.append(i) catch unreachable;
                        }
                    }
                } else if (selected_sprite < last) {
                    for (selected_sprite..last) |i| {
                        if (std.mem.indexOf(usize, self.selected_sprites.items, &[_]usize{i}) == null) {
                            self.selected_sprites.append(i) catch unreachable;
                        }
                    }
                } else if (selected_sprite_index) |i| {
                    _ = self.selected_sprites.swapRemove(i);
                } else {
                    self.selected_sprites.append(selected_sprite) catch unreachable;
                }
            } else {
                self.selected_sprites.append(selected_sprite) catch unreachable;
            }
        } else {
            if (selection) {
                self.selected_sprites.clearAndFree();
            }
            self.selected_sprites.append(selected_sprite) catch unreachable;
        }
    }

    pub fn spriteToImage(file: *Pixi, sprite_index: usize, all_layers: bool) !zstbi.Image {
        const sprite_image = try zstbi.Image.createEmpty(file.tile_width, file.tile_height, 4, .{});

        const tiles_wide = @divExact(file.width, file.tile_width);

        const column = @mod(@as(u32, @intCast(sprite_index)), tiles_wide);
        const row = @divTrunc(@as(u32, @intCast(sprite_index)), tiles_wide);

        const src_x = column * file.tile_width;
        const src_y = row * file.tile_height;

        if (all_layers) {
            var i: usize = file.layers.items.len;
            while (i > 0) {
                i -= 1;

                const working_layer = &file.layers.items[i];

                if (!working_layer.visible) continue;

                const first_index = working_layer.getPixelIndex(.{ src_x, src_y });

                var src_pixels = @as([*][4]u8, @ptrCast(working_layer.texture.image.data.ptr))[0 .. working_layer.texture.image.data.len / 4];
                var dest_pixels = @as([*][4]u8, @ptrCast(sprite_image.data.ptr))[0 .. sprite_image.data.len / 4];

                var r: usize = 0;
                while (r < @as(usize, @intCast(file.tile_height))) : (r += 1) {
                    const p_src = first_index + (r * @as(usize, @intCast(file.width)));
                    const src = src_pixels[p_src .. p_src + @as(usize, @intCast(file.tile_width))];

                    const p_dest = r * @as(usize, @intCast(file.tile_width));
                    const dest = dest_pixels[p_dest .. p_dest + @as(usize, @intCast(file.tile_width))];

                    for (src, 0..) |pixel, pixel_i| {
                        if (pixel[3] != 0)
                            dest[pixel_i] = pixel;
                    }
                }
            }
        } else {
            const selected_layer = &file.layers.items[file.selected_layer_index];

            const first_index = selected_layer.getPixelIndex(.{ src_x, src_y });

            var src_pixels = @as([*][4]u8, @ptrCast(selected_layer.texture.image.data.ptr))[0 .. selected_layer.texture.image.data.len / 4];
            var dest_pixels = @as([*][4]u8, @ptrCast(sprite_image.data.ptr))[0 .. sprite_image.data.len / 4];

            var r: usize = 0;
            while (r < @as(usize, @intCast(file.tile_height))) : (r += 1) {
                const p_src = first_index + (r * @as(usize, @intCast(file.width)));
                const src = src_pixels[p_src .. p_src + @as(usize, @intCast(file.tile_width))];

                const p_dest = r * @as(usize, @intCast(file.tile_width));
                const dest = dest_pixels[p_dest .. p_dest + @as(usize, @intCast(file.tile_width))];

                for (src, 0..) |pixel, pixel_i| {
                    if (pixel[3] != 0)
                        dest[pixel_i] = pixel;
                }
            }
        }

        return sprite_image;
    }

    pub fn getSpriteIndexAfterDirection(self: *Pixi, direction: pixi.math.Direction) usize {
        if (direction == .none) return self.selected_sprite_index;

        const current_index = self.selected_sprite_index;

        const rows: i32 = @intCast(@divExact(self.width, self.tile_width));
        const columns: i32 = @intCast(@divExact(self.height, self.tile_height));

        const column = @mod(@as(i32, @intCast(current_index)), rows);
        const row = @divTrunc(@as(i32, @intCast(current_index)), rows);

        const x_movement: i32 = @intFromFloat(direction.x());
        const y_movement: i32 = @intFromFloat(-direction.y());

        const x_sum = column + x_movement;
        const y_sum = row + y_movement;

        const future_column = if (x_sum < 0) columns - 1 else if (x_sum >= columns) 0 else x_sum;
        const future_row = if (y_sum < 0) rows - 1 else if (y_sum >= rows) 0 else y_sum;

        const future_index: usize = @intCast(future_column + future_row * rows);
        return future_index;
    }

    pub fn selectDirection(self: *Pixi, direction: pixi.math.Direction) void {
        self.flipbook_scroll_request = .{
            .from = self.flipbook_scroll,
            .to = self.flipbookScrollFromSpriteIndex(self.getSpriteIndexAfterDirection(direction)),
            .state = self.selected_animation_state,
        };
    }

    pub fn copyDirection(file: *Pixi, direction: pixi.math.Direction) !void {
        const src_index = file.selected_sprite_index;
        const dst_index = file.getSpriteIndexAfterDirection(direction);
        const layer_id = file.layers.items[file.selected_layer_index].id;

        try copySprite(file, src_index, dst_index, layer_id);

        file.flipbook_scroll_request = .{
            .from = file.flipbook_scroll,
            .to = file.flipbookScrollFromSpriteIndex(dst_index),
            .state = file.selected_animation_state,
        };
    }

    pub fn copySpriteAllLayers(file: *Pixi, src_index: usize, dst_index: usize) !void {
        for (file.layers.items) |working_layer| {
            try copySprite(file, src_index, dst_index, working_layer.id);
        }
    }

    pub fn copySprite(file: *Pixi, src_index: usize, dst_index: usize, layer_id: usize) !void {
        const tiles_wide = @divExact(file.width, file.tile_width);

        const src_col = @mod(@as(u32, @intCast(src_index)), tiles_wide);
        const src_row = @divTrunc(@as(u32, @intCast(src_index)), tiles_wide);

        const src_x = src_col * file.tile_width;
        const src_y = src_row * file.tile_height;

        const dst_col = @mod(@as(u32, @intCast(dst_index)), tiles_wide);
        const dst_row = @divTrunc(@as(u32, @intCast(dst_index)), tiles_wide);

        const dst_x = dst_col * file.tile_width;
        const dst_y = dst_row * file.tile_height;

        var layer_index: usize = file.selected_layer_index;

        for (file.layers.items, 0..) |working_layer, i| {
            if (working_layer.id == layer_id) {
                layer_index = i;
            }
        }

        const working_layer = &file.layers.items[layer_index];

        const src_first_index = working_layer.getPixelIndex(.{ src_x, src_y });
        const dst_first_index = working_layer.getPixelIndex(.{ dst_x, dst_y });

        var src_pixels = @as([*][4]u8, @ptrCast(working_layer.texture.image.data.ptr))[0 .. working_layer.texture.image.data.len / 4];

        var row: usize = 0;
        while (row < @as(usize, @intCast(file.tile_height))) : (row += 1) {
            const src_i = src_first_index + (row * @as(usize, @intCast(file.width)));
            const src = src_pixels[src_i .. src_i + @as(usize, @intCast(file.tile_width))];

            const dest_i = dst_first_index + (row * @as(usize, @intCast(file.width)));
            const dest = src_pixels[dest_i .. dest_i + @as(usize, @intCast(file.tile_width))];

            for (src, 0..) |pixel, pixel_i| {
                try file.buffers.stroke.append(pixel_i + dest_i, dest[pixel_i]);
                dest[pixel_i] = pixel;
            }
        }

        working_layer.texture.update(pixi.state.device);

        // Submit the stroke change buffer
        if (file.buffers.stroke.indices.items.len > 0) {
            const change = try file.buffers.stroke.toChange(@intCast(layer_index));
            try file.history.append(change);
        }
    }

    pub fn shiftDirection(file: *Pixi, direction: pixi.math.Direction) !void {
        const direction_vector = direction.f32x4();

        const tiles_wide = @divExact(file.width, file.tile_width);

        const src_col = @mod(@as(u32, @intCast(file.selected_sprite_index)), tiles_wide);
        const src_row = @divTrunc(@as(u32, @intCast(file.selected_sprite_index)), tiles_wide);

        const one: usize = 1;
        const zero: usize = 0;

        const src_x: usize = src_col * file.tile_width + switch (direction) {
            .w => one,
            else => zero,
        };
        const src_y: usize = src_row * file.tile_height + switch (direction) {
            .n => one,
            else => zero,
        };
        const tile_height: usize = file.tile_height - switch (direction) {
            .s, .n => one,
            else => zero,
        };
        const tile_width: usize = file.tile_width - switch (direction) {
            .e, .w => one,
            else => zero,
        };

        const dst_x: u32 = @intCast(@as(i32, @intCast(src_x)) + @as(i32, @intFromFloat(direction_vector[0])));
        const dst_y: u32 = @intCast(@as(i32, @intCast(src_y)) - @as(i32, @intFromFloat(direction_vector[1])));

        const selected_layer = &file.layers.items[file.selected_layer_index];

        const src_first_index = selected_layer.getPixelIndex(.{ src_x, src_y });
        const dst_first_index = selected_layer.getPixelIndex(.{ dst_x, dst_y });

        var src_pixels = @as([*][4]u8, @ptrCast(selected_layer.texture.image.data.ptr))[0 .. selected_layer.texture.image.data.len / 4];

        const forwards: bool = switch (direction) {
            .e, .s => false,
            else => true,
        };

        var row: usize = if (forwards) 0 else tile_height - 1;
        while (if (forwards) row < tile_height else row > 0) : (if (forwards) {
            row += 1;
        } else {
            row -= 1;
        }) {
            const src_i = src_first_index + (row * @as(usize, @intCast(file.width)));
            const src = src_pixels[src_i .. src_i + tile_width];

            const dest_i = dst_first_index + (row * @as(usize, @intCast(file.width)));
            const dest = src_pixels[dest_i .. dest_i + tile_width];

            for (src, 0..) |_, pixel_i| {
                try file.buffers.stroke.append(pixel_i + dest_i, dest[pixel_i]);
            }
            switch (direction) {
                .e => std.mem.copyBackwards([4]u8, dest, src),
                else => std.mem.copyForwards([4]u8, dest, src),
            }
        }

        selected_layer.texture.update(pixi.state.device);

        // Submit the stroke change buffer
        if (file.buffers.stroke.indices.items.len > 0) {
            const change = try file.buffers.stroke.toChange(@intCast(file.selected_layer_index));
            try file.history.append(change);
        }
    }

    pub fn eraseSprite(file: *Pixi, sprite_index: usize, append_history: bool) !void {
        const tiles_wide = @divExact(file.width, file.tile_width);

        const src_col = @mod(@as(u32, @intCast(sprite_index)), tiles_wide);
        const src_row = @divTrunc(@as(u32, @intCast(sprite_index)), tiles_wide);

        const src_x = src_col * file.tile_width;
        const src_y = src_row * file.tile_height;

        const selected_layer = &file.layers.items[file.selected_layer_index];

        const src_first_index = selected_layer.getPixelIndex(.{ src_x, src_y });

        var src_pixels = @as([*][4]u8, @ptrCast(selected_layer.texture.image.data.ptr))[0 .. selected_layer.texture.image.data.len / 4];

        var row: usize = 0;
        while (row < @as(usize, @intCast(file.tile_height))) : (row += 1) {
            const p_dest = src_first_index + (row * @as(usize, @intCast(file.width)));
            const dest = src_pixels[p_dest .. p_dest + @as(usize, @intCast(file.tile_width))];

            for (dest, 0..) |pixel, pixel_i| {
                try file.buffers.stroke.append(pixel_i + p_dest, pixel);
                dest[pixel_i] = .{ 0.0, 0.0, 0.0, 0.0 };
            }
        }

        selected_layer.texture.update(pixi.state.device);

        // Submit the stroke change buffer
        if (file.buffers.stroke.indices.items.len > 0 and append_history) {
            const change = try file.buffers.stroke.toChange(@intCast(file.selected_layer_index));
            try file.history.append(change);
        }
    }
};

pub const Layer = struct {
    name: [:0]const u8,
    texture: pixi.gfx.Texture,
    visible: bool = true,
    collapse: bool = false,
    id: u32 = 0,
    transform_bindgroup: ?*gpu.BindGroup = null,

    pub fn pixels(self: *Layer) [][4]u8 {
        return @as([*][4]u8, @ptrCast(self.texture.image.data.ptr))[0 .. self.texture.image.data.len / 4];
    }

    pub fn getPixelIndex(self: Layer, pixel: [2]usize) usize {
        return pixel[0] + pixel[1] * @as(usize, @intCast(self.texture.image.width));
    }

    pub fn getPixel(self: Layer, pixel: [2]usize) [4]u8 {
        const index = self.getPixelIndex(pixel);
        const p = @as([*][4]u8, @ptrCast(self.texture.image.data.ptr))[0 .. self.texture.image.data.len / 4];
        return p[index];
    }

    pub fn setPixel(self: *Layer, pixel: [2]usize, color: [4]u8, update: bool) void {
        const index = self.getPixelIndex(pixel);
        var p = self.pixels();
        p[index] = color;
        if (update)
            self.texture.update(pixi.state.device);
    }

    pub fn setPixelIndex(self: *Layer, index: usize, color: [4]u8, update: bool) void {
        var p = self.pixels();
        p[index] = color;
        if (update)
            self.texture.update(pixi.state.device);
    }

    pub const ShapeOffsetResult = struct {
        index: usize,
        color: [4]u8,
    };

    /// Only used for handling getting the pixels surrounding the origin
    /// for stroke sizes larger than 1
    pub fn getIndexShapeOffset(self: Layer, origin: [2]usize, current_index: usize) ?ShapeOffsetResult {
        const shape = pixi.state.tools.stroke_shape;
        const size: i32 = @intCast(pixi.state.tools.stroke_size);

        if (size == 1) {
            if (current_index != 0)
                return null;

            return .{
                .index = self.getPixelIndex(origin),
                .color = self.getPixel(origin),
            };
        }

        const size_center_offset: i32 = -@divFloor(@as(i32, @intCast(size)), 2);
        const index_i32: i32 = @as(i32, @intCast(current_index));
        const pixel_offset: [2]i32 = .{ @mod(index_i32, size) + size_center_offset, @divFloor(index_i32, size) + size_center_offset };

        if (shape == .circle) {
            const extra_pixel_offset_circle: [2]i32 = if (@mod(size, 2) == 0) .{ 1, 1 } else .{ 0, 0 };
            const pixel_offset_circle: [2]i32 = .{ pixel_offset[0] * 2 + extra_pixel_offset_circle[0], pixel_offset[1] * 2 + extra_pixel_offset_circle[1] };
            const sqr_magnitude = pixel_offset_circle[0] * pixel_offset_circle[0] + pixel_offset_circle[1] * pixel_offset_circle[1];

            // adjust radius check for nicer looking circles
            const radius_check_mult: f32 = (if (size == 3 or size > 10) 0.7 else 0.8);

            if (@as(f32, @floatFromInt(sqr_magnitude)) > @as(f32, @floatFromInt(size * size)) * radius_check_mult) {
                return null;
            }
        }

        const pixel_i32: [2]i32 = .{ @as(i32, @intCast(origin[0])) + pixel_offset[0], @as(i32, @intCast(origin[1])) + pixel_offset[1] };

        if (pixel_i32[0] < 0 or pixel_i32[1] < 0 or pixel_i32[0] >= self.texture.image.width or pixel_i32[1] >= self.texture.image.height) {
            return null;
        }

        const pixel: [2]usize = .{ @intCast(pixel_i32[0]), @intCast(pixel_i32[1]) };

        return .{
            .index = getPixelIndex(self, pixel),
            .color = getPixel(self, pixel),
        };
    }

    pub fn clear(self: *Layer, update: bool) void {
        const p = self.pixels();
        for (p) |*pixel| {
            pixel.* = .{ 0, 0, 0, 0 };
        }
        if (update)
            self.texture.update(pixi.state.device);
    }
};

pub const Reference = struct {
    path: [:0]const u8,
    texture: pixi.gfx.Texture,
    camera: pixi.gfx.Camera = .{},
    opacity: f32 = 100.0,

    pub fn deinit(self: *Reference) void {
        self.texture.deinit();
        pixi.state.allocator.free(self.path);
    }

    pub fn canvasCenterOffset(self: *Reference) [2]f32 {
        const width: f32 = @floatFromInt(self.texture.image.width);
        const height: f32 = @floatFromInt(self.texture.image.height);

        return .{ -width / 2.0, -height / 2.0 };
    }

    pub fn getPixelIndex(self: Reference, pixel: [2]usize) usize {
        return pixel[0] + pixel[1] * @as(usize, @intCast(self.texture.image.width));
    }

    pub fn getPixel(self: Reference, pixel: [2]usize) [4]u8 {
        const index = self.getPixelIndex(pixel);
        const pixels = @as([*][4]u8, @ptrCast(self.texture.image.data.ptr))[0 .. self.texture.image.data.len / 4];
        return pixels[index];
    }

    pub fn processSampleTool(self: *Reference) void {
        const sample_key = if (pixi.state.hotkeys.hotkey(.{ .proc = .sample })) |hotkey| hotkey.down() else false;
        const sample_button = if (pixi.state.mouse.button(.sample)) |sample| sample.down() else false;

        if (!sample_key and !sample_button) return;

        imgui.setMouseCursor(imgui.MouseCursor_None);
        self.camera.drawCursor(pixi.assets.pixi_atlas.dropper_0_default, 0xFFFFFFFF);

        const mouse_position = pixi.state.mouse.position;
        var camera = self.camera;

        const pixel_coord_opt = camera.pixelCoordinates(.{
            .texture_position = canvasCenterOffset(self),
            .position = mouse_position,
            .width = self.texture.image.width,
            .height = self.texture.image.height,
        });

        if (pixel_coord_opt) |pixel_coord| {
            const pixel = .{ @as(usize, @intFromFloat(pixel_coord[0])), @as(usize, @intFromFloat(pixel_coord[1])) };

            const color = self.getPixel(pixel);

            camera.drawColorTooltip(color);

            if (color[3] != 0)
                pixi.state.colors.primary = color;
        }
    }
};

pub const Sprite = struct {
    name: [:0]const u8,
    index: usize,
    origin_x: f32 = 0.0,
    origin_y: f32 = 0.0,
};

pub const Animation = struct {
    name: [:0]const u8,
    start: usize,
    length: usize,
    fps: usize,
};

pub const KeyframeAnimation = struct {
    name: [:0]const u8,
    id: u32,
    keyframes: std.ArrayList(Keyframe),
    elapsed_time: f32 = 0.0,
    active_keyframe_id: u32,

    pub fn keyframe(self: KeyframeAnimation, id: u32) ?*Keyframe {
        for (self.keyframes.items) |*fr| {
            if (fr.id == id)
                return fr;
        }
        return null;
    }

    pub fn keyframeIndex(self: KeyframeAnimation, id: u32) ?usize {
        for (self.keyframes.items, 0..) |fr, i| {
            if (fr.id == id)
                return i;
        }
        return null;
    }

    pub fn getKeyframeMilliseconds(self: KeyframeAnimation, ms: usize) ?*Keyframe {
        for (self.keyframes.items) |*kf| {
            const kf_ms: usize = @intFromFloat(kf.time * 1000.0);
            if (ms == kf_ms)
                return kf;
        }

        return null;
    }

    pub fn getKeyframeFromFrame(self: KeyframeAnimation, frame_id: u32) ?*Keyframe {
        for (self.keyframes.items) |*kf| {
            if (kf.frame(frame_id) != null) {
                return kf;
            }
        }

        return null;
    }

    pub fn getFrameNodeColor(self: KeyframeAnimation, frame_id: u32) u32 {
        var color_index: usize = @mod(frame_id * 2, 35);

        if (self.getTweenStartFrame(frame_id)) |tween_start_frame| {
            var last_frame = tween_start_frame;
            while (true) {
                if (self.getTweenStartFrame(last_frame.id)) |fr| {
                    last_frame = fr;
                } else {
                    break;
                }
            }

            color_index = @mod(last_frame.id * 2, 35);
        }

        return if (pixi.state.colors.keyframe_palette) |palette| pixi.math.Color.initBytes(
            palette.colors[color_index][0],
            palette.colors[color_index][1],
            palette.colors[color_index][2],
            palette.colors[color_index][3],
        ).toU32() else pixi.state.theme.text.toU32();
    }

    pub fn getTweenStartFrame(self: KeyframeAnimation, frame_id: u32) ?*Frame {
        for (self.keyframes.items) |kf| {
            for (kf.frames.items) |*fr| {
                if (fr.tween_id) |tween_id| {
                    if (tween_id == frame_id) {
                        return fr;
                    }
                }
            }
        }
        return null;
    }

    /// Returns the length of the animation in seconds
    pub fn length(self: KeyframeAnimation) f32 {
        var len: f32 = 0.0;
        for (self.keyframes.items) |kf| {
            if (kf.time > len)
                len = kf.time;
        }
        return len;
    }

    /// Returns the number of frames in the largest keyframe
    pub fn maxNodes(self: KeyframeAnimation) usize {
        var nodes: usize = 0;
        for (self.keyframes.items) |kf| {
            if (kf.frames.items.len > nodes)
                nodes = kf.frames.items.len;
        }
        return nodes;
    }
};

pub const Keyframe = struct {
    frames: std.ArrayList(Frame),
    time: f32 = 0.0,
    id: u32,
    active_frame_id: u32,

    pub fn frame(self: Keyframe, id: u32) ?*Frame {
        for (self.frames.items) |*fr| {
            if (fr.id == id)
                return fr;
        }
        return null;
    }

    pub fn frameIndex(self: Keyframe, id: u32) ?usize {
        for (self.frames.items, 0..) |*fr, i| {
            if (fr.id == id)
                return i;
        }
        return null;
    }
};

pub const Frame = struct {
    vertices: [4]Pixi.TransformVertex,
    pivot: Pixi.TransformVertex,
    rotation: f32 = 0.0,
    id: u32,
    sprite_index: usize,
    layer_id: u32,
    parent_id: ?u32 = null,
    visible: bool = true,
    tween_id: ?u32 = null,
    tween: pixi.math.Tween = .none,
};

pub const Palette = struct {
    const PackedColor = packed struct(u32) { r: u8, g: u8, b: u8, a: u8 };
    name: [:0]const u8,
    colors: [][4]u8,

    pub fn loadFromFile(file: [:0]const u8) !Palette {
        var colors = std.ArrayList([4]u8).init(pixi.state.allocator);
        const base_name = std.fs.path.basename(file);
        const ext = std.fs.path.extension(file);
        if (std.mem.eql(u8, ext, ".hex")) {
            var contents = try std.fs.cwd().openFile(file, .{});
            defer contents.close();

            while (try contents.reader().readUntilDelimiterOrEofAlloc(pixi.state.allocator, '\n', 200000)) |line| {
                const color_u32 = try std.fmt.parseInt(u32, line[0 .. line.len - 1], 16);
                const color_packed: PackedColor = @as(PackedColor, @bitCast(color_u32));
                try colors.append(.{ color_packed.b, color_packed.g, color_packed.r, 255 });
                pixi.state.allocator.free(line);
            }
        } else {
            return error.WrongFileType;
        }

        return .{
            .name = try pixi.state.allocator.dupeZ(u8, base_name),
            .colors = try colors.toOwnedSlice(),
        };
    }

    pub fn deinit(self: *Palette) void {
        pixi.state.allocator.free(self.name);
        pixi.state.allocator.free(self.colors);
    }
};

pub const Atlas = struct {
    diffusemap: ?pixi.gfx.Texture = null,
    heightmap: ?pixi.gfx.Texture = null,
    external: ?external.Atlas = undefined,

    pub fn save(self: Atlas, path: [:0]const u8) !void {
        if (self.external) |atlas| {
            const atlas_ext = ".atlas";

            const output_path = try std.fmt.allocPrintZ(pixi.state.allocator, "{s}{s}", .{ path, atlas_ext });
            defer pixi.state.allocator.free(output_path);

            var handle = try std.fs.cwd().createFile(output_path, .{});
            defer handle.close();

            const out_stream = handle.writer();
            const options: std.json.StringifyOptions = .{};

            try std.json.stringify(atlas, options, out_stream);
        }

        if (self.diffusemap) |diffusemap| {
            const png_ext = ".png";

            const output_path = try std.fmt.allocPrintZ(pixi.state.allocator, "{s}{s}", .{ path, png_ext });
            defer pixi.state.allocator.free(output_path);

            try diffusemap.image.writeToFile(output_path, .png);
        }

        if (self.heightmap) |heightmap| {
            const png_ext = ".png";

            const output_path = try std.fmt.allocPrintZ(pixi.state.allocator, "{s}_h{s}", .{ path, png_ext });
            defer pixi.state.allocator.free(output_path);

            try heightmap.image.writeToFile(output_path, .png);
        }
    }
};
