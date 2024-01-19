const std = @import("std");
const pixi = @import("pixi.zig");

const Self = @This();

pub const Tool = enum(u32) {
    pointer,
    pencil,
    eraser,
    animation,
    heightmap,
    bucket,
};

pub const Shape = enum(u32) {
    circle,
    square,
};

current: Tool = .pointer,
previous: Tool = .pointer,
stroke_size: u8 = 1,
stroke_shape: Shape = .circle,

pub fn set(self: *Self, tool: Tool) void {
    if (self.current != tool) {
        if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
            switch (tool) {
                .heightmap => {
                    file.heightmap.enable();
                    if (file.heightmap.layer == null)
                        return;
                },
                .pointer => {
                    file.heightmap.disable();
                },
                else => {},
            }
        }
        self.previous = self.current;
        self.current = tool;
    }
}

pub fn swap(self: *Self) void {
    const temp = self.current;
    self.current = self.previous;
    self.previous = temp;
}
