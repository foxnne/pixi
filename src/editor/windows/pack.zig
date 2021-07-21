const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

const editor = @import("../editor.zig");
const canvas = editor.canvas;
const menubar = editor.menubar;
const sprites = editor.sprites;

const types = @import("../types/types.zig");
const File = types.File;
const Layer = types.Layer;
const Sprite = types.Sprite;

pub fn draw() void {
    if (canvas.getActiveFile()) |_| {}
}
