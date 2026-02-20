const std = @import("std");
const pixi = @import("../pixi.zig");
const zip = @import("zip");
const dvui = @import("dvui");

const Editor = pixi.Editor;

const File = @This();

const Layer = @import("Layer.zig");
const Sprite = @import("Sprite.zig");
const Animation = @import("Animation.zig");

const alpha_checkerboard_count: u32 = 8;

id: u64,
path: []const u8,

columns: u32 = 1,
rows: u32 = 1,
column_width: u32,
row_height: u32,

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
    // Only valid while file widget is drawing the file
    workspace: *pixi.Editor.Workspace = undefined,
    canvas: pixi.dvui.CanvasWidget = .{},
    layers_scroll_info: dvui.ScrollInfo = .{ .horizontal = .auto },
    sprites_scroll_info: dvui.ScrollInfo = .{ .horizontal = .auto },
    animations_scroll_info: dvui.ScrollInfo = .{ .horizontal = .auto },
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

    checkerboard: std.DynamicBitSet = undefined,
    checkerboard_tile: dvui.ImageSource = undefined,
};

pub const History = @import("History.zig");
pub const Buffers = @import("Buffers.zig");

pub const InitOptions = struct {
    columns: u32 = 1,
    rows: u32 = 1,
    column_width: u32,
    row_height: u32,
};

pub fn init(path: []const u8, options: InitOptions) !pixi.Internal.File {
    var internal: pixi.Internal.File = .{
        .id = pixi.editor.newFileID(),
        .path = try pixi.app.allocator.dupe(u8, path),
        .columns = options.columns,
        .rows = options.rows,
        .column_width = options.column_width,
        .row_height = options.row_height,
        .history = pixi.Internal.File.History.init(pixi.app.allocator),
        .buffers = pixi.Internal.File.Buffers.init(pixi.app.allocator),
    };

    // Initialize editor layers and selected sprites
    internal.editor.temporary_layer = try .init(internal.newLayerID(), "Temporary", internal.width(), internal.height(), .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .always);
    internal.editor.selection_layer = try .init(internal.newLayerID(), "Selection", internal.width(), internal.height(), .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr);
    internal.editor.transform_layer = try .init(internal.newLayerID(), "Transform", internal.width(), internal.height(), .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr);
    internal.editor.selected_sprites = try std.DynamicBitSet.initEmpty(pixi.app.allocator, internal.spriteCount());

    internal.editor.checkerboard = try std.DynamicBitSet.initEmpty(pixi.app.allocator, internal.width() * internal.height());
    // Create a layer-sized checkerboard pattern for selection tools
    for (0..internal.width() * internal.height()) |i| {
        const value = pixi.math.checker(.{ .w = @floatFromInt(internal.width()), .h = @floatFromInt(internal.height()) }, i);
        internal.editor.checkerboard.setValue(i, value);
    }

    // Initialize checkerboard tile image source
    {
        const alpha_width = alpha_checkerboard_count;
        const aspect_ratio = @as(f32, @floatFromInt(internal.column_width)) / @as(f32, @floatFromInt(internal.row_height));
        const alpha_height = @round(alpha_width / aspect_ratio);

        internal.editor.checkerboard_tile = pixi.image.init(
            alpha_width,
            std.math.clamp(2, @as(u32, @intFromFloat(alpha_height)), 1024),
            .{ .r = 0, .g = 0, .b = 0, .a = 0 },
            .ptr,
        ) catch return error.LayerCreateError;

        for (pixi.image.pixels(internal.editor.checkerboard_tile), 0..) |*pixel, i| {
            if (pixi.math.checker(pixi.image.size(internal.editor.checkerboard_tile), i)) {
                pixel.* = pixi.editor.settings.checker_color_even;
            } else {
                pixel.* = pixi.editor.settings.checker_color_odd;
            }
        }
        dvui.textureInvalidateCache(internal.editor.checkerboard_tile.hash());
    }

    {
        // Create a single layer for the file
        const layer: pixi.Internal.Layer = try .init(internal.newLayerID(), "Layer", internal.width(), internal.height(), .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr);
        internal.layers.append(pixi.app.allocator, layer) catch return error.LayerCreateError;
    }

    // Initialize sprites
    for (0..internal.spriteCount()) |_| {
        internal.sprites.append(pixi.app.allocator, .{
            .origin = .{ 0.0, 0.0 },
        }) catch return error.FileLoadError;
    }

    return internal;
}

pub fn width(file: *File) u32 {
    return file.columns * file.column_width;
}

pub fn height(file: *File) u32 {
    return file.rows * file.row_height;
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

    const null_terminated_path = try pixi.app.allocator.dupeZ(u8, path);
    defer pixi.app.allocator.free(null_terminated_path);

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
            if (std.json.parseFromSlice(pixi.File.FileV3, pixi.app.allocator, content, options) catch null) |old_file| {
                std.log.info("Loading file v3: {s}", .{path});
                const animations = try pixi.app.allocator.alloc(pixi.Animation, old_file.value.animations.len);
                for (animations, old_file.value.animations) |*animation, old_animation| {
                    animation.name = try pixi.app.allocator.dupe(u8, old_animation.name);
                    animation.frames = try pixi.app.allocator.alloc(Animation.Frame, old_animation.frames.len);
                    for (animation.frames, old_animation.frames) |*frame, old_frame| {
                        frame.sprite_index = old_frame;
                        frame.ms = @intFromFloat(1000 / old_animation.fps);
                    }
                }

                ext = .{
                    .version = old_file.value.version,
                    .columns = old_file.value.columns,
                    .rows = old_file.value.rows,
                    .column_width = old_file.value.column_width,
                    .row_height = old_file.value.row_height,
                    .layers = old_file.value.layers,
                    .sprites = old_file.value.sprites,
                    .animations = animations,
                };
            } else if (std.json.parseFromSlice(pixi.File.FileV2, pixi.app.allocator, content, options) catch null) |old_file| {
                std.log.info("Loading file v2: {s}", .{path});
                const animations = try pixi.app.allocator.alloc(pixi.Animation, old_file.value.animations.len);
                for (animations, old_file.value.animations) |*animation, old_animation| {
                    animation.name = try pixi.app.allocator.dupe(u8, old_animation.name);
                    animation.frames = try pixi.app.allocator.alloc(Animation.Frame, old_animation.frames.len);
                    for (animation.frames, old_animation.frames) |*frame, old_frame| {
                        frame.sprite_index = old_frame;
                        frame.ms = @intFromFloat(1000 / old_animation.fps);
                    }
                }

                ext = .{
                    .version = old_file.value.version,
                    .columns = @divExact(old_file.value.width, old_file.value.tile_width),
                    .rows = @divExact(old_file.value.height, old_file.value.tile_height),
                    .column_width = old_file.value.tile_width,
                    .row_height = old_file.value.tile_height,
                    .layers = old_file.value.layers,
                    .sprites = old_file.value.sprites,
                    .animations = animations,
                };
            } else if (std.json.parseFromSlice(pixi.File.FileV1, pixi.app.allocator, content, options) catch null) |old_file| {
                std.log.info("Loading file v1: {s}", .{path});
                const animations = try pixi.app.allocator.alloc(pixi.Animation, old_file.value.animations.len);
                for (animations, 0..) |*animation, i| {
                    animation.name = try pixi.app.allocator.dupe(u8, old_file.value.animations[i].name);
                    animation.frames = try pixi.app.allocator.alloc(Animation.Frame, old_file.value.animations[i].length);
                    for (animation.frames, 0..old_file.value.animations[i].length) |*frame, j| {
                        frame.sprite_index = old_file.value.animations[i].start + j;
                        frame.ms = @intFromFloat(1000 / old_file.value.animations[i].fps);
                    }
                }

                ext = .{
                    .version = old_file.value.version,
                    .columns = @divExact(old_file.value.width, old_file.value.tile_width),
                    .rows = @divExact(old_file.value.height, old_file.value.tile_height),
                    .column_width = old_file.value.tile_width,
                    .row_height = old_file.value.tile_height,
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
            .columns = ext.columns,
            .rows = ext.rows,
            .column_width = ext.column_width,
            .row_height = ext.row_height,
            .history = pixi.Internal.File.History.init(pixi.app.allocator),
            .buffers = pixi.Internal.File.Buffers.init(pixi.app.allocator),
        };

        //Initialize editor layers and selected sprites
        internal.editor.temporary_layer = try .init(internal.newLayerID(), "Temporary", internal.width(), internal.height(), .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr);
        internal.editor.selection_layer = try .init(internal.newLayerID(), "Selection", internal.width(), internal.height(), .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr);
        internal.editor.transform_layer = try .init(internal.newLayerID(), "Transform", internal.width(), internal.height(), .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr);
        internal.editor.selected_sprites = try std.DynamicBitSet.initEmpty(pixi.app.allocator, internal.spriteCount());

        internal.editor.checkerboard = try std.DynamicBitSet.initEmpty(pixi.app.allocator, internal.width() * internal.height());
        // Create a layer-sized checkerboard pattern for selection tools
        for (0..internal.width() * internal.height()) |i| {
            const value = pixi.math.checker(.{ .w = @floatFromInt(internal.width()), .h = @floatFromInt(internal.height()) }, i);
            internal.editor.checkerboard.setValue(i, value);
        }

        // Initialize checkerboard tile image source
        {
            const alpha_width = alpha_checkerboard_count;
            const aspect_ratio = @as(f32, @floatFromInt(internal.column_width)) / @as(f32, @floatFromInt(internal.row_height));
            const alpha_height = @round(alpha_width / aspect_ratio);

            internal.editor.checkerboard_tile = pixi.image.init(
                alpha_width,
                std.math.clamp(2, @as(u32, @intFromFloat(alpha_height)), 1024),
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
            //dvui.textureInvalidateCache(internal.editor.checkerboard_tile.hash());
        }

        var set_layer_index: bool = false;
        for (ext.layers, 0..) |l, i| {
            const layer_image_name = std.fmt.allocPrintSentinel(pixi.app.allocator, "{s}.layer", .{l.name}, 0) catch "Memory Allocation Failed";
            defer pixi.app.allocator.free(layer_image_name);
            const png_image_name = std.fmt.allocPrintSentinel(pixi.app.allocator, "{s}.png", .{l.name}, 0) catch "Memory Allocation Failed";
            defer pixi.app.allocator.free(png_image_name);

            var img_buf: ?*anyopaque = null;
            var img_len: usize = 0;

            if (zip.zip_entry_open(pixi_file, layer_image_name.ptr) == 0) { // Read layer file as directly pixels
                _ = zip.zip_entry_read(pixi_file, &img_buf, &img_len);
                const data = img_buf orelse continue;

                var new_layer: pixi.Internal.Layer = try .fromPixelsPMA(
                    internal.newLayerID(),
                    l.name,
                    @as([*]dvui.Color.PMA, @ptrCast(@constCast(data)))[0..(internal.width() * internal.height())],
                    internal.width(),
                    internal.height(),
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

        for (0..internal.spriteCount()) |sprite_index| {
            if (sprite_index >= ext.sprites.len) {
                internal.sprites.append(pixi.app.allocator, .{
                    .origin = .{ 0, 0 },
                }) catch return error.FileLoadError;
            } else {
                internal.sprites.append(pixi.app.allocator, .{
                    .origin = .{ ext.sprites[sprite_index].origin[0], ext.sprites[sprite_index].origin[1] },
                }) catch return error.FileLoadError;
            }
        }

        for (ext.animations) |animation| {
            internal.animations.append(pixi.app.allocator, .{
                .id = internal.newAnimationID(),
                .name = try pixi.app.allocator.dupe(u8, animation.name),
                .frames = try pixi.app.allocator.dupe(Animation.Frame, animation.frames),
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
    const column_width: u32 = @intFromFloat(size.w);
    const row_height: u32 = @intFromFloat(size.h);

    var internal: pixi.Internal.File = .{
        .id = pixi.editor.newFileID(),
        .path = try pixi.app.allocator.dupe(u8, path),
        .columns = 1,
        .rows = 1,
        .column_width = column_width,
        .row_height = row_height,
        .history = pixi.Internal.File.History.init(pixi.app.allocator),
        .buffers = pixi.Internal.File.Buffers.init(pixi.app.allocator),
    };

    internal.layers.append(pixi.app.allocator, png_layer) catch return error.LayerCreateError;

    // Initialize editor layers and selected sprites
    internal.editor.temporary_layer = try .init(internal.newLayerID(), "Temporary", internal.width(), internal.height(), .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr);
    internal.editor.selection_layer = try .init(internal.newLayerID(), "Selection", internal.width(), internal.height(), .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr);
    internal.editor.transform_layer = try .init(internal.newLayerID(), "Transform", internal.width(), internal.height(), .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr);
    internal.editor.selected_sprites = try std.DynamicBitSet.initEmpty(pixi.app.allocator, internal.spriteCount());

    internal.editor.checkerboard = try std.DynamicBitSet.initEmpty(pixi.app.allocator, internal.width() * internal.height());
    // Create a layer-sized checkerboard pattern for selection tools
    for (0..internal.width() * internal.height()) |i| {
        const value = pixi.math.checker(.{ .w = @floatFromInt(internal.width()), .h = @floatFromInt(internal.height()) }, i);
        internal.editor.checkerboard.setValue(i, value);
    }

    // Initialize checkerboard tile image source
    {
        const alpha_width = alpha_checkerboard_count;
        const aspect_ratio = @as(f32, @floatFromInt(internal.column_width)) / @as(f32, @floatFromInt(internal.row_height));
        const alpha_height = @round(alpha_width / aspect_ratio);

        internal.editor.checkerboard_tile = pixi.image.init(
            alpha_width,
            std.math.clamp(2, @as(u32, @intFromFloat(alpha_height)), 1024),
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
    }

    return internal;
}

pub const ResizeOptions = struct {
    columns: u32,
    rows: u32,
    history: bool = true, // If true, layer data will be recorded for undo/redo
    layer_data: ?[][][4]u8 = null, // If provided, the layer data will be applied to the layers after resizing
    animation_data: ?[][]pixi.Animation.Frame = null, // If provided, the animation data will be applied to the animations after resizing
    sprite_data: ?[][2]f32 = null, // If provided, the sprite data will be applied to the sprites after resizing
};

pub fn resize(file: *File, options: ResizeOptions) !void {
    const current_columns = file.columns;
    const current_rows = file.rows;

    if (options.columns == current_columns and
        options.rows == current_rows) return;

    if (options.columns == 0 or options.rows == 0) return error.InvalidImageSize;

    const new_columns = options.columns;
    const new_rows = options.rows;

    const new_width = new_columns * file.column_width;
    const new_height = new_rows * file.row_height;

    // First, record the current layer data for undo/redo
    if (options.history) {
        file.history.append(.{ .resize = .{ .width = file.width(), .height = file.height() } }) catch return error.HistoryAppendError;

        var layer_data = try pixi.app.allocator.alloc([][4]u8, file.layers.len);
        for (0..file.layers.len) |layer_index| {
            var layer = file.layers.get(layer_index);
            layer_data[layer_index] = pixi.app.allocator.dupe([4]u8, layer.pixels()) catch return error.MemoryAllocationFailed;
        }
        file.history.undo_layer_data_stack.append(layer_data) catch return error.MemoryAllocationFailed;

        // Store all the animations before the resize event
        var anim_data = try pixi.app.allocator.alloc([]pixi.Animation.Frame, file.animations.len);
        for (0..file.animations.len) |anim_index| {
            const animation = file.animations.get(anim_index);
            anim_data[anim_index] = pixi.app.allocator.dupe(pixi.Animation.Frame, animation.frames) catch return error.MemoryAllocationFailed;
        }
        file.history.undo_animation_data_stack.append(anim_data) catch return error.MemoryAllocationFailed;

        var sprite_data = try pixi.app.allocator.alloc([2]f32, file.spriteCount());
        for (0..file.spriteCount()) |sprite_index| {
            sprite_data[sprite_index] = file.sprites.items(.origin)[sprite_index];
        }
        file.history.undo_sprite_data_stack.append(sprite_data) catch return error.MemoryAllocationFailed;
    }

    if (options.animation_data) |anim_data| {
        for (0..file.animations.len) |anim_index| {
            var current_animation = file.animations.get(anim_index);
            const current_data = anim_data[anim_index];

            var new_animation = pixi.Internal.Animation.init(pixi.app.allocator, current_animation.id, current_animation.name, &.{}) catch return error.AnimationCreateError;
            defer file.animations.set(anim_index, new_animation);
            defer current_animation.deinit(pixi.app.allocator);
            for (current_data) |frame| {
                new_animation.appendFrame(pixi.app.allocator, .{ .sprite_index = frame.sprite_index, .ms = frame.ms }) catch return error.AnimationFrameAppendError;
            }
        }
    } else for (0..file.animations.len) |anim_index| {
        var animation = file.animations.get(anim_index);
        var new_animation = pixi.Internal.Animation.init(pixi.app.allocator, animation.id, animation.name, &.{}) catch return error.AnimationCreateError;
        defer file.animations.set(anim_index, new_animation);
        defer animation.deinit(pixi.app.allocator);
        for (0..animation.frames.len) |frame_index| {
            const old_sprite_index = animation.frames[frame_index].sprite_index;
            if (file.getResizedIndex(old_sprite_index, new_columns, new_rows)) |new_sprite_index| {
                new_animation.appendFrame(pixi.app.allocator, .{ .sprite_index = new_sprite_index, .ms = animation.frames[frame_index].ms }) catch return error.AnimationFrameAppendError;
            }
        }
    }

    file.sprites.resize(
        pixi.app.allocator,
        new_columns * new_rows,
    ) catch return error.MemoryAllocationFailed;

    // Read all sprite data into our sprites array
    if (options.sprite_data) |sprite_data| {
        for (0..file.spriteCount()) |sprite_index| {
            if (sprite_index >= sprite_data.len) break;
            const current_data = sprite_data[sprite_index];
            const new_origin: [2]f32 = .{ current_data[0], current_data[1] };
            file.sprites.items(.origin)[sprite_index] = new_origin;
        }
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
    file.editor.selected_sprites.resize(options.columns * options.rows, false) catch return error.MemoryAllocationFailed;

    file.editor.checkerboard.resize(new_width * new_height, false) catch return error.MemoryAllocationFailed;
    for (0..new_width * new_height) |i| {
        const value = pixi.math.checker(.{ .w = @floatFromInt(new_width), .h = @floatFromInt(new_height) }, i);
        file.editor.checkerboard.setValue(i, value);
    }

    file.columns = new_columns;
    file.rows = new_rows;
}

/// Returns the sprite index after a grid resize, or null if the cell is outside the new grid.
/// Index layout is row-major: index = row * columns + column.
pub fn getResizedIndex(
    self: *File,
    sprite_index: usize,
    new_columns: u32,
    new_rows: u32,
) ?usize {
    const old_col: u32 = @intCast(@mod(sprite_index, self.columns));
    const old_row: u32 = @intCast(@divTrunc(sprite_index, self.columns));

    if (old_row >= self.rows or old_col >= self.columns)
        return null;

    if (old_row < new_rows and old_col < new_columns) {
        return old_row * new_columns + old_col;
    } else {
        return null;
    }
}

/// Returns the sprite index after a drag-and-drop reorder of one column, row, or single cell.
/// For column/row: `removed_index` is the column/row that was dragged, `insert_before_index` is where it was dropped (before that column/row).
/// For cell: `removed_index` and `insert_before_index` are sprite indices (grid cell indices); returns where `sprite_index` ends up after the move.
pub fn getReorderedIndex(
    self: *File,
    removed_index: usize,
    insert_before_index: usize,
    orientation: enum { column, row, cell },
    sprite_index: usize,
) usize {
    if (removed_index == insert_before_index) return sprite_index;

    const insert_pos: usize = if (insert_before_index > removed_index)
        insert_before_index - 1
    else
        insert_before_index;

    const col: u32 = @intCast(@mod(sprite_index, self.columns));
    const row: u32 = @intCast(@divTrunc(sprite_index, self.columns));

    const pos_along: usize = switch (orientation) {
        .column => col,
        .row => row,
        .cell => sprite_index,
    };

    const new_pos_along: usize = if (pos_along == removed_index)
        insert_pos
    else blk: {
        const temp = if (pos_along < removed_index) pos_along else pos_along - 1;
        break :blk if (temp >= insert_pos) temp + 1 else temp;
    };

    return switch (orientation) {
        .column => row * self.columns + @as(u32, @intCast(new_pos_along)),
        .row => @as(u32, @intCast(new_pos_along)) * self.columns + col,
        .cell => new_pos_along,
    };
}

pub fn reorderColumns(file: *File, removed_column_index: usize, insert_before_column_index: usize) !void {
    if (removed_column_index == insert_before_column_index) return;
    if (removed_column_index > file.columns or insert_before_column_index > file.columns) return error.InvalidIndex;

    for (0..file.layers.len) |layer_index| {
        var layer = file.layers.get(layer_index);

        var insert_column_rect = file.columnRect(insert_before_column_index);
        var removed_column_rect = file.columnRect(removed_column_index);

        if (insert_before_column_index < removed_column_index) {
            var translate_rect = insert_column_rect;
            translate_rect.w = @as(f32, @floatFromInt(file.column_width)) * @as(f32, @floatFromInt(removed_column_index - insert_before_column_index));

            const translate_pixels = layer.pixelsFromRect(dvui.currentWindow().arena(), translate_rect) orelse return error.MemoryAllocationFailed;
            translate_rect.x += @as(f32, @floatFromInt(file.column_width));

            const removed_pixels = layer.pixelsFromRect(dvui.currentWindow().arena(), removed_column_rect) orelse return error.MemoryAllocationFailed;

            layer.blit(translate_pixels, translate_rect, .{ .transparent = false, .mask = false });
            layer.blit(removed_pixels, insert_column_rect, .{ .transparent = false, .mask = false });
        } else {
            var translate_rect = removed_column_rect.offsetPoint(.{ .x = @as(f32, @floatFromInt(file.column_width)) });
            translate_rect.w = @as(f32, @floatFromInt(file.column_width)) * @as(f32, @floatFromInt(insert_before_column_index - removed_column_index));

            const translate_pixels = layer.pixelsFromRect(dvui.currentWindow().arena(), translate_rect) orelse return error.MemoryAllocationFailed;
            translate_rect.x -= @as(f32, @floatFromInt(file.column_width));

            const removed_pixels = layer.pixelsFromRect(dvui.currentWindow().arena(), removed_column_rect) orelse return error.MemoryAllocationFailed;
            layer.blit(translate_pixels, translate_rect, .{ .transparent = false, .mask = false });
            layer.blit(removed_pixels, insert_column_rect.offsetPoint(.{ .x = -@as(f32, @floatFromInt(file.column_width)) }), .{ .transparent = false, .mask = false });
        }
    }

    for (file.animations.items(.frames)) |*frames| {
        for (frames.*) |*frame| {
            frame.sprite_index = file.getReorderedIndex(
                removed_column_index,
                insert_before_column_index,
                .column,
                frame.sprite_index,
            );
        }
    }

    var new_origins = try dvui.currentWindow().arena().dupe([2]f32, file.sprites.items(.origin));
    for (file.sprites.items(.origin), 0..) |*origin, sprite_index| {
        const reordered_index = file.getReorderedIndex(removed_column_index, insert_before_column_index, .column, sprite_index);

        if (reordered_index != sprite_index) {
            new_origins[reordered_index] = origin.*;
        }
    }

    for (new_origins, 0..) |origin, sprite_index| {
        file.sprites.items(.origin)[sprite_index] = origin;
    }
}

pub fn reorderRows(file: *File, removed_row_index: usize, insert_before_row_index: usize) !void {
    if (removed_row_index + 1 == insert_before_row_index) return;
    if (removed_row_index >= file.rows or insert_before_row_index > file.rows) return error.InvalidIndex;

    for (0..file.layers.len) |layer_index| {
        var layer = file.layers.get(layer_index);

        var insert_row_rect = file.rowRect(insert_before_row_index);
        var removed_row_rect = file.rowRect(removed_row_index);

        if (insert_before_row_index < removed_row_index) {
            var translate_rect = insert_row_rect;
            translate_rect.h = @as(f32, @floatFromInt(file.row_height)) * @as(f32, @floatFromInt(removed_row_index - insert_before_row_index));

            const translate_pixels = layer.pixelsFromRect(dvui.currentWindow().arena(), translate_rect) orelse return error.MemoryAllocationFailed;
            translate_rect.y += @as(f32, @floatFromInt(file.row_height));

            const removed_pixels = layer.pixelsFromRect(dvui.currentWindow().arena(), removed_row_rect) orelse return error.MemoryAllocationFailed;

            layer.blit(translate_pixels, translate_rect, .{ .transparent = false, .mask = false });
            layer.blit(removed_pixels, insert_row_rect, .{ .transparent = false, .mask = false });
        } else {
            var translate_rect = removed_row_rect.offsetPoint(.{ .y = @as(f32, @floatFromInt(file.row_height)) });
            translate_rect.h = @as(f32, @floatFromInt(file.row_height)) * @as(f32, @floatFromInt(insert_before_row_index - removed_row_index));

            const translate_pixels = layer.pixelsFromRect(dvui.currentWindow().arena(), translate_rect) orelse return error.MemoryAllocationFailed;
            translate_rect.y -= @as(f32, @floatFromInt(file.row_height));

            const removed_pixels = layer.pixelsFromRect(dvui.currentWindow().arena(), removed_row_rect) orelse return error.MemoryAllocationFailed;
            layer.blit(translate_pixels, translate_rect, .{ .transparent = false, .mask = false });
            layer.blit(removed_pixels, insert_row_rect.offsetPoint(.{ .y = -@as(f32, @floatFromInt(file.row_height)) }), .{ .transparent = false, .mask = false });
        }
    }

    for (file.animations.items(.frames)) |*frames| {
        for (frames.*) |*frame| {
            frame.sprite_index = file.getReorderedIndex(
                removed_row_index,
                insert_before_row_index,
                .row,
                frame.sprite_index,
            );
        }
    }

    var new_origins = try dvui.currentWindow().arena().dupe([2]f32, file.sprites.items(.origin));
    for (file.sprites.items(.origin), 0..) |*origin, sprite_index| {
        const reordered_index = file.getReorderedIndex(removed_row_index, insert_before_row_index, .row, sprite_index);

        if (reordered_index != sprite_index) {
            new_origins[reordered_index] = origin.*;
        }
    }

    for (new_origins, 0..) |origin, sprite_index| {
        file.sprites.items(.origin)[sprite_index] = origin;
    }
}

/// Returns a freshly allocated slice of length file.spriteCount() such that result[original_sprite_index]
/// is the new sprite index after applying the given reorder moves. Caller owns the returned memory.
/// Use this to preview reorder(file, removed_sprite_indices, insert_before_sprite_indices) without modifying the file.
pub fn getReorderIndices(
    file: *File,
    allocator: std.mem.Allocator,
    removed_sprite_indices: []const usize,
    insert_before_sprite_indices: []const usize,
) ![]usize {
    if (removed_sprite_indices.len == 0 or insert_before_sprite_indices.len == 0) return error.InvalidReorderSlices;
    if (removed_sprite_indices.len != insert_before_sprite_indices.len) return error.InvalidReorderSlices;

    const total = file.spriteCount();

    var order = try allocator.alloc(usize, total);
    defer allocator.free(order);
    for (0..total) |i| order[i] = i;

    // removed_sprite_indices are original sprite ids; insert_before_sprite_indices are target positions (where each sprite should end up) in current layout.
    for (removed_sprite_indices, insert_before_sprite_indices) |r_orig, b| {
        if (r_orig == b) continue;
        var r_current: usize = 0;
        while (order[r_current] != r_orig) : (r_current += 1) {}

        const removed_elem = order[r_current];
        for (r_current + 1..total) |i| {
            order[i - 1] = order[i];
        }
        const insert_at = if (b > r_current) b - 1 else b;
        var i = total - 1;
        while (i > insert_at) : (i -= 1) {
            order[i] = order[i - 1];
        }
        order[insert_at] = removed_elem;
    }

    const new_index = try allocator.alloc(usize, total);
    for (order, 0..) |orig, pos| {
        new_index[orig] = pos;
    }
    return new_index;
}

/// Reorders sprites by applying a batch of moves. Each move is (removed_sprite_indices[i], insert_before_sprite_indices[i]):
/// remove the sprite at that position and insert it before the other. Moves are applied sequentially in slice order.
/// Uses cycle-following with two cell buffers per layer so no full-layer copy is needed.
pub fn reorder(file: *File, removed_sprite_indices: []const usize, insert_before_sprite_indices: []const usize) !void {
    if (removed_sprite_indices.len == 0) return;
    if (insert_before_sprite_indices.len == 0) return;
    if (removed_sprite_indices.len != insert_before_sprite_indices.len) return error.InvalidReorderSlices;

    const total = file.spriteCount();
    if (removed_sprite_indices.len != insert_before_sprite_indices.len) return error.InvalidReorderSlices;

    for (removed_sprite_indices, insert_before_sprite_indices) |r, b| {
        if (r >= total or b > total) return error.InvalidIndex;
    }

    const arena = dvui.currentWindow().arena();

    // order[position] = original sprite index that ends up at that position after all moves
    const order = try arena.alloc(usize, total);
    for (0..total) |i| order[i] = i;

    // removed_sprite_indices are original sprite ids; insert_before_sprite_indices are target positions in current layout.
    for (removed_sprite_indices, insert_before_sprite_indices) |r_orig, b| {
        if (r_orig == b) continue;
        var r_current: usize = 0;
        while (order[r_current] != r_orig) : (r_current += 1) {}

        const removed_elem = order[r_current];
        for (r_current + 1..total) |i| {
            order[i - 1] = order[i];
        }
        const insert_at = if (b > r_current) b - 1 else b;
        var i = total - 1;
        while (i > insert_at) : (i -= 1) {
            order[i] = order[i - 1];
        }
        order[insert_at] = removed_elem;
    }

    // new_index[original] = final position of that original index
    const new_index = try arena.alloc(usize, total);
    for (order, 0..) |orig, pos| {
        new_index[orig] = pos;
    }

    // Apply permutation to each layer using cycle-following (two cell buffers: carry + read-before-write)
    for (0..file.layers.len) |layer_index| {
        var layer = file.layers.get(layer_index);
        var visited = try arena.alloc(bool, total);
        @memset(visited, false);

        for (0..total) |i_0| {
            if (visited[i_0]) continue;
            const to_fill = new_index[i_0];
            if (to_fill == i_0) {
                visited[i_0] = true;
                continue;
            }
            // Rotate cycle: i0 -> to_fill -> ... -> i0. Buffer holds content to write at current position.
            var buffer = layer.pixelsFromRect(arena, file.spriteRect(i_0)) orelse return error.MemoryAllocationFailed;
            layer.blit(
                layer.pixelsFromRect(arena, file.spriteRect(order[i_0])) orelse return error.MemoryAllocationFailed,
                file.spriteRect(i_0),
                .{ .transparent = false, .mask = false },
            );
            visited[i_0] = true;
            var pos = to_fill;
            while (pos != i_0) {
                visited[pos] = true;
                const save = layer.pixelsFromRect(arena, file.spriteRect(pos)) orelse return error.MemoryAllocationFailed;
                layer.blit(buffer, file.spriteRect(pos), .{ .transparent = false, .mask = false });
                buffer = save;
                pos = new_index[order[pos]];
            }
            layer.blit(buffer, file.spriteRect(i_0), .{ .transparent = false, .mask = false });
        }
    }

    for (file.animations.items(.frames)) |*frames| {
        for (frames.*) |*frame| {
            frame.sprite_index = new_index[frame.sprite_index];
        }
    }

    var new_origins = try arena.dupe([2]f32, file.sprites.items(.origin));
    for (file.sprites.items(.origin), 0..) |*origin, sprite_index| {
        new_origins[new_index[sprite_index]] = origin.*;
    }
    for (new_origins, 0..) |origin, sprite_index| {
        file.sprites.items(.origin)[sprite_index] = origin;
    }
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

    file.editor.temporary_layer.deinit();
    file.editor.selection_layer.deinit();
    file.editor.transform_layer.deinit();

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
    const column = @divTrunc(@as(i32, @intFromFloat(point.x)), @as(i32, @intCast(file.column_width)));
    const row = @divTrunc(@as(i32, @intFromFloat(point.y)), @as(i32, @intCast(file.row_height)));

    return .{
        .x = @as(f32, @floatFromInt(column * @as(i32, @intCast(file.column_width)))),
        .y = @as(f32, @floatFromInt(row * @as(i32, @intCast(file.row_height)))),
    };
}

pub fn spriteCount(file: *File) usize {
    return file.columns * file.rows;
}

pub fn spriteIndex(file: *File, point: dvui.Point) ?usize {
    if (!file.editor.canvas.dataFromScreenRect(file.editor.canvas.rect).contains(point)) return null;

    const tiles_wide = @divExact(file.width(), file.column_width);

    const column = @divTrunc(@as(u32, @intFromFloat(point.x)), file.column_width);
    const row = @divTrunc(@as(u32, @intFromFloat(point.y)), file.row_height);

    return row * tiles_wide + column;
}

pub const SpriteName = enum { index, animation, file, grid };

// Names sprites based o
pub fn fmtSprite(file: *File, allocator: std.mem.Allocator, sprite_index: usize, name_type: SpriteName) ![]const u8 {
    return switch (name_type) {
        .animation => blk: {
            for (file.animations.items(.frames), 0..) |frames, animation_index| {
                for (frames) |frame| {
                    if (frame.sprite_index != sprite_index) continue;

                    if (frames.len > 1) {
                        break :blk std.fmt.allocPrint(allocator, "{s}_{d}", .{ file.animations.items(.name)[animation_index], animation_index }) catch return error.MemoryAllocationFailed;
                    } else {
                        break :blk std.fmt.allocPrint(allocator, "{s}", .{file.animations.items(.name)[animation_index]}) catch return error.MemoryAllocationFailed;
                    }
                }
            }

            break :blk std.fmt.allocPrint(allocator, "{d}", .{sprite_index}) catch return error.MemoryAllocationFailed;
        },
        .file => std.fmt.allocPrint(allocator, "{s}_{s}_{d}", .{ std.fs.path.basename(file.path), file.layers.items(.name)[file.selected_layer_index], sprite_index }) catch return error.MemoryAllocationFailed,
        .index => std.fmt.allocPrint(allocator, "{d}", .{sprite_index}) catch return error.MemoryAllocationFailed,
        .grid => std.fmt.allocPrint(allocator, "{s}{d}", .{ try fmtColumn(file, allocator, file.columnFromIndex(sprite_index)), file.rowFromIndex(sprite_index) }) catch return error.MemoryAllocationFailed,
    };
}

pub fn fmtColumn(_: *File, allocator: std.mem.Allocator, column: u32) ![]const u8 {
    // Excel-style: 0 -> A, 1 -> B, ... 25 -> Z, 26 -> AA, 27 -> AB, etc.
    var temp: [10]u8 = undefined; // Enough for absurdly large columns (> 1 billion)
    var len: usize = 0;

    var idx = column;
    while (true) {
        const rem = idx % 26;
        temp[9 - len] = std.ascii.uppercase[rem];
        len += 1;
        if (idx < 26) break;
        // Adjust for 1-based carryover because Excel-style is nonzero-based
        idx = idx / 26 - 1;
    }
    const start = 10 - len;
    const fmt = allocator.alloc(u8, len) catch return error.MemoryAllocationFailed;
    @memcpy(fmt, temp[start .. start + len]);
    return fmt;
}

pub fn columnFromIndex(file: *File, index: usize) u32 {
    return @mod(@as(u32, @intCast(index)), file.columns);
}

pub fn rowFromIndex(file: *File, index: usize) u32 {
    return @divTrunc(@as(u32, @intCast(index)), file.columns);
}

pub fn columnFromPixel(file: *File, pixel: dvui.Point) u32 {
    return @mod(@as(u32, @intFromFloat(pixel.x)), file.column_width);
}

pub fn rowFromPixel(file: *File, pixel: dvui.Point) u32 {
    return @divTrunc(@as(u32, @intFromFloat(pixel.y)), file.row_height);
}

pub fn spriteRect(file: *File, index: usize) dvui.Rect {
    const column = file.columnFromIndex(index);
    const row = file.rowFromIndex(index);

    const out: dvui.Rect = .{
        .x = @as(f32, @floatFromInt(column)) * @as(f32, @floatFromInt(file.column_width)),
        .y = @as(f32, @floatFromInt(row)) * @as(f32, @floatFromInt(file.row_height)),
        .w = @as(f32, @floatFromInt(file.column_width)),
        .h = @as(f32, @floatFromInt(file.row_height)),
    };
    return out;
}

pub fn columnRect(file: *File, column_index: usize) dvui.Rect {
    return .{
        .x = @as(f32, @floatFromInt(column_index)) * @as(f32, @floatFromInt(file.column_width)),
        .y = 0,
        .w = @as(f32, @floatFromInt(file.column_width)),
        .h = @as(f32, @floatFromInt(file.height())),
    };
}

pub fn columnIndex(file: *File, point: dvui.Point) ?usize {
    if (point.x < 0 or point.x >= @as(f32, @floatFromInt(file.width()))) return null;
    if (point.y < 0 or point.y >= @as(f32, @floatFromInt(file.height()))) return null;
    const index = @divTrunc(@as(usize, @intFromFloat(point.x)), file.column_width);
    if (index >= file.columns) return null;
    return index;
}

pub fn rowIndex(file: *File, point: dvui.Point) ?usize {
    if (point.x < 0 or point.x >= @as(f32, @floatFromInt(file.width()))) return null;
    if (point.y < 0 or point.y >= @as(f32, @floatFromInt(file.height()))) return null;
    const index = @divTrunc(@as(usize, @intFromFloat(point.y)), file.row_height);
    if (index >= file.rows) return null;
    return index;
}

pub fn rowRect(file: *File, row_index: usize) dvui.Rect {
    return .{
        .x = 0,
        .y = @as(f32, @floatFromInt(row_index)) * @as(f32, @floatFromInt(file.row_height)),
        .w = @as(f32, @floatFromInt(file.width())),
        .h = @as(f32, @floatFromInt(file.row_height)),
    };
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

    if (point.x < 0 or point.x >= @as(f32, @floatFromInt(file.width())) or point.y < 0 or point.y >= @as(f32, @floatFromInt(file.height()))) {
        return;
    }

    const column = file.columnFromPixel(point);
    const row = file.rowFromPixel(point);

    const min_x: f32 = @as(f32, @floatFromInt(column)) * @as(f32, @floatFromInt(file.column_width));
    const min_y: f32 = @as(f32, @floatFromInt(row)) * @as(f32, @floatFromInt(file.row_height));

    const max_x: f32 = min_x + @as(f32, @floatFromInt(file.column_width));
    const max_y: f32 = min_y + @as(f32, @floatFromInt(file.row_height));

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

    if (point1.x < 0 or point1.x >= @as(f32, @floatFromInt(file.width())) or point1.y < 0 or point1.y >= @as(f32, @floatFromInt(file.height()))) {
        return;
    }

    if (point2.x < 0 or point2.x >= @as(f32, @floatFromInt(file.width())) or point2.y < 0 or point2.y >= @as(f32, @floatFromInt(file.height()))) {
        return;
    }

    const column = file.columnFromPixel(point2);
    const row = file.rowFromPixel(point2);

    const min_x: f32 = @as(f32, @floatFromInt(column)) * @as(f32, @floatFromInt(file.column_width));
    const min_y: f32 = @as(f32, @floatFromInt(row)) * @as(f32, @floatFromInt(file.row_height));

    const max_x: f32 = min_x + @as(f32, @floatFromInt(file.column_width));
    const max_y: f32 = min_y + @as(f32, @floatFromInt(file.row_height));

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

    if (point.x < 0 or point.x >= @as(f32, @floatFromInt(file.width())) or point.y < 0 or point.y >= @as(f32, @floatFromInt(file.height()))) {
        return;
    }

    const mask_value: bool = draw_options.color.a != 0;

    const column = file.columnFromPixel(point);
    const row = file.rowFromPixel(point);

    const min_x: f32 = @as(f32, @floatFromInt(column)) * @as(f32, @floatFromInt(file.column_width));
    const min_y: f32 = @as(f32, @floatFromInt(row)) * @as(f32, @floatFromInt(file.row_height));

    const max_x: f32 = min_x + @as(f32, @floatFromInt(file.column_width));
    const max_y: f32 = min_y + @as(f32, @floatFromInt(file.row_height));

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

    if (point1.x < 0 or point1.x >= @as(f32, @floatFromInt(file.width())) or point1.y < 0 or point1.y >= @as(f32, @floatFromInt(file.height()))) {
        return;
    }

    if (point2.x < 0 or point2.x >= @as(f32, @floatFromInt(file.width())) or point2.y < 0 or point2.y >= @as(f32, @floatFromInt(file.height()))) {
        return;
    }

    const mask_value: bool = draw_options.color.a != 0;

    const column = file.columnFromPixel(point2);
    const row = file.rowFromPixel(point2);

    const min_x: f32 = @as(f32, @floatFromInt(column)) * @as(f32, @floatFromInt(file.column_width));
    const min_y: f32 = @as(f32, @floatFromInt(row)) * @as(f32, @floatFromInt(file.row_height));

    const max_x: f32 = min_x + @as(f32, @floatFromInt(file.column_width));
    const max_y: f32 = min_y + @as(f32, @floatFromInt(file.row_height));

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

    if (point.x < 0 or point.x >= @as(f32, @floatFromInt(file.width())) or point.y < 0 or point.y >= @as(f32, @floatFromInt(file.height()))) {
        return;
    }

    if (fill_options.replace) {
        if (active_layer.pixel(point)) |c| {
            active_layer.clearMask();
            active_layer.setMaskFromColor(.{ .r = c[0], .g = c[1], .b = c[2], .a = c[3] }, true);
        }
    } else {
        active_layer.clearMask();
        active_layer.floodMaskPoint(point, .fromSize(.{ .w = @as(f32, @floatFromInt(file.width())), .h = @as(f32, @floatFromInt(file.height())) }), true) catch {
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

    var new_layer = Layer.init(self.newLayerID(), new_name, self.width(), self.height(), .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr) catch return error.FailedToDuplicateLayer;
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
    if (pixi.Internal.Layer.init(self.newLayerID(), "New Layer", self.width(), self.height(), .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr) catch null) |layer| {
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
    var animation = Animation.init(
        pixi.app.allocator,
        self.newAnimationID(),
        "New Animation",
        &[_]Animation.Frame{},
    ) catch return error.FailedToCreateAnimation;

    if (self.editor.selected_sprites.count() > 0) {
        animation.frames = try pixi.app.allocator.alloc(Animation.Frame, self.editor.selected_sprites.count());

        var iter = self.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
        var i: usize = 0;
        while (iter.next()) |sprite_index| : (i += 1) {
            animation.frames[i] = .{ .sprite_index = sprite_index, .ms = @intFromFloat(1000.0 / @as(f32, @floatFromInt(self.editor.selected_sprites.count()))) };
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
    const new_animation = Animation.init(pixi.app.allocator, self.newAnimationID(), new_name, animation.frames) catch return error.FailedToDuplicateAnimation;
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
    //if (!self.dirty()) return;

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
        sprite.origin = self.sprites.items(.origin)[i];
    }

    for (animations, 0..) |*animation, i| {
        animation.name = try allocator.dupe(u8, self.animations.items(.name)[i]);
        animation.frames = try allocator.dupe(Animation.Frame, self.animations.items(.frames)[i]);
    }

    return .{
        .version = pixi.version,
        .columns = self.columns,
        .rows = self.rows,
        .column_width = self.column_width,
        .row_height = self.row_height,
        .layers = layers,
        .sprites = sprites,
        .animations = animations,
    };
}
