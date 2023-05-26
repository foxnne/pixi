const std = @import("std");
const builtin = @import("builtin");
const math = @import("../math/math.zig");
const fs = @import("../tools/fs.zig");
const Sprite = @import("sprite.zig").Sprite;
const Animation = @import("animation.zig").Animation;

pub const Atlas = struct {
    sprites: []Sprite,
    animations: []Animation,

    pub fn init(allocator: *std.mem.Allocator, width: i32, height: i32, columns: i32, rows: i32) Atlas {
        var count: i32 = columns * rows;

        var atlas: Atlas = .{
            .sprites = try allocator.alloc(Sprite, count),
        };

        var sprite_width = @divExact(@floatToInt(i32, width), columns);
        var sprite_height = @divExact(@floatToInt(i32, height), rows);

        var r: i32 = 0;
        while (r < rows) : (r += 1) {
            var c: i32 = 0;
            while (c < columns) : (c += 1) {
                var source: math.Rect = .{
                    .x = c * sprite_width,
                    .y = r * sprite_height,
                    .width = sprite_width,
                    .height = sprite_height,
                };

                var origin: math.Point = .{
                    .x = @divExact(sprite_width, 2),
                    .y = @divExact(sprite_height, 2),
                };

                var s: Sprite = .{
                    .name = "Sprite_" ++ std.fmt.allocPrint(allocator, "{}", .{c + r}), // add _0, _1 etc...
                    .source = source,
                    .origin = origin,
                };

                atlas.sprites[c + r] = s;
            }
        }
        return atlas;
    }

    pub fn initFromFile(allocator: std.mem.Allocator, file: []const u8) !Atlas {
        const read = try fs.read(allocator, file);
        errdefer allocator.free(read);

        const options = std.json.ParseOptions{ .duplicate_field_behavior = .use_first, .ignore_unknown_fields = true };
        const atlas = try std.json.parseFromSlice(Atlas, allocator, read, options);

        return atlas;
    }

    /// returns sprite by name
    pub fn sprite(this: Atlas, name: []const u8) !Sprite {
        for (this.sprites) |s| {
            if (std.mem.eql(u8, s.name, name))
                return s;
        }
        return error.NotFound;
    }

    /// returns index of sprite by name
    pub fn indexOf(this: Atlas, name: []const u8) !usize {
        for (this.sprites, 0..) |s, i| {
            if (std.mem.eql(u8, s.name, name))
                return i;
        }
        return error.NotFound;
    }
};
