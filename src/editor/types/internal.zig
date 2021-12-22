const std = @import("std");
const upaya = @import("upaya");
const editor = @import("../editor.zig");
const history = editor.history;

const types = @import("types.zig");
const Sprite = types.Sprite;
const Animation = types.Animation;

const IOFile = types.IOFile;
const IOLayer = types.IOLayer;
const IOSprite = types.IOSprite;

// internal file
pub const File = struct {
    name: []const u8,
    path: ?[]const u8 = null,
    width: i32,
    height: i32,
    tileWidth: i32,
    tileHeight: i32,
    background: upaya.Texture = undefined,
    temporary: Layer = undefined,
    layers: std.ArrayList(Layer) = undefined,
    sprites: std.ArrayList(Sprite) = undefined,
    animations: std.ArrayList(Animation) = undefined,
    history: history.History = undefined,
    dirty: bool = true,

    pub fn deinit(self: *File) void {
        for (self.layers.items) |layer| {
            layer.texture.deinit();
            layer.image.deinit();
            layer.heightmap_texture.deinit();
            layer.heightmap_image.deinit();
        }
        self.layers.deinit();
        self.background.deinit();
        self.temporary.texture.deinit();
        self.temporary.image.deinit();
        self.sprites.deinit();
    }

    pub fn toIOFile(self: File) IOFile {
        var layers: std.ArrayList(IOLayer) = std.ArrayList(IOLayer).initCapacity(upaya.mem.allocator, self.layers.items.len) catch unreachable;

        for (self.layers.items) |layer| {
            layers.append(.{
                .name = upaya.mem.allocator.dupe(u8, layer.name) catch unreachable,
            }) catch unreachable;
        }

        var sprites: std.ArrayList(IOSprite) = std.ArrayList(IOSprite).initCapacity(upaya.mem.allocator, self.sprites.items.len) catch unreachable;

        for (self.sprites.items) |sprite| {
            sprites.append(.{
                .name = upaya.mem.allocator.dupe(u8, sprite.name) catch unreachable,
                .origin_x = sprite.origin_x,
                .origin_y = sprite.origin_y,
            }) catch unreachable;
        }

        var animations: std.ArrayList(Animation) = std.ArrayList(Animation).initCapacity(upaya.mem.allocator, self.animations.items.len) catch unreachable;

        for (self.animations.items) |animation| {
            animations.append(.{
                .name = upaya.mem.allocator.dupe(u8, animation.name) catch unreachable,
                .start = animation.start,
                .length = animation.length,
                .fps = animation.fps,
            }) catch unreachable;
        }

        var ioFile: IOFile = .{
            .name = upaya.mem.allocator.dupe(u8, self.name) catch unreachable,
            .width = self.width,
            .height = self.height,
            .tileWidth = self.tileWidth,
            .tileHeight = self.tileHeight,
            .layers = layers.toOwnedSlice(),
            .sprites = sprites.toOwnedSlice(),
            .animations = animations.toOwnedSlice(),
        };

        layers.deinit();
        sprites.deinit();
        animations.deinit();

        //TODO: should I free all the fields in the IOFile?

        return ioFile;
    }
};

// internal layer
pub const Layer = struct {
    name: []const u8,
    texture: upaya.Texture,
    image: upaya.Image,
    heightmap_image: upaya.Image,
    heightmap_texture: upaya.Texture,
    id: usize,
    hidden: bool = false,
    dirty: bool = false,

    pub fn updateTexture(self: *Layer) void {
        if (self.dirty) {
            self.texture.setColorData(self.image.pixels);
            self.heightmap_texture.setColorData(self.heightmap_image.pixels);
            self.dirty = false;
        }
    }
};
