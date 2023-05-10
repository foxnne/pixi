const std = @import("std");
const pixi = @import("root");
const History = @This();

pub const Action = enum { undo, redo };
pub const ChangeType = enum { pixels, origins };

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

    pixels: Pixels,
    origins: Origins,

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
        }
    }
};

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
            }
        } else equal = false;
    }

    if (equal) {
        change.deinit();
    } else try self.undo_stack.append(change);
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

    if (active_stack.items.len == 0) {
        return;
    }

    if (active_stack.popOrNull()) |change| {
        switch (change) {
            .pixels => |*pixels| {
                for (pixels.indices, 0..) |pixel_index, i| {
                    const color: [4]u8 = pixels.values[i];
                    var current_pixels = @ptrCast([*][4]u8, file.layers.items[pixels.layer].texture.image.data.ptr)[0 .. file.layers.items[pixels.layer].texture.image.data.len / 4];
                    pixels.values[i] = current_pixels[pixel_index];
                    current_pixels[pixel_index] = color;
                }
                file.layers.items[pixels.layer].texture.update(pixi.state.gctx);
            },
            .origins => |*origins| {
                for (origins.indices, 0..) |sprite_index, i| {
                    var origin_x = origins.values[i][0];
                    var origin_y = origins.values[i][1];
                    origins.values[i] = .{ file.sprites.items[sprite_index].origin_x, file.sprites.items[sprite_index].origin_y };
                    file.sprites.items[sprite_index].origin_x = origin_x;
                    file.sprites.items[sprite_index].origin_y = origin_y;
                }
            },
        }
        try other_stack.append(change);
    }
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
