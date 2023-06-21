const std = @import("std");
const pixi = @import("root");
const zgui = @import("zgui");
const History = @This();

pub const Action = enum { undo, redo };
pub const RestoreDelete = enum { restore, delete };
pub const ChangeType = enum {
    pixels,
    origins,
    animation,
    animation_restore_delete,
    layers_order,
    layer_restore_delete,
    layer_name,
    heightmap_restore_delete,
};

pub const Change = union(ChangeType) {
    pub const Pixels = struct {
        layer: i32,
        indices: []usize,
        values: [][4]u8,
    };

    pub const Origins = struct {
        indices: []usize,
        values: [][2]f32,
    };

    pub const Animation = struct {
        index: usize,
        name: [128:0]u8,
        fps: usize,
        start: usize,
        length: usize,
    };

    pub const AnimationRestoreDelete = struct {
        index: usize,
        action: RestoreDelete,
    };

    pub const LayersOrder = struct {
        order: []usize,
        selected: usize,
    };

    pub const LayerRestoreDelete = struct {
        index: usize,
        action: RestoreDelete,
    };
    pub const LayerName = struct {
        index: usize,
        name: [128:0]u8,
    };
    pub const HeightmapRestoreDelete = struct {
        action: RestoreDelete,
    };

    pixels: Pixels,
    origins: Origins,
    animation: Animation,
    animation_restore_delete: AnimationRestoreDelete,
    layers_order: LayersOrder,
    layer_restore_delete: LayerRestoreDelete,
    layer_name: LayerName,
    heightmap_restore_delete: HeightmapRestoreDelete,

    pub fn create(allocator: std.mem.Allocator, field: ChangeType, len: usize) !Change {
        return switch (field) {
            .pixels => .{
                .pixels = .{
                    .layer = 0,
                    .indices = try allocator.alloc(usize, len),
                    .values = try allocator.alloc([4]u8, len),
                },
            },
            .origins => .{
                .origins = .{
                    .indices = try allocator.alloc(usize, len),
                    .values = try allocator.alloc([2]f32, len),
                },
            },
            .animation => .{
                .animation = .{
                    .index = 0,
                    .name = undefined,
                    .fps = 1,
                    .start = 0,
                    .length = 1,
                },
            },
            .layers_order => .{ .layers_order = .{
                .order = try allocator.alloc(usize, len),
                .selected = 0,
            } },
            .layer_name => .{ .layer_name = .{
                .name = [_:0]u8{0} ** 128,
                .index = 0,
            } },
            else => error.NotSupported,
        };
    }

    pub fn deinit(self: Change) void {
        switch (self) {
            .pixels => |*pixels| {
                pixi.state.allocator.free(pixels.indices);
                pixi.state.allocator.free(pixels.values);
            },
            .origins => |*origins| {
                pixi.state.allocator.free(origins.indices);
                pixi.state.allocator.free(origins.values);
            },
            .layers_order => |*layers_order| {
                pixi.state.allocator.free(layers_order.order);
            },
            else => {},
        }
    }
};

bookmark: i32 = 0,
undo_stack: std.ArrayList(Change),
redo_stack: std.ArrayList(Change),

pub fn init(allocator: std.mem.Allocator) History {
    return .{
        .undo_stack = std.ArrayList(Change).init(allocator),
        .redo_stack = std.ArrayList(Change).init(allocator),
    };
}

pub fn append(self: *History, change: Change) !void {
    if (self.redo_stack.items.len > 0) {
        for (self.redo_stack.items) |*c| {
            c.deinit();
        }
        self.redo_stack.clearRetainingCapacity();
    }

    // Equality check, don't append if equal
    var equal: bool = self.undo_stack.items.len > 0;
    if (self.undo_stack.getLastOrNull()) |last| {
        const last_active_tag = std.meta.activeTag(last);
        const change_active_tag = std.meta.activeTag(change);

        if (last_active_tag == change_active_tag) {
            switch (last) {
                .origins => |origins| {
                    if (std.mem.eql(usize, origins.indices, change.origins.indices)) {
                        for (origins.values, 0..) |value, i| {
                            if (!std.mem.eql(f32, &value, &change.origins.values[i])) {
                                equal = false;
                                break;
                            }
                        }
                    } else {
                        equal = false;
                    }
                },
                .pixels => |pixels| {
                    equal = std.mem.eql(usize, pixels.indices, change.pixels.indices);
                    if (equal) {
                        for (pixels.values, 0..) |value, i| {
                            equal = std.mem.eql(u8, &value, &change.pixels.values[i]);
                            if (!equal) break;
                        }
                    }
                },
                .animation => |animation| {
                    equal = std.mem.eql(u8, &animation.name, &change.animation.name);
                    if (equal) {
                        equal = animation.index == change.animation.index;
                        if (equal) {
                            equal = animation.fps == change.animation.fps;
                            if (equal) {
                                equal = animation.start == change.animation.start;
                                if (equal) {
                                    equal = animation.length == change.animation.length;
                                }
                            }
                        }
                    }
                },
                .animation_restore_delete => {
                    equal = false;
                },
                .layers_order => {},
                .layer_restore_delete => {
                    equal = false;
                },
                .layer_name => {
                    equal = false;
                },
                .heightmap_restore_delete => {
                    equal = false;
                },
            }
        } else equal = false;
    }

    if (equal) {
        change.deinit();
    } else {
        try self.undo_stack.append(change);
        self.bookmark += 1;
    }
}

pub fn undoRedo(self: *History, file: *pixi.storage.Internal.Pixi, action: Action) !void {
    var active_stack = switch (action) {
        .undo => &self.undo_stack,
        .redo => &self.redo_stack,
    };

    var other_stack = switch (action) {
        .undo => &self.redo_stack,
        .redo => &self.undo_stack,
    };

    if (active_stack.items.len == 0) return;

    var change = active_stack.pop();

    switch (change) {
        .pixels => |*pixels| {
            var layer = if (pixels.layer < 0) &file.heightmap_layer.? else &file.layers.items[@intCast(usize, pixels.layer)];
            for (pixels.indices, 0..) |pixel_index, i| {
                const color: [4]u8 = pixels.values[i];
                var current_pixels = @ptrCast([*][4]u8, layer.texture.image.data.ptr)[0 .. layer.texture.image.data.len / 4];
                pixels.values[i] = current_pixels[pixel_index];
                current_pixels[pixel_index] = color;
                if (color[3] == 0 and pixels.layer >= 0) {
                    // Erasing a pixel on a layer, we also need to erase the heightmap
                    if (file.heightmap_layer) |heightmap_layer| {
                        var heightmap_pixels = @ptrCast([*][4]u8, heightmap_layer.texture.image.data.ptr)[0 .. heightmap_layer.texture.image.data.len / 4];
                        heightmap_pixels[pixel_index] = color;
                    }
                }
            }

            if (pixels.layer < 0) {
                pixi.state.tools.current = .heightmap;
            } else {
                pixi.state.tools.current = .pencil;
            }

            layer.texture.update(pixi.state.gctx);
            if (pixi.state.sidebar == .sprites)
                pixi.state.sidebar = .tools;
        },
        .origins => |*origins| {
            file.selected_sprites.clearAndFree();
            for (origins.indices, 0..) |sprite_index, i| {
                var origin_x = origins.values[i][0];
                var origin_y = origins.values[i][1];
                origins.values[i] = .{ file.sprites.items[sprite_index].origin_x, file.sprites.items[sprite_index].origin_y };
                file.sprites.items[sprite_index].origin_x = origin_x;
                file.sprites.items[sprite_index].origin_y = origin_y;
                try file.selected_sprites.append(sprite_index);
            }
            pixi.state.sidebar = .sprites;
        },
        .layers_order => |*layers_order| {
            var new_order = try pixi.state.allocator.alloc(usize, layers_order.order.len);
            for (file.layers.items, 0..) |layer, i| {
                new_order[i] = layer.id;
            }

            for (layers_order.order, 0..) |id, i| {
                if (file.layers.items[i].id == id) continue;

                // Save current layer
                const current_layer = file.layers.items[i];
                layers_order.order[i] = current_layer.id;

                // Make changes to the layers
                for (file.layers.items, 0..) |layer, layer_i| {
                    if (layer.id == layers_order.selected) {
                        file.selected_layer_index = layer_i;
                    }
                    if (layer.id == id) {
                        file.layers.items[i] = layer;
                        file.layers.items[layer_i] = current_layer;
                        continue;
                    }
                }
            }

            @memcpy(layers_order.order, new_order);
            pixi.state.allocator.free(new_order);
        },
        .layer_restore_delete => |*layer_restore_delete| {
            const a = layer_restore_delete.action;
            switch (a) {
                .restore => {
                    try file.layers.insert(layer_restore_delete.index, file.deleted_layers.pop());
                    layer_restore_delete.action = .delete;
                },
                .delete => {
                    try file.deleted_layers.append(file.layers.orderedRemove(layer_restore_delete.index));
                    layer_restore_delete.action = .restore;
                },
            }
        },
        .layer_name => |*layer_name| {
            var name = [_:0]u8{0} ** 128;
            @memcpy(name[0..layer_name.name.len], &layer_name.name);
            layer_name.name = [_:0]u8{0} ** 128;
            @memcpy(layer_name.name[0..file.layers.items[layer_name.index].name.len], file.layers.items[layer_name.index].name);
            pixi.state.allocator.free(file.layers.items[layer_name.index].name);
            file.layers.items[layer_name.index].name = try pixi.state.allocator.dupeZ(u8, &name);
        },
        .animation => |*animation| {
            // Set sprite names to generic
            const current_animation = file.animations.items[animation.index];
            var sprite_index = current_animation.start;
            while (sprite_index < current_animation.start + current_animation.length) : (sprite_index += 1) {
                pixi.state.allocator.free(file.sprites.items[sprite_index].name);
                file.sprites.items[sprite_index].name = std.fmt.allocPrintZ(pixi.state.allocator, "Sprite_{d}", .{sprite_index}) catch unreachable;
            }

            // Set sprite names to specific animation
            sprite_index = animation.start;
            var animation_index: usize = 0;
            while (sprite_index < animation.start + animation.length) : (sprite_index += 1) {
                pixi.state.allocator.free(file.sprites.items[sprite_index].name);
                file.sprites.items[sprite_index].name = std.fmt.allocPrintZ(pixi.state.allocator, "{s}_{d}", .{ std.mem.trimRight(u8, &animation.name, "\u{0}"), animation_index }) catch unreachable;
                animation_index += 1;
            }

            // Name
            var name = [_:0]u8{0} ** 128;
            @memcpy(name[0..animation.name.len], &animation.name);
            animation.name = [_:0]u8{0} ** 128;
            @memcpy(animation.name[0..file.animations.items[animation.index].name.len], file.animations.items[animation.index].name);
            pixi.state.allocator.free(file.animations.items[animation.index].name);
            file.animations.items[animation.index].name = try pixi.state.allocator.dupeZ(u8, std.mem.trimRight(u8, &name, "\u{0}"));
            // FPS
            const fps = animation.fps;
            animation.fps = file.animations.items[animation.index].fps;
            file.animations.items[animation.index].fps = fps;
            // Start
            const start = animation.start;
            animation.start = file.animations.items[animation.index].start;
            file.animations.items[animation.index].start = start;
            // Length
            const length = animation.length;
            animation.length = file.animations.items[animation.index].length;
            file.animations.items[animation.index].length = length;
        },
        .animation_restore_delete => |*animation_restore_delete| {
            const a = animation_restore_delete.action;
            switch (a) {
                .restore => {
                    const animation = file.deleted_animations.pop();
                    try file.animations.insert(animation_restore_delete.index, animation);
                    animation_restore_delete.action = .delete;

                    var i: usize = animation.start;
                    var animation_i: usize = 0;
                    while (i < animation.start + animation.length) : (i += 1) {
                        pixi.state.allocator.free(file.sprites.items[i].name);
                        file.sprites.items[i].name = std.fmt.allocPrintZ(pixi.state.allocator, "{s}_{d}", .{ animation.name[0..], animation_i }) catch unreachable;
                        animation_i += 1;
                    }
                },
                .delete => {
                    const animation = file.animations.orderedRemove(animation_restore_delete.index);
                    try file.deleted_animations.append(animation);
                    animation_restore_delete.action = .restore;

                    var i: usize = animation.start;
                    while (i < animation.start + animation.length) : (i += 1) {
                        pixi.state.allocator.free(file.sprites.items[i].name);
                        file.sprites.items[i].name = std.fmt.allocPrintZ(pixi.state.allocator, "Sprite_{d}", .{i}) catch unreachable;
                    }

                    if (file.selected_animation_index == animation_restore_delete.index)
                        file.selected_animation_index = 0;
                },
            }
        },
        .heightmap_restore_delete => |*heightmap_restore_delete| {
            const a = heightmap_restore_delete.action;
            switch (a) {
                .restore => {
                    file.heightmap_layer = file.deleted_heightmap_layers.pop();
                    heightmap_restore_delete.action = .delete;
                },
                .delete => {
                    try file.deleted_heightmap_layers.append(file.heightmap_layer.?);
                    file.heightmap_layer = null;
                    heightmap_restore_delete.action = .restore;
                    if (pixi.state.tools.current == .heightmap) {
                        pixi.state.tools.set(.pointer);
                    }
                },
            }
        },
        //else => {},
    }

    try other_stack.append(change);

    self.bookmark += switch (action) {
        .undo => -1,
        .redo => 1,
    };
}

pub fn clearAndFree(self: *History) void {
    for (self.undo_stack.items) |*u| {
        u.deinit();
    }
    for (self.redo_stack.items) |*r| {
        r.deinit();
    }
    self.undo_stack.clearAndFree();
    self.redo_stack.clearAndFree();
}

pub fn clearRetainingCapacity(self: *History) void {
    for (self.undo_stack.items) |*u| {
        u.deinit();
    }
    for (self.redo_stack.items) |*r| {
        r.deinit();
    }
    self.undo_stack.clearRetainingCapacity();
    self.redo_stack.clearRetainingCapacity();
}

pub fn deinit(self: *History) void {
    self.clearAndFree();
    self.undo_stack.deinit();
    self.redo_stack.deinit();
}
