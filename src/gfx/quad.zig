const std = @import("std");
const zm = @import("zmath");
const game = @import("game");
const gfx = game.gfx;

pub const Quad = struct {
    vertices: [4]gfx.Vertex,

    pub fn setData(self: *Quad, data: gfx.VertexData) void {
        for (self.vertices, 0..) |_, i| {
            self.vertices[i].data = data.value;
        }
    }

    pub fn setHeight(self: *Quad, height: f32) void {
        for (self.vertices, 0..) |_, i| {
            self.vertices[i].position[2] = height;
        }
    }

    pub fn setColor(self: *Quad, color: [4]f32) void {
        for (self.vertices, 0..) |_, i| {
            self.vertices[i].color = color;
        }
    }

    pub fn setViewport(self: *Quad, x: f32, y: f32, width: f32, height: f32, tex_width: f32, tex_height: f32) void {
        // squeeze texcoords in by 128th of a pixel to avoid bleed
        const w_tol = (1.0 / tex_width) / 128.0;
        const h_tol = (1.0 / tex_height) / 128.0;

        const inv_w = 1.0 / tex_width;
        const inv_h = 1.0 / tex_height;

        self.vertices[0].uv = [_]f32{ x * inv_w + w_tol, y * inv_h + h_tol };
        self.vertices[1].uv = [_]f32{ (x + width) * inv_w - w_tol, y * inv_h + h_tol };
        self.vertices[2].uv = [_]f32{ (x + width) * inv_w - w_tol, (y + height) * inv_h - h_tol };
        self.vertices[3].uv = [_]f32{ x * inv_w + w_tol, (y + height) * inv_h - h_tol };
    }

    pub fn flipHorizontally(self: *Quad) void {
        const bl_uv = self.vertices[0].uv;
        self.vertices[0].uv = self.vertices[1].uv;
        self.vertices[1].uv = bl_uv;

        const tr_uv = self.vertices[2].uv;
        self.vertices[2].uv = self.vertices[3].uv;
        self.vertices[3].uv = tr_uv;
    }

    pub fn flipVertically(self: *Quad) void {
        const bl_uv = self.vertices[0].uv;
        self.vertices[0].uv = self.vertices[1].uv;
        self.vertices[1].uv = bl_uv;

        const tr_uv = self.vertices[2].uv;
        self.vertices[2].uv = self.vertices[3].uv;
        self.vertices[3].uv = tr_uv;
    }

    pub fn rotate(self: *Quad, rotation: f32, pos_x: f32, pos_y: f32, origin_x: f32, origin_y: f32) void {
        for (self.vertices, 0..) |vert, i| {
            var position = zm.loadArr3(vert.position);
            const offset = zm.f32x4(pos_x, pos_y, 0, 0);

            const radians = std.math.degreesToRadians(f32, rotation);

            const translation_matrix = zm.translation(origin_x, origin_y, 0);
            const rotation_matrix = zm.rotationZ(radians);

            position -= offset;
            position = zm.mul(position, zm.mul(translation_matrix, rotation_matrix));
            position += offset;

            zm.storeArr3(&self.vertices[i].position, position);
        }
    }
};
