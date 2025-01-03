const std = @import("std");
const zm = @import("zmath");
const pixi = @import("../Pixi.zig");
const mach = @import("mach");
const gpu = @import("mach").gpu;
const imgui = @import("zig-imgui");

pub const Camera = struct {
    position: [2]f32 = .{ 0.0, 0.0 },
    zoom: f32 = 1.0,
    zoom_initialized: bool = false,
    zoom_timer: f32 = 0.2,
    zoom_wait_timer: f32 = 0.4,
    zoom_tooltip_timer: f32 = 0.6,
    min_zoom: f32 = 0.1,

    pub fn matrix(self: Camera) Matrix3x2 {
        const window_size = imgui.getWindowSize();
        const window_half_size: [2]f32 = .{ @trunc(window_size.x * 0.5), @trunc(window_size.y * 0.5) };

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

    pub fn drawGrid(camera: Camera, position: [2]f32, width: f32, height: f32, columns: usize, rows: usize, color: u32, skip_centers: bool) void {
        const rect_min_max = camera.getRectMinMax(.{ position[0], position[1], width, height });

        const tile_width = width / @as(f32, @floatFromInt(columns));
        const tile_height = height / @as(f32, @floatFromInt(rows));

        if (imgui.getWindowDrawList()) |draw_list| {
            var i: usize = 0;
            while (i < columns + 1) : (i += 1) {
                if (skip_centers) {
                    if (@divFloor(columns, 2) == i)
                        continue;
                }

                const p1: imgui.Vec2 = .{ .x = rect_min_max[0][0] + @as(f32, @floatFromInt(i)) * tile_width * camera.zoom, .y = rect_min_max[0][1] };
                const p2: imgui.Vec2 = .{ .x = rect_min_max[0][0] + @as(f32, @floatFromInt(i)) * tile_width * camera.zoom, .y = rect_min_max[0][1] + height * camera.zoom };
                draw_list.addLineEx(
                    p1,
                    p2,
                    color,
                    1.0,
                );
            }

            i = 0;
            while (i < rows + 1) : (i += 1) {
                if (skip_centers) {
                    if (@divFloor(rows, 2) == i)
                        continue;
                }
                const p1: imgui.Vec2 = .{ .x = rect_min_max[0][0], .y = rect_min_max[0][1] + @as(f32, @floatFromInt(i)) * tile_height * camera.zoom };
                const p2: imgui.Vec2 = .{ .x = rect_min_max[0][0] + width * camera.zoom, .y = rect_min_max[0][1] + @as(f32, @floatFromInt(i)) * tile_height * camera.zoom };
                draw_list.addLineEx(
                    p1,
                    p2,
                    color,
                    1.0,
                );
            }
        }
    }

    pub fn drawLine(camera: Camera, start: [2]f32, end: [2]f32, color: u32, thickness: f32) void {
        const window_position = imgui.getWindowPos();
        const mat = camera.matrix();

        var p1 = mat.transformVec2(start);
        p1[0] += window_position.x;
        p1[1] += window_position.y;
        var p2 = mat.transformVec2(end);
        p2[0] += window_position.x;
        p2[1] += window_position.y;

        p1[0] = std.math.floor(p1[0]);
        p1[1] = std.math.floor(p1[1]);
        p2[0] = std.math.floor(p2[0]);
        p2[1] = std.math.floor(p2[1]);

        const p1_vec: imgui.Vec2 = .{ .x = p1[0], .y = p1[1] };
        const p2_vec: imgui.Vec2 = .{ .x = p2[0], .y = p2[1] };

        if (imgui.getWindowDrawList()) |draw_list| {
            draw_list.addLineEx(
                p1_vec,
                p2_vec,
                color,
                thickness,
            );
        }
    }

    pub fn drawText(camera: Camera, comptime fmt: []const u8, args: anytype, position: [2]f32, color: u32) void {
        const window_position = imgui.getWindowPos();
        const mat = camera.matrix();

        var pos = mat.transformVec2(position);
        pos[0] += window_position.x;
        pos[1] += window_position.y;

        const pos_vec: imgui.Vec2 = .{ .x = pos[0], .y = pos[1] };

        const text = std.fmt.allocPrintZ(pixi.state.allocator, fmt, args) catch unreachable;
        defer pixi.state.allocator.free(text);

        if (imgui.getWindowDrawList()) |draw_list|
            draw_list.addText(pos_vec, color, text.ptr);
    }

    pub fn drawTextWithShadow(camera: Camera, comptime fmt: []const u8, args: anytype, position: [2]f32, color: u32, shadow_color: u32) void {
        const window_position = imgui.getWindowPos();
        const mat = camera.matrix();

        var pos = mat.transformVec2(position);
        pos[0] += window_position.x;
        pos[1] += window_position.y;

        const pos_vec: imgui.Vec2 = .{ .x = pos[0], .y = pos[1] };

        const text = std.fmt.allocPrintZ(pixi.state.allocator, fmt, args) catch unreachable;
        defer pixi.state.allocator.free(text);

        if (imgui.getWindowDrawList()) |draw_list| {
            draw_list.addText(.{ .x = pos_vec.x + 1.0, .y = pos_vec.y }, shadow_color, text.ptr);
            draw_list.addText(.{ .x = pos_vec.x, .y = pos_vec.y + 1.0 }, shadow_color, text.ptr);
            draw_list.addText(pos_vec, color, text.ptr);
        }
    }

    pub fn drawCircle(camera: Camera, position: [2]f32, radius: f32, thickness: f32, color: u32) void {
        const window_position = imgui.getWindowPos();
        const mat = camera.matrix();

        var pos = mat.transformVec2(position);
        pos[0] += window_position.x;
        pos[1] += window_position.y;

        const pos_vec: imgui.Vec2 = .{ .x = pos[0], .y = pos[1] };

        if (imgui.getWindowDrawList()) |draw_list|
            draw_list.addCircleEx(pos_vec, radius, color, 100, thickness);
    }

    pub fn drawCircleFilled(camera: Camera, position: [2]f32, radius: f32, color: u32) void {
        const window_position = imgui.getWindowPos();
        const mat = camera.matrix();

        var pos = mat.transformVec2(position);
        pos[0] += window_position.x;
        pos[1] += window_position.y;

        const pos_vec: imgui.Vec2 = .{ .x = pos[0], .y = pos[1] };

        if (imgui.getWindowDrawList()) |draw_list|
            draw_list.addCircleFilled(pos_vec, radius, color, 20);
    }

    pub fn drawRect(camera: Camera, rect: [4]f32, thickness: f32, color: u32) void {
        const rect_min_max = camera.getRectMinMax(rect);

        const min: imgui.Vec2 = .{ .x = rect_min_max[0][0], .y = rect_min_max[0][1] };
        const max: imgui.Vec2 = .{ .x = rect_min_max[1][0], .y = rect_min_max[1][1] };

        if (imgui.getWindowDrawList()) |draw_list|
            draw_list.addRectEx(
                min,
                max,
                color,
                0.0,
                imgui.DrawFlags_None,
                thickness,
            );
    }

    pub fn drawRectFilled(camera: Camera, rect: [4]f32, color: u32) void {
        const rect_min_max = camera.getRectMinMax(rect);

        const min: imgui.Vec2 = .{ .x = rect_min_max[0][0], .y = rect_min_max[0][1] };
        const max: imgui.Vec2 = .{ .x = rect_min_max[1][0], .y = rect_min_max[1][1] };

        if (imgui.getWindowDrawList()) |draw_list|
            draw_list.addRectFilled(
                min,
                max,
                color,
            );
    }

    pub fn drawAnimationRect(camera: Camera, start_rect: [4]f32, end_rect: [4]f32, thickness: f32, start_color: u32, end_color: u32) void {
        const start_rect_min_max = camera.getRectMinMax(start_rect);
        const end_rect_min_max = camera.getRectMinMax(end_rect);

        const width = start_rect_min_max[1][0] - start_rect_min_max[0][0];

        const start_min: imgui.Vec2 = .{ .x = start_rect_min_max[0][0], .y = start_rect_min_max[0][1] };
        const end_max: imgui.Vec2 = .{ .x = end_rect_min_max[1][0], .y = end_rect_min_max[1][1] };

        if (imgui.getWindowDrawList()) |draw_list| {

            // Start
            draw_list.addLineEx(
                start_min,
                .{ .x = start_rect_min_max[0][0] + width / 2.0, .y = start_rect_min_max[0][1] },
                start_color,
                thickness,
            );
            draw_list.addLineEx(
                start_min,
                .{ .x = start_rect_min_max[0][0], .y = start_rect_min_max[1][1] },
                start_color,
                thickness,
            );
            draw_list.addLineEx(
                .{ .x = start_rect_min_max[0][0], .y = start_rect_min_max[1][1] },
                .{ .x = start_rect_min_max[0][0] + width / 2.0, .y = start_rect_min_max[1][1] },
                start_color,
                thickness,
            );
            // End
            draw_list.addLineEx(
                end_max,
                .{ .x = end_rect_min_max[1][0] - width / 2.0, .y = end_rect_min_max[1][1] },
                end_color,
                thickness,
            );
            draw_list.addLineEx(
                end_max,
                .{ .x = end_rect_min_max[1][0], .y = end_rect_min_max[0][1] },
                end_color,
                thickness,
            );
            draw_list.addLineEx(
                .{ .x = end_rect_min_max[1][0], .y = end_rect_min_max[0][1] },
                .{ .x = end_rect_min_max[1][0] - width / 2.0, .y = end_rect_min_max[0][1] },
                end_color,
                thickness,
            );
        }
    }

    pub fn drawTexture(camera: Camera, texture: *gpu.TextureView, width: u32, height: u32, position: [2]f32, color: u32) void {
        const rect_min_max = camera.getRectMinMax(.{ position[0], position[1], @as(f32, @floatFromInt(width)), @as(f32, @floatFromInt(height)) });

        const min: imgui.Vec2 = .{ .x = rect_min_max[0][0], .y = rect_min_max[0][1] };
        const max: imgui.Vec2 = .{ .x = rect_min_max[1][0], .y = rect_min_max[1][1] };

        if (imgui.getWindowDrawList()) |draw_list|
            draw_list.addImageEx(
                texture,
                min,
                max,
                .{ .x = 0.0, .y = 0.0 },
                .{ .x = 1.0, .y = 1.0 },
                color,
            );
    }

    pub fn drawCursor(self: Camera, sprite_index: usize, color: u32) void {
        _ = self;
        if (sprite_index >= pixi.state.loaded_assets.atlas.sprites.len) return;

        const sprite = pixi.state.loaded_assets.atlas.sprites[sprite_index];
        const texture = pixi.state.loaded_assets.atlas_png;
        const position = pixi.state.mouse.position;

        const sprite_source: [4]f32 = .{
            @floatFromInt(sprite.source[0]),
            @floatFromInt(sprite.source[1]),
            @floatFromInt(sprite.source[2]),
            @floatFromInt(sprite.source[3]),
        };

        const inv_w = 1.0 / @as(f32, @floatFromInt(texture.image.width));
        const inv_h = 1.0 / @as(f32, @floatFromInt(texture.image.height));

        var min: imgui.Vec2 = .{ .x = position[0], .y = position[1] };
        var max: imgui.Vec2 = .{ .x = position[0] + sprite_source[2], .y = position[1] + sprite_source[3] };

        min.x += @floatFromInt(sprite.origin[0]);
        min.y -= @floatFromInt(sprite.origin[1]);
        max.x += @floatFromInt(sprite.origin[0]);
        max.y -= @floatFromInt(sprite.origin[1]);

        const uvmin: imgui.Vec2 = .{ .x = sprite_source[0] * inv_w, .y = sprite_source[1] * inv_h };
        const uvmax: imgui.Vec2 = .{ .x = (sprite_source[0] + sprite_source[2]) * inv_w, .y = (sprite_source[1] + sprite_source[3]) * inv_h };

        if (imgui.getForegroundDrawList()) |draw_list|
            draw_list.addImageEx(
                texture.view_handle,
                min,
                max,
                uvmin,
                uvmax,
                color,
            );
    }

    pub fn drawLayer(camera: Camera, layer: pixi.storage.Internal.Layer, position: [2]f32) void {
        const rect_min_max = camera.getRectMinMax(.{ position[0], position[1], @as(f32, @floatFromInt(layer.texture.image.width)), @as(f32, @floatFromInt(layer.texture.image.height)) });

        const min: imgui.Vec2 = .{ .x = rect_min_max[0][0], .y = rect_min_max[0][1] };
        const max: imgui.Vec2 = .{ .x = rect_min_max[1][0], .y = rect_min_max[1][1] };

        if (imgui.getWindowDrawList()) |draw_list|
            draw_list.addImageEx(
                layer.texture.view_handle,
                min,
                max,
                .{ .x = 0.0, .y = 0.0 },
                .{ .x = 1.0, .y = 1.0 },
                0xFFFFFFFF,
            );
    }

    pub fn drawSprite(camera: Camera, layer: pixi.storage.Internal.Layer, src_rect: [4]f32, dst_rect: [4]f32) void {
        const rect_min_max = camera.getRectMinMax(dst_rect);

        const inv_w = 1.0 / @as(f32, @floatFromInt(layer.texture.image.width));
        const inv_h = 1.0 / @as(f32, @floatFromInt(layer.texture.image.height));

        const min: imgui.Vec2 = .{ .x = rect_min_max[0][0], .y = rect_min_max[0][1] };
        const max: imgui.Vec2 = .{ .x = rect_min_max[1][0], .y = rect_min_max[1][1] };

        const uvmin: imgui.Vec2 = .{ .x = src_rect[0] * inv_w, .y = src_rect[1] * inv_h };
        const uvmax: imgui.Vec2 = .{ .x = (src_rect[0] + src_rect[2]) * inv_w, .y = (src_rect[1] + src_rect[3]) * inv_h };

        if (imgui.getWindowDrawList()) |draw_list|
            draw_list.addImageEx(
                layer.texture.view_handle,
                min,
                max,
                uvmin,
                uvmax,
                0xFFFFFFFF,
            );
    }

    pub fn drawSpriteQuad(camera: Camera, layer: pixi.storage.Internal.Layer, src_rect: [4]f32, dst_p1: [2]f32, dst_p2: [2]f32, dst_p3: [2]f32, dst_p4: [2]f32) void {
        const dst = camera.getQuad(dst_p1, dst_p2, dst_p3, dst_p4);

        const inv_w = 1.0 / @as(f32, @floatFromInt(layer.texture.image.width));
        const inv_h = 1.0 / @as(f32, @floatFromInt(layer.texture.image.height));

        const uvmin: imgui.Vec2 = .{ .x = src_rect[0] * inv_w, .y = src_rect[1] * inv_h };
        const uvmax: imgui.Vec2 = .{ .x = (src_rect[0] + src_rect[2]) * inv_w, .y = (src_rect[1] + src_rect[3]) * inv_h };

        if (imgui.getWindowDrawList()) |draw_list| {
            draw_list.addImageQuadEx(
                layer.texture.view_handle,
                dst[0],
                dst[1],
                dst[2],
                dst[3],
                uvmin,
                .{ .x = uvmax.x, .y = uvmin.y },
                uvmax,
                .{ .x = uvmin.x, .y = uvmax.y },
                0xFFFFFFFF,
            );
        }
    }

    pub fn drawQuad(camera: Camera, dst_p1: [2]f32, dst_p2: [2]f32, dst_p3: [2]f32, dst_p4: [2]f32, color: u32, thickness: f32) void {
        const dst = camera.getQuad(dst_p1, dst_p2, dst_p3, dst_p4);

        if (imgui.getWindowDrawList()) |draw_list| {
            draw_list.addQuadEx(dst[0], dst[1], dst[2], dst[3], color, thickness);
        }
    }

    pub fn drawQuadFilled(camera: Camera, dst_p1: [2]f32, dst_p2: [2]f32, dst_p3: [2]f32, dst_p4: [2]f32, color: u32) void {
        const dst = camera.getQuad(dst_p1, dst_p2, dst_p3, dst_p4);

        if (imgui.getWindowDrawList()) |draw_list| {
            draw_list.addQuadFilled(dst[0], dst[1], dst[2], dst[3], color);
        }
    }

    pub fn nearestZoomIndex(camera: Camera) usize {
        var nearest_zoom_index: usize = 0;
        var nearest_zoom_step: f32 = pixi.state.settings.zoom_steps[nearest_zoom_index];
        for (pixi.state.settings.zoom_steps, 0..) |step, i| {
            const step_difference = @abs(camera.zoom - step);
            const current_difference = @abs(camera.zoom - nearest_zoom_step);
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

    pub fn setNearZoomFloor(camera: *Camera) void {
        var nearest_zoom_index = camera.nearestZoomIndex();
        if (nearest_zoom_index > 3)
            nearest_zoom_index -= 4;
        camera.zoom = pixi.state.settings.zoom_steps[nearest_zoom_index];
    }

    pub fn isHovered(camera: Camera, rect: [4]f32) bool {
        const mouse_position = pixi.state.mouse.position;
        return camera.isContained(rect, mouse_position);
    }

    pub fn isHoveredTriangle(camera: Camera, triangle: [3]zm.F32x4) bool {
        const mouse_position = pixi.state.mouse.position;
        return camera.isContainedTriangle(triangle, mouse_position);
    }

    pub fn isContained(camera: Camera, rect: [4]f32, position: [2]f32) bool {
        const rect_min_max = camera.getRectMinMax(rect);

        const min: [2]f32 = rect_min_max[0];
        const max: [2]f32 = rect_min_max[1];
        const rect_min_max_fixed: [2][2]f32 = .{
            .{ //min
                if (min[0] > max[0]) max[0] else min[0],
                if (min[1] > max[1]) max[1] else min[1],
            },
            .{ //max
                if (min[0] > max[0]) min[0] else max[0],
                if (min[1] > max[1]) min[1] else max[1],
            },
        };
        return (position[0] > rect_min_max_fixed[0][0] and position[0] < rect_min_max_fixed[1][0] and position[1] < rect_min_max_fixed[1][1] and position[1] > rect_min_max_fixed[0][1]);
    }

    pub fn isContainedTriangle(camera: Camera, triangle: [3]zm.F32x4, position: [2]f32) bool {
        const window_position_raw = imgui.getWindowPos();
        const window_position = zm.loadArr2(.{ window_position_raw.x, window_position_raw.y });
        const mat = camera.matrix();

        const triangle_1: [3]zm.F32x4 = .{
            zm.loadArr2(mat.transformVec2(.{ triangle[0][0], triangle[0][1] })) + window_position,
            zm.loadArr2(mat.transformVec2(.{ triangle[1][0], triangle[1][1] })) + window_position,
            zm.loadArr2(.{ position[0], position[1] }),
        };

        const triangle_2: [3]zm.F32x4 = .{
            zm.loadArr2(mat.transformVec2(.{ triangle[1][0], triangle[1][1] })) + window_position,
            zm.loadArr2(mat.transformVec2(.{ triangle[2][0], triangle[2][1] })) + window_position,
            zm.loadArr2(.{ position[0], position[1] }),
        };

        const triangle_3: [3]zm.F32x4 = .{
            zm.loadArr2(mat.transformVec2(.{ triangle[0][0], triangle[0][1] })) + window_position,
            zm.loadArr2(mat.transformVec2(.{ triangle[2][0], triangle[2][1] })) + window_position,
            zm.loadArr2(.{ position[0], position[1] }),
        };

        const triangle_4: [3]zm.F32x4 = .{
            zm.loadArr2(mat.transformVec2(.{ triangle[0][0], triangle[0][1] })) + window_position,
            zm.loadArr2(mat.transformVec2(.{ triangle[1][0], triangle[1][1] })) + window_position,
            zm.loadArr2(mat.transformVec2(.{ triangle[2][0], triangle[2][1] })) + window_position,
        };

        const area_1 = area(triangle_1);
        const area_2 = area(triangle_2);
        const area_3 = area(triangle_3);
        const area_4 = area(triangle_4);

        const combined = area_1 + area_2 + area_3;
        const diff = @abs(combined - area_4);

        return diff < 0.1;
    }

    fn area(triangle: [3]zm.F32x4) f32 {
        return @abs((triangle[0][0] * (triangle[1][1] - triangle[2][1]) + triangle[1][0] * (triangle[2][1] - triangle[0][1]) + triangle[2][0] * (triangle[0][1] - triangle[1][1])) / 2.0);
    }

    pub fn getRectMinMax(camera: Camera, rect: [4]f32) [2][2]f32 {
        const window_position = imgui.getWindowPos();
        const mat = camera.matrix();
        var tl = mat.transformVec2(.{ rect[0], rect[1] });
        tl[0] += window_position.x;
        tl[1] += window_position.y;
        var br: [2]f32 = .{ rect[0], rect[1] };
        br[0] += rect[2];
        br[1] += rect[3];
        br = mat.transformVec2(br);
        br[0] += window_position.x;
        br[1] += window_position.y;

        tl[0] = std.math.floor(tl[0]);
        tl[1] = std.math.floor(tl[1]);
        br[0] = std.math.floor(br[0]);
        br[1] = std.math.floor(br[1]);

        return .{ tl, br };
    }

    pub fn getQuad(camera: Camera, p1: [2]f32, p2: [2]f32, p3: [2]f32, p4: [2]f32) [4]imgui.Vec2 {
        const window_position = imgui.getWindowPos();
        const mat = camera.matrix();
        var p1_trans = mat.transformVec2(p1);
        p1_trans[0] += window_position.x;
        p1_trans[1] += window_position.y;
        var p2_trans = mat.transformVec2(p2);
        p2_trans[0] += window_position.x;
        p2_trans[1] += window_position.y;
        var p3_trans = mat.transformVec2(p3);
        p3_trans[0] += window_position.x;
        p3_trans[1] += window_position.y;
        var p4_trans = mat.transformVec2(p4);
        p4_trans[0] += window_position.x;
        p4_trans[1] += window_position.y;

        p1_trans[0] = @floor(p1_trans[0]);
        p1_trans[1] = @floor(p1_trans[1]);
        p2_trans[0] = @floor(p2_trans[0]);
        p2_trans[1] = @floor(p2_trans[1]);
        p3_trans[0] = @floor(p3_trans[0]);
        p3_trans[1] = @floor(p3_trans[1]);
        p4_trans[0] = @floor(p4_trans[0]);
        p4_trans[1] = @floor(p4_trans[1]);

        return .{
            .{ .x = p1_trans[0], .y = p1_trans[1] },
            .{ .x = p2_trans[0], .y = p2_trans[1] },
            .{ .x = p3_trans[0], .y = p3_trans[1] },
            .{ .x = p4_trans[0], .y = p4_trans[1] },
        };
    }

    const PixelCoordinatesOptions = struct {
        texture_position: [2]f32,
        position: [2]f32,
        width: u32,
        height: u32,
    };

    pub fn pixelCoordinates(camera: Camera, options: PixelCoordinatesOptions) ?[2]f32 {
        const screen_position = imgui.getCursorScreenPos();
        var tl = camera.matrix().transformVec2(options.texture_position);
        tl[0] += screen_position.x;
        tl[1] += screen_position.y;
        var br = options.texture_position;
        br[0] += @as(f32, @floatFromInt(options.width));
        br[1] += @as(f32, @floatFromInt(options.height));
        br = camera.matrix().transformVec2(br);
        br[0] += screen_position.x;
        br[1] += screen_position.y;

        if (options.position[0] > tl[0] and options.position[0] < br[0] and options.position[1] < br[1] and options.position[1] > tl[1]) {
            var pixel_pos: [2]f32 = .{ 0.0, 0.0 };

            pixel_pos[0] = @divTrunc(options.position[0] - tl[0], camera.zoom);
            pixel_pos[1] = @divTrunc(options.position[1] - tl[1], camera.zoom);

            return pixel_pos;
        } else return null;
    }

    pub fn pixelCoordinatesRaw(camera: Camera, options: PixelCoordinatesOptions) [2]f32 {
        const screen_position = imgui.getCursorScreenPos();
        var tl = camera.matrix().transformVec2(options.texture_position);
        tl[0] += screen_position.x;
        tl[1] += screen_position.y;
        var br = options.texture_position;
        br[0] += @as(f32, @floatFromInt(options.width));
        br[1] += @as(f32, @floatFromInt(options.height));
        br = camera.matrix().transformVec2(br);
        br[0] += screen_position.x;
        br[1] += screen_position.y;

        var pixel_pos: [2]f32 = .{ 0.0, 0.0 };

        pixel_pos[0] = @divTrunc(options.position[0] - tl[0], camera.zoom);
        pixel_pos[1] = @divTrunc(options.position[1] - tl[1], camera.zoom);

        return pixel_pos;
    }

    pub fn coordinatesRaw(camera: Camera, options: PixelCoordinatesOptions) [2]f32 {
        const screen_position = imgui.getCursorScreenPos();
        var tl = camera.matrix().transformVec2(options.texture_position);
        tl[0] += screen_position.x;
        tl[1] += screen_position.y;
        var br = options.texture_position;
        br[0] += @as(f32, @floatFromInt(options.width));
        br[1] += @as(f32, @floatFromInt(options.height));
        br = camera.matrix().transformVec2(br);
        br[0] += screen_position.x;
        br[1] += screen_position.y;

        var pixel_pos: [2]f32 = .{ 0.0, 0.0 };

        pixel_pos[0] = (options.position[0] - tl[0]) / camera.zoom;
        pixel_pos[1] = (options.position[1] - tl[1]) / camera.zoom;

        return pixel_pos;
    }

    const FlipbookPixelCoordinatesOptions = struct {
        sprite_position: [2]f32,
        position: [2]f32,
        width: u32,
        height: u32,
    };

    pub fn flipbookPixelCoordinates(camera: Camera, file: *pixi.storage.Internal.PixiFile, options: FlipbookPixelCoordinatesOptions) ?[2]f32 {
        const i = file.selected_sprite_index;
        const tile_width = @as(f32, @floatFromInt(file.tile_width));
        const tile_height = @as(f32, @floatFromInt(file.tile_height));
        const sprite_scale = std.math.clamp(0.4 / @abs(@as(f32, @floatFromInt(i)) / 1.2 + (file.flipbook_scroll / tile_width / 1.2)), 0.4, 1.0);
        const dst_x: f32 = options.sprite_position[0] + file.flipbook_scroll + (@as(f32, @floatFromInt(i)) / 1.2 * tile_width * 1.2) - (tile_width * sprite_scale / 1.2) - (1.0 - sprite_scale) * (tile_width * 0.5);
        const dst_y: f32 = options.sprite_position[1];
        const dst_width: f32 = tile_width * sprite_scale;
        const dst_height: f32 = tile_height * sprite_scale;
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

    pub const PanZoomTarget = enum {
        primary,
        flipbook,
        reference,
    };

    pub fn processPanZoom(camera: *Camera, target: PanZoomTarget) void {
        var zoom_key = if (pixi.state.hotkeys.hotkey(.{ .proc = .zoom })) |hotkey| hotkey.down() else false;
        if (pixi.state.settings.input_scheme != .trackpad) zoom_key = true;
        if (pixi.state.mouse.magnify != null) zoom_key = true;

        const canvas_center_offset = switch (target) {
            .primary => pixi.state.open_files.items[pixi.state.open_file_index].canvasCenterOffset(.primary),
            .flipbook => pixi.state.open_files.items[pixi.state.open_file_index].canvasCenterOffset(.flipbook),
            .reference => pixi.state.open_references.items[pixi.state.open_reference_index].canvasCenterOffset(),
        };

        const canvas_width = switch (target) {
            .primary, .flipbook => pixi.state.open_files.items[pixi.state.open_file_index].width,
            .reference => pixi.state.open_references.items[pixi.state.open_reference_index].texture.image.width,
        };

        const canvas_height = switch (target) {
            .primary, .flipbook => pixi.state.open_files.items[pixi.state.open_file_index].height,
            .reference => pixi.state.open_references.items[pixi.state.open_reference_index].texture.image.height,
        };

        const previous_zoom = camera.zoom;

        const previous_mouse = camera.coordinatesRaw(.{
            .texture_position = canvas_center_offset,
            .position = pixi.state.mouse.position,
            .width = canvas_width,
            .height = canvas_height,
        });

        // Handle controls while canvas is hovered
        if (imgui.isWindowHovered(imgui.HoveredFlags_None)) {
            camera.processZoomTooltip();
            if (pixi.state.mouse.scroll_x) |x| {
                if (!zoom_key and camera.zoom_timer >= pixi.state.settings.zoom_time) {
                    camera.position[0] -= x * pixi.state.settings.pan_sensitivity * (1.0 / camera.zoom);
                }
                pixi.state.mouse.scroll_x = null;
            }

            if (pixi.state.mouse.scroll_y) |y| {
                if (zoom_key) {
                    camera.zoom_timer = 0.0;
                    camera.zoom_wait_timer = 0.0;

                    switch (pixi.state.settings.input_scheme) {
                        .trackpad => {
                            const nearest_zoom_index = camera.nearestZoomIndex();
                            const t = @as(f32, @floatFromInt(nearest_zoom_index)) / @as(f32, @floatFromInt(pixi.state.settings.zoom_steps.len - 1));
                            const sensitivity = pixi.math.lerp(pixi.state.settings.zoom_min_sensitivity, pixi.state.settings.zoom_max_sensitivity, t) * (pixi.state.settings.zoom_sensitivity / 100.0);
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
                pixi.state.mouse.scroll_y = null;
            }

            if (pixi.state.mouse.magnify) |magnification| {
                camera.zoom_timer = 0.0;
                camera.zoom_wait_timer = 0.0;

                const nearest_zoom_index = camera.nearestZoomIndex();
                const t = @as(f32, @floatFromInt(nearest_zoom_index)) / @as(f32, @floatFromInt(pixi.state.settings.zoom_steps.len - 1));
                const sensitivity = pixi.math.lerp(pixi.state.settings.zoom_min_sensitivity, pixi.state.settings.zoom_max_sensitivity, t) * (pixi.state.settings.zoom_sensitivity / 100.0);
                const zoom_delta = magnification * 60 * sensitivity;

                camera.zoom += zoom_delta;

                pixi.state.mouse.magnify = null;
            }

            const mouse_drag_delta = imgui.getMouseDragDelta(imgui.MouseButton_Middle, 0.0);
            if (mouse_drag_delta.x != 0.0 or mouse_drag_delta.y != 0.0) {
                camera.position[0] -= mouse_drag_delta.x * (1.0 / camera.zoom);
                camera.position[1] -= mouse_drag_delta.y * (1.0 / camera.zoom);

                imgui.resetMouseDragDeltaEx(imgui.MouseButton_Middle);
            }
        }

        camera.zoom_wait_timer = @min(camera.zoom_wait_timer + pixi.state.delta_time, pixi.state.settings.zoom_wait_time);

        // Round to nearest pixel perfect zoom step when zoom key is released
        switch (pixi.state.settings.input_scheme) {
            .trackpad => {
                if (!zoom_key and camera.zoom_wait_timer >= pixi.state.settings.zoom_wait_time) {
                    camera.zoom_timer = @min(camera.zoom_timer + pixi.state.delta_time, pixi.state.settings.zoom_time);
                }
            },
            .mouse => {
                if (pixi.state.mouse.scroll_x == null and pixi.state.mouse.scroll_y == null and camera.zoom_wait_timer >= pixi.state.settings.zoom_wait_time) {
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

        switch (target) {
            .primary, .reference => {
                // Lock camera from zooming in or out too far for the flipbook
                camera.zoom = std.math.clamp(camera.zoom, camera.min_zoom, pixi.state.settings.zoom_steps[pixi.state.settings.zoom_steps.len - 1]);

                // Lock camera from moving too far away from canvas
                camera.position[0] = std.math.clamp(
                    camera.position[0],
                    -(canvas_center_offset[0] + @as(f32, @floatFromInt(canvas_width))),
                    canvas_center_offset[0] + @as(f32, @floatFromInt(canvas_width)),
                );
                camera.position[1] = std.math.clamp(
                    camera.position[1],
                    -(canvas_center_offset[1] + @as(f32, @floatFromInt(canvas_height))),
                    canvas_center_offset[1] + @as(f32, @floatFromInt(canvas_height)),
                );
            },
            .flipbook => {
                var file = &pixi.state.open_files.items[pixi.state.open_file_index];

                const tile_width = @as(f32, @floatFromInt(file.tile_width));
                const tile_height = @as(f32, @floatFromInt(file.tile_height));

                // Lock camera from zooming in or out too far for the flipbook
                camera.zoom = std.math.clamp(camera.zoom, camera.min_zoom, pixi.state.settings.zoom_steps[pixi.state.settings.zoom_steps.len - 1]);

                const view_width: f32 = if (pixi.state.settings.flipbook_view == .grid) tile_width * 3.0 else tile_width;
                const view_height: f32 = if (pixi.state.settings.flipbook_view == .grid) tile_height * 3.0 else tile_height;

                // Lock camera from moving too far away from canvas
                const min_position: [2]f32 = .{ -(canvas_center_offset[0] + view_width) - view_width / 2.0, -(canvas_center_offset[1] + view_height) };
                const max_position: [2]f32 = .{ canvas_center_offset[0] + view_width - view_width / 2.0, canvas_center_offset[1] + view_height };

                var scroll_delta: f32 = 0.0;
                if (file.selected_animation_state != .play) {
                    if (camera.position[0] < min_position[0]) scroll_delta = camera.position[0] - min_position[0];
                    if (camera.position[0] > max_position[0]) scroll_delta = camera.position[0] - max_position[0];
                }

                file.flipbook_scroll = std.math.clamp(file.flipbook_scroll - scroll_delta, file.flipbookScrollFromSpriteIndex(file.sprites.items.len - 1), 0.0);

                camera.position[0] = std.math.clamp(camera.position[0], min_position[0], max_position[0]);
                camera.position[1] = std.math.clamp(camera.position[1], min_position[1], max_position[1]);

                // Skip moving towards the mouse in the flipbook
                return;
            },
        }

        // Move camera position to maintain mouse position
        const zoom_delta = camera.zoom - previous_zoom;
        if (@abs(zoom_delta) > 0.0) {
            const current_mouse =
                camera.coordinatesRaw(.{
                .texture_position = canvas_center_offset,
                .position = pixi.state.mouse.position,
                .width = canvas_width,
                .height = canvas_height,
            });

            const difference: [2]f32 = .{ previous_mouse[0] - current_mouse[0], previous_mouse[1] - current_mouse[1] };

            camera.position[0] += difference[0];
            camera.position[1] += difference[1];
        }
    }

    pub fn drawLayerTooltip(camera: Camera, layer_index: usize) void {
        imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 8.0 * pixi.content_scale[0], .y = 8.0 * pixi.content_scale[1] });
        imgui.pushStyleVar(imgui.StyleVar_WindowRounding, 8.0 * pixi.content_scale[0]);
        imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0 * pixi.content_scale[0], .y = 4.0 * pixi.content_scale[1] });
        defer imgui.popStyleVarEx(3);
        _ = camera;
        if (imgui.beginTooltip()) {
            defer imgui.endTooltip();
            const layer_name = pixi.state.open_files.items[pixi.state.open_file_index].layers.items[layer_index].name;
            const label = std.fmt.allocPrintZ(pixi.state.allocator, "{s} {s}", .{ pixi.fa.layer_group, layer_name }) catch unreachable;
            defer pixi.state.allocator.free(label);
            imgui.text(label);
        }
    }

    pub fn drawZoomTooltip(camera: Camera, zoom: f32) void {
        imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 8.0 * pixi.content_scale[0], .y = 8.0 * pixi.content_scale[1] });
        imgui.pushStyleVar(imgui.StyleVar_WindowRounding, 8.0 * pixi.content_scale[0]);
        imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0 * pixi.content_scale[0], .y = 4.0 * pixi.content_scale[1] });
        defer imgui.popStyleVarEx(3);
        _ = camera;
        if (imgui.beginTooltip()) {
            defer imgui.endTooltip();
            imgui.textColored(pixi.state.theme.text.toImguiVec4(), pixi.fa.search ++ " ");
            imgui.sameLine();
            imgui.textColored(pixi.state.theme.text_secondary.toImguiVec4(), "%0.1f", zoom);
        }
    }

    pub fn drawColorTooltip(camera: Camera, color: [4]u8) void {
        imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 8.0 * pixi.content_scale[0], .y = 8.0 * pixi.content_scale[1] });
        imgui.pushStyleVar(imgui.StyleVar_WindowRounding, 8.0 * pixi.content_scale[0]);
        imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0 * pixi.content_scale[0], .y = 4.0 * pixi.content_scale[1] });
        defer imgui.popStyleVarEx(3);
        _ = camera;
        if (imgui.beginTooltip()) {
            defer imgui.endTooltip();
            const col: imgui.Vec4 = .{
                .x = @as(f32, @floatFromInt(color[0])) / 255.0,
                .y = @as(f32, @floatFromInt(color[1])) / 255.0,
                .z = @as(f32, @floatFromInt(color[2])) / 255.0,
                .w = @as(f32, @floatFromInt(color[3])) / 255.0,
            };
            _ = imgui.colorButtonEx("Eyedropper", col, imgui.ColorEditFlags_None, .{
                .x = pixi.state.settings.eyedropper_preview_size * pixi.content_scale[0],
                .y = pixi.state.settings.eyedropper_preview_size * pixi.content_scale[1],
            });
            imgui.text("R: %d", color[0]);
            imgui.text("G: %d", color[1]);
            imgui.text("B: %d", color[2]);
            imgui.text("A: %d", color[3]);
        }
    }

    pub fn processZoomTooltip(camera: *Camera) void {
        const zoom_key = if (pixi.state.hotkeys.hotkey(.{ .proc = .zoom })) |hotkey| hotkey.down() else false;
        const zooming = (pixi.state.mouse.scroll_y != null and zoom_key) or pixi.state.mouse.magnify != null;

        // Draw current zoom tooltip
        if (camera.zoom_tooltip_timer < pixi.state.settings.zoom_tooltip_time) {
            camera.zoom_tooltip_timer = @min(camera.zoom_tooltip_timer + pixi.state.delta_time, pixi.state.settings.zoom_tooltip_time);
            camera.drawZoomTooltip(camera.zoom);
        } else if (zooming and pixi.state.settings.input_scheme == .trackpad) {
            camera.zoom_tooltip_timer = 0.0;
            camera.drawZoomTooltip(camera.zoom);
        } else if (!zoom_key and pixi.state.settings.input_scheme == .mouse) {
            if (camera.zoom_wait_timer < pixi.state.settings.zoom_wait_time) {
                camera.zoom_tooltip_timer = 0.0;
                camera.drawZoomTooltip(camera.zoom);
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
