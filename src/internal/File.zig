const std = @import("std");
const pixi = @import("../pixi.zig");
const zip = @import("zip");
const dvui = @import("dvui");

const Editor = pixi.Editor;

const File = @This();

const Texture = @import("Texture.zig");
const Layer = @import("Layer.zig");
const Sprite = @import("Sprite.zig");
const Animation = @import("Animation.zig");

id: u64,
path: []const u8,
width: u32,
height: u32,
tile_width: u32 = 0,
tile_height: u32 = 0,

layers: std.MultiArrayList(Layer) = .{},
deleted_layers: std.MultiArrayList(Layer) = .{},

sprites: std.MultiArrayList(Sprite) = .{},
selected_sprites: std.DynamicBitSet,

animations: std.MultiArrayList(Animation) = .{},
deleted_animations: std.MultiArrayList(Animation) = .{},

selected_layer_index: usize = 0,

temporary_layer: Layer,
selection_layer: Layer,
checkerboard: dvui.ImageSource,

history: History,
buffers: Buffers,
counter: u64 = 0,
saving: bool = false,
grouping: u64 = 0,

/// File-specific editor data
editor: EditorData = .{},

pub const EditorData = struct {
    canvas: pixi.dvui.CanvasWidget = .{},
    layers_scroll_info: dvui.ScrollInfo = .{},
    transform: ?Transform = null,
};

pub const ScrollRequest = struct {
    from: f32,
    to: f32,
    elapsed: f32 = 0.0,
    state: AnimationState,
};

pub const Transform = struct {
    data_points: [5]dvui.Point,
    active_data_point: ?usize = null,
    rotation: f32 = 0.0,
    source: dvui.ImageSource,
};

pub const TransformAction = enum {
    none,
    pan,
    rotate,
    move_pivot,
    move_vertex,
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

pub const AnimationState = enum { pause, play };
pub const Canvas = enum { primary, flipbook };

pub const History = @import("History.zig");
pub const Buffers = @import("Buffers.zig");

pub fn load(path: []const u8) !?pixi.Internal.File {
    if (!std.mem.eql(u8, std.fs.path.extension(path[0..path.len]), ".pixi"))
        return null;

    const null_terminated_path = try dvui.currentWindow().arena().dupeZ(u8, path);

    zip_open: {
        const pixi_file = zip.zip_open(null_terminated_path.ptr, 0, 'r') orelse break :zip_open;
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
            .id = pixi.editor.newFileID(),
            .path = try pixi.app.allocator.dupe(u8, path),
            .width = ext.width,
            .height = ext.height,
            .tile_width = ext.tile_width,
            .tile_height = ext.tile_height,
            .history = pixi.Internal.File.History.init(pixi.app.allocator),
            .buffers = pixi.Internal.File.Buffers.init(pixi.app.allocator),
            .checkerboard = pixi.image.init(
                ext.tile_width * 2,
                ext.tile_height * 2,
                .{ .r = 0, .g = 0, .b = 0, .a = 0 },
                .ptr,
            ) catch return error.LayerCreateError,
            .temporary_layer = undefined,
            .selection_layer = undefined,
            .selected_sprites = undefined,
        };

        const checker_color_1: [4]u8 = .{ 255, 255, 255, 255 };
        const checker_color_2: [4]u8 = .{ 175, 175, 175, 255 };

        if (@mod(internal.width, 2) == 0) {
            // width is even
            for (pixi.image.pixels(internal.checkerboard), 0..) |*pixel, i| {
                const checkerboard_width = internal.tile_width * 2;
                // Calculate which pixel row we are on
                const row = @divTrunc(i, checkerboard_width);

                if (@mod(row, 2) == 0) {
                    if (@mod(i, 2) == 0) {
                        pixel.* = checker_color_1;
                    } else {
                        pixel.* = checker_color_2;
                    }
                } else {
                    if (@mod(i, 2) != 0) {
                        pixel.* = checker_color_1;
                    } else {
                        pixel.* = checker_color_2;
                    }
                }
            }
        } else {
            // width is odd
            for (pixi.image.pixels(internal.checkerboard), 0..) |*pixel, i| {
                if (@mod(i, 2) == 0) {
                    pixel.* = checker_color_1;
                } else {
                    pixel.* = checker_color_2;
                }
            }
        }

        dvui.textureInvalidateCache(internal.checkerboard.hash());

        // Initialize layers and selected sprites
        internal.temporary_layer = try .init(internal.newID(), "Temporary", internal.width, internal.height, .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .always);
        internal.selection_layer = try .init(internal.newID(), "Selection", internal.width, internal.height, .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr);
        internal.selected_sprites = try std.DynamicBitSet.initEmpty(pixi.app.allocator, internal.spriteCount());

        var set_layer_index: bool = false;

        for (ext.layers, 0..) |l, i| {
            const layer_image_name = std.fmt.allocPrintZ(dvui.currentWindow().arena(), "{s}.layer", .{l.name}) catch "Memory Allocation Failed";
            const png_image_name = std.fmt.allocPrintZ(dvui.currentWindow().arena(), "{s}.png", .{l.name}) catch "Memory Allocation Failed";

            var img_buf: ?*anyopaque = null;
            var img_len: usize = 0;

            if (zip.zip_entry_open(pixi_file, layer_image_name.ptr) == 0) { // Read layer file as directly pixels
                _ = zip.zip_entry_read(pixi_file, &img_buf, &img_len);
                const data = img_buf orelse continue;

                var new_layer: pixi.Internal.Layer = try .fromPixels(
                    internal.newID(),
                    l.name,
                    @as([*]u8, @ptrCast(data))[0..img_len],
                    internal.width,
                    internal.height,
                    .ptr,
                );

                new_layer.visible = l.visible;
                new_layer.collapse = l.collapse;
                internal.layers.append(pixi.app.allocator, new_layer) catch return error.FileLoadError;

                if (l.visible and !set_layer_index) {
                    internal.selected_layer_index = i;
                    set_layer_index = true;
                }
            } else if (zip.zip_entry_open(pixi_file, png_image_name.ptr) == 0) { // Read the layer file as PNG file
                _ = zip.zip_entry_read(pixi_file, &img_buf, &img_len);
                const data = img_buf orelse continue;

                var new_layer: pixi.Internal.Layer = try .fromImageFile(
                    internal.newID(),
                    l.name,
                    @as([*]u8, @ptrCast(data))[0..img_len],
                    .ptr,
                );

                new_layer.visible = l.visible;
                new_layer.collapse = l.collapse;
                internal.layers.append(pixi.app.allocator, new_layer) catch return error.FileLoadError;

                if (l.visible and !set_layer_index) {
                    internal.selected_layer_index = i;
                    set_layer_index = true;
                }
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
                .name = try pixi.app.allocator.dupe(u8, animation.name),
                .start = animation.start,
                .length = animation.length,
                .fps = animation.fps,
            }) catch return error.FileLoadError;
        }
        return internal;
    }
    // { // Loading TAR experiment
    //     var file_name_buffer: [std.fs.max_path_bytes]u8 = undefined;
    //     var link_name_buffer: [std.fs.max_path_bytes]u8 = undefined;

    //     if (pixi.fs.read(pixi.app.allocator, path) catch null) |file_bytes| {
    //         std.log.debug("Read file bytes!", .{});
    //         var input = std.io.fixedBufferStream(file_bytes);
    //         var iter = std.tar.iterator(input.reader(), .{
    //             .file_name_buffer = &file_name_buffer,
    //             .link_name_buffer = &link_name_buffer,
    //         });

    //         var json_content = std.ArrayList(u8).init(pixi.app.allocator);
    //         defer json_content.deinit();

    //         while (try iter.next()) |entry| {
    //             const ext = std.fs.path.extension(entry.name);
    //             if (std.mem.eql(u8, ext, ".json")) {
    //                 entry.writeAll(json_content.writer()) catch return error.FileLoadError;
    //             }
    //         }

    //         const options = std.json.ParseOptions{
    //             .duplicate_field_behavior = .use_first,
    //             .ignore_unknown_fields = true,
    //         };

    //         if (std.json.parseFromSlice(pixi.File, pixi.app.allocator, json_content.items, options) catch null) |parsed| {
    //             defer parsed.deinit();

    //             std.log.debug("Parsed pixidata.json!", .{});

    //             const ext = parsed.value;

    //             var internal: pixi.Internal.File = .{
    //                 .id = pixi.editor.newFileID(),
    //                 .path = try pixi.app.allocator.dupe(u8, path),
    //                 .width = ext.width,
    //                 .height = ext.height,
    //                 .tile_width = ext.tile_width,
    //                 .tile_height = ext.tile_height,
    //                 .history = pixi.Internal.File.History.init(pixi.app.allocator),
    //                 .buffers = pixi.Internal.File.Buffers.init(pixi.app.allocator),
    //                 .checkerboard = pixi.image.init(
    //                     ext.tile_width * 2,
    //                     ext.tile_height * 2,
    //                     .{ .r = 0, .g = 0, .b = 0, .a = 0 },
    //                     .ptr,
    //                 ) catch return error.LayerCreateError,
    //                 .temporary_layer = undefined,
    //                 .selection_layer = undefined,
    //                 .selected_sprites = try std.DynamicBitSet.initEmpty(
    //                     pixi.app.allocator,
    //                     @divExact(ext.width, ext.tile_width) * @divExact(ext.height, ext.tile_height),
    //                 ),
    //             };

    //             internal.temporary_layer = try .init(internal.newID(), "Temporary", internal.width, internal.height, .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .always);

    //             for (ext.layers, 0..) |ext_layer, i| {
    //                 const layer_image_name = std.fmt.allocPrintZ(dvui.currentWindow().arena(), "{s}.layer", .{ext_layer.name}) catch "Memory Allocation Failed";

    //                 if (ext_layer.visible) {
    //                     internal.selected_layer_index = i;
    //                 }

    //                 iter = std.tar.iterator(input.reader(), .{
    //                     .file_name_buffer = &file_name_buffer,
    //                     .link_name_buffer = &link_name_buffer,
    //                 });

    //                 while (iter.next() catch null) |entry| {
    //                     std.log.debug("Entry name: {s}", .{entry.name});

    //                     if (std.mem.eql(u8, entry.name, layer_image_name)) {
    //                         var layer_content = std.ArrayList(u8).init(pixi.app.allocator);
    //                         try entry.writeAll(layer_content.writer());

    //                         var cond: ?pixi.Internal.Layer = pixi.Internal.Layer.fromPixels(internal.newID(), pixi.app.allocator.dupe(u8, ext_layer.name) catch ext_layer.name, layer_content.items, ext.width, ext.height, .ptr) catch null;

    //                         if (cond) |*new_layer| {
    //                             new_layer.visible = ext_layer.visible;
    //                             new_layer.collapse = ext_layer.collapse;
    //                             internal.layers.append(pixi.app.allocator, new_layer.*) catch return error.FileLoadError;
    //                         } else {
    //                             std.log.err("Failed to create layer from pixels", .{});
    //                         }
    //                     }
    //                 }
    //             }

    //             return internal;
    //         }
    //     }
    // }

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
    //file.deleted_heightmap_layers.deinit(pixi.app.allocator);
    file.sprites.deinit(pixi.app.allocator);
    //file.selected_sprites.deinit();
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

pub fn spriteCount(file: *File) usize {
    const tiles_wide = @divExact(file.width, file.tile_width);
    const tiles_high = @divExact(file.height, file.tile_height);
    return tiles_wide * tiles_high;
}

pub fn spriteIndex(file: *File, point: dvui.Point) ?usize {
    if (!file.editor.canvas.dataFromScreenRect(file.editor.canvas.rect).contains(point)) return null;

    const tiles_wide = @divExact(file.width, file.tile_width);

    const column = @divTrunc(@as(u32, @intFromFloat(point.x)), file.tile_width);
    const row = @divTrunc(@as(u32, @intFromFloat(point.y)), file.tile_height);

    return row * tiles_wide + column;
}

pub fn spriteRect(file: *File, index: usize) dvui.Rect {
    const tiles_wide = @divExact(file.width, file.tile_width);
    const column = @mod(@as(u32, @intCast(index)), tiles_wide);
    const row = @divTrunc(@as(u32, @intCast(index)), tiles_wide);
    return .{
        .x = @as(f32, @floatFromInt(column)) * @as(f32, @floatFromInt(file.tile_width)),
        .y = @as(f32, @floatFromInt(row)) * @as(f32, @floatFromInt(file.tile_height)),
        .w = @as(f32, @floatFromInt(file.tile_width)),
        .h = @as(f32, @floatFromInt(file.tile_height)),
    };
}

pub fn clearSelectedSprites(file: *File) void {
    file.selected_sprites.setRangeValue(.{ .start = 0, .end = file.spriteCount() }, false);
}

pub fn setSpriteSelection(file: *File, selection_rect: dvui.Rect, value: bool) void {
    for (0..spriteCount(file)) |index| {
        if (!file.spriteRect(index).intersect(selection_rect).empty()) {
            file.selected_sprites.setValue(index, value);
        }
    }
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

    defer active_layer.dirty = true;

    if (point.x < 0 or point.x >= @as(f32, @floatFromInt(file.width)) or point.y < 0 or point.y >= @as(f32, @floatFromInt(file.height))) {
        return;
    }

    const column = @as(u32, @intFromFloat(point.x)) / file.tile_width;
    const row = @as(u32, @intFromFloat(point.y)) / file.tile_height;

    const min_x: f32 = @as(f32, @floatFromInt(column)) * @as(f32, @floatFromInt(file.tile_width));
    const min_y: f32 = @as(f32, @floatFromInt(row)) * @as(f32, @floatFromInt(file.tile_height));

    const max_x: f32 = min_x + @as(f32, @floatFromInt(file.tile_width));
    const max_y: f32 = min_y + @as(f32, @floatFromInt(file.tile_height));

    if (draw_options.stroke_size < 10) {
        const size: usize = @intCast(draw_options.stroke_size);

        for (0..(size * size)) |index| {
            if (active_layer.getIndexShapeOffset(point, index)) |result| {
                if (draw_options.constrain_to_tile) {
                    if (result.point.x < min_x or result.point.x >= max_x or result.point.y < min_y or result.point.y >= max_y) {
                        continue;
                    }
                }

                if (layer == .selected) {
                    file.buffers.stroke.append(result.index, result.color) catch {
                        dvui.log.err("Failed to append to stroke buffer", .{});
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

            if (active_layer.pixelIndex(new_point)) |index| {
                if (layer == .selected) {
                    file.buffers.stroke.append(index, active_layer.pixels()[index]) catch {
                        dvui.log.err("Failed to append to stroke buffer", .{});
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
                dvui.log.err("Failed to append to history", .{});
            };
        }
    }
}

pub const FillOptions = struct {
    invalidate: bool = false,
    to_change: bool = false,
    constrain_to_tile: bool = false,
    replace: bool = false,
};

pub fn fillPoint(file: *File, point: dvui.Point, color: [4]u8, layer: DrawLayer, fill_options: FillOptions) void {
    var active_layer: Layer = switch (layer) {
        .temporary => file.temporary_layer,
        .selected => file.layers.get(file.selected_layer_index),
    };

    defer active_layer.dirty = true;

    if (point.x < 0 or point.x >= @as(f32, @floatFromInt(file.width)) or point.y < 0 or point.y >= @as(f32, @floatFromInt(file.height))) {
        return;
    }

    if (fill_options.replace) {
        if (active_layer.pixel(point)) |c| {
            active_layer.setMaskFromColor(c);
        }
    } else {
        active_layer.setMaskFloodPoint(point, .fromSize(.{ .w = @as(f32, @floatFromInt(file.width)), .h = @as(f32, @floatFromInt(file.height)) })) catch {
            dvui.log.err("Failed to fill point", .{});
        };
    }

    var iter = active_layer.mask.iterator(.{ .kind = .set, .direction = .forward });
    while (iter.next()) |index| {
        file.buffers.stroke.append(index, active_layer.pixels()[index]) catch {
            dvui.log.err("Failed to append to stroke buffer", .{});
        };

        active_layer.pixels()[index] = color;
    }

    if (fill_options.invalidate) {
        active_layer.invalidate();
    }

    if (fill_options.to_change and layer == .selected) {
        const change_opt = file.buffers.stroke.toChange(active_layer.id) catch null;
        if (change_opt) |change| {
            file.history.append(change) catch {
                dvui.log.err("Failed to append to history", .{});
            };
        }
    }
}

pub const DrawOptions = struct {
    stroke_size: usize,
    invalidate: bool = false,
    to_change: bool = false,
    constrain_to_tile: bool = false,
};

pub fn drawLine(file: *File, point1: dvui.Point, point2: dvui.Point, color: [4]u8, layer: DrawLayer, draw_options: DrawOptions) void {
    var active_layer: Layer = switch (layer) {
        .temporary => file.temporary_layer,
        .selected => file.layers.get(file.selected_layer_index),
    };

    defer active_layer.dirty = true;

    if (point1.x < 0 or point1.x >= @as(f32, @floatFromInt(file.width)) or point1.y < 0 or point1.y >= @as(f32, @floatFromInt(file.height))) {
        return;
    }

    if (point2.x < 0 or point2.x >= @as(f32, @floatFromInt(file.width)) or point2.y < 0 or point2.y >= @as(f32, @floatFromInt(file.height))) {
        return;
    }

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

    if (draw_options.stroke_size > pixi.Editor.Tools.min_full_stroke_size) {
        for (0..(stroke_size * stroke_size)) |index| {
            if (pixi.editor.tools.getIndexShapeOffset(center.diff(diff), index)) |i| {
                mask.unset(i);
            }
        }
    }

    if (pixi.algorithms.brezenham.process(point1, point2) catch null) |points| {
        for (points, 0..) |point, point_i| {
            if (draw_options.stroke_size < pixi.Editor.Tools.min_full_stroke_size) {
                drawPoint(file, point, color, layer, .{ .stroke_size = draw_options.stroke_size });
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

                    if (active_layer.pixelIndex(new_point)) |index| {
                        if (layer == .selected) {
                            file.buffers.stroke.append(index, active_layer.pixels()[index]) catch {
                                dvui.log.err("Failed to append to stroke buffer", .{});
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
                    dvui.log.err("Failed to append to history", .{});
                };
            }
        }
    }
}

pub fn transform(self: *File) !void {
    //if (self.editor.transform != null) return;

    var selected_layer = self.layers.get(self.selected_layer_index);

    //const active_layer = self.layers.get(self.selected_layer_index);
    self.selection_layer.clear();

    for (0..self.spriteCount()) |index| {
        if (self.selected_sprites.isSet(index)) {
            const source_rect = self.spriteRect(index);
            std.log.debug("Source rect: {any}", .{source_rect});
            if (selected_layer.pixelsFromRect(
                dvui.currentWindow().arena(),
                source_rect,
            )) |source_pixels| {
                self.selection_layer.blit(source_pixels, source_rect, true);
                selected_layer.clearRect(source_rect);
            }
        }
    }

    // At this point, we will assume that the selection layer has a copy of the active layer pixels,
    // and we can use this to reduce and create a new image source

    const source_rect = dvui.Rect.fromSize(self.selection_layer.size());

    if (self.selection_layer.reduce(source_rect)) |reduced_data_rect| {
        self.editor.transform = .{
            .data_points = .{
                reduced_data_rect.topLeft(),
                reduced_data_rect.topRight(),
                reduced_data_rect.bottomRight(),
                reduced_data_rect.bottomLeft(),
                reduced_data_rect.center(),
            },
            .source = pixi.image.fromPixels(
                @ptrCast(self.selection_layer.pixelsFromRect(pixi.app.allocator, reduced_data_rect)),
                @intFromFloat(reduced_data_rect.w),
                @intFromFloat(reduced_data_rect.h),
                .ptr,
            ) catch return error.MemoryAllocationFailed,
        };
    }
}

pub fn deleteLayer(self: *File, index: usize) !void {
    try self.deleted_layers.append(pixi.app.allocator, self.layers.slice().get(index));
    self.layers.orderedRemove(index);
    try self.history.append(.{ .layer_restore_delete = .{
        .action = .restore,
        .index = index,
    } });
}

pub fn duplicateLayer(self: *File, index: usize) !u64 {
    const layer = self.layers.slice().get(index);

    const new_name = try std.fmt.allocPrint(dvui.currentWindow().lifo(), "{s}_copy", .{layer.name});
    defer dvui.currentWindow().lifo().free(new_name);

    var new_layer = Layer.init(self.newID(), new_name, self.width, self.height, .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr) catch return error.FailedToDuplicateLayer;
    new_layer.visible = layer.visible;
    new_layer.collapse = layer.collapse;

    @memcpy(new_layer.pixels(), layer.pixels());

    self.layers.insert(pixi.app.allocator, 0, new_layer) catch {
        dvui.log.err("Failed to append layer", .{});
    };

    self.selected_layer_index = 0;

    self.history.append(.{
        .layer_restore_delete = .{
            .index = 0,
            .action = .delete,
        },
    }) catch {
        dvui.log.err("Failed to append history", .{});
    };

    return new_layer.id;
}

pub fn createLayer(self: *File) !u64 {
    if (pixi.Internal.Layer.init(self.newID(), "New Layer", self.width, self.height, .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr) catch null) |layer| {
        self.layers.insert(pixi.app.allocator, 0, layer) catch {
            dvui.log.err("Failed to append layer", .{});
        };
        self.selected_layer_index = 0;

        self.history.append(.{
            .layer_restore_delete = .{
                .index = 0,
                .action = .delete,
            },
        }) catch {
            dvui.log.err("Failed to append history", .{});
        };

        return layer.id;
    }

    return error.FailedToCreateLayer;
}

pub fn undo(self: *File) !void {
    return self.history.undoRedo(self, .undo);
}

pub fn redo(self: *File) !void {
    return self.history.undoRedo(self, .redo);
}

pub fn saveTar(self: *File, window: *dvui.Window) !void {
    if (self.saving) return;
    self.saving = true;
    var ext = try self.external(pixi.app.allocator);
    defer ext.deinit(pixi.app.allocator);

    const output_path = try pixi.editor.arena.allocator().dupeZ(u8, self.path);

    var handle = try std.fs.cwd().createFile(output_path, .{});
    defer handle.close();
    var wrt = std.tar.writer(handle.writer());

    var json = std.ArrayList(u8).init(pixi.app.allocator);
    const out_stream = json.writer();
    const options = std.json.StringifyOptions{};

    try std.json.stringify(ext, options, out_stream);

    const json_output = try json.toOwnedSlice();

    try wrt.writeFileBytes("pixidata.json", json_output, .{});

    if (self.layers.len > 0) {
        const slice = self.layers.slice();
        var index: usize = 0;
        while (index < self.layers.len) : (index += 1) {
            const layer = slice.get(index);

            const data: []u8 = switch (layer.source) {
                .pixels => |p| @as([*]u8, @ptrCast(@constCast(p.rgba.ptr)))[0..(p.width * p.height * 4)],
                .pixelsPMA => |p| @as([*]u8, @ptrCast(@constCast(p.rgba.ptr)))[0..(p.width * p.height * 4)],
                else => return error.InvalidImageSource,
            };

            try wrt.writeFileBytes(try std.fmt.allocPrintZ(pixi.editor.arena.allocator(), "{s}.layer", .{layer.name}), data, .{});
        }
    }

    try wrt.finish();

    {
        const id_mutex = dvui.toastAdd(window, @src(), 0, self.editor.canvas.id, pixi.dvui.toastDisplay, 2_000_000);
        const id = id_mutex.id;
        const message = std.fmt.allocPrint(window.arena(), "Saved {s}", .{std.fs.path.basename(self.path)}) catch "Saved file";
        dvui.dataSetSlice(window, id, "_message", message);
        id_mutex.mutex.unlock();
    }

    self.saving = false;
    self.history.bookmark = 0;
}

pub fn saveZip(self: *File, window: *dvui.Window) !void {
    if (self.saving) return;
    self.saving = true;
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

        if (self.layers.len > 0) {
            const slice = self.layers.slice();
            var index: usize = 0;
            while (index < self.layers.len) : (index += 1) {
                const layer = slice.get(index);

                const image_name = try std.fmt.allocPrintZ(pixi.editor.arena.allocator(), "{s}.layer", .{layer.name});
                _ = zip.zip_entry_open(z, @as([*c]const u8, @ptrCast(image_name)));
                _ = zip.zip_entry_write(z, @as([*]u8, @ptrCast(layer.bytes().ptr)), layer.bytes().len);

                //try layer.writeSourceToZip(z);
                _ = zip.zip_entry_close(z);
            }
        }

        zip.zip_close(z);

        {
            const id_mutex = dvui.toastAdd(window, @src(), 0, self.editor.canvas.id, pixi.dvui.toastDisplay, 2_000_000);
            const id = id_mutex.id;
            const message = std.fmt.allocPrint(window.arena(), "Saved {s}", .{std.fs.path.basename(self.path)}) catch "Saved file";
            dvui.dataSetSlice(window, id, "_message", message);
            id_mutex.mutex.unlock();
        }
    }

    self.saving = false;
    self.history.bookmark = 0;
}

pub fn saveAsync(self: *File) !void {
    if (!self.dirty()) return;
    const thread = try std.Thread.spawn(.{}, saveZip, .{ self, dvui.currentWindow() });
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
