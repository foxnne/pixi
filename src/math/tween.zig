const std = @import("std");
const Pixi = @import("../Pixi.zig");
const zmath = @import("zmath");

pub const Tween = enum {
    none,
    linear,
};
