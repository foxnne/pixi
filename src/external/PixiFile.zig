const std = @import("std");
const Pixi = @import("../Pixi.zig");

const PixiFile = @This();

// TODO: Kept old names for compatibility with old files, but need to change.
// TODO: `tileWidth` => `tile_width`, `tileHeight` => `tile_height`
// TODO: Also remove useless `name` field.
pub const OldPixi = struct {
    //name: []const u8,
    width: u32,
    height: u32,
    tileWidth: u32,
    tileHeight: u32,
    layers: []Pixi.External.Layer,
    sprites: []Pixi.External.OldSprite,
    animations: []Pixi.External.Animation,
};

version: std.SemanticVersion,
width: u32,
height: u32,
tile_width: u32,
tile_height: u32,
layers: []Pixi.External.Layer,
sprites: []Pixi.External.Sprite,
animations: []Pixi.External.Animation,

pub fn deinit(self: *PixiFile, allocator: std.mem.Allocator) void {
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
