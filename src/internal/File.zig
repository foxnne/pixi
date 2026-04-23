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

/// Deferred brush snapshot is skipped above this area (width×height); drawing falls back to per-pixel stroke recording.
pub const stroke_undo_max_snapshot_pixels: u64 = 16 * 1024 * 1024;

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

    /// Flattened visible-layer stack cached as a render target.
    /// Reused across frames; rebuilt only when content or structure changes.
    layer_composite_target: ?dvui.Texture.Target = null,
    layer_composite_frame_built: u64 = 0,
    layer_composite_dirty: bool = true,

    /// Split composites for use during active drawing. The "below" target
    /// contains all visible layers below the active layer; the "above" target
    /// contains all visible layers above it. This avoids per-layer draws
    /// without requiring per-frame render target switches.
    split_composite_below: ?dvui.Texture.Target = null,
    split_composite_above: ?dvui.Texture.Target = null,
    split_composite_layer: ?usize = null,
    split_composite_dirty: bool = true,
    split_composite_frame_built: u64 = 0,

    /// Tracks when the active layer transparency mask was last built,
    /// so we can skip rebuilding it when the layer hasn't changed.
    mask_built_for_layer: ?usize = null,
    mask_built_source_hash: u64 = 0,

    /// Pixel region written by the last temp layer brush preview. Used to
    /// cheaply clear only the affected area instead of memset-ing the full
    /// 64 MB buffer each frame.
    temp_preview_dirty_rect: ?dvui.Rect = null,
    /// True when the temp layer contains any non-zero content (brush preview,
    /// selection visualization, etc.) and needs clearing next frame.
    temp_layer_has_content: bool = false,
    /// Accumulated region of the temp layer whose CPU pixels differ from the
    /// GPU texture. Persists across frames until flushed via sub-rect upload
    /// in renderLayers, so stale GPU data is always cleaned up.
    temp_gpu_dirty_rect: ?dvui.Rect = null,
    /// True while a stroke drag is in progress (mouse pressed and captured).
    active_drawing: bool = false,
    /// Accumulated dirty rect for the active layer during the current frame.
    /// Used to perform a sub-rect texture upload instead of a full invalidate.
    active_layer_dirty_rect: ?dvui.Rect = null,

    /// While true, brush painting skips per-pixel `buffers.stroke.append` during the drag; the
    /// pre-stroke region is snapshotted and diffed on commit (mouse release) instead.
    stroke_undo_deferred: bool = false,
    /// Row-major RGBA snapshot for `stroke_undo_{x,y,w,h}` (length `w * h * 4`).
    stroke_undo_pixels: ?[]u8 = null,
    stroke_undo_x: u32 = 0,
    stroke_undo_y: u32 = 0,
    stroke_undo_w: u32 = 0,
    stroke_undo_h: u32 = 0,

    /// Layer list reorder preview while dragging in the tree (`null` = no preview). Matches drop logic in `explorer/tools.zig`.
    layer_drag_preview_removed: ?usize = null,
    layer_drag_preview_insert_before: ?usize = null,

    /// Multi-selection for the layer list. Sorted, deduplicated. Lazily seeded with the primary
    /// `selected_layer_index` on first click gesture; the tree's drop handler uses this set to
    /// move multiple selected layers as a group. The primary index must always be present (the
    /// editor cannot have zero selected layers).
    selected_layer_indices: std.ArrayListUnmanaged(usize) = .empty,
    layer_selection_anchor: ?usize = null,

    /// Multi-selection for the animation list. Sorted, deduplicated. Empty iff no animation is
    /// selected; otherwise always contains the primary `selected_animation_index`.
    selected_animation_indices: std.ArrayListUnmanaged(usize) = .empty,
    animation_selection_anchor: ?usize = null,

    /// Multi-selection for the frame list of the currently selected animation. Cleared and
    /// reseeded whenever the primary animation changes. `..._for_animation_id` tracks which
    /// animation the set belongs to so stale selections are discarded cheaply.
    selected_frame_indices: std.ArrayListUnmanaged(usize) = .empty,
    selected_frame_indices_for_animation_id: u64 = 0,
    frame_selection_anchor: ?usize = null,
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

pub fn width(file: *const File) u32 {
    return file.columns * file.column_width;
}

pub fn height(file: *const File) u32 {
    return file.rows * file.row_height;
}

/// Clears the cached per-layer transparency mask used by the selection overlay (`FileWidget.updateActiveLayerMask`).
/// Call after any in-memory edit to layer pixels while `ImageSource.hash()` is pointer-based and does not
/// change when bytes change (see also `Transform.accept` / undo-redo).
pub fn invalidateActiveLayerTransparencyMaskCache(file: *File) void {
    file.editor.mask_built_for_layer = null;
}

/// Fills `out[0..len]` with storage indices in list order (position 0 = top row / front of stack)
/// after moving the layer at `removed` to sit before `insert_before`, matching `explorer/tools.zig` drop handling.
pub fn layerOrderAfterMove(len: usize, removed: usize, insert_before: usize, out: []usize) void {
    std.debug.assert(out.len >= len);
    std.debug.assert(removed < len);
    std.debug.assert(insert_before <= len);
    if (removed == insert_before) {
        for (0..len) |i| out[i] = i;
        return;
    }
    const insert_pos = if (removed < insert_before) insert_before - 1 else insert_before;
    var tmp: [1024]usize = undefined;
    std.debug.assert(len <= tmp.len);
    var m: usize = 0;
    for (0..len) |i| {
        if (i == removed) continue;
        tmp[m] = i;
        m += 1;
    }
    var ti: usize = 0;
    for (0..len) |dst| {
        if (dst == insert_pos) {
            out[dst] = removed;
        } else {
            out[dst] = tmp[ti];
            ti += 1;
        }
    }
}

/// Attempts to load a file from the given path to create a new file
pub fn fromPath(path: []const u8) !?pixi.Internal.File {
    const extension = std.fs.path.extension(path[0..path.len]);
    if (isFlatImageExtension(extension)) {
        const file = fromPathFlatImage(path) catch |err| {
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
        // .ptr: same as new-file init — GPU sync via invalidate / temp_gpu_dirty_rect + updateSubRect.
        // .always would re-upload the full texture on every getTexture() (e.g. sprite panel reflection).
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

fn isFlatImageExtension(ext: []const u8) bool {
    return std.mem.eql(u8, ext, ".png") or
        std.mem.eql(u8, ext, ".jpg") or
        std.mem.eql(u8, ext, ".jpeg");
}

/// Loads a PNG or JPEG as the first layer of a new file, and retains the path
/// when saved; layers will be flattened to that file
pub fn fromPathFlatImage(path: []const u8) !?pixi.Internal.File {
    if (!isFlatImageExtension(std.fs.path.extension(path[0..path.len])))
        return error.InvalidExtension;

    var image_layer: pixi.Internal.Layer = try pixi.Internal.Layer.fromImageFilePath(pixi.editor.newFileID(), "Layer", path, .ptr);
    const size = image_layer.size();
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

    internal.layers.append(pixi.app.allocator, image_layer) catch return error.LayerCreateError;

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

    const old_sprite_count = current_columns * current_rows;
    const new_sprite_count = new_columns * new_rows;

    var old_origins_snapshot: ?[][2]f32 = null;
    defer if (old_origins_snapshot) |s| pixi.app.allocator.free(s);

    if (options.sprite_data == null) {
        const snapshot = try pixi.app.allocator.alloc([2]f32, old_sprite_count);
        for (0..old_sprite_count) |i| {
            snapshot[i] = file.sprites.items(.origin)[i];
        }
        old_origins_snapshot = snapshot;
    }

    file.sprites.resize(
        pixi.app.allocator,
        new_sprite_count,
    ) catch return error.MemoryAllocationFailed;

    // MultiArrayList growth leaves new elements undefined; zero everything then restore from undo data or remaps.
    for (0..new_sprite_count) |i| {
        file.sprites.items(.origin)[i] = .{ 0, 0 };
    }

    if (options.sprite_data) |sprite_data| {
        const n = @min(new_sprite_count, sprite_data.len);
        for (0..n) |sprite_index| {
            const d = sprite_data[sprite_index];
            file.sprites.items(.origin)[sprite_index] = .{ d[0], d[1] };
        }
    } else {
        const old_origins = old_origins_snapshot orelse unreachable;
        for (0..old_sprite_count) |old_i| {
            if (getResizedIndex(file, old_i, new_columns, new_rows)) |new_i| {
                file.sprites.items(.origin)[new_i] = old_origins[old_i];
            }
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

const SpriteReorderMode = enum {
    replace,
    insert,
};

pub const CellMovePair = struct {
    remove: usize,
    insert: usize,
};

pub const CellSorting = struct {
    pub fn asc(_: void, a: CellMovePair, b: CellMovePair) bool {

        // This below line makes the sorting logic work correctly, but crashes when moving outside of the bounds sometimes.
        if (a.remove > a.insert and b.remove > b.insert) return a.remove < b.remove else if (a.remove < a.insert and b.remove < b.insert) return a.remove > b.remove;

        // This removes the crashing, and works for all cases, except for when moving a set forward (increasing index from removed to insert) and overlapping with the removed set.
        if ((a.remove > a.insert and b.remove > b.insert) or (a.remove < a.insert and b.remove < b.insert)) {
            return a.remove < b.remove;
        }
        return a.remove > a.insert;
    }

    pub fn desc(_: void, a: CellMovePair, b: CellMovePair) bool {
        return if (a.remove < a.insert) a.remove < b.remove else a.remove > b.remove;
    }
};

/// Returns a freshly allocated slice of length file.spriteCount() such that result[original_sprite_index]
/// is the new sprite index after applying the given reorder moves. Caller owns the returned memory.
pub fn getReorderIndices(
    file: *File,
    allocator: std.mem.Allocator,
    removed_sprite_indices: []const usize,
    insert_before_sprite_indices: []const usize,
    mode: SpriteReorderMode,
    reverse: bool,
) ![]usize {
    if (removed_sprite_indices.len == 0 or insert_before_sprite_indices.len == 0) return error.InvalidReorderSlices;
    if (removed_sprite_indices.len != insert_before_sprite_indices.len) return error.InvalidReorderSlices;

    const sprite_count = file.spriteCount();
    if (removed_sprite_indices.len > sprite_count) return error.InvalidReorderSlices;

    var order = try allocator.alloc(usize, sprite_count);
    defer allocator.free(order);
    for (0..sprite_count) |i| order[i] = i;

    var pairs = try dvui.currentWindow().arena().alloc(CellMovePair, removed_sprite_indices.len);
    for (0..removed_sprite_indices.len) |i| {
        pairs[i] = .{ .remove = removed_sprite_indices[i], .insert = insert_before_sprite_indices[i] };
    }

    std.mem.sort(CellMovePair, pairs, {}, CellSorting.asc);
    if (reverse) {
        std.mem.reverse(CellMovePair, pairs);
    }

    for (pairs) |pair| {
        if (mode == .insert) {
            dvui.ReorderWidget.reorderSlice(usize, order, pair.remove, pair.insert);
        } else {
            std.mem.swap(usize, &order[pair.remove], &order[pair.insert]);
        }
    }

    const reorder_indices = try allocator.alloc(usize, sprite_count);
    for (order, 0..) |order_index, i| {
        reorder_indices[order_index] = i;
    }

    return reorder_indices;
}

pub fn reorderCells(file: *File, removed_sprite_indices: []const usize, insert_before_sprite_indices: []const usize, mode: SpriteReorderMode, reverse: bool) !void {
    const arena = dvui.currentWindow().arena();
    const new_sprite_indices = try file.getReorderIndices(arena, removed_sprite_indices, insert_before_sprite_indices, mode, reverse);

    const sprite_count = new_sprite_indices.len;
    const layer_count = file.layers.len;

    var old_pixels_per_layer = try arena.alloc([]?[][4]u8, layer_count);
    for (old_pixels_per_layer) |*slice| slice.* = try arena.alloc(?[][4]u8, sprite_count);

    for (0..layer_count) |layer_index| {
        var layer = file.layers.get(layer_index);
        for (0..sprite_count) |i| {
            const new_sprite_index = new_sprite_indices[i];
            if (new_sprite_index != i) {
                const old_rect = file.spriteRect(i);
                old_pixels_per_layer[layer_index][i] = layer.pixelsFromRect(arena, old_rect);
            }
        }
    }

    for (0..layer_count) |layer_index| {
        var layer = file.layers.get(layer_index);
        for (0..sprite_count) |original_sprite_index| {
            const new_sprite_index = new_sprite_indices[original_sprite_index];
            if (new_sprite_index != original_sprite_index) {
                const src_pixels = old_pixels_per_layer[layer_index][original_sprite_index] orelse return error.MemoryAllocationFailed;
                const dst_rect = file.spriteRect(new_sprite_index);
                layer.blit(src_pixels, dst_rect, .{ .transparent = false, .mask = false });
            }
        }
    }

    for (file.animations.items(.frames)) |*frames| {
        for (frames.*) |*frame| {
            frame.sprite_index = new_sprite_indices[frame.sprite_index];
        }
    }

    var new_origins = try arena.dupe([2]f32, file.sprites.items(.origin));
    for (file.sprites.items(.origin), 0..) |origin, sprite_index| {
        const new_index = new_sprite_indices[sprite_index];
        if (new_index != sprite_index) {
            new_origins[new_index] = origin;
        }
    }
    for (new_origins, 0..) |origin, sprite_index| {
        file.sprites.items(.origin)[sprite_index] = origin;
    }

    if (file.editor.selected_sprites.count() > 0) {
        const selected_count = file.editor.selected_sprites.count();
        var old_indices = try arena.alloc(usize, selected_count);
        var idx: usize = 0;
        var iter = file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
        while (iter.next()) |old_index| {
            old_indices[idx] = old_index;
            idx += 1;
        }
        file.editor.selected_sprites.setRangeValue(.{ .start = 0, .end = sprite_count }, false);
        for (old_indices) |old_index| {
            file.editor.selected_sprites.set(new_sprite_indices[old_index]);
        }
    }
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

pub fn deinit(file: *File) void {
    pixi.render.destroyLayerCompositeResources(file);

    strokeUndoFreeSnapshot(file);

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

    file.editor.selected_layer_indices.deinit(pixi.app.allocator);
    file.editor.selected_animation_indices.deinit(pixi.app.allocator);
    file.editor.selected_frame_indices.deinit(pixi.app.allocator);

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

pub fn wrappedSpriteIndex(file: *File, point: dvui.Point) usize {
    if (file.spriteIndex(point)) |index| {
        return index;
    }
    // Point is outside bounds: wrap coordinates into [0, width) x [0, height)
    const w = @as(f32, @floatFromInt(file.width()));
    const h = @as(f32, @floatFromInt(file.height()));
    const wrapped_x = @mod(point.x, w);
    const wrapped_y = @mod(point.y, h);

    const tiles_wide = @divExact(file.width(), file.column_width);
    const column = @divTrunc(@as(u32, @intFromFloat(wrapped_x)), file.column_width);
    const row = @divTrunc(@as(u32, @intFromFloat(wrapped_y)), file.row_height);

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

/// Default base name (no extension) for exporting a single tile: `{file_stem}_{anim}_{frame_idx}` if the
/// sprite appears in an animation, else `{file_stem}_{grid}`. If `selected_animation_index` is set
/// and that animation contains the sprite, that animation and frame index are used; otherwise the
/// first matching animation in file order is used.
pub fn spriteExportName(file: *File, allocator: std.mem.Allocator, sprite_index: usize) ![]const u8 {
    const basename = std.fs.path.basename(file.path);
    const file_stem = std.fs.path.stem(basename);

    if (file.selected_animation_index) |ai| {
        const anim = file.animations.get(ai);
        for (anim.frames, 0..) |frame, fi| {
            if (frame.sprite_index == sprite_index) {
                return try std.fmt.allocPrint(allocator, "{s}_{s}_{d}", .{ file_stem, anim.name, fi });
            }
        }
    }

    for (file.animations.items(.frames), file.animations.items(.name), 0..) |frames, name, aidx| {
        _ = aidx;
        for (frames, 0..) |frame, fi| {
            if (frame.sprite_index == sprite_index) {
                return try std.fmt.allocPrint(allocator, "{s}_{s}_{d}", .{ file_stem, name, fi });
            }
        }
    }

    const grid = try file.fmtSprite(allocator, sprite_index, .grid);
    defer allocator.free(grid);
    return try std.fmt.allocPrint(allocator, "{s}_{s}", .{ file_stem, grid });
}

pub fn fmtColumn(_: *File, allocator: std.mem.Allocator, column: usize) ![]const u8 {
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

pub fn columnFromIndex(file: *File, index: usize) usize {
    return @mod(index, file.columns);
}

pub fn rowFromIndex(file: *File, index: usize) usize {
    return @divTrunc(index, file.columns);
}

pub fn columnFromPixel(file: *File, pixel: dvui.Point) usize {
    return @mod(@as(usize, @intFromFloat(pixel.x)), file.column_width);
}

pub fn rowFromPixel(file: *File, pixel: dvui.Point) usize {
    return @divTrunc(@as(usize, @intFromFloat(pixel.y)), file.row_height);
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

/// Collapse animation list multi-selection to the current primary only. Used when the primary is
/// set from the canvas/grid; the animation tree keeps multi-select via `applyAnimationClick`, but
/// those paths must not leave stale extra indices when the grid picks a new animation.
pub fn collapseAnimationSelectionToPrimary(file: *File) void {
    if (file.selected_animation_index) |p| {
        file.editor.selected_animation_indices.clearRetainingCapacity();
        file.editor.selected_animation_indices.append(pixi.app.allocator, p) catch return;
        file.editor.animation_selection_anchor = p;
    }
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

/// Selects every opaque pixel on the active layer inside the axis-aligned rectangle between `p1` and `p2` (inclusive).
pub fn selectRectBetweenPoints(file: *File, p1: dvui.Point, p2: dvui.Point, select_options: SelectOptions) void {
    const read_layer: Layer = file.layers.get(file.selected_layer_index);
    const selection_layer: *Layer = &file.editor.selection_layer;

    const x0: i32 = @intFromFloat(@floor(@min(p1.x, p2.x)));
    const y0: i32 = @intFromFloat(@floor(@min(p1.y, p2.y)));
    const x1: i32 = @intFromFloat(@floor(@max(p1.x, p2.x)));
    const y1: i32 = @intFromFloat(@floor(@max(p1.y, p2.y)));

    const iw: i32 = @intCast(file.width());
    const ih: i32 = @intCast(file.height());

    var py = y0;
    while (py <= y1) : (py += 1) {
        if (py < 0 or py >= ih) continue;
        var px = x0;
        while (px <= x1) : (px += 1) {
            if (px < 0 or px >= iw) continue;
            const pt: dvui.Point = .{ .x = @floatFromInt(px), .y = @floatFromInt(py) };
            if (selection_layer.pixelIndex(pt)) |idx| {
                if (read_layer.pixels()[idx][3] > 0) {
                    selection_layer.mask.setValue(idx, select_options.value);
                }
            }
        }
    }
}

/// Flood-selects or flood-deselects every pixel in the active layer that matches the color at `p`
/// (4-way contiguous region), same as bucket fill matching. `value` true adds to the selection mask, false removes.
pub fn selectColorFloodFromPoint(file: *File, p: dvui.Point, value: bool) !void {
    const read_layer = file.layers.get(file.selected_layer_index);
    const selection_layer: *Layer = &file.editor.selection_layer;

    const bounds = dvui.Rect.fromSize(.{ .w = @floatFromInt(file.width()), .h = @floatFromInt(file.height()) });
    if (!bounds.contains(p)) return;

    const start_idx = pixi.image.pixelIndex(read_layer.source, p) orelse return;
    const original_color = read_layer.pixels()[start_idx];

    const n = read_layer.pixels().len;
    if (selection_layer.mask.capacity() != n) return;

    var visited = try std.DynamicBitSet.initEmpty(pixi.app.allocator, n);
    defer visited.deinit();

    var queue = std.array_list.Managed(dvui.Point).init(pixi.app.allocator);
    defer queue.deinit();

    try queue.append(p);
    visited.set(start_idx);

    const directions: [4]dvui.Point = .{
        .{ .x = 0, .y = -1 },
        .{ .x = 0, .y = 1 },
        .{ .x = -1, .y = 0 },
        .{ .x = 1, .y = 0 },
    };

    while (queue.pop()) |qp| {
        const idx = pixi.image.pixelIndex(read_layer.source, qp) orelse continue;
        if (!std.meta.eql(original_color, read_layer.pixels()[idx])) continue;

        selection_layer.mask.setValue(idx, value);

        for (directions) |direction| {
            const np = qp.plus(direction);
            if (!bounds.contains(np)) continue;
            if (pixi.image.pixelIndex(read_layer.source, np)) |ni| {
                if (visited.isSet(ni)) continue;
                if (!std.meta.eql(original_color, read_layer.pixels()[ni])) continue;
                visited.set(ni);
                try queue.append(np);
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
    /// When set, only writes pixels inside this rect (data space). Used for temporary preview draws.
    clip_rect: ?dvui.Rect = null,
};

/// Computes the pixel bounding rect of a brush stamp, clamped to image bounds.
fn brushRect(point: dvui.Point, stroke_size: usize, img_w: u32, img_h: u32) dvui.Rect {
    const s: i32 = @intCast(stroke_size);
    const half: i32 = @divFloor(s, 2);
    const px: i32 = @intFromFloat(@floor(point.x));
    const py: i32 = @intFromFloat(@floor(point.y));
    const w: i32 = @intCast(img_w);
    const h: i32 = @intCast(img_h);
    const x0 = @max(px - half, 0);
    const y0 = @max(py - half, 0);
    const x1 = @min(px - half + s, w);
    const y1 = @min(py - half + s, h);
    return .{
        .x = @floatFromInt(x0),
        .y = @floatFromInt(y0),
        .w = @floatFromInt(@max(x1 - x0, 0)),
        .h = @floatFromInt(@max(y1 - y0, 0)),
    };
}

/// Expands the active layer dirty rect to include a new brush stamp region.
fn expandActiveLayerDirtyRect(file: *File, new_rect: dvui.Rect) void {
    if (file.editor.active_layer_dirty_rect) |existing| {
        file.editor.active_layer_dirty_rect = existing.unionWith(new_rect);
    } else {
        file.editor.active_layer_dirty_rect = new_rect;
    }
    file.editor.layer_composite_dirty = true;
}

fn intRectFromDvuiRect(r: dvui.Rect, img_w: u32, img_h: u32) struct { x: u32, y: u32, w: u32, h: u32 } {
    const x0 = @as(i32, @intFromFloat(@floor(r.x)));
    const y0 = @as(i32, @intFromFloat(@floor(r.y)));
    const x1 = @as(i32, @intFromFloat(@ceil(r.x + r.w)));
    const y1 = @as(i32, @intFromFloat(@ceil(r.y + r.h)));
    const wlim: i32 = @intCast(img_w);
    const hlim: i32 = @intCast(img_h);
    const ix0 = @max(x0, 0);
    const iy0 = @max(y0, 0);
    const ix1 = @min(x1, wlim);
    const iy1 = @min(y1, hlim);
    const cw: u32 = @intCast(@max(ix1 - ix0, 0));
    const ch: u32 = @intCast(@max(iy1 - iy0, 0));
    return .{ .x = @intCast(ix0), .y = @intCast(iy0), .w = cw, .h = ch };
}

/// Bounding box (clamped to image) that covers a brush stroke along the segment between two points.
pub fn lineBrushCoverRect(file: *const File, p1: dvui.Point, p2: dvui.Point, stroke_size: usize) dvui.Rect {
    const iw = file.width();
    const ih = file.height();
    const w: i32 = @intCast(iw);
    const h: i32 = @intCast(ih);
    const s: i32 = @intCast(stroke_size);
    const half = @divFloor(s, 2);
    const ix1 = @as(i32, @intFromFloat(@floor(p1.x)));
    const iy1 = @as(i32, @intFromFloat(@floor(p1.y)));
    const ix2 = @as(i32, @intFromFloat(@floor(p2.x)));
    const iy2 = @as(i32, @intFromFloat(@floor(p2.y)));
    const min_px = @min(ix1, ix2) - half;
    const min_py = @min(iy1, iy2) - half;
    const max_px = @max(ix1, ix2) - half + s;
    const max_py = @max(iy1, iy2) - half + s;
    const x0 = @max(min_px, 0);
    const y0 = @max(min_py, 0);
    const x1 = @min(max_px, w);
    const y1 = @min(max_py, h);
    return .{
        .x = @floatFromInt(x0),
        .y = @floatFromInt(y0),
        .w = @floatFromInt(@max(x1 - x0, 0)),
        .h = @floatFromInt(@max(y1 - y0, 0)),
    };
}

pub fn brushStampRect(file: *const File, point: dvui.Point, stroke_size: usize) dvui.Rect {
    return brushRect(point, stroke_size, file.width(), file.height());
}

fn strokeUndoFreeSnapshot(file: *File) void {
    if (file.editor.stroke_undo_pixels) |p| {
        pixi.app.allocator.free(p);
        file.editor.stroke_undo_pixels = null;
    }
    file.editor.stroke_undo_x = 0;
    file.editor.stroke_undo_y = 0;
    file.editor.stroke_undo_w = 0;
    file.editor.stroke_undo_h = 0;
    file.editor.stroke_undo_deferred = false;
}

/// Clears any prior snapshot and captures the current active layer pixels under `cover` (clamped).
pub fn strokeUndoBegin(file: *File, cover: dvui.Rect) !void {
    strokeUndoFreeSnapshot(file);

    const iw = file.width();
    const ih = file.height();
    const b = intRectFromDvuiRect(cover, iw, ih);
    if (b.w == 0 or b.h == 0) {
        return;
    }

    const snap_area = @as(u64, b.w) * @as(u64, b.h);
    if (snap_area > stroke_undo_max_snapshot_pixels) {
        return;
    }

    const n = @as(usize, b.w) * @as(usize, b.h) * 4;
    const buf = try pixi.app.allocator.alloc(u8, n);

    const layer = file.layers.get(file.selected_layer_index);
    const pix = layer.pixels();
    const stride: usize = @intCast(iw);
    var row: u32 = 0;
    while (row < b.h) : (row += 1) {
        const gy: usize = @intCast(b.y + row);
        const src_start: usize = gy * stride + @as(usize, b.x);
        const dst_start: usize = @as(usize, row) * @as(usize, b.w) * 4;
        const row_px: usize = @intCast(b.w);
        @memcpy(buf[dst_start..][0 .. row_px * 4], std.mem.sliceAsBytes(pix[src_start..][0..row_px]));
    }

    file.editor.stroke_undo_pixels = buf;
    file.editor.stroke_undo_x = b.x;
    file.editor.stroke_undo_y = b.y;
    file.editor.stroke_undo_w = b.w;
    file.editor.stroke_undo_h = b.h;
    file.editor.stroke_undo_deferred = true;
}

/// Grows the snapshot so it includes `cover` (copying newly exposed pixels from the layer before paint).
pub fn strokeUndoExpandToCoverRect(file: *File, cover: dvui.Rect) !void {
    if (!file.editor.stroke_undo_deferred) return;

    const old_buf = file.editor.stroke_undo_pixels orelse return;
    const iw = file.width();
    const ih = file.height();
    const ox = file.editor.stroke_undo_x;
    const oy = file.editor.stroke_undo_y;
    const ow = file.editor.stroke_undo_w;
    const oh = file.editor.stroke_undo_h;

    const nb = intRectFromDvuiRect(cover, iw, ih);
    if (nb.w == 0 or nb.h == 0) return;

    const tx: u32 = @min(ox, nb.x);
    const ty: u32 = @min(oy, nb.y);
    const tw: u32 = @max(ox + ow, nb.x + nb.w) - tx;
    const th: u32 = @max(oy + oh, nb.y + nb.h) - ty;

    if (tw == ow and th == oh and tx == ox and ty == oy) return;

    const new_n = @as(usize, tw) * @as(usize, th) * 4;
    const new_buf = try pixi.app.allocator.alloc(u8, new_n);

    const layer = file.layers.get(file.selected_layer_index);
    const pix = layer.pixels();
    const stride: usize = @intCast(iw);

    var gy: u32 = 0;
    while (gy < th) : (gy += 1) {
        var gx_off: u32 = 0;
        while (gx_off < tw) : (gx_off += 1) {
            const gx: u32 = tx + gx_off;
            const gyy: u32 = ty + gy;
            const dst: usize = (@as(usize, gy) * @as(usize, tw) + @as(usize, gx_off)) * 4;
            const in_old = gx >= ox and gx < ox + ow and gyy >= oy and gyy < oy + oh;
            if (in_old) {
                const ox_l = gx - ox;
                const oy_l = gyy - oy;
                const src: usize = (@as(usize, oy_l) * @as(usize, ow) + @as(usize, ox_l)) * 4;
                @memcpy(new_buf[dst..][0..4], old_buf[src..][0..4]);
            } else {
                const idx: usize = @as(usize, gyy) * stride + @as(usize, gx);
                @memcpy(new_buf[dst..][0..4], std.mem.asBytes(&pix[idx]));
            }
        }
    }

    pixi.app.allocator.free(old_buf);
    file.editor.stroke_undo_pixels = new_buf;
    file.editor.stroke_undo_x = tx;
    file.editor.stroke_undo_y = ty;
    file.editor.stroke_undo_w = tw;
    file.editor.stroke_undo_h = th;
}

pub fn strokeUndoCommit(file: *File) void {
    defer strokeUndoFreeSnapshot(file);
    const snap = file.editor.stroke_undo_pixels orelse return;

    const layer = file.layers.get(file.selected_layer_index);
    const pixels = layer.pixels();
    const iw: usize = @intCast(file.width());

    const sx = file.editor.stroke_undo_x;
    const sy = file.editor.stroke_undo_y;
    const sw = file.editor.stroke_undo_w;
    const sh = file.editor.stroke_undo_h;

    file.buffers.stroke.clearAndFree();

    var row: u32 = 0;
    while (row < sh) : (row += 1) {
        var col: u32 = 0;
        while (col < sw) : (col += 1) {
            const gx: usize = @as(usize, sx + col);
            const gyy: usize = @as(usize, sy + row);
            const idx: usize = gyy * iw + gx;
            const off: usize = (@as(usize, row) * @as(usize, sw) + @as(usize, col)) * 4;
            const old_px: [4]u8 = .{ snap[off], snap[off + 1], snap[off + 2], snap[off + 3] };
            const cur = pixels[idx];
            if (!std.mem.eql(u8, &old_px, &cur)) {
                file.buffers.stroke.append(idx, old_px) catch {
                    dvui.log.err("Failed to append to stroke buffer (deferred commit)", .{});
                };
            }
        }
    }

    const change_opt = file.buffers.stroke.toChange(layer.id) catch null;
    if (change_opt) |change| {
        file.history.append(change) catch {
            dvui.log.err("Failed to append to history", .{});
        };
    }
}

fn selectionMaskHasPixels(file: *const File) bool {
    var it = file.editor.selection_layer.mask.iterator(.{ .kind = .set, .direction = .forward });
    return it.next() != null;
}

fn pixelInAnySelectedSprite(file: *File, px: usize, py: usize) bool {
    const fx: f32 = @floatFromInt(px);
    const fy: f32 = @floatFromInt(py);
    var it = file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
    while (it.next()) |idx| {
        const r = file.spriteRect(idx);
        if (fx >= r.x and fx < r.x + r.w and fy >= r.y and fy < r.y + r.h) {
            return true;
        }
    }
    return false;
}

/// Clears pixels covered by the fine selection mask, or clears every selected sprite tile on the
/// active layer. When the selection mask is non-empty, it takes precedence over sprite tile selection.
pub fn deleteSelectedContents(file: *File) void {
    if (file.editor.transform != null) return;

    if (selectionMaskHasPixels(file)) {
        deleteSelectedFinePixels(file);
        return;
    }

    if (file.editor.selected_sprites.count() > 0) {
        deleteSelectedSpriteTiles(file);
    }
}

fn deleteSelectedFinePixels(file: *File) void {
    const iw: u32 = file.width();
    const stride: usize = @intCast(iw);

    var min_x: u32 = iw;
    var min_y: u32 = file.height();
    var max_x: u32 = 0;
    var max_y: u32 = 0;
    var any = false;

    {
        var it = file.editor.selection_layer.mask.iterator(.{ .kind = .set, .direction = .forward });
        while (it.next()) |pixel_index| {
            const x: u32 = @intCast(pixel_index % stride);
            const y: u32 = @intCast(pixel_index / stride);
            min_x = @min(min_x, x);
            min_y = @min(min_y, y);
            max_x = @max(max_x, x);
            max_y = @max(max_y, y);
            any = true;
        }
    }
    if (!any) return;

    const cover = dvui.Rect{
        .x = @floatFromInt(min_x),
        .y = @floatFromInt(min_y),
        .w = @floatFromInt(max_x - min_x + 1),
        .h = @floatFromInt(max_y - min_y + 1),
    };

    file.strokeUndoBegin(cover) catch {
        dvui.log.err("deleteSelectedFinePixels: strokeUndoBegin failed", .{});
        return;
    };

    var layer = file.layers.get(file.selected_layer_index);

    if (file.editor.stroke_undo_deferred) {
        var it2 = file.editor.selection_layer.mask.iterator(.{ .kind = .set, .direction = .forward });
        while (it2.next()) |pixel_index| {
            layer.pixels()[pixel_index] = .{ 0, 0, 0, 0 };
        }
        layer.invalidate();
        file.strokeUndoCommit();
    } else {
        file.buffers.stroke.clearAndFree();
        var it2 = file.editor.selection_layer.mask.iterator(.{ .kind = .set, .direction = .forward });
        while (it2.next()) |pixel_index| {
            file.buffers.stroke.append(pixel_index, layer.pixels()[pixel_index]) catch {
                dvui.log.err("deleteSelectedFinePixels: stroke buffer append failed", .{});
                return;
            };
            layer.pixels()[pixel_index] = .{ 0, 0, 0, 0 };
        }
        layer.invalidate();
        const change = file.buffers.stroke.toChange(layer.id) catch |err| {
            dvui.log.err("deleteSelectedFinePixels: toChange failed: {}", .{err});
            return;
        };
        file.history.append(change) catch {
            dvui.log.err("deleteSelectedFinePixels: history append failed", .{});
        };
    }

    file.editor.selection_layer.clearMask();
    file.invalidateActiveLayerTransparencyMaskCache();
    file.editor.layer_composite_dirty = true;
    file.editor.split_composite_dirty = true;
}

fn deleteSelectedSpriteTiles(file: *File) void {
    var cover: ?dvui.Rect = null;
    {
        var it = file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
        while (it.next()) |idx| {
            const r = file.spriteRect(idx);
            cover = if (cover) |c| c.unionWith(r) else r;
        }
    }
    const cvr = cover orelse return;

    file.strokeUndoBegin(cvr) catch {
        dvui.log.err("deleteSelectedSpriteTiles: strokeUndoBegin failed", .{});
        return;
    };

    var layer = file.layers.get(file.selected_layer_index);

    if (file.editor.stroke_undo_deferred) {
        var it = file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
        while (it.next()) |idx| {
            layer.clearRect(file.spriteRect(idx));
        }
        file.strokeUndoCommit();
    } else {
        file.buffers.stroke.clearAndFree();
        const b = intRectFromDvuiRect(cvr, file.width(), file.height());
        if (b.w == 0 or b.h == 0) {
            file.invalidateActiveLayerTransparencyMaskCache();
            file.editor.layer_composite_dirty = true;
            file.editor.split_composite_dirty = true;
            return;
        }
        const iw_sz: usize = @intCast(file.width());
        var row: u32 = 0;
        while (row < b.h) : (row += 1) {
            var col: u32 = 0;
            while (col < b.w) : (col += 1) {
                const gx: usize = @as(usize, b.x + col);
                const gy: usize = @as(usize, b.y + row);
                if (!pixelInAnySelectedSprite(file, gx, gy)) continue;
                const pidx = gy * iw_sz + gx;
                file.buffers.stroke.append(pidx, layer.pixels()[pidx]) catch {
                    dvui.log.err("deleteSelectedSpriteTiles: stroke buffer append failed", .{});
                    return;
                };
                layer.pixels()[pidx] = .{ 0, 0, 0, 0 };
            }
        }
        layer.invalidate();
        const change = file.buffers.stroke.toChange(layer.id) catch |err| {
            dvui.log.err("deleteSelectedSpriteTiles: toChange failed: {}", .{err});
            return;
        };
        file.history.append(change) catch {
            dvui.log.err("deleteSelectedSpriteTiles: history append failed", .{});
        };
    }

    file.invalidateActiveLayerTransparencyMaskCache();
    file.editor.layer_composite_dirty = true;
    file.editor.split_composite_dirty = true;
}

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

    const clip_rect: ?dvui.Rect = if (layer == .temporary) draw_options.clip_rect else null;

    const mask_value: bool = draw_options.color.a != 0;

    const column = file.columnFromPixel(point);
    const row = file.rowFromPixel(point);

    const min_x: f32 = @as(f32, @floatFromInt(column)) * @as(f32, @floatFromInt(file.column_width));
    const min_y: f32 = @as(f32, @floatFromInt(row)) * @as(f32, @floatFromInt(file.row_height));

    const max_x: f32 = min_x + @as(f32, @floatFromInt(file.column_width));
    const max_y: f32 = min_y + @as(f32, @floatFromInt(file.row_height));

    if (clip_rect) |cr| {
        const br = brushRect(point, draw_options.stroke_size, file.width(), file.height());
        if (br.intersect(cr).empty()) return;
    }

    if (draw_options.stroke_size < 10) {
        const size: usize = @intCast(draw_options.stroke_size);

        for (0..(size * size)) |index| {
            if (active_layer.getIndexShapeOffset(point, index)) |result| {
                if (clip_rect) |cr| {
                    if (!cr.contains(result.point)) continue;
                }
                if (draw_options.constrain_to_tile) {
                    if (result.point.x < min_x or result.point.x >= max_x or result.point.y < min_y or result.point.y >= max_y) {
                        continue;
                    }
                }

                active_layer.mask.setValue(result.index, mask_value);

                if (draw_options.mask_only) {
                    continue;
                }

                if (layer == .selected and !file.editor.stroke_undo_deferred) {
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

            if (clip_rect) |cr| {
                if (!cr.contains(new_point)) continue;
            }
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
                if (layer == .selected and !file.editor.stroke_undo_deferred) {
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
        if (layer == .selected) {
            expandActiveLayerDirtyRect(file, brushRect(point, draw_options.stroke_size, file.width(), file.height()));
        } else {
            active_layer.invalidate();
        }
    }

    if (draw_options.to_change and layer == .selected) {
        if (file.editor.stroke_undo_deferred) {
            file.strokeUndoCommit();
        } else {
            const change_opt = file.buffers.stroke.toChange(active_layer.id) catch null;
            if (change_opt) |change| {
                file.history.append(change) catch {
                    dvui.log.err("Failed to append to history", .{});
                };
            }
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

    const clip_rect: ?dvui.Rect = if (layer == .temporary) draw_options.clip_rect else null;
    const iw = file.width();
    const ih = file.height();

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
            if (clip_rect) |cr| {
                const br = brushRect(point, draw_options.stroke_size, iw, ih);
                if (br.intersect(cr).empty()) continue;
            }
            if (draw_options.stroke_size < pixi.Editor.Tools.min_full_stroke_size) {
                drawPoint(file, point, layer, .{
                    .color = draw_options.color,
                    .stroke_size = draw_options.stroke_size,
                    .mask_only = draw_options.mask_only,
                    .invalidate = false,
                    .to_change = false,
                    .constrain_to_tile = draw_options.constrain_to_tile,
                    .clip_rect = draw_options.clip_rect,
                });
            } else {
                var stroke = if (point_i == 0) pixi.editor.tools.stroke else mask;

                var iter = stroke.iterator(.{ .kind = .set, .direction = .forward });
                while (iter.next()) |i| {
                    const offset = pixi.editor.tools.offset_table[i];
                    const new_point: dvui.Point = .{ .x = point.x + offset[0], .y = point.y + offset[1] };

                    if (clip_rect) |cr| {
                        if (!cr.contains(new_point)) continue;
                    }
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
                        if (layer == .selected and !file.editor.stroke_undo_deferred) {
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
            if (layer == .selected) {
                const r1 = brushRect(point1, draw_options.stroke_size, file.width(), file.height());
                const r2 = brushRect(point2, draw_options.stroke_size, file.width(), file.height());
                expandActiveLayerDirtyRect(file, r1.unionWith(r2));
            } else {
                active_layer.invalidate();
            }
        }

        if (draw_options.to_change and layer == .selected) {
            if (file.editor.stroke_undo_deferred) {
                file.strokeUndoCommit();
            } else {
                const change_opt = file.buffers.stroke.toChange(active_layer.id) catch null;
                if (change_opt) |change| {
                    file.history.append(change) catch {
                        dvui.log.err("Failed to append to history", .{});
                    };
                }
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
    self.editor.layer_composite_dirty = true;
    self.editor.split_composite_dirty = true;
    try self.history.append(.{ .layer_restore_delete = .{
        .action = .restore,
        .index = index,
    } });

    if (index > 0) {
        self.selected_layer_index = index - 1;
    }
}

pub fn mergeSelectedLayerUp(self: *File) !void {
    const s = self.selected_layer_index;
    if (s == 0) return;
    try self.mergeLayerInternal(.up, s, s - 1);
}

pub fn mergeSelectedLayerDown(self: *File) !void {
    const s = self.selected_layer_index;
    if (s + 1 >= self.layers.len) return;
    try self.mergeLayerInternal(.down, s, s + 1);
}

fn mergeLayerInternal(self: *File, kind: History.Change.LayerMerge.Kind, src_i: usize, dest_i: usize) !void {
    var dest = self.layers.get(dest_i);
    const src = self.layers.get(src_i);

    const pix_n = dest.pixels().len;
    if (src.pixels().len != pix_n) return error.InvalidLayerMerge;

    const dest_id = self.layers.items(.id)[dest_i];
    const src_id = self.layers.items(.id)[src_i];

    const dest_pixels_before = try pixi.app.allocator.dupe([4]u8, dest.pixels());
    errdefer pixi.app.allocator.free(dest_pixels_before);

    var dest_mask_before = try dest.mask.clone(pixi.app.allocator);
    errdefer dest_mask_before.deinit();

    for (0..pix_n) |i| {
        const dpx = dest.pixels()[i];
        const spx = src.pixels()[i];
        dest.pixels()[i] = switch (kind) {
            .up => Layer.blendPmaSrcOver(dpx, spx),
            .down => Layer.blendPmaSrcOver(spx, dpx),
        };
    }
    dest.mask.setUnion(src.mask);
    dest.invalidate();
    self.layers.set(dest_i, dest);

    try self.deleted_layers.append(pixi.app.allocator, self.layers.slice().get(src_i));
    self.layers.orderedRemove(src_i);

    self.editor.layer_composite_dirty = true;
    self.editor.split_composite_dirty = true;

    self.selected_layer_index = switch (kind) {
        .up => dest_i,
        .down => dest_i - 1,
    };

    try self.history.append(.{ .layer_merge = .{
        .kind = kind,
        .source_index = src_i,
        .dest_layer_id = dest_id,
        .source_layer_id = src_id,
        .dest_pixels_before = dest_pixels_before,
        .dest_mask_before = dest_mask_before,
    } });
    pixi.editor.explorer.pane = .tools;
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
    self.editor.layer_composite_dirty = true;
    self.editor.split_composite_dirty = true;

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
        self.editor.layer_composite_dirty = true;
        self.editor.split_composite_dirty = true;

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

pub fn saveJpg(self: *File, window: *dvui.Window) !void {
    if (self.editor.saving) return;
    self.editor.saving = true;

    const ppi: u16 = @intFromFloat(@round(window.natural_scale * 72.0));
    try pixi.image.writeToJpgPpi(self.layers.get(self.selected_layer_index).source, self.path, ppi);

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

/// Point `path` at `new_path`, then `saveZip` (same on-disk work as a normal .pixi save). Restores the previous `path` if saving fails.
pub fn saveAsPixi(self: *File, new_path: []const u8, window: *dvui.Window) !void {
    if (self.editor.saving) return;
    if (std.mem.eql(u8, self.path, new_path)) {
        return saveZip(self, window);
    }
    const old_path = self.path;
    const new_owned = try pixi.app.allocator.dupe(u8, new_path);
    self.path = new_owned;
    errdefer {
        pixi.app.allocator.free(self.path[0..self.path.len]);
        self.path = old_path;
    }
    try saveZip(self, window);
    pixi.app.allocator.free(old_path[0..old_path.len]);
}

/// Default filename (with `.pixi`) for a Save As dialog, derived from the current path.
pub fn defaultSaveAsFilename(allocator: std.mem.Allocator, current_path: []const u8) ![]u8 {
    const base = std.fs.path.basename(current_path);
    const stem: []const u8 = if (std.mem.lastIndexOf(u8, base, ".")) |i| base[0..i] else base;
    if (stem.len == 0) {
        return try std.fmt.allocPrint(allocator, "{s}", .{"untitled.pixi"});
    }
    return try std.fmt.allocPrint(allocator, "{s}.pixi", .{stem});
}

fn deinitAllUserLayers(self: *File) void {
    while (self.layers.len > 0) {
        const i = self.layers.len - 1;
        var layer = self.layers.get(i);
        layer.deinit();
        self.layers.orderedRemove(i);
    }
}

fn clearAnimationsForSaveAs(self: *File) void {
    for (self.animations.items(.name)) |n| {
        pixi.app.allocator.free(n);
    }
    for (self.animations.items(.frames)) |frames| {
        pixi.app.allocator.free(frames);
    }
    self.animations.clearRetainingCapacity();
    self.deleted_animations.clearRetainingCapacity();
    self.selected_animation_index = null;
    self.selected_animation_frame_index = 0;
    self.editor.selected_animation_indices.clearRetainingCapacity();
    self.editor.selected_frame_indices.clearRetainingCapacity();
}

fn reinitEditorSurfaceForFlatDocument(self: *File) !void {
    self.editor.temporary_layer.deinit();
    self.editor.selection_layer.deinit();
    self.editor.transform_layer.deinit();
    self.editor.checkerboard.deinit();
    switch (self.editor.checkerboard_tile) {
        .pixelsPMA => |p| pixi.app.allocator.free(p.rgba),
        .pixels => |p| pixi.app.allocator.free(p.rgba),
        .texture => |t| dvui.textureDestroyLater(t),
        .imageFile => |i| pixi.app.allocator.free(i.bytes),
    }
    self.editor.selected_sprites.deinit();

    self.editor.temporary_layer = try .init(self.newLayerID(), "Temporary", self.width(), self.height(), .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr);
    self.editor.selection_layer = try .init(self.newLayerID(), "Selection", self.width(), self.height(), .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr);
    self.editor.transform_layer = try .init(self.newLayerID(), "Transform", self.width(), self.height(), .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr);
    self.editor.selected_sprites = try std.DynamicBitSet.initEmpty(pixi.app.allocator, self.spriteCount());

    self.editor.checkerboard = try std.DynamicBitSet.initEmpty(pixi.app.allocator, self.width() * self.height());
    for (0..self.width() * self.height()) |i| {
        const value = pixi.math.checker(.{ .w = @floatFromInt(self.width()), .h = @floatFromInt(self.height()) }, i);
        self.editor.checkerboard.setValue(i, value);
    }
    {
        const alpha_width = alpha_checkerboard_count;
        const aspect_ratio = @as(f32, @floatFromInt(self.column_width)) / @as(f32, @floatFromInt(self.row_height));
        const alpha_height = @round(alpha_width / aspect_ratio);
        self.editor.checkerboard_tile = pixi.image.init(
            alpha_width,
            std.math.clamp(2, @as(u32, @intFromFloat(alpha_height)), 1024),
            .{ .r = 0, .g = 0, .b = 0, .a = 0 },
            .ptr,
        ) catch return error.LayerCreateError;
        for (pixi.image.pixels(self.editor.checkerboard_tile), 0..) |*pixel, j| {
            if (pixi.math.checker(pixi.image.size(self.editor.checkerboard_tile), j)) {
                pixel.* = pixi.editor.settings.checker_color_even;
            } else {
                pixel.* = pixi.editor.settings.checker_color_odd;
            }
        }
    }
    self.editor.selected_layer_indices.clearRetainingCapacity();
    try self.editor.selected_layer_indices.append(pixi.app.allocator, 0);
}

/// Flattens visible layers (via GPU composite), writes PNG or JPEG to `output_path`, and replaces
/// the document with a single layer matching the flattened result.
pub fn saveAsFlattened(self: *File, output_path: []const u8, window: *dvui.Window) !void {
    if (self.editor.saving) return;
    self.editor.saving = true;
    errdefer self.editor.saving = false;

    strokeUndoFreeSnapshot(self);
    const w = self.width();
    const h = self.height();
    if (w == 0 or h == 0) {
        self.editor.saving = false;
        return error.InvalidImageSize;
    }

    try pixi.render.syncLayerComposite(self);
    const target = self.editor.layer_composite_target orelse {
        self.editor.saving = false;
        return error.NoLayerComposite;
    };

    const pma_read: []dvui.Color.PMA = try dvui.Texture.readTarget(pixi.app.allocator, target);
    defer {
        const byte_len = pma_read.len * @sizeOf(dvui.Color.PMA);
        pixi.app.allocator.free(@as([*]u8, @ptrCast(pma_read.ptr))[0..byte_len]);
    }

    const ext = std.fs.path.extension(output_path);
    const is_png = std.mem.eql(u8, ext, ".png");
    const is_jpg = std.mem.eql(u8, ext, ".jpg") or std.mem.eql(u8, ext, ".jpeg");
    if (!is_png and !is_jpg) {
        self.editor.saving = false;
        return error.InvalidExtension;
    }

    var single_layer: pixi.Internal.Layer = try .fromPixelsPMA(self.newLayerID(), "Layer", pma_read, w, h, .ptr);
    errdefer single_layer.deinit();

    if (is_png) {
        const r: u32 = @intFromFloat(@round(window.natural_scale * 72.0 / 0.0254));
        try pixi.image.writeToPngResolution(single_layer.source, output_path, r);
    } else {
        const ppi: u16 = @intFromFloat(@round(window.natural_scale * 72.0));
        try pixi.image.writeToJpgPpi(single_layer.source, output_path, ppi);
    }

    pixi.render.destroyLayerCompositeResources(self);
    pixi.render.destroySplitCompositeResources(self);

    deinitAllUserLayers(self);
    clearAnimationsForSaveAs(self);
    self.sprites.clearRetainingCapacity();
    for (0..self.spriteCount()) |_| {
        self.sprites.append(pixi.app.allocator, .{ .origin = .{ 0, 0 } }) catch {
            single_layer.deinit();
            return error.FileLoadError;
        };
    }

    const new_path = try pixi.app.allocator.dupe(u8, output_path);
    pixi.app.allocator.free(self.path[0..self.path.len]);
    self.path = new_path;
    self.columns = 1;
    self.rows = 1;
    self.column_width = w;
    self.row_height = h;
    self.selected_layer_index = 0;
    self.peek_layer_index = null;
    self.layers.append(pixi.app.allocator, single_layer) catch {
        single_layer.deinit();
        return error.LayerCreateError;
    };

    self.history.deinit();
    self.history = .init(pixi.app.allocator);

    try reinitEditorSurfaceForFlatDocument(self);
    self.editor.layer_composite_dirty = true;
    self.editor.split_composite_dirty = true;
    self.editor.saving = false;
    {
        const id_mutex = dvui.toastAdd(window, @src(), self.id, self.editor.canvas.id, pixi.dvui.toastDisplay, 2_000_000);
        const id = id_mutex.id;
        const message = std.fmt.allocPrint(window.arena(), "Saved {s} to disk", .{std.fs.path.basename(self.path)}) catch "Saved file";
        dvui.dataSetSlice(window, id, "_message", message);
        id_mutex.mutex.unlock();
    }
    pixi.editor.requestCompositeWarmup();
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
    } else if (std.mem.eql(u8, ext, ".jpg") or std.mem.eql(u8, ext, ".jpeg")) {
        const thread = try std.Thread.spawn(.{}, saveJpg, .{ self, dvui.currentWindow() });
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
