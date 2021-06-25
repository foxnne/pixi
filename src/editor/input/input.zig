const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");
const sokol = @import("sokol");

var zoom_tolerance: f32 = 0;

pub const Camera = @import("../utils/camera.zig").Camera;

pub fn pan(camera: *Camera, button: imgui.ImGuiMouseButton) void {
    imgui.igSetMouseCursor(imgui.ImGuiMouseCursor_Hand);
    var pan_delta = imgui.ogGetMouseDragDelta(button, 0);

    camera.position.x -= pan_delta.x * 1 / camera.zoom;
    camera.position.y -= pan_delta.y * 1 / camera.zoom;

    imgui.igResetMouseDragDelta(button);
    return;
}

pub fn zoom(camera: *Camera) void {
    zoom_tolerance += imgui.igGetIO().MouseWheel;

    if (zoom_tolerance > 2) {

        if (camera.zoom < 50)
            camera.zoom *= 2;

        zoom_tolerance = 0;
    }
    if (zoom_tolerance < -2) {

        if (camera.zoom > 0.2)
            camera.zoom *= 0.5;

        zoom_tolerance = 0;
    }

    var mouse_pos = camera.matrix().transformImVec2(imgui.igGetIO().MousePos);
    
    imgui.igGetIO().MouseWheel = 0;

}
