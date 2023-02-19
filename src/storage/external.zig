const std = @import("std");
const pixi = @import("pixi");
const storage = @import("storage.zig");
const zip = @import("zip");

// TODO: Kept old names for compatibility with old files, but need to change.
// TODO: `tileWidth` => `tile_width`, `tileHeight` => `tile_height`
// TODO: Also remove useless `name` field.
pub const Pixi = struct {
    //name: []const u8,
    width: u32,
    height: u32,
    tileWidth: u32,
    tileHeight: u32,
    layers: []Layer,
    sprites: []Sprite,
    animations: []Animation,
};

pub const Layer = struct {
    name: []const u8,
    index_on_export: bool = false,
};

pub const Sprite = struct {
    name: []const u8,
    origin_x: f32 = 0.0,
    origin_y: f32 = 0.0,
};

pub const Animation = storage.Internal.Animation;
