const std = @import("std");
const fs = @import("tools/fs.zig");
const pixi = @import("pixi.zig");

const Atlas = @This();

const Sprite = @import("Sprite.zig");
const Animation = @import("internal/Animation.zig");

sprites: []Sprite,
animations: []Animation,

pub fn loadFromFile(allocator: std.mem.Allocator, file: []const u8) !Atlas {
    const read = try fs.read(allocator, file);
    defer allocator.free(read);

    const options = std.json.ParseOptions{ .duplicate_field_behavior = .use_first, .ignore_unknown_fields = true };
    const parsed = try std.json.parseFromSlice(Atlas, allocator, read, options);
    defer parsed.deinit();

    const animations = try allocator.dupe(Animation, parsed.value.animations);

    for (animations) |*animation| {
        animation.name = try allocator.dupe(u8, animation.name);
    }

    return .{
        .sprites = try allocator.dupe(Sprite, parsed.value.sprites),
        .animations = animations,
    };
}

pub fn spriteName(atlas: *Atlas, allocator: std.mem.Allocator, index: usize) ![]const u8 {
    for (atlas.animations) |animation| {
        if (index >= animation.start and index < animation.start + animation.length) {
            if (animation.length > 1) {
                const frame: usize = index - animation.start;
                return std.fmt.allocPrint(allocator, "{s}_{d}", .{ animation.name, frame });
            } else {
                return std.fmt.allocPrint(allocator, "{s}", .{animation.name});
            }
        }
    }

    return std.fmt.allocPrint(allocator, "Sprite_{d}", .{index});
}

pub fn deinit(atlas: *Atlas, allocator: std.mem.Allocator) void {
    for (atlas.animations) |*animation| {
        allocator.free(animation.name);
    }

    allocator.free(atlas.sprites);
    allocator.free(atlas.animations);
}
