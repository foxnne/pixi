const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");
const sokol = @import("sokol");

var zoom_tolerance: f32 = 0;
pub const zoom_steps = [_]f32{ 0.125, 0.167, 0.2, 0.25, 0.333, 0.5, 1, 2, 3, 4, 5, 6, 8, 12, 18, 28, 38, 50, 70, 90, 128 };

pub const Camera = @import("../utils/camera.zig").Camera;

pub fn pan(camera: *Camera, button: imgui.ImGuiMouseButton) void {
    var pan_delta = imgui.ogGetMouseDragDelta(button, 0);

    camera.position.x -= pan_delta.x * 1 / camera.zoom;
    camera.position.y -= pan_delta.y * 1 / camera.zoom;

    imgui.igResetMouseDragDelta(button);
    return;
}

pub fn zoom(camera: *Camera) void {
    const io = imgui.igGetIO();
    var target = io.MousePos.subtract(imgui.ogGetCursorScreenPos()).subtract(imgui.ogGetWindowCenter());

    zoom_tolerance += io.MouseWheel;

    if (std.math.fabs(zoom_tolerance) > 2) {
        for (zoom_steps) |z, i| {
            if (z == camera.zoom) {
                const previous_zoom = camera.zoom;
                camera.zoom = if (i > 0 and zoom_tolerance < -2) zoom_steps[i - 1] else if (zoom_tolerance > 2 and i < zoom_steps.len - 1) zoom_steps[i + 1] else zoom_steps[i] ;

                const previous = target.scale(1 / previous_zoom);
                const next = target.scale(1 / camera.zoom);

                camera.position.x += previous.x - next.x;
                camera.position.y += previous.y - next.y;

                break;
            }
        }
        zoom_tolerance = 0;
    }
   

    imgui.igGetIO().MouseWheel = 0;
}
