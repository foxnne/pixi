const zm = @import("zmath");
const std = @import("std");
const dvui = @import("dvui");

pub fn rotate(point: dvui.Point, origin: dvui.Point, radians: f32) dvui.Point {
    if (radians == 0) return point;

    const cos = @cos(radians);
    const sin = @sin(radians);

    // get vector from origin to point
    const d = point.diff(origin);

    // rotate vector
    const rotated: dvui.Point = .{
        .x = d.x * cos - d.y * sin,
        .y = d.x * sin + d.y * cos,
    };

    return origin.plus(rotated);
}

pub const sqrt2: f32 = 1.414213562373095;

pub const Direction = @import("direction.zig").Direction;
const rect = @import("rect.zig");
pub const Rect = rect.Rect;
pub const RectF = rect.RectF;
const color = @import("color.zig");
pub const Color = color.Color;
pub const Colors = color.Colors;
pub const Tween = @import("tween.zig").Tween;

pub const Point = struct { x: i32, y: i32 };

pub fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

pub fn ease(a: f32, b: f32, t: f32, ease_type: EaseType) f32 {
    return switch (ease_type) {
        .linear => lerp(a, b, t),
        .ease_in => lerp(a, b, square(t)),
        .ease_out => lerp(a, b, flip(square(flip(t)))),
        .ease_in_out => lerp(a, b, -(std.math.cos(std.math.pi * t) - 1.0) / 2.0),
    };
}

fn square(t: f32) f32 {
    return t * t;
}

fn flip(t: f32) f32 {
    return 1.0 - t;
}

pub const EaseType = enum {
    linear,
    ease_in,
    ease_out,
    ease_in_out,
};
