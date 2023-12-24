const std = @import("std");
const pixi = @import("root");
const storage = @import("storage.zig");
const zip = @import("zip");
const fs = @import("../tools/fs.zig");

// TODO: Kept old names for compatibility with old files, but need to change.
// TODO: `tileWidth` => `tile_width`, `tileHeight` => `tile_height`
// TODO: Also remove useless `name` field.
pub const OldPixi = struct {
    //name: []const u8,
    width: u32,
    height: u32,
    tileWidth: u32,
    tileHeight: u32,
    layers: []Layer,
    sprites: []OldSprite,
    animations: []Animation,
};

pub const Pixi = struct {
    version: std.SemanticVersion = .{ .major = 0, .minor = 0, .patch = 0 },
    width: u32,
    height: u32,
    tile_width: u32,
    tile_height: u32,
    layers: []Layer,
    sprites: []Sprite,
    animations: []Animation,

    pub fn deinit(self: *Pixi, allocator: std.mem.Allocator) void {
        for (self.layers) |*layer| {
            allocator.free(layer.name);
        }
        for (self.sprites) |*sprite| {
            allocator.free(sprite.name);
        }
        for (self.animations) |*animation| {
            allocator.free(animation.name);
        }
        allocator.free(self.layers);
        allocator.free(self.sprites);
        allocator.free(self.animations);
    }
};

pub const Layer = struct {
    name: [:0]const u8,
    index_on_export: bool = false,
};

pub const OldSprite = struct {
    name: [:0]const u8,
    origin_x: f32 = 0.0,
    origin_y: f32 = 0.0,
};

pub const Sprite = struct {
    name: [:0]const u8,
    source: [4]u32,
    origin: [2]i32,
};

pub const Animation = storage.Internal.Animation;

pub const Atlas = struct {
    sprites: []Sprite,
    animations: []Animation,

    pub fn initFromFile(allocator: std.mem.Allocator, file: []const u8) !Atlas {
        const read = try fs.read(allocator, file);
        defer allocator.free(read);

        const options = std.json.ParseOptions{ .duplicate_field_behavior = .use_first, .ignore_unknown_fields = true };
        const parsed = try std.json.parseFromSlice(Atlas, allocator, read, options);
        defer parsed.deinit();

        return parsed.value;
    }
};
