const std = @import("std");
const pixi = @import("../pixi.zig");
const zgui = @import("zgui");
const History = @This();
const Core = @import("mach").Core;
const Editor = pixi.Editor;

pub const Action = enum { undo, redo };
pub const RestoreDelete = enum { restore, delete };
pub const ChangeType = enum {
    pixels,
    origins,
    animation_name,
    animation_frames,
    animation_settings,
    animation_order,
    animation_restore_delete,
    layers_order,
    layer_restore_delete,
    layer_name,
    layer_settings,
    heightmap_restore_delete,
};

pub const Change = union(ChangeType) {
    pub const Pixels = struct {
        layer_id: u64,
        indices: []usize,
        values: [][4]u8,
        temporary: bool = false,
    };

    pub const Origins = struct {
        indices: []usize,
        values: [][2]f32,
    };

    pub const AnimationName = struct {
        index: usize,
        name: []u8,
    };

    pub const AnimationSettings = struct {
        index: usize,
        fps: f32,
    };

    pub const AnimationOrder = struct {
        order: []u64,
        selected: usize,
    };

    pub const AnimationFrames = struct {
        index: usize,
        frames: []usize,
    };

    pub const AnimationRestoreDelete = struct {
        index: usize,
        action: RestoreDelete,
    };

    pub const LayersOrder = struct {
        order: []u64,
        selected: usize,
    };

    pub const LayerRestoreDelete = struct {
        index: usize,
        action: RestoreDelete,
    };
    pub const LayerName = struct {
        index: usize,
        name: []u8,
    };
    pub const LayerSettings = struct {
        index: usize,
        visible: bool,
        collapse: bool,
    };
    pub const HeightmapRestoreDelete = struct {
        action: RestoreDelete,
    };

    pixels: Pixels,
    origins: Origins,
    animation_name: AnimationName,
    animation_frames: AnimationFrames,
    animation_settings: AnimationSettings,
    animation_order: AnimationOrder,
    animation_restore_delete: AnimationRestoreDelete,
    layers_order: LayersOrder,
    layer_restore_delete: LayerRestoreDelete,
    layer_name: LayerName,
    layer_settings: LayerSettings,
    heightmap_restore_delete: HeightmapRestoreDelete,

    pub fn create(allocator: std.mem.Allocator, field: ChangeType, len: usize) !Change {
        return switch (field) {
            .pixels => .{
                .pixels = .{
                    .layer_id = 0,
                    .indices = try allocator.alloc(usize, len),
                    .values = try allocator.alloc([4]u8, len),
                    .temporary = false,
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
            .layer_name => .{ .animation_name = .{
                .name = [_:0]u8{0} ** Editor.Constants.max_name_len,
                .index = 0,
            } },
            else => error.NotSupported,
        };
    }

    pub fn deinit(self: Change) void {
        switch (self) {
            .pixels => |*pixels| {
                pixi.app.allocator.free(pixels.indices);
                pixi.app.allocator.free(pixels.values);
            },
            .origins => |*origins| {
                pixi.app.allocator.free(origins.indices);
                pixi.app.allocator.free(origins.values);
            },
            .layers_order => |*layers_order| {
                pixi.app.allocator.free(layers_order.order);
            },
            else => {},
        }
    }
};

bookmark: i32 = 0,
undo_stack: std.array_list.Managed(Change),
redo_stack: std.array_list.Managed(Change),

pub fn init(allocator: std.mem.Allocator) History {
    return .{
        .undo_stack = std.array_list.Managed(Change).init(allocator),
        .redo_stack = std.array_list.Managed(Change).init(allocator),
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
                    equal = pixels.layer_id == change.pixels.layer_id;
                    if (equal) {
                        equal = std.mem.eql(usize, pixels.indices, change.pixels.indices);
                    }
                    if (equal) {
                        for (pixels.values, 0..) |value, i| {
                            equal = std.mem.eql(u8, &value, &change.pixels.values[i]);
                            if (!equal) break;
                        }
                    }
                },
                .animation_name => {
                    equal = false;
                },
                .animation_frames => {
                    equal = false;
                },
                .animation_settings => {
                    equal = false;
                },
                .animation_order => {
                    equal = false;
                },
                .animation_restore_delete => {
                    equal = false;
                },
                .layers_order => {
                    equal = false;
                },
                .layer_restore_delete => {
                    equal = false;
                },
                .layer_name => {
                    equal = false;
                },
                .layer_settings => {
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

// Handling cases in this function details how an undo/redo action works, and must be symmetrical.
// This means that `change` needs to be modified to contain the active state prior to changing the active state
pub fn undoRedo(self: *History, file: *pixi.Internal.File, action: Action) !void {
    var active_stack = switch (action) {
        .undo => &self.undo_stack,
        .redo => &self.redo_stack,
    };

    var other_stack = switch (action) {
        .undo => &self.redo_stack,
        .redo => &self.undo_stack,
    };

    if (active_stack.items.len == 0) return;

    var temporary: bool = false;

    // Modify this change before its put into the other stack.
    var change = active_stack.pop().?;

    switch (change) {
        .pixels => |*pixels| {
            if (pixels.temporary) temporary = true;

            const layer_index = for (file.layers.slice().items(.id), 0..) |layer_id, i| {
                if (layer_id == pixels.layer_id) break i;
            } else 0;

            var layer = file.layers.slice().get(layer_index);

            for (pixels.indices, 0..) |pixel_index, i| {
                std.mem.swap([4]u8, &pixels.values[i], &layer.pixels()[pixel_index]);
            }

            layer.invalidate();
            file.selected_layer_index = layer_index;
        },
        .origins => |*origins| {
            //file.editor.selected_sprites.clearAndFree();
            for (origins.indices, 0..) |sprite_index, i| {
                const origin = origins.values[i];
                origins.values[i] = file.sprites.items(.origin)[sprite_index];
                file.sprites.items(.origin)[sprite_index] = origin;

                //try file.editor.selected_sprites.append(sprite_index);
            }
            pixi.editor.explorer.pane = .sprites;
        },
        .layers_order => |*layers_order| {
            var new_order = try pixi.app.allocator.alloc(usize, layers_order.order.len);
            for (0..file.layers.len) |layer_index| {
                new_order[layer_index] = file.layers.items(.id)[layer_index];
            }

            const slice = file.layers.slice();

            for (layers_order.order, 0..) |id, i| {
                if (slice.items(.id)[i] == id) continue;

                // Save current layer
                const current_layer = slice.get(i);
                layers_order.order[i] = current_layer.id;

                // Make changes to the layers
                var other_layer_index: usize = 0;
                while (other_layer_index < file.layers.len) : (other_layer_index += 1) {
                    const layer = slice.get(other_layer_index);
                    if (layer.id == layers_order.selected) {
                        file.selected_layer_index = other_layer_index;
                    }
                    if (layer.id == id) {
                        file.layers.set(i, layer);
                        file.layers.set(other_layer_index, current_layer);
                        continue;
                    }
                }
            }

            @memcpy(layers_order.order, new_order);
            pixi.app.allocator.free(new_order);
        },
        .layer_restore_delete => |*layer_restore_delete| {
            const a = layer_restore_delete.action;
            switch (a) {
                .restore => {
                    try file.layers.insert(pixi.app.allocator, layer_restore_delete.index, file.deleted_layers.pop().?);
                    layer_restore_delete.action = .delete;
                },
                .delete => {
                    try file.deleted_layers.append(pixi.app.allocator, file.layers.slice().get(layer_restore_delete.index));
                    file.layers.orderedRemove(layer_restore_delete.index);
                    layer_restore_delete.action = .restore;
                },
            }
            pixi.editor.explorer.pane = .tools;
        },
        .layer_name => |*layer_name| {
            const name = try pixi.app.allocator.dupe(u8, file.layers.items(.name)[layer_name.index]);
            pixi.app.allocator.free(file.layers.items(.name)[layer_name.index]);
            file.layers.items(.name)[layer_name.index] = try pixi.app.allocator.dupe(u8, layer_name.name);
            layer_name.name = name;
            pixi.editor.explorer.pane = .tools;
        },
        .layer_settings => |*layer_settings| {
            const visible = file.layers.items(.visible)[layer_settings.index];
            const collapse = file.layers.items(.collapse)[layer_settings.index];
            file.layers.items(.visible)[layer_settings.index] = layer_settings.visible;
            file.layers.items(.collapse)[layer_settings.index] = layer_settings.collapse;
            layer_settings.visible = visible;
            layer_settings.collapse = collapse;
            pixi.editor.explorer.pane = .tools;
        },
        .animation_restore_delete => |*animation_restore_delete| {
            const a = animation_restore_delete.action;
            switch (a) {
                .restore => {
                    const animation = file.deleted_animations.pop().?;
                    try file.animations.insert(pixi.app.allocator, animation_restore_delete.index, animation);
                    animation_restore_delete.action = .delete;
                },
                .delete => {
                    const animation = file.animations.slice().get(animation_restore_delete.index);
                    file.animations.orderedRemove(animation_restore_delete.index);
                    try file.deleted_animations.append(pixi.app.allocator, animation);
                    animation_restore_delete.action = .restore;

                    // if (file.sele == animation_restore_delete.index)
                    //     file.selected_animation_index = 0;
                },
            }
            pixi.editor.explorer.pane = .sprites;
        },
        .animation_name => |*animation_name| {
            const name = try pixi.app.allocator.dupe(u8, file.animations.items(.name)[animation_name.index]);
            pixi.app.allocator.free(file.animations.items(.name)[animation_name.index]);
            file.animations.items(.name)[animation_name.index] = try pixi.app.allocator.dupe(u8, animation_name.name);
            animation_name.name = name;
            pixi.editor.explorer.pane = .sprites;
        },
        .animation_settings => |*animation_settings| {
            const fps = file.animations.items(.fps)[animation_settings.index];
            file.animations.items(.fps)[animation_settings.index] = animation_settings.fps;
            animation_settings.fps = fps;
            pixi.editor.explorer.pane = .sprites;
        },
        .animation_order => |*animation_order| {
            var new_order = try pixi.app.allocator.alloc(usize, animation_order.order.len);
            for (0..file.animations.len) |anim_index| {
                new_order[anim_index] = file.animations.items(.id)[anim_index];
            }

            const slice = file.animations.slice();

            for (animation_order.order, 0..) |id, i| {
                if (slice.items(.id)[i] == id) continue;

                // Save current animation
                const current_animation = slice.get(i);
                animation_order.order[i] = current_animation.id;

                // Make changes to the animations
                var other_animation_index: usize = 0;
                while (other_animation_index < file.animations.len) : (other_animation_index += 1) {
                    const animation = slice.get(other_animation_index);
                    if (animation.id == animation_order.selected) {
                        file.selected_animation_index = other_animation_index;
                    }
                    if (animation.id == id) {
                        file.animations.set(i, animation);
                        file.animations.set(other_animation_index, current_animation);
                        continue;
                    }
                }
            }

            @memcpy(animation_order.order, new_order);
            pixi.app.allocator.free(new_order);
        },
        .animation_frames => |*animation_frames| {
            const frames = try pixi.app.allocator.alloc(usize, animation_frames.frames.len);
            @memcpy(frames, animation_frames.frames);
            animation_frames.frames = try pixi.app.allocator.alloc(usize, file.animations.items(.frames)[animation_frames.index].len);
            @memcpy(animation_frames.frames, file.animations.items(.frames)[animation_frames.index]);
            pixi.app.allocator.free(file.animations.items(.frames)[animation_frames.index]);
            file.animations.items(.frames)[animation_frames.index] = frames;
            pixi.editor.explorer.pane = .sprites;
        },
        // .heightmap_restore_delete => |*heightmap_restore_delete| {
        //     const a = heightmap_restore_delete.action;
        //     switch (a) {
        //         .restore => {
        //             file.heightmap.layer = file.deleted_heightmap_layers.pop();
        //             heightmap_restore_delete.action = .delete;
        //         },
        //         .delete => {
        //             try file.deleted_heightmap_layers.append(pixi.app.allocator, file.heightmap.layer.?);
        //             file.heightmap.layer = null;
        //             heightmap_restore_delete.action = .restore;
        //             if (pixi.editor.tools.current == .heightmap) {
        //                 pixi.editor.tools.set(.pointer);
        //             }
        //         },
        //     }
        // },
        else => {},
    }

    if (!temporary) {
        try other_stack.append(change);
    } else change.deinit();

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
