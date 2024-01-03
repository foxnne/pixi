const std = @import("std");

pub const Sprite = struct {
    name: [:0]const u8,
    source: [4]u32,
    origin: [2]i32,
};
