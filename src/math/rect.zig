const std = @import("std");
const math = @import("math.zig");

pub const Rect = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: i32 = 0,
    height: i32 = 0,

    pub fn init(x: i32, y: i32, width: i32, height: i32) Rect {
        return .{ .x = x, .y = y, .width = width, .height = height };
    }

    pub fn top(self: Rect) i32 {
        return self.y;
    }

    pub fn bottom(self: Rect) i32 {
        return self.y + self.height;
    }

    pub fn left(self: Rect) i32 {
        return self.x;
    }

    pub fn right(self: Rect) i32 {
        return self.x + self.width;
    }

    pub fn containsPoint(self: Rect, point: math.Point) bool {
        return self.x <= point.x and point.x < self.right() and self.y <= point.y and point.y < self.bottom();
    }

    // pub fn containsVector2 (self: Rect, vector: math.Vector2) bool {

    //     return self.x <= vector.x and vector.x < self.right() and self.y <= vector.y and vector.y < self.bottom();
    // }

    pub fn rectF(self: Rect) RectF {
        return .{
            .x = @as(f32, @floatFromInt(self.x)),
            .y = @as(f32, @floatFromInt(self.y)),
            .width = @as(f32, @floatFromInt(self.width)),
            .height = @as(f32, @floatFromInt(self.height)),
        };
    }
};

pub const RectF = struct {
    x: f32 = 0,
    y: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,

    pub fn init(x: f32, y: f32, width: f32, height: f32) Rect {
        return .{ .x = x, .y = y, .width = width, .height = height };
    }

    pub fn top(self: RectF) f32 {
        return self.y;
    }

    pub fn bottom(self: RectF) f32 {
        return self.y + self.height;
    }

    pub fn left(self: RectF) f32 {
        return self.x;
    }

    pub fn right(self: RectF) f32 {
        return self.x + self.width;
    }

    pub fn rect(self: RectF) Rect {
        return .{
            .x = @as(i32, @intFromFloat(self.x)),
            .y = @as(i32, @intFromFloat(self.y)),
            .width = @as(i32, @intFromFloat(self.width)),
            .height = @as(i32, @intFromFloat(self.height)),
        };
    }
};
