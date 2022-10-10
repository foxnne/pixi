const zm = @import("zmath");
const game = @import("game");

pub const sqrt2: f32 = 1.414213562373095;

pub const Direction = @import("direction.zig").Direction;
const rect = @import("rect.zig");
pub const Rect = rect.Rect;
pub const RectF = rect.RectF;
const color = @import("color.zig");
pub const Color = color.Color;
pub const Colors = color.Colors;

pub const Point = struct { x: i32, y: i32 };

pub fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

/// Converts a tile coordinate to a pixel coordinate.
pub fn pixel (t: i32) f32 {
    return @intToFloat(f32, t) * game.settings.pixels_per_unit;
}

/// Converts a pixel coordinate to a tile coordinate.
pub fn tile (p: f32) i32 {
    return @floatToInt(i32, @round(p / game.settings.pixels_per_unit));
}
