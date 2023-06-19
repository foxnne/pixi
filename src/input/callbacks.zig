const std = @import("std");
const zglfw = @import("zglfw");
const pixi = @import("root");
const input = @import("input.zig");
const zgpu = @import("zgpu");
const zgui = @import("zgui");

pub fn cursor(_: *zglfw.Window, x: f64, y: f64) callconv(.C) void {
    pixi.state.controls.mouse.previous_position.x = pixi.state.controls.mouse.position.x;
    pixi.state.controls.mouse.previous_position.y = pixi.state.controls.mouse.position.y;
    pixi.state.controls.mouse.position.x = @floatCast(f32, x);
    pixi.state.controls.mouse.position.y = @floatCast(f32, y);
}

pub fn scroll(_: *zglfw.Window, x: f64, y: f64) callconv(.C) void {
    pixi.state.controls.mouse.scroll_x = @floatCast(f32, x);
    pixi.state.controls.mouse.scroll_y = @floatCast(f32, y);
}

pub fn button(_: *zglfw.Window, glfw_button: zglfw.MouseButton, action: zglfw.Action, _: zglfw.Mods) callconv(.C) void {
    if (glfw_button == pixi.state.controls.mouse.primary.button) {
        switch (action) {
            .release => {
                pixi.state.controls.mouse.primary.state = false;
            },
            .repeat, .press => {
                pixi.state.controls.mouse.primary.state = true;

                if (pixi.state.controls.mouse.primary.pressed()) {
                    pixi.state.controls.mouse.clicked_position = pixi.state.controls.mouse.position;
                }
            },
            else => {},
        }
    }

    if (glfw_button == pixi.state.controls.mouse.secondary.button) {
        switch (action) {
            .release => {
                pixi.state.controls.mouse.secondary.state = false;
            },
            .repeat, .press => {
                pixi.state.controls.mouse.secondary.state = true;
            },
            else => {},
        }
    }
}

pub fn key(_: *zglfw.Window, glfw_key: zglfw.Key, _: i32, action: zglfw.Action, mods: zglfw.Mods) callconv(.C) void {
    pixi.state.hotkeys.setHotkeyState(glfw_key, mods, action);
}
