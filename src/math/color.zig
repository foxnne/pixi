const zm = @import("zmath");

pub const Color = struct {
    value: zm.F32x4,

    pub fn initFloats(r: f32, g: f32, b: f32, a: f32) Color {
        return .{
            .value = zm.f32x4(r, g, b, a),
        };
    }

    pub fn initBytes(r: u8, g: u8, b: u8, a: u8) Color {
        return .{
            .value = zm.f32x4(@as(f32, @floatFromInt(r)) / 255, @as(f32, @floatFromInt(g)) / 255, @as(f32, @floatFromInt(b)) / 255, @as(f32, @floatFromInt(a)) / 255),
        };
    }

    pub fn bytes(self: Color) [4]u8 {
        return .{
            @as(u8, @intFromFloat(self.value[0] * 255.0)),
            @as(u8, @intFromFloat(self.value[1] * 255.0)),
            @as(u8, @intFromFloat(self.value[2] * 255.0)),
            @as(u8, @intFromFloat(self.value[3] * 255.0)),
        };
    }

    pub fn lerp(self: Color, other: Color, t: f32) Color {
        return .{ .value = zm.lerp(self.value, other.value, t) };
    }

    pub fn toSlice(self: Color) [4]f32 {
        var slice: [4]f32 = undefined;
        zm.storeArr4(&slice, self.value);
        return slice;
    }

    pub fn toU32(self: Color) u32 {
        const Packed = packed struct(u32) {
            r: u8,
            g: u8,
            b: u8,
            a: u8,
        };

        const p = Packed{
            .r = @as(u8, @intFromFloat(self.value[0] * 255.0)),
            .g = @as(u8, @intFromFloat(self.value[1] * 255.0)),
            .b = @as(u8, @intFromFloat(self.value[2] * 255.0)),
            .a = @as(u8, @intFromFloat(self.value[3] * 255.0)),
        };

        return @as(u32, @bitCast(p));
    }
};

pub const Colors = struct {
    pub const white = Color.initFloats(1, 1, 1, 1);
    pub const black = Color.initFloats(0, 0, 0, 1);
    pub const red = Color.initFloats(1, 0, 0, 1);
    pub const green = Color.initFloats(0, 1, 0, 1);
    pub const blue = Color.initFloats(0, 0, 1, 1);
    pub const grass = Color.initBytes(110, 138, 92, 255);
    pub const background = Color.initBytes(42, 44, 53, 255);
    pub const background_dark = Color.initBytes(30, 31, 38, 255);
    pub const text = Color.initBytes(222, 177, 142, 255);
};
