const std = @import("std");
const Pixi = @import("Pixi.zig");

const File = @This();

version: std.SemanticVersion,
width: u32,
height: u32,
tile_width: u32,
tile_height: u32,
layers: []Pixi.Layer,
sprites: []Pixi.Sprite,
animations: []Pixi.Animation,

pub fn deinit(self: *File, allocator: std.mem.Allocator) void {
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
