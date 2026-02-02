const std = @import("std");
const fs = @import("tools/fs.zig");
const pixi = @import("pixi.zig");

const Atlas = @This();

const Sprite = @import("Sprite.zig");
const Animation = @import("Animation.zig");

sprites: []Sprite,
animations: []Animation,

const AtlasV2 = struct {
    sprites: []Sprite,
    animations: []Animation.AnimationV2,
};

const AtlasV1 = struct {
    sprites: []Sprite,
    animations: []Animation.AnimationV1,
};

pub fn loadFromFile(allocator: std.mem.Allocator, file: []const u8) !Atlas {
    const read = try fs.read(allocator, file);
    defer allocator.free(read);

    return loadFromBytes(allocator, read);
}

pub fn loadFromBytes(allocator: std.mem.Allocator, bytes: []const u8) !Atlas {
    const options = std.json.ParseOptions{ .duplicate_field_behavior = .use_first, .ignore_unknown_fields = true };

    if (std.json.parseFromSlice(Atlas, allocator, bytes, options) catch null) |parsed| {
        const animations = try allocator.dupe(Animation, parsed.value.animations);

        for (animations) |*animation| {
            animation.name = try allocator.dupe(u8, animation.name);
        }

        return .{
            .sprites = try allocator.dupe(Sprite, parsed.value.sprites),
            .animations = animations,
        };
    } else if (std.json.parseFromSlice(AtlasV2, allocator, bytes, options) catch null) |parsed| {
        const animations = try allocator.alloc(Animation, parsed.value.animations.len);
        for (animations, parsed.value.animations) |*animation, old_animation| {
            animation.name = try allocator.dupe(u8, old_animation.name);
            animation.frames = try allocator.alloc(Animation.Frame, old_animation.frames.len);
            for (animation.frames, old_animation.frames) |*frame, old_frame| {
                frame.index = old_frame;
                frame.ms = @intFromFloat(1000.0 / old_animation.fps);
            }
        }

        return .{
            .sprites = try allocator.dupe(Sprite, parsed.value.sprites),
            .animations = animations,
        };
    } else if (std.json.parseFromSlice(AtlasV1, allocator, bytes, options) catch null) |parsed| {
        const animations = try allocator.alloc(Animation, parsed.value.animations.len);
        for (animations, parsed.value.animations) |*animation, old_animation| {
            animation.name = try allocator.dupe(u8, old_animation.name);
            animation.frames = try allocator.alloc(Animation.Frame, old_animation.length);
            for (animation.frames, 0..old_animation.length) |*frame, i| {
                frame.index = old_animation.start + i;
                frame.ms = @intFromFloat(1000.0 / old_animation.fps);
            }
            animation.fps = old_animation.fps;
        }

        return .{
            .sprites = try allocator.dupe(Sprite, parsed.value.sprites),
            .animations = animations,
        };
    }

    return error.CannotLoadAtlas;
}

pub fn spriteName(atlas: *Atlas, allocator: std.mem.Allocator, index: usize) ![]const u8 {
    for (atlas.animations) |animation| {
        for (animation.frames, 0..) |frame, i| {
            if (frame.index != index) continue;

            if (animation.frames.len > 1) {
                return std.fmt.allocPrint(allocator, "{s}_{d}", .{ animation.name, i });
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
