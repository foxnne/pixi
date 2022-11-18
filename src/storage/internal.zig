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
    camera: pixi.gfx.Camera = .{},
    flipbook_camera: pixi.gfx.Camera = .{},
    flipbook_scroll: f32 = 0.0,
    flipbook_scroll_request: ?ScrollRequest = null,
    selected_sprite_index: usize = 0,
    selected_animation_index: usize = 0,
    selected_animation_state: AnimationState = .pause,
    selected_animation_elapsed: f32 = 0.0,
    background_image: zstbi.Image,
    background_image_data: []u8,
    background_texture_handle: zgpu.TextureHandle,
    background_texture_view_handle: zgpu.TextureViewHandle,
    dirty: bool = true,

    pub const ScrollRequest = struct {
        from: f32,
        to: f32,
        elapsed: f32 = 0.0,
        state: AnimationState,
    };

    pub const AnimationState = enum { pause, play };

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

    /// Searches for an animation containing the current selected sprite index
    /// Returns true if one is found and set, false if not
    pub fn setAnimationFromSpriteIndex(self: *Pixi) bool {
        for (self.animations.items) |animation, i| {
            if (self.selected_sprite_index >= animation.start and self.selected_sprite_index <= animation.start + animation.length - 1) {
                self.selected_animation_index = i;
                return true;
            }
        }
        return false;
    }

    pub fn pixelCoordinatesFromIndex(self: Pixi, index: usize) ?[2]f32 {
        if (index > self.sprites.items.len - 1) return null;
        const x = @intToFloat(f32, @mod(@intCast(u32, index), self.width));
        const y = @intToFloat(f32, @divTrunc(@intCast(u32, index), self.width));
        return .{ x, y };
    }
};

pub const Layer = struct {
    name: [:0]const u8,
    texture_handle: zgpu.TextureHandle,
    texture_view_handle: zgpu.TextureViewHandle,
    data: []u8,
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
