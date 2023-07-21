const std = @import("std");
const zm = @import("zmath");
const pixi = @import("../pixi.zig");
const mach = @import("core");
const gpu = mach.gpu;
const zgui = @import("zgui").MachImgui(mach);

pub const Camera = struct {
    position: [2]f32 = .{ 0.0, 0.0 },
    zoom: f32 = 1.0,
    zoom_initialized: bool = false,
    zoom_timer: f32 = 0.2,
    zoom_wait_timer: f32 = 0.4,
    zoom_tooltip_timer: f32 = 0.6,

    pub fn matrix(self: Camera) Matrix3x2 {
        var window_size = zgui.getWindowSize();
        var window_half_size: [2]f32 = .{ @trunc(window_size[0] * 0.5), @trunc(window_size[1] * 0.5) };

        var transform = Matrix3x2.identity;

        var tmp = Matrix3x2.identity;
        tmp.translate(-self.position[0], -self.position[1]);
        transform = tmp.mul(transform);

        tmp = Matrix3x2.identity;
        tmp.scale(self.zoom, self.zoom);
        transform = tmp.mul(transform);

        tmp = Matrix3x2.identity;
        tmp.translate(window_half_size[0], window_half_size[1]);
        transform = tmp.mul(transform);

        return transform;
    }

    pub fn drawGrid(camera: Camera, position: [2]f32, width: f32, height: f32, columns: usize, rows: usize, color: u32) void {
        const rect_min_max = camera.getRectMinMax(.{ position[0], position[1], width, height });

        const draw_list = zgui.getWindowDrawList();
        const tile_width = width / @as(f32, @floatFromInt(columns));
        const tile_height = height / @as(f32, @floatFromInt(rows));

        var i: usize = 0;
        while (i < columns + 1) : (i += 1) {
            const p1: [2]f32 = .{ rect_min_max[0][0] + @as(f32, @floatFromInt(i)) * tile_width * camera.zoom, rect_min_max[0][1] };
            const p2: [2]f32 = .{ rect_min_max[0][0] + @as(f32, @floatFromInt(i)) * tile_width * camera.zoom, rect_min_max[0][1] + height * camera.zoom };
            draw_list.addLine(.{
                .p1 = p1,
                .p2 = p2,
                .col = color,
                .thickness = 1.0,
            });
        }

        i = 0;
        while (i < rows + 1) : (i += 1) {
            const p1: [2]f32 = .{ rect_min_max[0][0], rect_min_max[0][1] + @as(f32, @floatFromInt(i)) * tile_height * camera.zoom };
            const p2: [2]f32 = .{ rect_min_max[0][0] + width * camera.zoom, rect_min_max[0][1] + @as(f32, @floatFromInt(i)) * tile_height * camera.zoom };
            draw_list.addLine(.{
                .p1 = p1,
                .p2 = p2,
                .col = color,
                .thickness = 1.0,
            });
        }
    }

    pub fn drawLine(camera: Camera, start: [2]f32, end: [2]f32, color: u32, thickness: f32) void {
        const window_position = zgui.getWindowPos();
        const mat = camera.matrix();

        var p1 = mat.transformVec2(start);
        p1[0] += window_position[0];
        p1[1] += window_position[1];
        var p2 = mat.transformVec2(end);
        p2[0] += window_position[0];
        p2[1] += window_position[1];

        p1[0] = std.math.floor(p1[0]);
        p1[1] = std.math.floor(p1[1]);
        p2[0] = std.math.floor(p2[0]);
        p2[1] = std.math.floor(p2[1]);

        const draw_list = zgui.getWindowDrawList();
        draw_list.addLine(.{
            .p1 = p1,
            .p2 = p2,
            .col = color,
            .thickness = thickness,
        });
    }

    pub fn drawText(camera: Camera, comptime fmt: []const u8, args: anytype, position: [2]f32, color: u32) void {
        const window_position = zgui.getWindowPos();
        const mat = camera.matrix();

        var pos = mat.transformVec2(position);
        pos[0] += window_position[0];
        pos[1] += window_position[1];

        const draw_list = zgui.getWindowDrawList();
        draw_list.addText(pos, color, fmt, args);
    }

    pub fn drawRect(camera: Camera, rect: [4]f32, thickness: f32, color: u32) void {
        const rect_min_max = camera.getRectMinMax(rect);

        const draw_list = zgui.getWindowDrawList();
        draw_list.addRect(.{
            .pmin = rect_min_max[0],
            .pmax = rect_min_max[1],
            .col = color,
            .thickness = thickness,
        });
    }

    pub fn drawRectFilled(camera: Camera, rect: [4]f32, color: u32) void {
        const rect_min_max = camera.getRectMinMax(rect);

        const draw_list = zgui.getWindowDrawList();
        draw_list.addRectFilled(.{
            .pmin = rect_min_max[0],
            .pmax = rect_min_max[1],
            .col = color,
        });
    }

    pub fn drawAnimationRect(camera: Camera, start_rect: [4]f32, end_rect: [4]f32, thickness: f32, start_color: u32, end_color: u32) void {
        const start_rect_min_max = camera.getRectMinMax(start_rect);
        const end_rect_min_max = camera.getRectMinMax(end_rect);

        const width = start_rect_min_max[1][0] - start_rect_min_max[0][0];

        const draw_list = zgui.getWindowDrawList();

        // Start
        draw_list.addLine(.{
            .p1 = start_rect_min_max[0],
            .p2 = .{ start_rect_min_max[0][0] + width / 2.0, start_rect_min_max[0][1] },
            .col = start_color,
            .thickness = thickness,
        });
        draw_list.addLine(.{
            .p1 = start_rect_min_max[0],
            .p2 = .{ start_rect_min_max[0][0], start_rect_min_max[1][1] },
            .col = start_color,
            .thickness = thickness,
        });
        draw_list.addLine(.{
            .p1 = .{ start_rect_min_max[0][0], start_rect_min_max[1][1] },
            .p2 = .{ start_rect_min_max[0][0] + width / 2.0, start_rect_min_max[1][1] },
            .col = start_color,
            .thickness = thickness,
        });
        // End
        draw_list.addLine(.{
            .p1 = end_rect_min_max[1],
            .p2 = .{ end_rect_min_max[1][0] - width / 2.0, end_rect_min_max[1][1] },
            .col = end_color,
            .thickness = thickness,
        });
        draw_list.addLine(.{
            .p1 = end_rect_min_max[1],
            .p2 = .{ end_rect_min_max[1][0], end_rect_min_max[0][1] },
            .col = end_color,
            .thickness = thickness,
        });
        draw_list.addLine(.{
            .p1 = .{ end_rect_min_max[1][0], end_rect_min_max[0][1] },
            .p2 = .{ end_rect_min_max[1][0] - width / 2.0, end_rect_min_max[0][1] },
            .col = end_color,
            .thickness = thickness,
        });
    }

    pub fn drawTexture(camera: Camera, texture: *gpu.TextureView, width: u32, height: u32, position: [2]f32, color: u32) void {
        const rect_min_max = camera.getRectMinMax(.{ position[0], position[1], @as(f32, @floatFromInt(width)), @as(f32, @floatFromInt(height)) });

        const draw_list = zgui.getWindowDrawList();

        draw_list.addImage(texture, .{
            .pmin = rect_min_max[0],
            .pmax = rect_min_max[1],
            .col = color,
        });
    }

    pub fn drawCursor(_: Camera, texture: *gpu.TextureView, width: u32, height: u32, color: u32) void {
        zgui.setMouseCursor(.none);
        if (pixi.application.core.cursorMode() == .normal)
            pixi.application.core.setCursorMode(.hidden);
        var position = pixi.state.controls.mouse.position.toSlice();

        const draw_list = zgui.getForegroundDrawList();

        draw_list.addImage(texture, .{
            .pmin = .{ position[0], position[1] - @as(f32, @floatFromInt(height)) },
            .pmax = .{ position[0] + @as(f32, @floatFromInt(width)), position[1] },
            .col = color,
        });
    }

    pub fn drawLayer(camera: Camera, layer: pixi.storage.Internal.Layer, position: [2]f32) void {
        const rect_min_max = camera.getRectMinMax(.{ position[0], position[1], @as(f32, @floatFromInt(layer.texture.image.width)), @as(f32, @floatFromInt(layer.texture.image.height)) });

        const draw_list = zgui.getWindowDrawList();

        draw_list.addImage(layer.texture.view_handle, .{
            .pmin = rect_min_max[0],
            .pmax = rect_min_max[1],
            .col = 0xFFFFFFFF,
        });
    }

    pub fn drawSprite(camera: Camera, layer: pixi.storage.Internal.Layer, src_rect: [4]f32, dst_rect: [4]f32) void {
        const rect_min_max = camera.getRectMinMax(dst_rect);

        const inv_w = 1.0 / @as(f32, @floatFromInt(layer.texture.image.width));
        const inv_h = 1.0 / @as(f32, @floatFromInt(layer.texture.image.height));

        const uvmin: [2]f32 = .{ src_rect[0] * inv_w, src_rect[1] * inv_h };
        const uvmax: [2]f32 = .{ (src_rect[0] + src_rect[2]) * inv_w, (src_rect[1] + src_rect[3]) * inv_h };

        const draw_list = zgui.getWindowDrawList();

        draw_list.addImage(layer.texture.view_handle, .{
            .pmin = rect_min_max[0],
            .pmax = rect_min_max[1],
            .uvmin = uvmin,
            .uvmax = uvmax,
            .col = 0xFFFFFFFF,
        });
    }

    pub fn nearestZoomIndex(camera: Camera) usize {
        var nearest_zoom_index: usize = 0;
        var nearest_zoom_step: f32 = pixi.state.settings.zoom_steps[nearest_zoom_index];
        for (pixi.state.settings.zoom_steps, 0..) |step, i| {
            const step_difference = @fabs(camera.zoom - step);
            const current_difference = @fabs(camera.zoom - nearest_zoom_step);
            if (step_difference < current_difference) {
                nearest_zoom_step = step;
                nearest_zoom_index = i;
            }
        }
        return nearest_zoom_index;
    }

    pub fn setNearestZoom(camera: *Camera) void {
        camera.zoom = pixi.state.settings.zoom_steps[camera.nearestZoomIndex()];
    }

    pub fn setNearestZoomFloor(camera: *Camera) void {
        var nearest_zoom_index = camera.nearestZoomIndex();
        if (nearest_zoom_index > 0)
            nearest_zoom_index -= 1;
        camera.zoom = pixi.state.settings.zoom_steps[nearest_zoom_index];
    }

    pub fn isHovered(camera: Camera, rect: [4]f32) bool {
        const mouse_position: [2]f32 = .{ pixi.state.controls.mouse.position.x, pixi.state.controls.mouse.position.y };
        return camera.isContained(rect, mouse_position);
    }

    pub fn isContained(camera: Camera, rect: [4]f32, position: [2]f32) bool {
        const rect_min_max = camera.getRectMinMax(rect);
        return (position[0] > rect_min_max[0][0] and position[0] < rect_min_max[1][0] and position[1] < rect_min_max[1][1] and position[1] > rect_min_max[0][1]);
    }

    pub fn getRectMinMax(camera: Camera, rect: [4]f32) [2][2]f32 {
        const window_position = zgui.getWindowPos();
        const mat = camera.matrix();
        var tl = mat.transformVec2(.{ rect[0], rect[1] });
        tl[0] += window_position[0];
        tl[1] += window_position[1];
        var br: [2]f32 = .{ rect[0], rect[1] };
        br[0] += rect[2];
        br[1] += rect[3];
        br = mat.transformVec2(br);
        br[0] += window_position[0];
        br[1] += window_position[1];

        tl[0] = std.math.floor(tl[0]);
        tl[1] = std.math.floor(tl[1]);
        br[0] = std.math.floor(br[0]);
        br[1] = std.math.floor(br[1]);

        return .{ tl, br };
    }

    const PixelCoordinatesOptions = struct {
        texture_position: [2]f32,
        position: [2]f32,
        width: u32,
        height: u32,
    };

    pub fn pixelCoordinates(camera: Camera, options: PixelCoordinatesOptions) ?[2]f32 {
        const screen_position = zgui.getCursorScreenPos();
        var tl = camera.matrix().transformVec2(options.texture_position);
        tl[0] += screen_position[0];
        tl[1] += screen_position[1];
        var br = options.texture_position;
        br[0] += @as(f32, @floatFromInt(options.width));
        br[1] += @as(f32, @floatFromInt(options.height));
        br = camera.matrix().transformVec2(br);
        br[0] += screen_position[0];
        br[1] += screen_position[1];

        if (options.position[0] > tl[0] and options.position[0] < br[0] and options.position[1] < br[1] and options.position[1] > tl[1]) {
            var pixel_pos: [2]f32 = .{ 0.0, 0.0 };

            pixel_pos[0] = @divTrunc(options.position[0] - tl[0], camera.zoom);
            pixel_pos[1] = @divTrunc(options.position[1] - tl[1], camera.zoom);

            return pixel_pos;
        } else return null;
    }

    const FlipbookPixelCoordinatesOptions = struct {
        sprite_position: [2]f32,
        position: [2]f32,
        width: u32,
        height: u32,
    };

    pub fn flipbookPixelCoordinates(camera: Camera, file: *pixi.storage.Internal.Pixi, options: FlipbookPixelCoordinatesOptions) ?[2]f32 {
        const i = file.selected_sprite_index;
        const tile_width = @as(f32, @floatFromInt(file.tile_width));
        const tile_height = @as(f32, @floatFromInt(file.tile_height));
        const sprite_scale = std.math.clamp(0.5 / @fabs(@as(f32, @floatFromInt(i)) + (file.flipbook_scroll / tile_width / 1.1)), 0.5, 1.0);
        var dst_x: f32 = options.sprite_position[0] + file.flipbook_scroll + @as(f32, @floatFromInt(i)) * tile_width * 1.1 - (tile_width * sprite_scale / 2.0);
        var dst_y: f32 = options.sprite_position[1] + ((1.0 - sprite_scale) * (tile_height / 2.0));
        var dst_width: f32 = tile_width * sprite_scale;
        var dst_height: f32 = tile_height * sprite_scale;
        const dst_rect: [4]f32 = .{ dst_x, dst_y, dst_width, dst_height };
        const rect_min_max = camera.getRectMinMax(dst_rect);

        if (options.position[0] > rect_min_max[0][0] and options.position[0] < rect_min_max[1][0] and options.position[1] < rect_min_max[1][1] and options.position[1] > rect_min_max[0][1]) {
            const tiles_wide = @divExact(file.width, file.tile_width);
            const column = @as(f32, @floatFromInt(@mod(@as(u32, @intCast(i)), tiles_wide)));
            const row = @as(f32, @floatFromInt(@divTrunc(@as(u32, @intCast(i)), tiles_wide)));

            var pixel_pos: [2]f32 = .{ 0.0, 0.0 };
            pixel_pos[0] = @divTrunc(options.position[0] - rect_min_max[0][0], camera.zoom) + (column * tile_width);
            pixel_pos[1] = @divTrunc(options.position[1] - rect_min_max[0][1], camera.zoom) + (row * tile_height);
            return pixel_pos;
        } else return null;
    }

    pub fn processPanZoom(camera: *Camera) void {
        var zoom_key = if (pixi.state.hotkeys.hotkey(.{ .proc = .zoom })) |hotkey| hotkey.down() else false;
        if (pixi.state.settings.input_scheme != .trackpad) zoom_key = true;

        // Handle controls while canvas is hovered
        if (zgui.isWindowHovered(.{})) {
            if (pixi.state.controls.mouse.scroll_x) |x| {
                if (!zoom_key and camera.zoom_timer >= pixi.state.settings.zoom_time) {
                    camera.position[0] -= x * pixi.state.settings.pan_sensitivity * (1.0 / camera.zoom);
                }
                pixi.state.controls.mouse.scroll_x = null;
            }
            if (pixi.state.controls.mouse.scroll_y) |y| {
                if (zoom_key) {
                    camera.zoom_timer = 0.0;
                    camera.zoom_wait_timer = 0.0;

                    switch (pixi.state.settings.input_scheme) {
                        .trackpad => {
                            const nearest_zoom_index = camera.nearestZoomIndex();
                            const t = @as(f32, @floatFromInt(nearest_zoom_index)) / @as(f32, @floatFromInt(pixi.state.settings.zoom_steps.len - 1));
                            const sensitivity = pixi.math.lerp(pixi.state.settings.zoom_min_sensitivity, pixi.state.settings.zoom_max_sensitivity, t);
                            const zoom_delta = y * sensitivity;

                            camera.zoom += zoom_delta;
                        },
                        .mouse => {
                            const nearest_zoom_index = camera.nearestZoomIndex();
                            const sign = std.math.sign(y);
                            if (sign > 0.0 and nearest_zoom_index + 1 < pixi.state.settings.zoom_steps.len - 1) {
                                camera.zoom = pixi.state.settings.zoom_steps[nearest_zoom_index + 1];
                            } else if (sign < 0.0 and nearest_zoom_index >= 1) {
                                camera.zoom = pixi.state.settings.zoom_steps[nearest_zoom_index - 1];
                            }
                        },
                    }
                } else if (camera.zoom_timer >= pixi.state.settings.zoom_time) {
                    camera.position[1] -= y * pixi.state.settings.pan_sensitivity * (1.0 / camera.zoom);
                }
                pixi.state.controls.mouse.scroll_y = null;
            }
            const mouse_drag_delta = zgui.getMouseDragDelta(.middle, .{ .lock_threshold = 0.0 });
            if (mouse_drag_delta[0] != 0.0 or mouse_drag_delta[1] != 0.0) {
                camera.position[0] -= mouse_drag_delta[0] * (1.0 / camera.zoom);
                camera.position[1] -= mouse_drag_delta[1] * (1.0 / camera.zoom);

                zgui.resetMouseDragDelta(.middle);
            }
            camera.zoom_wait_timer = @min(camera.zoom_wait_timer + pixi.state.delta_time, pixi.state.settings.zoom_wait_time);
        }

        // Round to nearest pixel perfect zoom step when zoom key is released
        switch (pixi.state.settings.input_scheme) {
            .trackpad => {
                if (!zoom_key) {
                    camera.zoom_timer = @min(camera.zoom_timer + pixi.state.delta_time, pixi.state.settings.zoom_time);
                }
            },
            .mouse => {
                if (pixi.state.controls.mouse.scroll_x == null and pixi.state.controls.mouse.scroll_y == null and camera.zoom_wait_timer >= pixi.state.settings.zoom_wait_time) {
                    camera.zoom_timer = @min(camera.zoom_timer + pixi.state.delta_time, pixi.state.settings.zoom_time);
                }
            },
        }

        const nearest_zoom_index = camera.nearestZoomIndex();
        if (camera.zoom_timer < pixi.state.settings.zoom_time) {
            camera.zoom = pixi.math.lerp(camera.zoom, pixi.state.settings.zoom_steps[nearest_zoom_index], camera.zoom_timer / pixi.state.settings.zoom_time);
        } else {
            camera.zoom = pixi.state.settings.zoom_steps[nearest_zoom_index];
        }
    }

    pub fn drawLayerTooltip(camera: Camera, layer_index: usize) void {
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.window_padding, .v = .{ 8.0 * pixi.content_scale[0], 8.0 * pixi.content_scale[1] } });
        zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.window_rounding, .v = 8.0 * pixi.content_scale[0] });
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 4.0 * pixi.content_scale[0], 4.0 * pixi.content_scale[1] } });
        defer zgui.popStyleVar(.{ .count = 3 });
        _ = camera;
        if (zgui.beginTooltip()) {
            defer zgui.endTooltip();
            const layer_name = pixi.state.open_files.items[pixi.state.open_file_index].layers.items[layer_index].name;
            zgui.text("{s} {s}", .{ pixi.fa.layer_group, layer_name });
        }
    }

    pub fn drawZoomTooltip(camera: Camera, zoom: f32) void {
        _ = camera;
        if (zgui.beginTooltip()) {
            defer zgui.endTooltip();
            zgui.textColored(pixi.state.style.text.toSlice(), "{s} ", .{pixi.fa.search});
            zgui.sameLine(.{});
            zgui.textColored(pixi.state.style.text_secondary.toSlice(), "{d:0.1}", .{zoom});
        }
    }

    pub fn drawColorTooltip(camera: Camera, color: [4]u8) void {
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.window_padding, .v = .{ 8.0 * pixi.content_scale[0], 8.0 * pixi.content_scale[1] } });
        zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.window_rounding, .v = 8.0 * pixi.content_scale[0] });
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 4.0 * pixi.content_scale[0], 4.0 * pixi.content_scale[1] } });
        defer zgui.popStyleVar(.{ .count = 3 });
        _ = camera;
        if (zgui.beginTooltip()) {
            defer zgui.endTooltip();
            const col: [4]f32 = .{
                @as(f32, @floatFromInt(color[0])) / 255.0,
                @as(f32, @floatFromInt(color[1])) / 255.0,
                @as(f32, @floatFromInt(color[2])) / 255.0,
                @as(f32, @floatFromInt(color[3])) / 255.0,
            };
            _ = zgui.colorButton("Eyedropper", .{
                .col = col,
                .w = pixi.state.settings.eyedropper_preview_size * pixi.content_scale[0],
                .h = pixi.state.settings.eyedropper_preview_size * pixi.content_scale[1],
            });
            zgui.text("R: {d}", .{color[0]});
            zgui.text("G: {d}", .{color[1]});
            zgui.text("B: {d}", .{color[2]});
            zgui.text("A: {d}", .{color[3]});
        }
    }

    pub fn processZoomTooltip(camera: *Camera, zoom: f32) void {
        var zoom_key = if (pixi.state.hotkeys.hotkey(.{ .proc = .zoom })) |hotkey| hotkey.down() else false;

        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.window_padding, .v = .{ 8.0 * pixi.content_scale[0], 8.0 * pixi.content_scale[1] } });
        zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.window_rounding, .v = 8.0 * pixi.content_scale[0] });
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 4.0 * pixi.content_scale[0], 4.0 * pixi.content_scale[1] } });
        defer zgui.popStyleVar(.{ .count = 3 });
        // Draw current zoom tooltip
        if (camera.zoom_tooltip_timer < pixi.state.settings.zoom_tooltip_time) {
            camera.zoom_tooltip_timer = @min(camera.zoom_tooltip_timer + pixi.state.delta_time, pixi.state.settings.zoom_tooltip_time);
            camera.drawZoomTooltip(zoom);
        } else if (zoom_key and pixi.state.settings.input_scheme == .trackpad) {
            camera.zoom_tooltip_timer = 0.0;
            camera.drawZoomTooltip(zoom);
        } else if (!zoom_key and pixi.state.settings.input_scheme == .mouse) {
            if (camera.zoom_wait_timer < pixi.state.settings.zoom_wait_time) {
                camera.zoom_tooltip_timer = 0.0;
                camera.drawZoomTooltip(zoom);
            }
        }
    }
};

pub const Matrix3x2 = struct {
    data: [6]f32 = undefined,

    pub const TransformParams = struct { x: f32 = 0, y: f32 = 0, angle: f32 = 0, sx: f32 = 1, sy: f32 = 1, ox: f32 = 0, oy: f32 = 0 };

    pub const identity = Matrix3x2{ .data = .{ 1, 0, 0, 1, 0, 0 } };

    pub fn format(self: Matrix3x2, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options;
        _ = fmt;
        return writer.print("{d:0.6}, {d:0.6}, {d:0.6}, {d:0.6}, {d:0.6}, {d:0.6}", .{ self.data[0], self.data[1], self.data[2], self.data[3], self.data[4], self.data[5] });
    }

    pub fn init() Matrix3x2 {
        return identity;
    }

    pub fn initTransform(vals: TransformParams) Matrix3x2 {
        var mat = Matrix3x2{};
        mat.setTransform(vals);
        return mat;
    }

    pub fn initOrtho(width: f32, height: f32) Matrix3x2 {
        var result = Matrix3x2{};
        result.data[0] = 2 / width;
        result.data[3] = -2 / height;
        result.data[4] = -1;
        result.data[5] = 1;
        return result;
    }

    pub fn initOrthoOffCenter(width: f32, height: f32) Matrix3x2 {
        const half_w = @ceil(width / 2);
        const half_h = @ceil(height / 2);

        var result = identity;
        result.data[0] = 2.0 / (half_w + half_w);
        result.data[3] = 2.0 / (-half_h - half_h);
        result.data[4] = (-half_w + half_w) / (-half_w - half_w);
        result.data[5] = (half_h - half_h) / (half_h + half_h);
        return result;
    }

    pub fn setTransform(self: *Matrix3x2, vals: TransformParams) void {
        const c = @cos(vals.angle);
        const s = @sin(vals.angle);

        // matrix multiplication carried out on paper:
        // |1    x| |c -s  | |sx     | |1   -ox|
        // |  1  y| |s  c  | |   sy  | |  1 -oy|
        //   move    rotate    scale     origin
        self.data[0] = c * vals.sx;
        self.data[1] = s * vals.sx;
        self.data[2] = -s * vals.sy;
        self.data[3] = c * vals.sy;
        self.data[4] = vals.x - vals.ox * self.data[0] - vals.oy * self.data[2];
        self.data[5] = vals.y - vals.ox * self.data[1] - vals.oy * self.data[3];
    }

    pub fn mul(self: Matrix3x2, r: Matrix3x2) Matrix3x2 {
        var result = Matrix3x2{};
        result.data[0] = self.data[0] * r.data[0] + self.data[2] * r.data[1];
        result.data[1] = self.data[1] * r.data[0] + self.data[3] * r.data[1];
        result.data[2] = self.data[0] * r.data[2] + self.data[2] * r.data[3];
        result.data[3] = self.data[1] * r.data[2] + self.data[3] * r.data[3];
        result.data[4] = self.data[0] * r.data[4] + self.data[2] * r.data[5] + self.data[4];
        result.data[5] = self.data[1] * r.data[4] + self.data[3] * r.data[5] + self.data[5];
        return result;
    }

    pub fn translate(self: *Matrix3x2, x: f32, y: f32) void {
        self.data[4] = self.data[0] * x + self.data[2] * y + self.data[4];
        self.data[5] = self.data[1] * x + self.data[3] * y + self.data[5];
    }

    pub fn scale(self: *Matrix3x2, x: f32, y: f32) void {
        self.data[0] *= x;
        self.data[1] *= x;
        self.data[2] *= y;
        self.data[3] *= y;
    }

    pub fn determinant(self: Matrix3x2) f32 {
        return self.data[0] * self.data[3] - self.data[2] * self.data[1];
    }

    pub fn inverse(self: Matrix3x2) Matrix3x2 {
        var res = std.mem.zeroes(Matrix3x2);
        const s = 1.0 / self.determinant();
        res.data[0] = self.data[3] * s;
        res.data[1] = -self.data[1] * s;
        res.data[2] = -self.data[2] * s;
        res.data[3] = self.data[0] * s;
        res.data[4] = (self.data[5] * self.data[2] - self.data[4] * self.data[3]) * s;
        res.data[5] = -(self.data[5] * self.data[0] - self.data[4] * self.data[1]) * s;

        return res;
    }

    pub fn transformVec2(self: Matrix3x2, pos: [2]f32) [2]f32 {
        return .{
            pos[0] * self.data[0] + pos[1] * self.data[2] + self.data[4],
            pos[0] * self.data[1] + pos[1] * self.data[3] + self.data[5],
        };
    }
};
