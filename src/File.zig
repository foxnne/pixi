const std = @import("std");
const pixi = @import("pixi.zig");

const File = @This();

version: std.SemanticVersion,
columns: u32,
rows: u32,
column_width: u32,
row_height: u32,
layers: []pixi.Layer,
sprites: []pixi.Sprite,
animations: []pixi.Animation,

pub fn deinit(self: *File, allocator: std.mem.Allocator) void {
    for (self.layers) |*layer| {
        allocator.free(layer.name);
    }
    for (self.animations) |*animation| {
        allocator.free(animation.frames);
        allocator.free(animation.name);
    }
    allocator.free(self.layers);
    allocator.free(self.sprites);
    allocator.free(self.animations);
}

pub const FileV2 = struct {
    version: std.SemanticVersion,
    width: u32,
    height: u32,
    tile_width: u32,
    tile_height: u32,
    layers: []pixi.Layer,
    sprites: []pixi.Sprite,
    animations: []pixi.Animation,

    pub fn deinit(self: *File, allocator: std.mem.Allocator) void {
        for (self.layers) |*layer| {
            allocator.free(layer.name);
        }
        for (self.animations) |*animation| {
            allocator.free(animation.name);
        }
        allocator.free(self.layers);
        allocator.free(self.sprites);
        allocator.free(self.animations);
    }
};

pub const FileV1 = struct {
    version: std.SemanticVersion,
    width: u32,
    height: u32,
    tile_width: u32,
    tile_height: u32,
    layers: []pixi.Layer,
    sprites: []pixi.Sprite,
    animations: []pixi.Animation.OldAnimation,

    pub fn deinit(self: *File, allocator: std.mem.Allocator) void {
        for (self.layers) |*layer| {
            allocator.free(layer.name);
        }
        for (self.animations) |*animation| {
            allocator.free(animation.name);
        }
        allocator.free(self.layers);
        allocator.free(self.sprites);
        allocator.free(self.animations);
    }
};
