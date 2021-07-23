const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

pub const Camera = struct {
    position: imgui.ImVec2 = .{},
    zoom: f32 = 1,

    pub fn matrix (self: Camera) upaya.math.Mat32 {

        var window_half_size = imgui.ogGetWindowSize().scale(0.5);
        // make pixel perfect
        window_half_size.x = @trunc (window_half_size.x);
        window_half_size.y = @trunc (window_half_size.y);

        var transform = upaya.math.Mat32.identity;

        var tmp = upaya.math.Mat32.identity;
        tmp.translate(-self.position.x, -self.position.y);
        transform = tmp.mul(transform);

        tmp = upaya.math.Mat32.identity;
        tmp.scale(self.zoom, self.zoom);
        transform = tmp.mul(transform);

        tmp = upaya.math.Mat32.identity;
        tmp.translate(window_half_size.x, window_half_size.y);
        transform = tmp.mul(transform);

        return transform;
    }
};