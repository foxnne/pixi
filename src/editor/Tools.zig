const std = @import("std");
const pixi = @import("../pixi.zig");
const dvui = @import("dvui");

const Tools = @This();

pub const Tool = enum(u32) {
    pointer,
    pencil,
    eraser,
    animation,
    heightmap,
    bucket,
    selection,
};

pub const Shape = enum(u32) {
    circle,
    square,
};

current: Tool = .pointer,
previous: Tool = .pointer,
stroke_layer: pixi.Internal.Layer,
stroke_size: u8 = 1,
stroke_shape: Shape = .circle,
previous_drawing_tool: Tool = .pencil,

pub fn init() !Tools {
    const size: u32 = std.math.maxInt(u8);

    return .{
        .stroke_layer = try .init(0, "stroke_layer", .{ size, size }, .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr),
    };
}

pub fn deinit(self: *Tools) void {
    self.stroke_layer.deinit();
}

pub fn set(self: *Tools, tool: Tool) void {
    if (self.current != tool) {
        // if (pixi.editor.getFile(pixi.editor.open_file_index)) |file| {
        //     // if (file.transform_texture != null and tool != .pointer)
        //     //     return;

        //     switch (tool) {
        //         .heightmap => {
        //             file.heightmap.enable();
        //             if (file.heightmap.layer == null)
        //                 return;
        //         },
        //         .pointer => {
        //             file.heightmap.disable();

        //             // if (self.current == .selection)
        //             //     file.selection_layer.clear(true);
        //         },
        //         else => {},
        //     }
        // }
        self.previous = self.current;
        switch (self.previous) {
            .pencil, .bucket => |t| self.previous_drawing_tool = t,
            else => {},
        }
        self.current = tool;
    }
}

pub fn swap(self: *Tools) void {
    const temp = self.current;
    self.current = self.previous;
    self.previous = temp;
}
