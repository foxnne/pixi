const std = @import("std");
const upaya = @import("upaya");
const editor = @import("../editor.zig");
const history = editor.history;

pub const File = struct {
    name: []const u8,
    width: i32,
    height: i32,
    tileWidth: i32,
    tileHeight: i32,
    background: upaya.Texture,
    temporary: Layer,
    layers: std.ArrayList(Layer),
    sprites: std.ArrayList(Sprite),
    animations: std.ArrayList(Animation),
    history: history.History,
    dirty: bool = false,

    pub fn deinit (self: *File) void {
        for (self.layers.items) |layer| {
            layer.texture.deinit();
            layer.image.deinit();
        }
        self.layers.deinit();
        self.background.deinit();
        self.temporary.texture.deinit();
        self.temporary.image.deinit();
        self.sprites.deinit();
    }
};

pub const Layer = struct {
    name: []const u8,
    texture: upaya.Texture,
    image: upaya.Image,
    id: usize,
    hidden: bool = false,
    dirty: bool = false,

    pub fn updateTexture (self: *Layer) void {
        if (self.dirty) {
            self.texture.setColorData(self.image.pixels);
            self.dirty = false;
        }
    }
};

pub const Sprite = struct {
    name: []const u8,
    index: usize,
    origin_x: f32,
    origin_y: f32,
};

pub const Animation = struct {
    name: []const u8,
    start: usize,
    length: usize,
    fps: usize,
};