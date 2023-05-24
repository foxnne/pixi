const std = @import("std");
const pixi = @import("root");
const History = @This();

pub const Action = enum { undo, redo };
pub const LayerAction = enum { restore, delete };
pub const ChangeType = enum {
    pixels,
    origins,
    animation,
    layers_order,
    layer_restore_delete,
    layer_name,
};

pub const Change = union(ChangeType) {
    pub const Pixels = struct {
        layer: usize,
        indices: []usize,
        values: [][4]u8,
    };

    pub const Origins = struct {
        indices: []usize,
        values: [][2]f32,
    };

    pub const Animation = struct {
        index: usize,
        name: [:0]const u8,
        fps: usize,
        start: usize,
        length: usize,
    };

    pub const LayersOrder = struct {
        order: []usize,
        selected: usize,
    };

    pub const LayerRestoreDelete = struct {
        action: LayerAction,
        index: usize,
    };
    pub const LayerName = struct {
        name: [128:0]u8,
        index: usize,
    };

    pixels: Pixels,
    origins: Origins,
    animation: Animation,
    layers_order: LayersOrder,
    layer_restore_delete: LayerRestoreDelete,
    layer_name: LayerName,

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
            .animation => |*animation| {
                pixi.state.allocator.free(animation.name);
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
                    equal = std.mem.eql(u8, animation.name, change.animation.name);
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
                .layers_order => {},
                .layer_restore_delete => {
                    equal = false;
                },
                .layer_name => {
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
            for (pixels.indices, 0..) |pixel_index, i| {
                const color: [4]u8 = pixels.values[i];
                var current_pixels = @ptrCast([*][4]u8, file.layers.items[pixels.layer].texture.image.data.ptr)[0 .. file.layers.items[pixels.layer].texture.image.data.len / 4];
                pixels.values[i] = current_pixels[pixel_index];
                current_pixels[pixel_index] = color;
            }
            file.layers.items[pixels.layer].texture.update(pixi.state.gctx);
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
        else => {},
    }

    try other_stack.append(change);

    self.bookmark += switch (action) {
        .undo => -1,
        .redo => 1,
    };

    file.dirty = self.bookmark != 0;
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
