const std = @import("std");
const pixi = @import("../pixi.zig");
//const zstbi = @import("zstbi");
const zip = @import("zip");
const dvui = @import("dvui");

const Editor = pixi.Editor;

const File = @This();

const Texture = @import("Texture.zig");
const Layer = @import("Layer.zig");
const Sprite = @import("Sprite.zig");
const Animation = @import("Animation.zig");

id: u64,
canvas_id: dvui.WidgetId = undefined,
path: []const u8,
width: u32,
height: u32,
tile_width: u32,
tile_height: u32,
canvas: pixi.dvui.FileWidget.FileWidgetData = .{},
layers: std.MultiArrayList(Layer),
sprites: std.MultiArrayList(Sprite),
animations: std.MultiArrayList(Animation),
deleted_layers: std.MultiArrayList(Layer),
deleted_heightmap_layers: std.MultiArrayList(Layer),
deleted_animations: std.MultiArrayList(Animation),
selected_layer_index: usize = 0,
selected_sprite_index: usize = 0,
selected_sprites: std.ArrayList(usize),
temporary_layer: Layer,
selection_layer: Layer,
heightmap: Heightmap = .{},
history: History,
buffers: Buffers,
counter: u64 = 0,
saving: bool = false,
grouping: u8 = 0,

pub const ScrollRequest = struct {
    from: f32,
    to: f32,
    elapsed: f32 = 0.0,
    state: AnimationState,
};

pub const TransformTexture = struct {
    vertices: [4]TransformVertex,
    pivot: ?TransformVertex = null,
    control: ?TransformControl = null,
    action: TransformAction = .none,
    rotation: f32 = 0.0,
    rotation_grip_height: f32 = 8.0,
    texture: pixi.gfx.Texture,
    confirm: bool = false,
    pivot_offset_angle: f32 = 0.0,
    temporary: bool = false,
    keyframe_parent_id: ?u32 = null,
};

pub const TransformAction = enum {
    none,
    pan,
    rotate,
    move_pivot,
    move_vertex,
};

pub const TransformVertex = struct {
    position: [2]f32,
};

pub const TransformControl = struct {
    index: usize,
    mode: TransformMode,
};

pub const TransformMode = enum {
    locked_aspect,
    free_aspect,
    free,
};

//pub const FlipbookView = enum { canvas, timeline };

pub const AnimationState = enum { pause, play };
pub const Canvas = enum { primary, flipbook };

pub const History = @import("History.zig");
pub const Buffers = @import("Buffers.zig");

pub const Heightmap = struct {
    visible: bool = false,
    layer: ?Layer = null,

    pub fn enable(self: *Heightmap) void {
        if (self.layer != null) {
            self.visible = true;
        }
        // } else {
        //     pixi.editor.popups.heightmap = true;
        // }
    }

    pub fn disable(self: *Heightmap) void {
        self.visible = false;
        if (pixi.editor.tools.current == .heightmap) {
            pixi.editor.tools.swap();
        }
    }

    pub fn toggle(self: *Heightmap) void {
        if (self.visible) self.disable() else self.enable();
    }
};

pub fn load(path: []const u8) !?pixi.Internal.File {
    if (!std.mem.eql(u8, std.fs.path.extension(path[0..path.len]), ".pixi"))
        return null;

    blk_open: {
        const null_terminated_path = try dvui.currentWindow().arena().dupeZ(u8, path);

        const pixi_file = zip.zip_open(null_terminated_path.ptr, 0, 'r') orelse break :blk_open;
        defer zip.zip_close(pixi_file);

        var buf: ?*anyopaque = null;
        var size: u64 = 0;
        _ = zip.zip_entry_open(pixi_file, "pixidata.json");
        _ = zip.zip_entry_read(pixi_file, &buf, &size);
        _ = zip.zip_entry_close(pixi_file);

        const content: []const u8 = @as([*]const u8, @ptrCast(buf))[0..size];

        const options = std.json.ParseOptions{
            .duplicate_field_behavior = .use_first,
            .ignore_unknown_fields = true,
        };

        var parsed = std.json.parseFromSlice(pixi.File, pixi.app.allocator, content, options) catch return error.FileLoadError;
        defer parsed.deinit();

        const ext = parsed.value;

        var internal: pixi.Internal.File = .{
            .id = pixi.editor.counter,
            .path = try pixi.app.allocator.dupe(u8, path),
            .width = ext.width,
            .height = ext.height,
            .tile_width = ext.tile_width,
            .tile_height = ext.tile_height,
            .layers = .{},
            .deleted_layers = .{},
            .deleted_heightmap_layers = .{},
            .sprites = .{},
            .selected_sprites = .init(pixi.app.allocator),
            .animations = .{},
            .deleted_animations = .{},
            .history = pixi.Internal.File.History.init(pixi.app.allocator),
            .buffers = pixi.Internal.File.Buffers.init(pixi.app.allocator),
            .temporary_layer = undefined,
            .selection_layer = undefined,
        };

        internal.temporary_layer = try .init(internal.newID(), "Temporary", .{ internal.width, internal.height }, .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr);

        for (ext.layers) |l| {
            const layer_image_name = std.fmt.allocPrintZ(dvui.currentWindow().arena(), "{s}.png", .{l.name}) catch "Memory Allocation Failed";

            var img_buf: ?*anyopaque = null;
            var img_len: usize = 0;

            if (zip.zip_entry_open(pixi_file, layer_image_name.ptr) == 0) {
                _ = zip.zip_entry_read(pixi_file, &img_buf, &img_len);
                const data = img_buf orelse continue;

                const new_layer: pixi.Internal.Layer = try .fromImageFile(
                    internal.newID(),
                    l.name,
                    @as([*]u8, @ptrCast(data))[0..img_len],
                    .ptr,
                );
                internal.layers.append(pixi.app.allocator, new_layer) catch return error.FileLoadError;
            }

            _ = zip.zip_entry_close(pixi_file);
        }
        _ = zip.zip_entry_close(pixi_file);

        for (ext.sprites) |sprite| {
            internal.sprites.append(pixi.app.allocator, .{
                .origin = .{ @floatFromInt(sprite.origin[0]), @floatFromInt(sprite.origin[1]) },
            }) catch return error.FileLoadError;
        }

        for (ext.animations) |animation| {
            internal.animations.append(pixi.app.allocator, .{
                .name = try pixi.app.allocator.dupeZ(u8, animation.name),
                .start = animation.start,
                .length = animation.length,
                .fps = animation.fps,
            }) catch return error.FileLoadError;
        }
        pixi.editor.counter += 1;
        return internal;
    }

    return error.FileLoadError;
}

pub fn deinit(file: *File) void {
    file.history.deinit();
    file.buffers.deinit();

    for (file.layers.items(.name)) |name| {
        pixi.app.allocator.free(name);
    }

    file.layers.deinit(pixi.app.allocator);
    file.deleted_layers.deinit(pixi.app.allocator);
    file.deleted_heightmap_layers.deinit(pixi.app.allocator);
    file.sprites.deinit(pixi.app.allocator);
    file.selected_sprites.deinit();
    file.animations.deinit(pixi.app.allocator);
    file.deleted_animations.deinit(pixi.app.allocator);
    pixi.app.allocator.free(file.path);
}

pub fn dirty(self: File) bool {
    return self.history.bookmark != 0;
}

pub fn newID(file: *File) u64 {
    file.counter += 1;
    return file.counter;
}

pub const DrawLayer = enum {
    temporary,
    selected,
};

/// Draws a point on the selected (the point will be added to the stroke buffer) or temporary layer
/// If to_change is true, the point will be added to the stroke buffer and then the history will be appended
/// If invalidate is true, the layer will be invalidated
pub fn drawPoint(file: *File, point: dvui.Point, color: [4]u8, layer: DrawLayer, draw_options: DrawOptions) void {
    var active_layer: Layer = switch (layer) {
        .temporary => file.temporary_layer,
        .selected => file.layers.get(file.selected_layer_index),
    };

    const column = @as(u32, @intFromFloat(point.x)) / file.tile_width;
    const row = @as(u32, @intFromFloat(point.y)) / file.tile_height;

    const min_x: f32 = @as(f32, @floatFromInt(column)) * @as(f32, @floatFromInt(file.tile_width));
    const min_y: f32 = @as(f32, @floatFromInt(row)) * @as(f32, @floatFromInt(file.tile_height));

    const max_x: f32 = min_x + @as(f32, @floatFromInt(file.tile_width));
    const max_y: f32 = min_y + @as(f32, @floatFromInt(file.tile_height));

    if (pixi.editor.tools.stroke_size < 10) {
        const size: usize = @intCast(pixi.editor.tools.stroke_size);

        for (0..(size * size)) |index| {
            if (active_layer.getIndexShapeOffset(point, index)) |result| {
                if (draw_options.constrain_to_tile) {
                    if (result.point.x < min_x or result.point.x >= max_x or result.point.y < min_y or result.point.y >= max_y) {
                        continue;
                    }
                }

                if (layer == .selected) {
                    file.buffers.stroke.append(result.index, result.color) catch {
                        std.log.err("Failed to append to stroke buffer", .{});
                    };
                }
                active_layer.pixels()[result.index] = color;
            }
        }
    } else {
        var iter = pixi.editor.tools.stroke.iterator(.{ .kind = .set, .direction = .forward });
        while (iter.next()) |i| {
            const offset = pixi.editor.tools.offset_table[i];
            const new_point: dvui.Point = .{ .x = point.x + offset[0], .y = point.y + offset[1] };

            if (draw_options.constrain_to_tile) {
                if (new_point.x < min_x or new_point.x >= max_x or new_point.y < min_y or new_point.y >= max_y) {
                    continue;
                }
            }

            if (active_layer.getPixelIndex(new_point)) |index| {
                if (layer == .selected) {
                    file.buffers.stroke.append(index, active_layer.pixels()[index]) catch {
                        std.log.err("Failed to append to stroke buffer", .{});
                    };
                }

                active_layer.pixels()[index] = color;
            }
        }
    }

    if (draw_options.invalidate) {
        active_layer.invalidate();
    }

    if (draw_options.to_change and layer == .selected) {
        const change_opt = file.buffers.stroke.toChange(active_layer.id) catch null;
        if (change_opt) |change| {
            file.history.append(change) catch {
                std.log.err("Failed to append to history", .{});
            };
        }
    }
}

pub const DrawOptions = struct {
    invalidate: bool = false,
    to_change: bool = false,
    constrain_to_tile: bool = false,
};

pub fn drawLine(file: *File, point1: dvui.Point, point2: dvui.Point, color: [4]u8, layer: DrawLayer, draw_options: DrawOptions) void {
    var active_layer: Layer = switch (layer) {
        .temporary => file.temporary_layer,
        .selected => file.layers.get(file.selected_layer_index),
    };

    const column = @as(u32, @intFromFloat(point2.x)) / file.tile_width;
    const row = @as(u32, @intFromFloat(point2.y)) / file.tile_height;

    const min_x: f32 = @as(f32, @floatFromInt(column)) * @as(f32, @floatFromInt(file.tile_width));
    const min_y: f32 = @as(f32, @floatFromInt(row)) * @as(f32, @floatFromInt(file.tile_height));

    const max_x: f32 = min_x + @as(f32, @floatFromInt(file.tile_width));
    const max_y: f32 = min_y + @as(f32, @floatFromInt(file.tile_height));

    const diff = point2.diff(point1).normalize().scale(4, dvui.Point);
    const stroke_size: usize = @intCast(pixi.Editor.Tools.max_brush_size);

    const center: dvui.Point = .{ .x = @floor(pixi.Editor.Tools.max_brush_size_float / 2), .y = @floor(pixi.Editor.Tools.max_brush_size_float / 2) };
    var mask = pixi.editor.tools.stroke;

    if (pixi.editor.tools.stroke_size > pixi.Editor.Tools.min_full_stroke_size) {
        for (0..(stroke_size * stroke_size)) |index| {
            if (pixi.editor.tools.getIndexShapeOffset(center.diff(diff), index)) |i| {
                mask.unset(i);
            }
        }
    }

    if (pixi.algorithms.brezenham.process(point1, point2) catch null) |points| {
        for (points, 0..) |point, point_i| {
            if (pixi.editor.tools.stroke_size < pixi.Editor.Tools.min_full_stroke_size) {
                drawPoint(file, point, color, layer, .{});
            } else {
                var stroke = if (point_i == 0) pixi.editor.tools.stroke else mask;

                var iter = stroke.iterator(.{ .kind = .set, .direction = .forward });
                while (iter.next()) |i| {
                    const offset = pixi.editor.tools.offset_table[i];
                    const new_point: dvui.Point = .{ .x = point.x + offset[0], .y = point.y + offset[1] };

                    if (draw_options.constrain_to_tile) {
                        if (new_point.x < min_x or new_point.x >= max_x or new_point.y < min_y or new_point.y >= max_y) {
                            continue;
                        }
                    }

                    if (active_layer.getPixelIndex(new_point)) |index| {
                        if (layer == .selected) {
                            file.buffers.stroke.append(index, active_layer.pixels()[index]) catch {
                                std.log.err("Failed to append to stroke buffer", .{});
                            };
                        }

                        active_layer.pixels()[index] = color;
                    }
                }
            }
        }

        if (draw_options.invalidate) {
            active_layer.invalidate();
        }

        if (draw_options.to_change and layer == .selected) {
            const change_opt = file.buffers.stroke.toChange(active_layer.id) catch null;
            if (change_opt) |change| {
                file.history.append(change) catch {
                    std.log.err("Failed to append to history", .{});
                };
            }
        }
    }
}

pub fn undo(self: *File) !void {
    return self.history.undoRedo(self, .undo);
}

pub fn redo(self: *File) !void {
    return self.history.undoRedo(self, .redo);
}

pub fn save(self: *File, window: *dvui.Window) !void {
    if (self.saving) return;
    self.saving = true;
    self.history.bookmark = 0;
    var ext = try self.external(pixi.app.allocator);
    defer ext.deinit(pixi.app.allocator);
    const null_terminated_path = try pixi.editor.arena.allocator().dupeZ(u8, self.path);

    const zip_file = zip.zip_open(null_terminated_path.ptr, zip.ZIP_DEFAULT_COMPRESSION_LEVEL, 'w');

    if (zip_file) |z| {
        var json = std.ArrayList(u8).init(pixi.app.allocator);
        const out_stream = json.writer();
        const options = std.json.StringifyOptions{};

        try std.json.stringify(ext, options, out_stream);

        const json_output = try json.toOwnedSlice();
        defer pixi.app.allocator.free(json_output);

        _ = zip.zip_entry_open(z, "pixidata.json");
        _ = zip.zip_entry_write(z, json_output.ptr, json_output.len);
        _ = zip.zip_entry_close(z);

        var index: usize = 0;
        while (index < self.layers.slice().len) : (index += 1) {
            const layer = self.layers.slice().get(index);

            const image_name = try std.fmt.allocPrintZ(pixi.editor.arena.allocator(), "{s}.png", .{layer.name});
            _ = zip.zip_entry_open(z, @as([*c]const u8, @ptrCast(image_name)));

            try layer.writePngToFn(z);

            //try self.layers.items(.texture)[index].stbi_image().writeToFn(write, z, .png);
            _ = zip.zip_entry_close(z);
        }

        const id_mutex = dvui.toastAdd(window, @src(), 0, self.canvas_id, pixi.dvui.toastDisplay, 2_000_000);
        const id = id_mutex.id;
        const message = std.fmt.allocPrint(window.arena(), "Saved {s}", .{std.fs.path.basename(self.path)}) catch "Saved file";
        dvui.dataSetSlice(window, id, "_message", message);
        id_mutex.mutex.unlock();

        // if (self.heightmap.layer) |*working_layer| {
        //     const layer_name = try std.fmt.allocPrintZ(pixi.editor.arena.allocator(), "{s}.png", .{working_layer.name});
        //     _ = zip.zip_entry_open(z, @as([*c]const u8, @ptrCast(layer_name)));
        //     try working_layer.texture.stbi_image().writeToFn(write, z, .png);
        //     _ = zip.zip_entry_close(z);
        // }

        zip.zip_close(z);
    }

    self.saving = false;
}

pub fn saveAsync(self: *File) !void {
    //if (!self.dirty()) return;
    const thread = try std.Thread.spawn(.{}, save, .{ self, dvui.currentWindow() });
    thread.detach();
}

pub fn external(self: File, allocator: std.mem.Allocator) !pixi.File {
    const layers = try allocator.alloc(pixi.Layer, self.layers.slice().len);
    const sprites = try allocator.alloc(pixi.Sprite, self.sprites.slice().len);
    const animations = try allocator.alloc(pixi.Animation, self.animations.slice().len);

    for (layers, 0..) |*working_layer, i| {
        working_layer.name = try allocator.dupe(u8, self.layers.items(.name)[i]);
        working_layer.visible = self.layers.items(.visible)[i];
        working_layer.collapse = self.layers.items(.collapse)[i];
    }

    for (sprites, 0..) |*sprite, i| {
        sprite.origin = .{ @intFromFloat(@round(self.sprites.items(.origin)[i][0])), @intFromFloat(@round(self.sprites.items(.origin)[i][1])) };
    }

    for (animations, 0..) |*animation, i| {
        animation.name = try allocator.dupe(u8, self.animations.items(.name)[i]);
        animation.fps = self.animations.items(.fps)[i];
        animation.start = self.animations.items(.start)[i];
        animation.length = self.animations.items(.length)[i];
    }

    return .{
        .version = pixi.version,
        .width = self.width,
        .height = self.height,
        .tile_width = self.tile_width,
        .tile_height = self.tile_height,
        .layers = layers,
        .sprites = sprites,
        .animations = animations,
    };
}
