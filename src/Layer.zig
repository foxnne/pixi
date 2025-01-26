const std = @import("std");

const Layer = @This();

name: [:0]const u8,
visible: bool = true,
collapse: bool = false,

pub fn deinit(layer: *Layer, allocator: std.mem.Allocator) void {
    allocator.free(layer.name);
}
