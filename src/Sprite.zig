const std = @import("std");
const pixi = @import("pixi.zig");

const Sprite = @This();

name: [:0]const u8,
source: [4]u32,
origin: [2]i32,

pub fn deinit(sprite: *Sprite, allocator: std.mem.Allocator) void {
    allocator.free(sprite.name);
}
