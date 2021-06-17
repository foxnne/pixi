const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");
const sokol = @import("sokol");

pub const editor = @import("editor/editor.zig");

pub fn main() !void {
    upaya.run(.{
        .init = editor.init,
        .update = editor.update,
        .shutdown = editor.shutdown,
        .docking = true,
        .setupDockLayout = editor.setupDockLayout,
        .window_title = "Pixi",
        .onFileDropped = editor.onFileDropped,
        .fullscreen = true,
    });
}


