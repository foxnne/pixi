const std = @import("std");
const pixi = @import("../pixi.zig");
const zmath = @import("zmath");

pub const Tween = enum {
    none,
    linear,
};
