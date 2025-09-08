const zm = @import("zmath");
const std = @import("std");
const dvui = @import("dvui");

// Returns true if the pixel would be color 1 of a checkerboard pattern
// Returns false if the pixel would be color 2 of a checkerboard pattern
pub fn checker(size: dvui.Size, index: usize) bool {
    // Get the image width as usize
    const w = @as(usize, @intFromFloat(size.w));
    // Compute y (row) and x (column) from the index
    const y = index / w;
    const x = index % w;
    // Checkerboard: light if (x + y) is even, dark if odd
    return ((x + y) & 1) == 0;
}

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

const color = @import("color.zig");
pub const Color = color.Color;
pub const Colors = color.Colors;

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
