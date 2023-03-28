const std = @import("std");
const pixi = @import("root");
const zgpu = @import("zgpu");
const zstbi = @import("zstbi");
const storage = @import("storage.zig");
const zip = @import("zip");
const zgui = @import("zgui");

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
    selected_layer_index: usize = 0,
    selected_sprite_index: usize = 0,
    selected_sprites: std.ArrayList(usize),
    selected_animation_index: usize = 0,
    selected_animation_state: AnimationState = .pause,
    selected_animation_elapsed: f32 = 0.0,
    background_image: zstbi.Image,
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

    pub fn toExternal(self: Pixi, allocator: std.mem.Allocator) !storage.External.Pixi {
        var layers = try allocator.alloc(storage.External.Layer, self.layers.items.len);
        var sprites = try allocator.alloc(storage.External.Sprite, self.sprites.items.len);

        for (layers, 0..) |*layer, i| {
            layer.name = self.layers.items[i].name;
        }

        for (sprites, 0..) |*sprite, i| {
            sprite.name = self.sprites.items[i].name;
            sprite.origin_x = self.sprites.items[i].origin_x;
            sprite.origin_y = self.sprites.items[i].origin_y;
        }

        return .{
            .width = self.width,
            .height = self.height,
            .tileWidth = self.tile_width,
            .tileHeight = self.tile_height,
            .layers = layers,
            .sprites = sprites,
            .animations = self.animations.items,
        };
    }

    /// Returns true if file saved.
    pub fn save(self: *Pixi) !bool {
        if (!self.dirty) return false;

        var external = try self.toExternal(pixi.state.allocator);

        var zip_file = zip.zip_open(self.path, zip.ZIP_DEFAULT_COMPRESSION_LEVEL, 'w');

        if (zip_file) |z| {
            var json = std.ArrayList(u8).init(pixi.state.allocator);
            const out_stream = json.writer();
            const options = std.json.StringifyOptions{ .whitespace = .{} };

            try std.json.stringify(external, options, out_stream);

            var json_output = try json.toOwnedSlice();
            defer pixi.state.allocator.free(json_output);

            _ = zip.zip_entry_open(z, "pixidata.json");
            _ = zip.zip_entry_write(z, json_output.ptr, json_output.len);
            _ = zip.zip_entry_close(z);

            for (self.layers.items) |layer| {
                const layer_name = zgui.formatZ("{s}.png", .{layer.name});
                _ = zip.zip_entry_open(z, @ptrCast([*c]const u8, layer_name));
                try layer.texture.image.writeToFn(write, z, .png);
                _ = zip.zip_entry_close(z);
            }

            zip.zip_close(z);
            self.dirty = false;
        }

        pixi.state.allocator.free(external.layers);
        pixi.state.allocator.free(external.sprites);

        return false;
    }

    fn write(context: ?*anyopaque, data: ?*anyopaque, size: c_int) callconv(.C) void {
        const zip_file = @ptrCast(?*zip.struct_zip_t, context);

        if (zip_file) |z| {
            _ = zip.zip_entry_write(z, data, @intCast(usize, size));
        }
    }

    pub fn createBackground(self: *Pixi) !void {
        self.background_image = try zstbi.Image.createEmpty(self.tile_width * 2, self.tile_height * 2, 4, .{});
        // Set background image data to checkerboard
        {
            var i: usize = 0;
            while (i < @intCast(usize, self.tile_width * 2 * self.tile_height * 2 * 4)) : (i += 4) {
                const r = i;
                const g = i + 1;
                const b = i + 2;
                const a = i + 3;
                const primary = pixi.state.style.checkerboard_primary.bytes();
                const secondary = pixi.state.style.checkerboard_secondary.bytes();
                if (i % 3 == 0) {
                    self.background_image.data[r] = primary[0];
                    self.background_image.data[g] = primary[1];
                    self.background_image.data[b] = primary[2];
                    self.background_image.data[a] = primary[3];
                } else {
                    self.background_image.data[r] = secondary[0];
                    self.background_image.data[g] = secondary[1];
                    self.background_image.data[b] = secondary[2];
                    self.background_image.data[a] = secondary[3];
                }
            }
        }
        self.background_texture_handle = pixi.state.gctx.createTexture(.{
            .usage = .{ .texture_binding = true, .copy_dst = true },
            .size = .{
                .width = self.tile_width * 2,
                .height = self.tile_height * 2,
                .depth_or_array_layers = 1,
            },
            .format = zgpu.imageInfoToTextureFormat(4, 1, false),
        });
        self.background_texture_view_handle = pixi.state.gctx.createTextureView(self.background_texture_handle, .{});
        pixi.state.gctx.queue.writeTexture(
            .{ .texture = pixi.state.gctx.lookupResource(self.background_texture_handle).? },
            .{
                .bytes_per_row = self.background_image.bytes_per_row,
                .rows_per_image = self.background_image.height,
            },
            .{ .width = self.background_image.width, .height = self.background_image.height },
            u8,
            self.background_image.data,
        );
    }

    pub fn setSelectedSpritesOriginX(self: *Pixi, origin_x: f32) void {
        var dirty: bool = false;
        for (self.selected_sprites.items) |sprite_index| {
            if (self.sprites.items[sprite_index].origin_x != origin_x) {
                self.sprites.items[sprite_index].origin_x = origin_x;
                dirty = true;
            }
        }
        if (dirty) {
            self.dirty = dirty;
        }
    }

    pub fn setSelectedSpritesOriginY(self: *Pixi, origin_y: f32) void {
        var dirty: bool = false;
        for (self.selected_sprites.items) |sprite_index| {
            if (self.sprites.items[sprite_index].origin_y != origin_y) {
                self.sprites.items[sprite_index].origin_y = origin_y;
                dirty = true;
            }
        }
        if (dirty) {
            self.dirty = dirty;
        }
    }

    pub fn setSelectedSpritesOrigin(self: *Pixi, origin: [2]f32) void {
        var dirty: bool = false;
        for (self.selected_sprites.items) |sprite_index| {
            if (self.sprites.items[sprite_index].origin_x != origin[0] or self.sprites.items[sprite_index].origin_y != origin[1]) {
                self.sprites.items[sprite_index].origin_x = origin[0];
                self.sprites.items[sprite_index].origin_y = origin[1];
                dirty = true;
            }
        }
        if (dirty) {
            self.dirty = dirty;
        }
    }

    /// Searches for an animation containing the current selected sprite index
    /// Returns true if one is found and set, false if not
    pub fn setAnimationFromSpriteIndex(self: *Pixi) bool {
        for (self.animations.items, 0..) |animation, i| {
            if (self.selected_sprite_index >= animation.start and self.selected_sprite_index <= animation.start + animation.length - 1) {
                self.selected_animation_index = i;
                return true;
            }
        }
        return false;
    }

    pub fn flipbookScrollFromSpriteIndex(self: Pixi, index: usize) f32 {
        return -@intToFloat(f32, index * self.tile_width) * 1.1;
    }

    pub fn pixelCoordinatesFromIndex(self: Pixi, index: usize) ?[2]f32 {
        if (index > self.sprites.items.len - 1) return null;
        const x = @intToFloat(f32, @mod(@intCast(u32, index), self.width));
        const y = @intToFloat(f32, @divTrunc(@intCast(u32, index), self.width));
        return .{ x, y };
    }

    pub fn spriteSelectionIndex(self: Pixi, index: usize) ?usize {
        return std.mem.indexOf(usize, self.selected_sprites.items, &[_]usize{index});
    }

    pub fn makeSpriteSelection(self: *Pixi, selected_sprite: usize) void {
        const selection = self.selected_sprites.items.len > 0;
        const selected_sprite_index = self.spriteSelectionIndex(selected_sprite);
        const contains = selected_sprite_index != null;
        if (pixi.state.controls.key(.primary_modifier).down()) {
            if (!contains) {
                self.selected_sprites.append(selected_sprite) catch unreachable;
            } else {
                if (selected_sprite_index) |i| {
                    _ = self.selected_sprites.swapRemove(i);
                }
            }
        } else if (pixi.state.controls.key(.secondary_modifier).down()) {
            if (selection) {
                const last = self.selected_sprites.getLast();
                if (selected_sprite > last) {
                    for (last..selected_sprite + 1) |i| {
                        if (std.mem.indexOf(usize, self.selected_sprites.items, &[_]usize{i}) == null) {
                            self.selected_sprites.append(i) catch unreachable;
                        }
                    }
                } else if (selected_sprite < last) {
                    for (selected_sprite..last) |i| {
                        if (std.mem.indexOf(usize, self.selected_sprites.items, &[_]usize{i}) == null) {
                            self.selected_sprites.append(i) catch unreachable;
                        }
                    }
                } else if (selected_sprite_index) |i| {
                    _ = self.selected_sprites.swapRemove(i);
                } else {
                    self.selected_sprites.append(selected_sprite) catch unreachable;
                }
            } else {
                self.selected_sprites.append(selected_sprite) catch unreachable;
            }
        } else {
            if (selection) {
                self.selected_sprites.clearAndFree();
            }
            self.selected_sprites.append(selected_sprite) catch unreachable;
        }
    }
};

pub const Layer = struct {
    name: [:0]const u8,
    texture: pixi.gfx.Texture,

    pub fn getPixel(self: Layer, pixel: [2]usize) [4]u8 {
        const index = (pixel[0] * 4) + (pixel[1] * @intCast(usize, self.texture.image.width) * 4);
        return self.texture.image.data[index .. index + 4][0..4].*;
    }
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
