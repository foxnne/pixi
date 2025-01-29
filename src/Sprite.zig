const std = @import("std");
const pixi = @import("pixi.zig");

const Sprite = @This();

source: [4]u32,
origin: [2]i32,
