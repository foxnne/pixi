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

pub fn zoom(camera: *Camera, target: imgui.ImVec2) void {
    zoom_tolerance += imgui.igGetIO().MouseWheel;

    var direction: imgui.ImVec2 = .{ .x = target.x - camera.position.x, .y = target.y - camera.position.y};
    direction = direction.scale(0.5);

    if (zoom_tolerance > 2) {
        for (zoom_steps) |z, i| {
            if (z == camera.zoom and i < zoom_steps.len - 1) {
                camera.zoom = zoom_steps[i + 1];
                break;
               
            }
        }
        zoom_tolerance = 0;
    }
    if (zoom_tolerance < -2) {
        for (zoom_steps) |z, i| {
            if (z == camera.zoom and i > 0) {
                camera.zoom = zoom_steps[i - 1];
                break;
                
            }
        }
        zoom_tolerance = 0;
    }
    
    

    imgui.igGetIO().MouseWheel = 0;
}
