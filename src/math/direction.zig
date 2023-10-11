const std = @import("std");
const zm = @import("zmath");

const sqrt = 0.70710678118654752440084436210485;
const sqrt2 = 1.4142135623730950488016887242097;

pub const Direction = enum(u8) {
    none = 0,

    n = 0b0000_0001, // 1
    e = 0b0000_0100, // 4
    s = 0b0000_0011, // 3
    w = 0b0000_1100, // 12

    se = 0b0000_0111, // 5
    ne = 0b0000_0101, // 7
    nw = 0b0000_1101, // 15
    sw = 0b0000_1111, // 13

    /// Returns closest direction of size to the supplied vector.
    pub fn find(comptime size: usize, vx: f32, vy: f32) Direction {
        return switch (size) {
            4 => {
                var d: u8 = 0;

                const absx = @abs(vx);
                const absy = @abs(vy);

                if (absy < absx * sqrt2) {
                    //x
                    if (vx > 0) d = 0b0000_0100 else if (vx < 0) d = 0b0000_1100;
                } else {
                    //y
                    if (vy > 0) d = 0b0000_0001 else if (vy < 0) d = 0b0000_0011;
                }

                return @as(Direction, @enumFromInt(d));
            },

            8 => {
                var d: u8 = 0;

                const absx = @abs(vx);
                const absy = @abs(vy);

                if (absy < absx * (sqrt2 + 1.0)) {
                    // x
                    if (vx > 0) d = 0b0000_0100 else if (vx < 0) d = 0b0000_1100;
                }
                if (absy > absx * (sqrt2 - 1.0)) {
                    // y
                    if (vy > 0) d = d | 0b0000_0001 else if (vy < 0) d = d | 0b0000_0011;
                }

                return @as(Direction, @enumFromInt(d));
            },
            else => @compileError("Direction size is unsupported"),
        };
    }

    /// Writes the actual bits of the direction.
    /// Useful for converting input to directions.
    pub fn write(n: bool, s: bool, e: bool, w: bool) Direction {
        var d: u8 = 0;
        if (w) {
            d = d | 0b0000_1100;
        }
        if (e) {
            d = d | 0b0000_0100;
        }
        if (n) {
            d = d | 0b0000_0001;
        }
        if (s) {
            d = d | 0b0000_0011;
        }

        return @as(Direction, @enumFromInt(d));
    }

    /// Returns horizontal axis of the direction.
    pub fn x(self: Direction) f32 {
        return @as(f32, @floatFromInt(@as(i8, @bitCast(@intFromEnum(self))) << 4 >> 6));
    }

    /// Returns vertical axis of the direction.
    pub fn y(self: Direction) f32 {
        return @as(f32, @floatFromInt(@as(i8, @bitCast(@intFromEnum(self))) << 6 >> 6));
    }

    /// Returns direction as a F32x4.
    pub fn f32x4(self: Direction) zm.F32x4 {
        return zm.f32x4(self.x(), self.y(), 0, 0);
    }

    /// Returns direction as a normalized F32x4.
    pub fn normalized(self: Direction) zm.F32x4 {
        return switch (self) {
            .none => zm.f32x4s(0),
            .s => zm.f32x4(0, -1, 0, 0),
            .se => zm.f32x4(sqrt, -sqrt, 0, 0),
            .e => zm.f32x4(1, 0, 0, 0),
            .ne => zm.f32x4(sqrt, sqrt, 0, 0),
            .n => zm.f32x4(0, 1, 0, 0),
            .nw => zm.f32x4(-sqrt, sqrt, 0, 0),
            .w => zm.f32x4(-1, 0, 0, 0),
            .sw => zm.f32x4(-1, -1, 0, 0),
        };
    }

    /// Returns true if direction is flipped to face west.
    pub fn flippedHorizontally(self: Direction) bool {
        return switch (self) {
            .nw, .w, .sw => true,
            else => false,
        };
    }

    /// Returns true if direction is flipped to face north.
    pub fn flippedVertically(self: Direction) bool {
        return switch (self) {
            .nw, .n, .ne => true,
            else => false,
        };
    }

    pub fn rotateCW(self: Direction) Direction {
        return switch (self) {
            .s => .sw,
            .se => .s,
            .e => .se,
            .ne => .e,
            .n => .ne,
            .nw => .n,
            .w => .nw,
            .sw => .w,
            .none => .none,
        };
    }

    pub fn rotateCCW(self: Direction) Direction {
        return switch (self) {
            .s => .se,
            .se => .e,
            .e => .ne,
            .ne => .n,
            .n => .nw,
            .nw => .w,
            .w => .sw,
            .sw => .s,
            .none => .none,
        };
    }

    pub fn fmt(self: Direction) [:0]const u8 {
        return switch (self) {
            .s => "south",
            .se => "southeast",
            .e => "east",
            .ne => "northeast",
            .n => "north",
            .nw => "northwest",
            .w => "west",
            .sw => "southwest",
            .none => "none",
        };
    }
};

test "Direction" {
    var direction: Direction = .none;

    direction = Direction.find(8, 1, 1);
    std.testing.expect(direction == .se);
    std.testing.expectEqual(zm.f32x4(1, 1, 0, 0), direction.f32x4());
    std.testing.expectEqual(zm.f32x4(sqrt, sqrt, 0, 0), direction.normalized());

    direction = Direction.find(8, 0, 1);
    std.testing.expect(direction == .s);

    direction = Direction.find(8, -1, -1);
    std.testing.expect(direction == .nw);
    std.testing.expect(direction.flippedHorizontally() == true);

    direction = Direction.find(4, 1, 1);
    std.testing.expect(direction == .e);
    std.testing.expect(direction.flippedHorizontally() == false);
}
