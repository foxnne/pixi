const std = @import("std");
const zglfw = @import("zglfw");
const pixi = @import("pixi");
const input = @import("input.zig");
const zgpu = @import("zgpu");
const zgui = @import("zgui");

pub fn cursor(_: zglfw.Window, _: f64, _: f64) callconv(.C) void {
    // if (zgui.io.getWantCaptureMouse()) return;
    // const scale_factor = scale_factor: {
    //     const cs = window.getContentScale();
    //     break :scale_factor std.math.max(cs[0], cs[1]);
    // };
    // pixi.state.controls.mouse.position.x = @floatCast(f32, x / scale_factor);
    // pixi.state.controls.mouse.position.y = @floatCast(f32, y / scale_factor);
}

pub fn scroll(_: zglfw.Window, _: f64, _: f64) callconv(.C) void {
    // if (zgui.io.getWantCaptureMouse()) return;

    // if (y > pixi.settings.zoom_scroll_tolerance and pixi.state.camera.zoom_progress < 0.0) {
    //     const max_zoom = pixi.state.camera.maxZoom();
    //     pixi.state.camera.zoom_step = @round(pixi.state.camera.zoom);
    //     if (pixi.state.camera.zoom_step + 1.0 <= max_zoom) {
    //         pixi.state.camera.zoom_progress = 0.0;
    //         pixi.state.camera.zoom_step_next = pixi.state.camera.zoom_step + 1.0;
    //     }
    // }
    // if (y < -pixi.settings.zoom_scroll_tolerance and pixi.state.camera.zoom_progress < 0.0) {
    //     const min_zoom = pixi.state.camera.minZoom();
    //     pixi.state.camera.zoom_step = @round(pixi.state.camera.zoom);
    //     if (pixi.state.camera.zoom_step - 1.0 >= min_zoom) {
    //         pixi.state.camera.zoom_progress = 0.0;
    //         pixi.state.camera.zoom_step_next = pixi.state.camera.zoom_step - 1.0;
    //     }
    // }
}

pub fn button(_: zglfw.Window, _: zglfw.MouseButton, _: zglfw.Action, _: zglfw.Mods) callconv(.C) void {
    // if (glfw_button == pixi.state.controls.mouse.primary.button) {
    //     pixi.state.controls.mouse.primary.previous_state = pixi.state.controls.mouse.primary.state;
    //     switch (action) {
    //         .release => {
    //             pixi.state.controls.mouse.primary.state = false;
    //             pixi.state.controls.mouse.primary.up_tile = tile;
    //             pixi.state.controls.mouse.cursor = .standard;
    //         },
    //         .repeat, .press => {
    //             pixi.state.controls.mouse.primary.state = true;
    //             pixi.state.controls.mouse.primary.down_tile = tile;
    //         },
    //     }
    // }

    // if (glfw_button == pixi.state.controls.mouse.secondary.button) {
    //     pixi.state.controls.mouse.secondary.previous_state = pixi.state.controls.mouse.secondary.state;
    //     switch (action) {
    //         .release => {
    //             pixi.state.controls.mouse.secondary.state = false;
    //             pixi.state.controls.mouse.secondary.up_tile = tile;
    //         },
    //         .repeat, .press => {
    //             pixi.state.controls.mouse.secondary.state = true;
    //             pixi.state.controls.mouse.secondary.down_tile = tile;
    //         },
    //     }
    // }
}

pub fn key(_: zglfw.Window, _: zglfw.Key, _: i32, _: zglfw.Action, _: zglfw.Mods) callconv(.C) void {}
