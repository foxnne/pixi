const std = @import("std");
const zglfw = @import("zglfw");
const pixi = @import("pixi");
const input = @import("input.zig");
const zgpu = @import("zgpu");
const zgui = @import("zgui");

pub fn cursor(_: zglfw.Window, x: f64, y: f64) callconv(.C) void {
    pixi.state.controls.mouse.position.x = @floatCast(f32, x);
    pixi.state.controls.mouse.position.y = @floatCast(f32, y);
}

pub fn scroll(_: zglfw.Window, x: f64, y: f64) callconv(.C) void {
    pixi.state.controls.mouse.scroll_x = @floatCast(f32, x);
    pixi.state.controls.mouse.scroll_y = @floatCast(f32, y);
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

pub fn key(_: zglfw.Window, glfw_key: zglfw.Key, _: i32, action: zglfw.Action, _: zglfw.Mods) callconv(.C) void {
    for (pixi.state.controls.keys) |*k| {
        if (k.primary == glfw_key or k.secondary == glfw_key) {
            k.previous_state = k.state;
            k.state = switch (action) {
                .release => false,
                else => true,
            };
        }
    }
}
