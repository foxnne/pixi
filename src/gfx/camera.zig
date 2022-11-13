const std = @import("std");
const zm = @import("zmath");
const zgpu = @import("zgpu");
const zglfw = @import("zglfw");
const zgui = @import("zgui");
const pixi = @import("pixi");

pub const Camera = struct {
    position: [2]f32 = .{ 0.0, 0.0 },
    zoom: f32 = 1.0,
    zoom_initialized: bool = false,

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

    pub fn drawGrid(camera: pixi.gfx.Camera, position: [2]f32, width: f32, height: f32, columns: usize, rows: usize, color: u32) void {
        const window_position = zgui.getWindowPos();
        var tl = camera.matrix().transformVec2(position);
        tl[0] += window_position[0];
        tl[1] += window_position[1];
        var br = position;
        br[0] += width;
        br[1] += height;
        br = camera.matrix().transformVec2(br);
        br[0] += window_position[0];
        br[1] += window_position[1];

        tl[0] = std.math.round(tl[0]);
        tl[1] = std.math.round(tl[1]);
        br[0] = std.math.round(br[0]);
        br[1] = std.math.round(br[1]);

        const draw_list = zgui.getWindowDrawList();
        const tile_width = width / @intToFloat(f32, columns);
        const tile_height = height / @intToFloat(f32, rows);

        var i: usize = 0;
        while (i < columns + 1) : (i += 1) {
            const p1: [2]f32 = .{ tl[0] + @intToFloat(f32, i) * tile_width * camera.zoom, tl[1] };
            const p2: [2]f32 = .{ tl[0] + @intToFloat(f32, i) * tile_width * camera.zoom, tl[1] + height * camera.zoom };
            draw_list.addLine(.{
                .p1 = p1,
                .p2 = p2,
                .col = color,
                .thickness = 1.0,
            });
        }

        i = 0;
        while (i < rows + 1) : (i += 1) {
            const p1: [2]f32 = .{ tl[0], tl[1] + @intToFloat(f32, i) * tile_height * camera.zoom };
            const p2: [2]f32 = .{ tl[0] + width * camera.zoom, tl[1] + @intToFloat(f32, i) * tile_height * camera.zoom };
            draw_list.addLine(.{
                .p1 = p1,
                .p2 = p2,
                .col = color,
                .thickness = 1.0,
            });
        }
    }

    pub fn drawLayer(camera: pixi.gfx.Camera, layer: pixi.storage.Internal.Layer, position: [2]f32) void {
        const window_position = zgui.getWindowPos();
        var tl = camera.matrix().transformVec2(position);
        tl[0] += window_position[0];
        tl[1] += window_position[1];
        var br = position;
        br[0] += @intToFloat(f32, layer.image.width);
        br[1] += @intToFloat(f32, layer.image.height);
        br = camera.matrix().transformVec2(br);
        br[0] += window_position[0];
        br[1] += window_position[1];

        tl[0] = std.math.round(tl[0]);
        tl[1] = std.math.round(tl[1]);
        br[0] = std.math.round(br[0]);
        br[1] = std.math.round(br[1]);

        const draw_list = zgui.getWindowDrawList();
        if (pixi.state.gctx.lookupResource(layer.texture_view_handle)) |texture_id| {
            draw_list.addImage(texture_id, .{
                .pmin = tl,
                .pmax = br,
                .col = 0xFFFFFFFF,
            });
        }
    }

    pub fn drawSprite(camera: pixi.gfx.Camera, layer: pixi.storage.Internal.Layer, sprite_rect: [4]f32, position: [2]f32, color: u32) void {
        const window_position = zgui.getWindowPos();
        var tl = camera.matrix().transformVec2(position);
        tl[0] += window_position[0];
        tl[1] += window_position[1];
        var br = position;
        br[0] += sprite_rect[2];
        br[1] += sprite_rect[3];
        br = camera.matrix().transformVec2(br);
        br[0] += window_position[0];
        br[1] += window_position[1];

        tl[0] = std.math.round(tl[0]);
        tl[1] = std.math.round(tl[1]);
        br[0] = std.math.round(br[0]);
        br[1] = std.math.round(br[1]);

        const inv_w = 1.0 / @intToFloat(f32, layer.image.width);
        const inv_h = 1.0 / @intToFloat(f32, layer.image.height);

        const uvmin: [2]f32 = .{ sprite_rect[0] * inv_w, sprite_rect[1] * inv_h };
        const uvmax: [2]f32 = .{ (sprite_rect[0] + sprite_rect[2]) * inv_w, (sprite_rect[1] + sprite_rect[3]) * inv_h };

        const draw_list = zgui.getWindowDrawList();
        if (pixi.state.gctx.lookupResource(layer.texture_view_handle)) |texture_id| {
            draw_list.addImage(texture_id, .{
                .pmin = tl,
                .pmax = br,
                .uvmin = uvmin,
                .uvmax = uvmax,
                .col = 0xFFFFFFFF,
            });
            draw_list.addRect(.{
                .pmin = tl,
                .pmax = br,
                .col = color,
            });
        }
    }

    pub fn nearestZoomIndex(camera: pixi.gfx.Camera) usize {
        var nearest_zoom_index: usize = 0;
        var nearest_zoom_step: f32 = pixi.state.settings.zoom_steps[nearest_zoom_index];
        for (pixi.state.settings.zoom_steps) |step, i| {
            const step_difference = @fabs(camera.zoom - step);
            const current_difference = @fabs(camera.zoom - nearest_zoom_step);
            if (step_difference < current_difference) {
                nearest_zoom_step = step;
                nearest_zoom_index = i;
            }
        }
        return nearest_zoom_index;
    }

    pub fn setNearestZoom(camera: *pixi.gfx.Camera) void {
        camera.zoom = pixi.state.settings.zoom_steps[camera.nearestZoomIndex()];
    }

    pub fn setNearestZoomFloor(camera: *pixi.gfx.Camera) void {
        var nearest_zoom_index = camera.nearestZoomIndex();
        if (nearest_zoom_index > 0)
            nearest_zoom_index -= 1;
        camera.zoom = pixi.state.settings.zoom_steps[nearest_zoom_index];
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
