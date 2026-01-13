const std = @import("std");
const pixi = @import("../pixi.zig");
const zip = @import("zip");
const dvui = @import("dvui");

const Editor = pixi.Editor;

const File = @This();

const Layer = @import("Layer.zig");
const Sprite = @import("Sprite.zig");
const Animation = @import("Animation.zig");

id: u64,
path: []const u8,

width: u32,
height: u32,
tile_width: u32 = 0,
tile_height: u32 = 0,

selected_layer_index: usize = 0,
peek_layer_index: ?usize = null,
layers: std.MultiArrayList(Layer) = .{},
deleted_layers: std.MultiArrayList(Layer) = .{},

sprites: std.MultiArrayList(Sprite) = .{},

selected_animation_index: ?usize = null,
selected_animation_frame_index: usize = 0,

animations: std.MultiArrayList(Animation) = .{},
deleted_animations: std.MultiArrayList(Animation) = .{},

history: History,
buffers: Buffers,

layer_id_counter: u64 = 0,
anim_id_counter: u64 = 0,

/// File-specific editor data
editor: EditorData = .{},

/// This may be a confusing distinction between "editor" and File fields,
/// but the intent is that fields inside of the editor namespace are actively
/// used each frame to write/read data the editor directly depends on.
///
/// Also, the fields here tend to be directly coupled with the UI library
pub const EditorData = struct {
    canvas: pixi.dvui.CanvasWidget = .{},
    layers_scroll_info: dvui.ScrollInfo = .{},
    sprites_scroll_info: dvui.ScrollInfo = .{},
    sprites_hovered_index: usize = 0, // Last known hovered sprite index
    animations_scroll_info: dvui.ScrollInfo = .{},
    animations_scroll_to_index: ?usize = null,
    transform: ?Editor.Transform = null,

    playing: bool = false,
    saving: bool = false,
    grouping: u64 = 0,

    // Internal layers for editor
    isolate_layer: bool = false,
    temporary_layer: Layer = undefined,
    selection_layer: Layer = undefined,
    transform_layer: Layer = undefined,
    selected_sprites: std.DynamicBitSet = undefined,

    resized_layer_data_undo: std.array_list.Managed([][][4]u8) = undefined,
    resized_layer_data_redo: std.array_list.Managed([][][4]u8) = undefined,

    checkerboard: std.DynamicBitSet = undefined,
    checkerboard_tile: dvui.ImageSource = undefined,
};

pub const History = @import("History.zig");
pub const Buffers = @import("Buffers.zig");

pub fn init(path: []const u8, width: u32, height: u32) !pixi.Internal.File {
    var internal: pixi.Internal.File = .{
        .id = pixi.editor.newFileID(),
        .path = try pixi.app.allocator.dupe(u8, path),
        .width = width,
        .height = height,
        .history = pixi.Internal.File.History.init(pixi.app.allocator),
        .buffers = pixi.Internal.File.Buffers.init(pixi.app.allocator),
    };

    // Initialize editor layers and selected sprites
    internal.editor.temporary_layer = try .init(internal.newID(), "Temporary", internal.width, internal.height, .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .always);
    internal.editor.selection_layer = try .init(internal.newID(), "Selection", internal.width, internal.height, .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr);
    internal.editor.transform_layer = try .init(internal.newID(), "Transform", internal.width, internal.height, .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr);
    internal.editor.selected_sprites = try std.DynamicBitSet.initEmpty(pixi.app.allocator, internal.spriteCount());

    internal.editor.resized_layer_data_undo = std.array_list.Managed([][][4]u8).init(pixi.app.allocator);
    internal.editor.resized_layer_data_redo = std.array_list.Managed([][][4]u8).init(pixi.app.allocator);

    internal.editor.checkerboard = try std.DynamicBitSet.initEmpty(pixi.app.allocator, internal.width * internal.height);
    // Create a layer-sized checkerboard pattern for selection tools
    for (0..internal.width * internal.height) |i| {
        const value = pixi.math.checker(.{ .w = @floatFromInt(internal.width), .h = @floatFromInt(internal.height) }, i);
        internal.editor.checkerboard.setValue(i, value);
    }

    // Initialize checkerboard tile image source
    {
        internal.editor.checkerboard_tile = pixi.image.init(
            width * 2,
            height * 2,
            .{ .r = 0, .g = 0, .b = 0, .a = 0 },
            .ptr,
        ) catch return error.LayerCreateError;

        const checker_color_1: [4]u8 = .{ 255, 255, 255, 255 };
        const checker_color_2: [4]u8 = .{ 175, 175, 175, 255 };

        for (pixi.image.pixels(internal.editor.checkerboard_tile), 0..) |*pixel, i| {
            if (pixi.math.checker(pixi.image.size(internal.editor.checkerboard_tile), i)) {
                pixel.* = checker_color_1;
            } else {
                pixel.* = checker_color_2;
            }
        }
        dvui.textureInvalidateCache(internal.editor.checkerboard_tile.hash());
    }
    return internal;
}

/// Attempts to load a file from the given path to create a new file
pub fn fromPath(path: []const u8) !?pixi.Internal.File {
    const extension = std.fs.path.extension(path[0..path.len]);
    if (std.mem.eql(u8, extension, ".png")) {
        const file = fromPathPng(path) catch |err| {
            dvui.log.err("{any}: {s}", .{ err, path });
            return err;
        };
        return file;
    }

    if (std.mem.eql(u8, extension, ".pixi")) {
        const file = fromPathPixi(path) catch |err| {
            dvui.log.err("{any}: {s}", .{ err, path });
            return err;
        };
        return file;
    }

    return error.InvalidExtension;
}

pub fn fromPathPixi(path: []const u8) !?pixi.Internal.File {
    if (!std.mem.eql(u8, std.fs.path.extension(path[0..path.len]), ".pixi"))
        return error.InvalidExtension;

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

        var try_parse: ?std.json.Parsed(pixi.File) = null;

        try_parse = std.json.parseFromSlice(pixi.File, pixi.app.allocator, content, options) catch null;

        var ext: pixi.File = if (try_parse) |parsed| parsed.value else undefined;

        if (try_parse == null) {
            // If we are here, we have tried to load the file but hit an issue because the old animation format
            // exists

            // we now need to load the old animation format.

            if (std.json.parseFromSlice(pixi.File.OldFile, pixi.app.allocator, content, options) catch null) |old_file| {
                const animations = try pixi.app.allocator.alloc(pixi.Animation, old_file.value.animations.len);
                for (animations, old_file.value.animations) |*animation, old_animation| {
                    animation.name = try pixi.app.allocator.dupe(u8, old_animation.name);
                    animation.frames = try pixi.app.allocator.alloc(usize, old_animation.length);
                    for (animation.frames, 0..old_animation.length) |*frame, i| {
                        frame.* = old_animation.start + i;
                    }
                    animation.fps = old_animation.fps;
                }

                ext = .{
                    .version = old_file.value.version,
                    .width = old_file.value.width,
                    .height = old_file.value.height,
                    .tile_width = old_file.value.tile_width,
                    .tile_height = old_file.value.tile_height,
                    .layers = old_file.value.layers,
                    .sprites = old_file.value.sprites,
                    .animations = animations,
                };
            }
        }

        defer if (try_parse) |parsed| parsed.deinit();

        //defer parsed.deinit();

        var internal: pixi.Internal.File = .{
            .id = pixi.editor.newFileID(),
            .path = try pixi.app.allocator.dupe(u8, path),
            .width = ext.width,
            .height = ext.height,
            .tile_width = ext.tile_width,
            .tile_height = ext.tile_height,
            .history = pixi.Internal.File.History.init(pixi.app.allocator),
            .buffers = pixi.Internal.File.Buffers.init(pixi.app.allocator),
        };

        //Initialize editor layers and selected sprites
        internal.editor.temporary_layer = try .init(internal.newLayerID(), "Temporary", internal.width, internal.height, .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr);
        internal.editor.selection_layer = try .init(internal.newLayerID(), "Selection", internal.width, internal.height, .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr);
        internal.editor.transform_layer = try .init(internal.newLayerID(), "Transform", internal.width, internal.height, .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr);
        internal.editor.selected_sprites = try std.DynamicBitSet.initEmpty(pixi.app.allocator, internal.spriteCount());

        internal.editor.resized_layer_data_undo = std.array_list.Managed([][][4]u8).init(pixi.app.allocator);
        internal.editor.resized_layer_data_redo = std.array_list.Managed([][][4]u8).init(pixi.app.allocator);

        internal.editor.checkerboard = try std.DynamicBitSet.initEmpty(pixi.app.allocator, internal.width * internal.height);
        // Create a layer-sized checkerboard pattern for selection tools
        for (0..internal.width * internal.height) |i| {
            const value = pixi.math.checker(.{ .w = @floatFromInt(internal.width), .h = @floatFromInt(internal.height) }, i);
            internal.editor.checkerboard.setValue(i, value);
        }

        // Initialize checkerboard tile image source
        {
            internal.editor.checkerboard_tile = pixi.image.init(
                ext.tile_width * 2,
                ext.tile_height * 2,
                .{ .r = 0, .g = 0, .b = 0, .a = 0 },
                .ptr,
            ) catch return error.LayerCreateError;

            const checker_color_1: [4]u8 = .{ 255, 255, 255, 255 };
            const checker_color_2: [4]u8 = .{ 175, 175, 175, 255 };

            for (pixi.image.pixels(internal.editor.checkerboard_tile), 0..) |*pixel, i| {
                if (pixi.math.checker(pixi.image.size(internal.editor.checkerboard_tile), i)) {
                    pixel.* = checker_color_1;
                } else {
                    pixel.* = checker_color_2;
                }
            }
            dvui.textureInvalidateCache(internal.editor.checkerboard_tile.hash());
        }

        var set_layer_index: bool = false;
        for (ext.layers, 0..) |l, i| {
            const layer_image_name = std.fmt.allocPrintSentinel(dvui.currentWindow().arena(), "{s}.layer", .{l.name}, 0) catch "Memory Allocation Failed";
            const png_image_name = std.fmt.allocPrintSentinel(dvui.currentWindow().arena(), "{s}.png", .{l.name}, 0) catch "Memory Allocation Failed";

            var img_buf: ?*anyopaque = null;
            var img_len: usize = 0;

            if (zip.zip_entry_open(pixi_file, layer_image_name.ptr) == 0) { // Read layer file as directly pixels
                _ = zip.zip_entry_read(pixi_file, &img_buf, &img_len);
                const data = img_buf orelse continue;

                var new_layer: pixi.Internal.Layer = try .fromPixelsPMA(
                    internal.newLayerID(),
                    l.name,
                    @as([*]dvui.Color.PMA, @ptrCast(@constCast(data)))[0..(internal.width * internal.height)],
                    internal.width,
                    internal.height,
                    .ptr,
                );

                new_layer.visible = l.visible;
                new_layer.collapse = l.collapse;

                new_layer.setMaskFromTransparency(true);

                internal.layers.append(pixi.app.allocator, new_layer) catch return error.FileLoadError;

                if (l.visible and !set_layer_index) {
                    internal.selected_layer_index = i;
                    set_layer_index = true;
                }
            } else if (zip.zip_entry_open(pixi_file, png_image_name.ptr) == 0) { // Read the layer file as PNG file
                _ = zip.zip_entry_read(pixi_file, &img_buf, &img_len);
                const data = img_buf orelse continue;

                var new_layer: pixi.Internal.Layer = try .fromImageFileBytes(
                    internal.newLayerID(),
                    l.name,
                    @as([*]u8, @ptrCast(data))[0..img_len],
                    .ptr,
                );

                new_layer.visible = l.visible;
                new_layer.collapse = l.collapse;

                new_layer.setMaskFromTransparency(true);

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
                .id = internal.newAnimationID(),
                .name = try pixi.app.allocator.dupe(u8, animation.name),
                .frames = try pixi.app.allocator.dupe(usize, animation.frames),
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

    //         var json_content = std.array_list.Managed(u8).init(pixi.app.allocator);
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
    //                         var layer_content = std.array_list.Managed(u8).init(pixi.app.allocator);
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

/// Loads a PNG file as the first layer of a new file, and retains the png path
/// when saved, layers will be flattened to the png file
pub fn fromPathPng(path: []const u8) !?pixi.Internal.File {
    if (!std.mem.eql(u8, std.fs.path.extension(path[0..path.len]), ".png"))
        return error.InvalidExtension;

    var png_layer: pixi.Internal.Layer = try pixi.Internal.Layer.fromImageFilePath(pixi.editor.newFileID(), "Layer", path, .ptr);
    const size = png_layer.size();
    const width: u32 = @intFromFloat(size.w);
    const height: u32 = @intFromFloat(size.h);

    var internal: pixi.Internal.File = .{
        .id = pixi.editor.newFileID(),
        .path = try pixi.app.allocator.dupe(u8, path),
        .width = width,
        .height = height,
        .tile_width = width,
        .tile_height = height,
        .history = pixi.Internal.File.History.init(pixi.app.allocator),
        .buffers = pixi.Internal.File.Buffers.init(pixi.app.allocator),
    };

    internal.layers.append(pixi.app.allocator, png_layer) catch return error.LayerCreateError;

    // Initialize editor layers and selected sprites
    internal.editor.temporary_layer = try .init(internal.newLayerID(), "Temporary", internal.width, internal.height, .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr);
    internal.editor.selection_layer = try .init(internal.newLayerID(), "Selection", internal.width, internal.height, .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr);
    internal.editor.transform_layer = try .init(internal.newLayerID(), "Transform", internal.width, internal.height, .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr);
    internal.editor.selected_sprites = try std.DynamicBitSet.initEmpty(pixi.app.allocator, internal.spriteCount());

    internal.editor.checkerboard = try std.DynamicBitSet.initEmpty(pixi.app.allocator, internal.width * internal.height);
    // Create a layer-sized checkerboard pattern for selection tools
    for (0..internal.width * internal.height) |i| {
        const value = pixi.math.checker(.{ .w = @floatFromInt(internal.width), .h = @floatFromInt(internal.height) }, i);
        internal.editor.checkerboard.setValue(i, value);
    }

    // Initialize checkerboard tile image source
    {
        internal.editor.checkerboard_tile = pixi.image.init(
            width * 2,
            height * 2,
            .{ .r = 0, .g = 0, .b = 0, .a = 0 },
            .ptr,
        ) catch return error.LayerCreateError;

        const checker_color_1: [4]u8 = .{ 255, 255, 255, 255 };
        const checker_color_2: [4]u8 = .{ 175, 175, 175, 255 };

        for (pixi.image.pixels(internal.editor.checkerboard_tile), 0..) |*pixel, i| {
            if (pixi.math.checker(pixi.image.size(internal.editor.checkerboard_tile), i)) {
                pixel.* = checker_color_1;
            } else {
                pixel.* = checker_color_2;
            }
        }
        dvui.textureInvalidateCache(internal.editor.checkerboard_tile.hash());
    }

    return internal;
}

pub const ResizeOptions = struct {
    tiles_wide: u32,
    tiles_high: u32,
    history: bool = true, // If true, layer data will be recorded for undo/redo
    layer_data: ?[][][4]u8 = null, // If provided, the layer data will be applied to the layers after resizing
};

pub fn resize(file: *File, options: ResizeOptions) !void {
    const current_tiles_wide = @divExact(file.width, file.tile_width);
    const current_tiles_high = @divExact(file.height, file.tile_height);

    if (options.tiles_wide == current_tiles_wide and
        options.tiles_high == current_tiles_high) return;

    const new_width = options.tiles_wide * file.tile_width;
    const new_height = options.tiles_high * file.tile_height;

    // First, record the current layer data for undo/redo
    if (options.history) {
        file.history.append(.{ .resize = .{ .width = file.width, .height = file.height } }) catch return error.HistoryAppendError;

        var layer_data = try pixi.app.allocator.alloc([][4]u8, file.layers.len);
        for (0..file.layers.len) |layer_index| {
            var layer = file.layers.get(layer_index);
            layer_data[layer_index] = pixi.app.allocator.dupe([4]u8, layer.pixels()) catch return error.MemoryAllocationFailed;
        }
        file.editor.resized_layer_data_undo.append(layer_data) catch return error.MemoryAllocationFailed;
    }

    // Now, resize the layers, and apply any layer data if needed
    for (0..file.layers.len) |layer_index| {
        var layer = file.layers.get(layer_index);

        layer.resize(.{ .w = @floatFromInt(new_width), .h = @floatFromInt(new_height) }) catch return error.LayerResizeError;

        if (options.layer_data) |data| {
            if (data[layer_index].len == new_width * new_height)
                layer.blit(data[layer_index], .fromSize(.{ .w = @floatFromInt(new_width), .h = @floatFromInt(new_height) }), .{});
        }
        file.layers.set(layer_index, layer);
    }

    file.editor.temporary_layer.resize(.{ .w = @floatFromInt(new_width), .h = @floatFromInt(new_height) }) catch return error.LayerResizeError;
    file.editor.selection_layer.resize(.{ .w = @floatFromInt(new_width), .h = @floatFromInt(new_height) }) catch return error.LayerResizeError;
    file.editor.transform_layer.resize(.{ .w = @floatFromInt(new_width), .h = @floatFromInt(new_height) }) catch return error.LayerResizeError;

    file.editor.selected_sprites.resize(options.tiles_wide * options.tiles_high, false) catch return error.MemoryAllocationFailed;

    file.editor.checkerboard.resize(new_width * new_height, false) catch return error.MemoryAllocationFailed;
    for (0..new_width * new_height) |i| {
        const value = pixi.math.checker(.{ .w = @floatFromInt(new_width), .h = @floatFromInt(new_height) }, i);
        file.editor.checkerboard.setValue(i, value);
    }

    file.width = new_width;
    file.height = new_height;
}

pub fn deinit(file: *File) void {
    file.history.deinit();
    file.buffers.deinit();

    for (file.layers.items(.name)) |name| {
        pixi.app.allocator.free(name);
    }

    for (file.animations.items(.name)) |name| {
        pixi.app.allocator.free(name);
    }

    for (file.animations.items(.frames)) |frames| {
        pixi.app.allocator.free(frames);
    }

    file.layers.deinit(pixi.app.allocator);
    file.deleted_layers.deinit(pixi.app.allocator);
    file.sprites.deinit(pixi.app.allocator);
    file.animations.deinit(pixi.app.allocator);
    file.deleted_animations.deinit(pixi.app.allocator);
    pixi.app.allocator.free(file.path);
}

pub fn dirty(self: File) bool {
    return self.history.bookmark != 0;
}

pub fn newAnimationID(file: *File) u64 {
    file.anim_id_counter += 1;
    return file.anim_id_counter;
}

pub fn newLayerID(file: *File) u64 {
    file.layer_id_counter += 1;
    return file.layer_id_counter;
}

pub fn spritePoint(file: *File, point: dvui.Point) dvui.Point {
    const column = @divTrunc(@as(i32, @intFromFloat(point.x)), @as(i32, @intCast(file.tile_width)));
    const row = @divTrunc(@as(i32, @intFromFloat(point.y)), @as(i32, @intCast(file.tile_height)));

    return .{ .x = @as(f32, @floatFromInt(column)) * @as(f32, @floatFromInt(file.tile_width)), .y = @as(f32, @floatFromInt(row)) * @as(f32, @floatFromInt(file.tile_height)) };
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

// Returns the name of the animation and the frame index of the sprite, or just the frame index
pub fn spriteName(file: *File, allocator: std.mem.Allocator, index: usize, by_animation: bool) ![]const u8 {
    if (by_animation) {
        for (file.animations.items(.frames), 0..) |frames, animation_index| {
            for (frames, 0..) |frame, i| {
                if (frame != index) continue;

                if (frames.len > 1) {
                    return std.fmt.allocPrint(allocator, "{s}_{d}", .{ file.animations.items(.name)[animation_index], i });
                } else {
                    return std.fmt.allocPrint(allocator, "{s}", .{file.animations.items(.name)[animation_index]});
                }
            }
        }
    }

    return std.fmt.allocPrint(allocator, "Index: {d}", .{index});
}

pub fn spriteRect(file: *File, index: usize) dvui.Rect {
    const tiles_wide = @divExact(file.width, file.tile_width);
    const column = @mod(@as(u32, @intCast(index)), tiles_wide);
    const row = @divTrunc(@as(u32, @intCast(index)), tiles_wide);

    const out: dvui.Rect = .{
        .x = @as(f32, @floatFromInt(column)) * @as(f32, @floatFromInt(file.tile_width)),
        .y = @as(f32, @floatFromInt(row)) * @as(f32, @floatFromInt(file.tile_height)),
        .w = @as(f32, @floatFromInt(file.tile_width)),
        .h = @as(f32, @floatFromInt(file.tile_height)),
    };
    return out;
}

pub fn clearSelectedSprites(file: *File) void {
    file.editor.selected_sprites.setRangeValue(.{ .start = 0, .end = file.spriteCount() }, false);
}

pub fn setSpriteSelection(file: *File, selection_rect: dvui.Rect, value: bool) void {
    for (0..spriteCount(file)) |index| {
        if (!file.spriteRect(index).intersect(selection_rect).empty()) {
            file.editor.selected_sprites.setValue(index, value);
        }
    }
}

pub const SelectOptions = struct {
    value: bool = true,
    clear: bool = false,
    stroke_size: usize,
    constrain_to_tile: bool = false,
};

/// Selects a point by considering the current stroke size and setting bits in the selection layer mask if there are
/// non-transparent pixels in the currently active layer.
/// If `value` is true, the point will be selected, otherwise it will be deselected.
/// If `clear` is true, the selection layer mask will be cleared before setting the new value.
pub fn selectPoint(file: *File, point: dvui.Point, select_options: SelectOptions) void {
    const read_layer: Layer = file.layers.get(file.selected_layer_index);
    var selection_layer: *Layer = &file.editor.selection_layer;

    if (select_options.clear) {
        selection_layer.clearMask();
    }

    if (point.x < 0 or point.x >= @as(f32, @floatFromInt(file.width)) or point.y < 0 or point.y >= @as(f32, @floatFromInt(file.height))) {
        return;
    }

    const column = @as(u32, @intFromFloat(point.x)) / file.tile_width;
    const row = @as(u32, @intFromFloat(point.y)) / file.tile_height;

    const min_x: f32 = @as(f32, @floatFromInt(column)) * @as(f32, @floatFromInt(file.tile_width));
    const min_y: f32 = @as(f32, @floatFromInt(row)) * @as(f32, @floatFromInt(file.tile_height));

    const max_x: f32 = min_x + @as(f32, @floatFromInt(file.tile_width));
    const max_y: f32 = min_y + @as(f32, @floatFromInt(file.tile_height));

    if (select_options.stroke_size < 10) {
        const size: usize = @intCast(select_options.stroke_size);

        for (0..(size * size)) |index| {
            if (selection_layer.getIndexShapeOffset(point, index)) |result| {
                if (select_options.constrain_to_tile) {
                    if (result.point.x < min_x or result.point.x >= max_x or result.point.y < min_y or result.point.y >= max_y) {
                        continue;
                    }
                }

                if (read_layer.pixels()[result.index][3] > 0) {
                    selection_layer.mask.setValue(result.index, select_options.value);
                }
            }
        }
    } else {
        var iter = pixi.editor.tools.stroke.iterator(.{ .kind = .set, .direction = .forward });
        while (iter.next()) |i| {
            const offset = pixi.editor.tools.offset_table[i];
            const new_point: dvui.Point = .{ .x = point.x + offset[0], .y = point.y + offset[1] };

            if (select_options.constrain_to_tile) {
                if (new_point.x < min_x or new_point.x >= max_x or new_point.y < min_y or new_point.y >= max_y) {
                    continue;
                }
            }

            if (selection_layer.pixelIndex(new_point)) |index| {
                if (read_layer.pixels()[index][3] > 0) {
                    selection_layer.mask.setValue(index, select_options.value);
                }
            }
        }
    }
}

pub fn selectLine(file: *File, point1: dvui.Point, point2: dvui.Point, select_options: SelectOptions) void {
    const read_layer: Layer = file.layers.get(file.selected_layer_index);
    var selection_layer: *Layer = &file.editor.selection_layer;

    if (select_options.clear) {
        selection_layer.clearMask();
    }

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

    if (select_options.stroke_size > pixi.Editor.Tools.min_full_stroke_size) {
        for (0..(stroke_size * stroke_size)) |index| {
            if (pixi.editor.tools.getIndexShapeOffset(center.diff(diff), index)) |i| {
                mask.unset(i);
            }
        }
    }

    if (pixi.algorithms.brezenham.process(point1, point2) catch null) |points| {
        for (points, 0..) |point, point_i| {
            if (select_options.stroke_size < pixi.Editor.Tools.min_full_stroke_size) {
                selectPoint(file, point, select_options);
            } else {
                var stroke = if (point_i == 0) pixi.editor.tools.stroke else mask;

                var iter = stroke.iterator(.{ .kind = .set, .direction = .forward });
                while (iter.next()) |i| {
                    const offset = pixi.editor.tools.offset_table[i];
                    const new_point: dvui.Point = .{ .x = point.x + offset[0], .y = point.y + offset[1] };

                    if (select_options.constrain_to_tile) {
                        if (new_point.x < min_x or new_point.x >= max_x or new_point.y < min_y or new_point.y >= max_y) {
                            continue;
                        }
                    }

                    if (selection_layer.pixelIndex(new_point)) |index| {
                        if (read_layer.pixels()[index][3] > 0) {
                            selection_layer.mask.setValue(index, select_options.value);
                        }
                    }
                }
            }
        }
    }
}

pub const DrawLayer = enum {
    temporary,
    selected,
};

pub const DrawOptions = struct {
    stroke_size: usize,
    mask_only: bool = false,
    invalidate: bool = false,
    to_change: bool = false,
    constrain_to_tile: bool = false,
    color: dvui.Color = .{ .r = 0, .g = 0, .b = 0, .a = 255 },
};

/// Draws a point on the `.selected` (the point will be added to the stroke buffer) or `.temporary` layer.
/// If `to_change` is true, the point will be added to the stroke buffer and then the history will be appended.
/// If `invalidate` is true, the layer will be invalidated.
/// If `mask_only` is true, the drawn pixels will only be marked on the mask, not the layer pixels themselves.
/// If `constrain_to_tile` is true, the drawn pixels will only be marked on the tile that the point is currently within
/// regardless of the stroke size.
pub fn drawPoint(file: *File, point: dvui.Point, layer: DrawLayer, draw_options: DrawOptions) void {
    var active_layer: Layer = switch (layer) {
        .temporary => file.editor.temporary_layer,
        .selected => file.layers.get(file.selected_layer_index),
    };

    defer active_layer.dirty = true;

    if (point.x < 0 or point.x >= @as(f32, @floatFromInt(file.width)) or point.y < 0 or point.y >= @as(f32, @floatFromInt(file.height))) {
        return;
    }

    const mask_value: bool = draw_options.color.a != 0;

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

                active_layer.mask.setValue(result.index, mask_value);

                if (draw_options.mask_only) {
                    continue;
                }

                if (layer == .selected) {
                    file.buffers.stroke.append(result.index, result.color) catch {
                        dvui.log.err("Failed to append to stroke buffer", .{});
                    };
                }

                active_layer.pixels()[result.index] = draw_options.color.toRGBA();
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
                active_layer.mask.setValue(index, mask_value);
                if (draw_options.mask_only) {
                    continue;
                }
                if (layer == .selected) {
                    file.buffers.stroke.append(index, active_layer.pixels()[index]) catch {
                        dvui.log.err("Failed to append to stroke buffer", .{});
                    };
                }

                active_layer.pixels()[index] = draw_options.color.toRGBA();
            }
        }
    }

    if (draw_options.mask_only) {
        return;
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

pub fn drawLine(file: *File, point1: dvui.Point, point2: dvui.Point, layer: DrawLayer, draw_options: DrawOptions) void {
    var active_layer: Layer = switch (layer) {
        .temporary => file.editor.temporary_layer,
        .selected => file.layers.get(file.selected_layer_index),
    };

    defer active_layer.dirty = true;

    if (point1.x < 0 or point1.x >= @as(f32, @floatFromInt(file.width)) or point1.y < 0 or point1.y >= @as(f32, @floatFromInt(file.height))) {
        return;
    }

    if (point2.x < 0 or point2.x >= @as(f32, @floatFromInt(file.width)) or point2.y < 0 or point2.y >= @as(f32, @floatFromInt(file.height))) {
        return;
    }

    const mask_value: bool = draw_options.color.a != 0;

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
                drawPoint(file, point, layer, .{
                    .color = draw_options.color,
                    .stroke_size = draw_options.stroke_size,
                    .mask_only = draw_options.mask_only,
                    .invalidate = false,
                    .to_change = false,
                    .constrain_to_tile = draw_options.constrain_to_tile,
                });
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
                        active_layer.mask.setValue(index, mask_value);
                        if (draw_options.mask_only) {
                            continue;
                        }
                        if (layer == .selected) {
                            file.buffers.stroke.append(index, active_layer.pixels()[index]) catch {
                                dvui.log.err("Failed to append to stroke buffer", .{});
                            };
                        }

                        active_layer.pixels()[index] = draw_options.color.toRGBA();
                    }
                }
            }
        }

        if (draw_options.mask_only) {
            return;
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

pub const FillOptions = struct {
    invalidate: bool = false,
    to_change: bool = false,
    mask_only: bool = false,
    constrain_to_tile: bool = false,
    replace: bool = false,
    color: dvui.Color = .{ .r = 0, .g = 0, .b = 0, .a = 255 },
};

pub fn fillPoint(file: *File, point: dvui.Point, layer: DrawLayer, fill_options: FillOptions) void {
    var active_layer: Layer = switch (layer) {
        .temporary => file.editor.temporary_layer,
        .selected => file.layers.get(file.selected_layer_index),
    };

    defer active_layer.dirty = true;

    const active_mask_before = active_layer.mask.clone(dvui.currentWindow().arena()) catch {
        dvui.log.err("Failed to clone active mask", .{});
        return;
    };

    if (point.x < 0 or point.x >= @as(f32, @floatFromInt(file.width)) or point.y < 0 or point.y >= @as(f32, @floatFromInt(file.height))) {
        return;
    }

    if (fill_options.replace) {
        if (active_layer.pixel(point)) |c| {
            active_layer.clearMask();
            active_layer.setMaskFromColor(.{ .r = c[0], .g = c[1], .b = c[2], .a = c[3] }, true);
        }
    } else {
        active_layer.clearMask();
        active_layer.floodMaskPoint(point, .fromSize(.{ .w = @as(f32, @floatFromInt(file.width)), .h = @as(f32, @floatFromInt(file.height)) }), true) catch {
            dvui.log.err("Failed to fill point", .{});
        };
    }

    if (fill_options.mask_only) {
        active_layer.mask.setUnion(active_mask_before);
        return;
    }

    var iter = active_layer.mask.iterator(.{ .kind = .set, .direction = .forward });
    while (iter.next()) |index| {
        file.buffers.stroke.append(index, active_layer.pixels()[index]) catch {
            dvui.log.err("Failed to append to stroke buffer", .{});
        };

        active_layer.pixels()[index] = fill_options.color.toRGBA();
    }

    if (fill_options.invalidate) {
        active_layer.invalidate();
    }

    if (fill_options.to_change and layer == .selected and !fill_options.mask_only) {
        const change_opt = file.buffers.stroke.toChange(active_layer.id) catch null;
        if (change_opt) |change| {
            file.history.append(change) catch {
                dvui.log.err("Failed to append to history", .{});
            };
        }
    }

    if (fill_options.color.a != 0) {
        active_layer.mask.toggleAll(); // This will ensure that all drawn pixels are off, and all undrawn pixels are on
    }

    active_layer.mask.setUnion(active_mask_before);
}

pub fn getLayer(self: *File, id: u64) ?Layer {
    for (self.layers.items(.id), 0..) |layer_id, layer_index| {
        if (layer_id == id) {
            return self.layers.get(layer_index);
        }
    }

    return null;
}

pub fn deleteLayer(self: *File, index: usize) !void {
    try self.deleted_layers.append(pixi.app.allocator, self.layers.slice().get(index));
    self.layers.orderedRemove(index);
    try self.history.append(.{ .layer_restore_delete = .{
        .action = .restore,
        .index = index,
    } });

    if (index > 0) {
        self.selected_layer_index = index - 1;
    }
}

pub fn duplicateLayer(self: *File, index: usize) !u64 {
    const layer = self.layers.slice().get(index);

    const new_name = try std.fmt.allocPrint(dvui.currentWindow().lifo(), "{s}_copy", .{layer.name});
    defer dvui.currentWindow().lifo().free(new_name);

    var new_layer = Layer.init(self.newLayerID(), new_name, self.width, self.height, .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr) catch return error.FailedToDuplicateLayer;
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
    if (pixi.Internal.Layer.init(self.newLayerID(), "New Layer", self.width, self.height, .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr) catch null) |layer| {
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

pub fn createAnimation(self: *File) !usize {
    var animation = Animation.init(pixi.app.allocator, self.newAnimationID(), "New Animation", &[_]usize{}, 1.0) catch return error.FailedToCreateAnimation;

    if (self.editor.selected_sprites.count() > 0) {
        animation.frames = try pixi.app.allocator.alloc(usize, self.editor.selected_sprites.count());

        var iter = self.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
        var i: usize = 0;
        while (iter.next()) |sprite_index| : (i += 1) {
            animation.frames[i] = sprite_index;
        }
    }

    self.animations.append(pixi.app.allocator, animation) catch {
        dvui.log.err("Failed to append animation", .{});
    };
    return self.animations.len - 1;
}

pub fn duplicateAnimation(self: *File, index: usize) !usize {
    const animation = self.animations.slice().get(index);
    const new_name = try std.fmt.allocPrint(dvui.currentWindow().lifo(), "{s}_copy", .{animation.name});
    const new_animation = Animation.init(pixi.app.allocator, self.newAnimationID(), new_name, animation.frames, animation.fps) catch return error.FailedToDuplicateAnimation;
    self.animations.insert(pixi.app.allocator, index + 1, new_animation) catch {
        dvui.log.err("Failed to append animation", .{});
    };
    return index + 1;
}

pub fn deleteAnimation(self: *File, index: usize) !void {
    try self.deleted_animations.append(pixi.app.allocator, self.animations.slice().get(index));
    self.animations.orderedRemove(index);
    try self.history.append(.{ .animation_restore_delete = .{
        .action = .restore,
        .index = index,
    } });
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

    var json = std.array_list.Managed(u8).init(pixi.app.allocator);
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

pub fn savePng(self: *File, window: *dvui.Window) !void {
    if (self.editor.saving) return;
    self.editor.saving = true;

    // Write only the first layer, we shouldn't do anything with other layers
    try pixi.image.writeToPngResolution(self.layers.get(self.selected_layer_index).source, self.path, @intFromFloat(@round(window.natural_scale * 72.0 / 0.0254)));

    {
        const id_mutex = dvui.toastAdd(window, @src(), self.id, self.editor.canvas.id, pixi.dvui.toastDisplay, 2_000_000);
        const id = id_mutex.id;
        const message = std.fmt.allocPrint(window.arena(), "Saved {s} to disk", .{std.fs.path.basename(self.path)}) catch "Saved file";
        dvui.dataSetSlice(window, id, "_message", message);
        id_mutex.mutex.unlock();
    }

    self.editor.saving = false;
    self.history.bookmark = 0;
}

pub fn saveZip(self: *File, window: *dvui.Window) !void {
    if (self.editor.saving) return;
    self.editor.saving = true;
    var ext = try self.external(pixi.app.allocator);
    defer ext.deinit(pixi.app.allocator);
    const null_terminated_path = try pixi.editor.arena.allocator().dupeZ(u8, self.path);

    const zip_file = zip.zip_open(null_terminated_path.ptr, zip.ZIP_DEFAULT_COMPRESSION_LEVEL, 'w');

    if (zip_file) |z| {
        var json = std.array_list.Managed(u8).init(pixi.app.allocator);
        const writer = json.writer();
        const options = std.json.Stringify.Options{};

        const output = try std.json.Stringify.valueAlloc(pixi.app.allocator, ext, options);
        defer pixi.app.allocator.free(output);

        writer.writeAll(output) catch return error.CouldNotWriteZipFile;

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

                const image_name = try std.fmt.allocPrintSentinel(pixi.editor.arena.allocator(), "{s}.layer", .{layer.name}, 0);
                _ = zip.zip_entry_open(z, @as([*c]const u8, @ptrCast(image_name)));
                _ = zip.zip_entry_write(z, @ptrCast(layer.bytes().ptr), layer.bytes().len);
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

    self.editor.saving = false;
    self.history.bookmark = 0;
}

pub fn saveAsync(self: *File) !void {
    if (!self.dirty()) return;

    const ext = std.fs.path.extension(self.path);

    if (std.mem.eql(u8, ext, ".pixi")) {
        const thread = try std.Thread.spawn(.{}, saveZip, .{ self, dvui.currentWindow() });
        thread.detach();
    } else if (std.mem.eql(u8, ext, ".png")) {
        const thread = try std.Thread.spawn(.{}, savePng, .{ self, dvui.currentWindow() });
        thread.detach();
    }
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
        //animation.start = self.animations.items(.start)[i];
        //animation.length = self.animations.items(.length)[i];
        animation.frames = try allocator.dupe(usize, self.animations.items(.frames)[i]);
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
