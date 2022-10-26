const std = @import("std");
const pixi = @import("pixi");
const zgpu = @import("zgpu");
const zstbi = @import("zstbi");
const storage = @import("storage.zig");

pub const Pixi = struct {
    path: [:0]const u8,
    width: u32,
    height: u32,
    tile_width: u32,
    tile_height: u32,
    layers: std.ArrayList(Layer),
    sprites: std.ArrayList(Sprite),
    animations: std.ArrayList(Animation),
    dirty: bool = true,

    pub fn toExternal(self: Pixi) !storage.External.Pixi {
        const allocator = pixi.state.allocator;
        var layers = try allocator.alloc(storage.External.Layer, self.layers.items.len);
        var sprites = try allocator.alloc(storage.External.Sprite, self.sprites.items.len);

        for (layers) |*layer, i| {
            layer.name = allocator.dupe(u8, self.layers.items[i].name);
        }

        for (sprites) |*sprite, i| {
            sprite.name = allocator.dupe(u8, self.sprites.items[i].name);
            sprite.origin_x = self.sprites.items[i].origin_x;
            sprite.origin_y = self.sprites.items[i].origin_y;
        }

        return .{
            .width = self.width,
            .height = self.height,
            .tile_width = self.tile_width,
            .tile_height = self.tile_height,
            .layers = layers,
            .sprites = sprites,
            .animations = self.animations.toOwnedSlice(),
        };
    }
};

pub const Layer = struct {
    name: [:0]const u8,
    texture_handle: zgpu.TextureHandle,
    texture_view_handle: zgpu.TextureViewHandle,
    image: zstbi.Image,
};

pub const Sprite = struct {
    name: [:0]const u8,
    index: usize,
    origin_x: f32 = 0.0,
    origin_y: f32 = 0.0,
};

pub const Animation = struct {
    name: [:0]const u8,
    start: usize,
    length: usize,
    fps: usize,
};
