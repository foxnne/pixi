const std = @import("std");
const pixi = @import("pixi.zig");

const Self = @This();

pub const MinSize: i32 = 1;
pub const MaxSize: i32 = 64;

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
shape: Shape = .circle,
size: i32 = 1,

pub fn set(self: *Self, tool: Tool) void {
    if (self.current != tool) {
        if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
            switch (tool) {
                .heightmap => {
                    file.heightmap.enable();
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

pub fn unsigned_size(self: *Self) u16 {
    if (self.size < MinSize)
        return MinSize;

    return @as(u16, @intCast(self.size));
}

pub fn increment_size(self: *Self, inc: i32) void {
    if (self.size + inc < MinSize) {
        self.size = MinSize;
        return;
    }

    if (self.size + inc >= MaxSize) {
        self.size = MaxSize;
        return;
    }

    self.size += inc;
}
