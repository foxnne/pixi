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
    tools: Tools = .{},
    layers: std.ArrayList(Layer),
    deleted_layers: std.ArrayList(Layer),
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
    temporary_layer: Layer,
    history: History,
    buffers: Buffers,
    counter: usize = 0,
    dirty: bool = true,

    pub const ScrollRequest = struct {
        from: f32,
        to: f32,
        elapsed: f32 = 0.0,
        state: AnimationState,
    };

    pub const AnimationState = enum { pause, play };
    pub const Canvas = enum { primary, flipbook };

    pub const History = @import("History.zig");
    pub const Buffers = @import("Buffers.zig");

    pub fn canvasCenterOffset(self: *Pixi, canvas: Canvas) [2]f32 {
        const width = switch (canvas) {
            .primary => @intToFloat(f32, self.width),
            .flipbook => @intToFloat(f32, self.tile_width),
        };
        const height = switch (canvas) {
            .primary => @intToFloat(f32, self.height),
            .flipbook => @intToFloat(f32, self.tile_height),
        };

        return .{ -width / 2.0, -height / 2.0 };
    }

    pub fn id(file: *Pixi) usize {
        file.counter += 1;
        return file.counter;
    }

    pub fn processSample(file: *Pixi, canvas: Canvas) void {
        var mouse_position = pixi.state.controls.mouse.position.toSlice();
        var camera = switch (canvas) {
            .primary => file.camera,
            .flipbook => file.flipbook_camera,
        };

        const pixel_coord_opt = switch (canvas) {
            .primary => camera.pixelCoordinates(.{
                .texture_position = canvasCenterOffset(file, canvas),
                .position = mouse_position,
                .width = file.width,
                .height = file.height,
            }),
            .flipbook => camera.flipbookPixelCoordinates(file, .{
                .sprite_position = canvasCenterOffset(file, canvas),
                .position = mouse_position,
                .width = file.width,
                .height = file.height,
            }),
        };

        if (pixel_coord_opt) |pixel_coord| {
            const pixel = .{ @floatToInt(usize, pixel_coord[0]), @floatToInt(usize, pixel_coord[1]) };
            // Eyedropper tool
            if (pixi.state.controls.sample()) {
                var color: [4]u8 = .{ 0, 0, 0, 0 };

                var layer_index: ?usize = null;
                // Go through all layers until we hit an opaque pixel
                for (file.layers.items, 0..) |layer, i| {
                    const p = layer.getPixel(pixel);
                    if (p[3] > 0) {
                        color = p;
                        layer_index = i;
                        if (pixi.state.settings.eyedropper_auto_switch_layer)
                            file.selected_layer_index = i;
                        break;
                    } else continue;
                }

                if (color[3] == 0) {
                    pixi.state.tools.set(.eraser);
                } else {
                    pixi.state.tools.set(.pencil);
                    file.tools.primary_color = color;
                }

                if (layer_index) |index| {
                    camera.drawLayerTooltip(index);
                    camera.drawColorTooltip(color);
                } else {
                    camera.drawColorTooltip(color);
                }
            }
        }
    }

    pub fn processStroke(file: *Pixi, canvas: Canvas) void {
        if (switch (pixi.state.tools.current) {
            .pencil, .eraser => false,
            else => true,
        }) return;

        const canvas_center_offset = canvasCenterOffset(file, canvas);
        const mouse_position = pixi.state.controls.mouse.position.toSlice();
        const previous_mouse_position = pixi.state.controls.mouse.previous_position.toSlice();

        var layer: pixi.storage.Internal.Layer = file.layers.items[file.selected_layer_index];

        const camera = switch (canvas) {
            .primary => file.camera,
            .flipbook => file.flipbook_camera,
        };

        const pixel_coords_opt = switch (canvas) {
            .primary => camera.pixelCoordinates(.{
                .texture_position = canvas_center_offset,
                .position = mouse_position,
                .width = file.width,
                .height = file.height,
            }),

            .flipbook => camera.flipbookPixelCoordinates(file, .{
                .sprite_position = canvas_center_offset,
                .position = mouse_position,
                .width = file.width,
                .height = file.height,
            }),
        };

        if (pixi.state.controls.mouse.primary.down()) {
            const color = switch (pixi.state.tools.current) {
                .pencil => file.tools.primary_color,
                .eraser => [_]u8{ 0, 0, 0, 0 },
                else => unreachable,
            };

            if (pixi.state.controls.mouse.dragging()) {
                if (pixel_coords_opt) |pixel_coord| {
                    const prev_pixel_coords_opt = switch (canvas) {
                        .primary => camera.pixelCoordinates(.{
                            .texture_position = canvas_center_offset,
                            .position = previous_mouse_position,
                            .width = file.width,
                            .height = file.height,
                        }),

                        .flipbook => camera.flipbookPixelCoordinates(file, .{
                            .sprite_position = canvas_center_offset,
                            .position = previous_mouse_position,
                            .width = file.width,
                            .height = file.height,
                        }),
                    };

                    if (prev_pixel_coords_opt) |prev_pixel_coord| {
                        const pixel_coords = pixi.algorithms.brezenham.process(prev_pixel_coord, pixel_coord) catch unreachable;
                        for (pixel_coords) |p_coord| {
                            const p = .{ @floatToInt(usize, p_coord[0]), @floatToInt(usize, p_coord[1]) };
                            const index = layer.getPixelIndex(p);
                            const value = layer.getPixel(p);
                            if (!std.mem.containsAtLeast(usize, file.buffers.stroke.indices.items, 1, &.{index}))
                                file.buffers.stroke.append(index, value) catch unreachable;
                            layer.setPixel(p, color, false);
                        }
                        layer.texture.update(pixi.state.gctx);
                        file.dirty = true;
                        pixi.state.allocator.free(pixel_coords);
                    }
                }
            } else if (pixi.state.controls.mouse.primary.pressed()) {
                if (pixel_coords_opt) |pixel_coord| {
                    const pixel = .{ @floatToInt(usize, pixel_coord[0]), @floatToInt(usize, pixel_coord[1]) };

                    const index = layer.getPixelIndex(pixel);
                    const value = layer.getPixel(pixel);
                    file.buffers.stroke.append(index, value) catch unreachable;

                    layer.setPixel(pixel, color, true);
                    file.dirty = true;
                }
            }
        } else { // Not actively drawing, but hovering over canvas
            if (pixel_coords_opt) |pixel_coord| {
                const pixel = .{ @floatToInt(usize, pixel_coord[0]), @floatToInt(usize, pixel_coord[1]) };
                switch (pixi.state.tools.current) {
                    .pencil => file.temporary_layer.setPixel(pixel, file.tools.primary_color, true),
                    .eraser => file.temporary_layer.setPixel(pixel, .{ 255, 255, 255, 255 }, true),
                    else => unreachable,
                }
            }

            // Submit the stroke change buffer
            if (file.buffers.stroke.indices.items.len > 0 and pixi.state.controls.mouse.primary.released()) {
                const change = file.buffers.stroke.toChange(file.selected_layer_index) catch unreachable;
                file.history.append(change) catch unreachable;
            }
        }
    }

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

    fn write(context: ?*anyopaque, data: ?*anyopaque, size: c_int) callconv(.C) void {
        const zip_file = @ptrCast(?*zip.struct_zip_t, context);

        if (zip_file) |z| {
            _ = zip.zip_entry_write(z, data, @intCast(usize, size));
        }
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

        self.history.bookmark = 0;

        return false;
    }

    pub fn newHistorySelectedSprites(file: *Pixi, change_type: History.ChangeType) !void {
        switch (change_type) {
            .origins => {
                var change = try pixi.storage.Internal.Pixi.History.Change.create(pixi.state.allocator, change_type, file.selected_sprites.items.len);
                for (file.selected_sprites.items, 0..) |sprite_index, i| {
                    const sprite = file.sprites.items[sprite_index];
                    change.origins.indices[i] = sprite_index;
                    change.origins.values[i] = .{ sprite.origin_x, sprite.origin_y };
                }
                try file.history.append(change);
            },
            else => {},
        }
    }

    pub fn undo(self: *Pixi) !void {
        return self.history.undoRedo(self, .undo);
    }

    pub fn redo(self: *Pixi) !void {
        return self.history.undoRedo(self, .redo);
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

    pub fn createLayer(self: *Pixi, name: [:0]const u8) !void {
        try self.layers.insert(0, .{
            .name = try pixi.state.allocator.dupeZ(u8, name),
            .texture = try pixi.gfx.Texture.createEmpty(pixi.state.gctx, self.width, self.height, .{}),
            .visible = true,
            .id = self.id(),
        });
        try self.history.append(.{ .layer_restore_delete = .{
            .action = .delete,
            .index = 0,
        } });
        self.dirty = true;
    }

    pub fn deleteLayer(self: *Pixi, index: usize) !void {
        if (index >= self.layers.items.len) return;
        try self.deleted_layers.append(self.layers.orderedRemove(index));
        try self.history.append(.{ .layer_restore_delete = .{
            .action = .restore,
            .index = index,
        } });
        self.dirty = true;
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

    pub fn getSelectedSpritesOrigin(self: *Pixi) ?[2]f32 {
        if (self.selected_sprites.items.len == 0) return null;
        const first = self.sprites.items[self.selected_sprites.items[0]];
        const origin = .{ first.origin_x, first.origin_y };

        for (self.selected_sprites.items) |sprite_index| {
            const sprite = self.sprites.items[sprite_index];
            if (sprite.origin_x != origin[0] or sprite.origin_y != origin[1])
                return null;
        }

        return origin;
    }

    pub fn setSelectedSpritesOrigin(self: *Pixi, origin: [2]f32) void {
        var dirty: bool = false;

        for (self.selected_sprites.items) |sprite_index| {
            const current_origin = .{ self.sprites.items[sprite_index].origin_x, self.sprites.items[sprite_index].origin_y };
            if (current_origin[0] != origin[0] or current_origin[1] != origin[1]) {
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

    pub const Tools = struct {
        primary_color: [4]u8 = .{ 255, 255, 255, 255 },
        secondary_color: [4]u8 = .{ 0, 0, 0, 255 },
    };
};

pub const Layer = struct {
    name: [:0]const u8,
    texture: pixi.gfx.Texture,
    visible: bool = true,
    active: bool = false,
    id: usize = 0,

    pub fn getPixelIndex(self: Layer, pixel: [2]usize) usize {
        return pixel[0] + pixel[1] * @intCast(usize, self.texture.image.width);
    }

    pub fn getPixel(self: Layer, pixel: [2]usize) [4]u8 {
        const index = self.getPixelIndex(pixel);
        const pixels = @ptrCast([*][4]u8, self.texture.image.data.ptr)[0 .. self.texture.image.data.len / 4];
        return pixels[index];
    }

    pub fn setPixel(self: *Layer, pixel: [2]usize, color: [4]u8, update: bool) void {
        const index = self.getPixelIndex(pixel);
        var pixels = @ptrCast([*][4]u8, self.texture.image.data.ptr)[0 .. self.texture.image.data.len / 4];
        pixels[index] = color;
        if (update)
            self.texture.update(pixi.state.gctx);
    }

    pub fn clear(self: *Layer, update: bool) void {
        var pixels = @ptrCast([*][4]u8, self.texture.image.data.ptr)[0 .. self.texture.image.data.len / 4];
        for (pixels) |*pixel| {
            pixel.* = .{ 0, 0, 0, 0 };
        }
        if (update)
            self.texture.update(pixi.state.gctx);
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
