const std = @import("std");
const upaya = @import("upaya");

pub usingnamespace @import("internal.zig");
pub usingnamespace @import("io.zig");

pub const Sprite = struct {
    name: []const u8,
    index: usize,
    origin_x: f32,
    origin_y: f32,
};

pub const Animation = struct {
    name: []const u8,
    start: usize,
    length: usize,
    fps: usize,
};