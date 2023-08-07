const std = @import("std");
const pixi = @import("pixi.zig");

const Self = @This();

pub const Tool = enum {
    pointer,
    pencil,
    eraser,
    animation,
    heightmap,
    bucket,
};

current: Tool = .pointer,
previous: Tool = .pointer,

pub fn set(self: *Self, tool: Tool) void {
    if (self.current != tool) {
        if (tool == .heightmap) {
            if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
                if (file.heightmap_layer == null) {
                    pixi.state.popups.heightmap = true;
                    return;
                }
            } else return;
        }
        self.previous = self.current;
        self.current = tool;
    }
}
