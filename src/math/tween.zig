const std = @import("std");
const pixi = @import("../Pixi.zig");
const zmath = @import("zmath");

pub const Tween = enum {
    none,
    linear,
};
