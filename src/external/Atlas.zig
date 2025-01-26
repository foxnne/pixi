const std = @import("std");
const fs = @import("../tools/fs.zig");
const Pixi = @import("../Pixi.zig");

const Atlas = @This();

const Sprite = @import("Sprite.zig");
const Animation = @import("../internal/Animation.zig");

sprites: []Sprite,
animations: []Animation,

pub fn loadFromFile(allocator: std.mem.Allocator, file: [:0]const u8) !Atlas {
    const read = try fs.read(allocator, file);
    defer allocator.free(read);

    const options = std.json.ParseOptions{ .duplicate_field_behavior = .use_first, .ignore_unknown_fields = true };
    const parsed = try std.json.parseFromSlice(Atlas, allocator, read, options);
    defer parsed.deinit();

    return .{
        .sprites = try allocator.dupe(Sprite, parsed.value.sprites),
        .animations = try allocator.dupe(Animation, parsed.value.animations),
    };
}
