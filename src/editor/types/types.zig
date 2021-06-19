const std = @import("std");
const upaya = @import("upaya");

pub const File = struct {
    name: []const u8,
    width: i32,
    height: i32,
    tileWidth: i32,
    tileHeight: i32,
    background: upaya.Texture,
    layers: std.ArrayList(Layer),
};

pub const Layer = struct {
    name: []const u8,
    texture: upaya.Texture,
    hidden: bool = false,
};

pub const Animation = struct {
    name: []const u8,
    start: usize,
    length: usize,
};