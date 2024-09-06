const std = @import("std");
const pixi = @import("../pixi.zig");
const mach = @import("mach");
const core = mach.core;
const zip = @import("zip");
const zstbi = @import("zstbi");
const zgpu = @import("zgpu");
const nfd = @import("nfd");
const imgui = @import("zig-imgui");
const zmath = @import("zmath");

pub const Theme = @import("theme.zig");

pub const sidebar = @import("sidebar/sidebar.zig");
pub const explorer = @import("explorer/explorer.zig");
pub const artboard = @import("artboard/artboard.zig");

pub const popup_rename = @import("popups/rename.zig");
pub const popup_file_setup = @import("popups/file_setup.zig");
pub const popup_about = @import("popups/about.zig");
pub const popup_file_confirm_close = @import("popups/file_confirm_close.zig");
pub const popup_layer_setup = @import("popups/layer_setup.zig");
pub const popup_export_to_png = @import("popups/export_png.zig");
pub const popup_animation = @import("popups/animation.zig");
pub const popup_heightmap = @import("popups/heightmap.zig");
pub const popup_references = @import("popups/references.zig");

pub fn draw() void {
    imgui.pushStyleVarImVec2(imgui.StyleVar_SeparatorTextAlign, .{ .x = pixi.state.settings.explorer_title_align, .y = 0.5 });
    defer imgui.popStyleVar();

    sidebar.draw();
    explorer.draw();
    artboard.draw();

    popup_rename.draw();
    popup_file_setup.draw();
    popup_about.draw();
    popup_file_confirm_close.draw();
    popup_layer_setup.draw();
    popup_export_to_png.draw();
    popup_animation.draw();
    popup_heightmap.draw();
    popup_references.draw();
}

pub fn setProjectFolder(path: [:0]const u8) void {
    if (pixi.state.project_folder) |folder| {
        pixi.state.allocator.free(folder);
    }
    pixi.state.project_folder = pixi.state.allocator.dupeZ(u8, path) catch unreachable;
    pixi.state.recents.appendFolder(pixi.state.allocator.dupeZ(u8, path) catch unreachable) catch unreachable;
    pixi.state.recents.save() catch unreachable;
    pixi.state.sidebar = .files;
}

pub fn saving() bool {
    for (pixi.state.open_files.items) |file| {
        if (file.saving) return true;
    }
    return false;
}

/// Returns true if a new file was created.
pub fn newFile(path: [:0]const u8, import_path: ?[:0]const u8) !bool {
    for (pixi.state.open_files.items, 0..) |file, i| {
        if (std.mem.eql(u8, file.path, path)) {
            // Free path since we aren't adding it to open files again.
            pixi.state.allocator.free(path);
            setActiveFile(i);
            return false;
        }
    }

    var internal: pixi.storage.Internal.Pixi = .{
        .path = try pixi.state.allocator.dupeZ(u8, path),
        .width = @as(u32, @intCast(pixi.state.popups.file_setup_tiles[0] * pixi.state.popups.file_setup_tile_size[0])),
        .height = @as(u32, @intCast(pixi.state.popups.file_setup_tiles[1] * pixi.state.popups.file_setup_tile_size[1])),
        .tile_width = @as(u32, @intCast(pixi.state.popups.file_setup_tile_size[0])),
        .tile_height = @as(u32, @intCast(pixi.state.popups.file_setup_tile_size[1])),
        .layers = std.ArrayList(pixi.storage.Internal.Layer).init(pixi.state.allocator),
        .deleted_layers = std.ArrayList(pixi.storage.Internal.Layer).init(pixi.state.allocator),
        .deleted_heightmap_layers = std.ArrayList(pixi.storage.Internal.Layer).init(pixi.state.allocator),
        .sprites = std.ArrayList(pixi.storage.Internal.Sprite).init(pixi.state.allocator),
        .selected_sprites = std.ArrayList(usize).init(pixi.state.allocator),
        .animations = std.ArrayList(pixi.storage.Internal.Animation).init(pixi.state.allocator),
        .keyframe_animations = std.ArrayList(pixi.storage.Internal.KeyframeAnimation).init(pixi.state.allocator),
        .keyframe_animation_texture = undefined,
        .keyframe_transform_texture = undefined,
        .deleted_animations = std.ArrayList(pixi.storage.Internal.Animation).init(pixi.state.allocator),
        .background = undefined,
        .history = pixi.storage.Internal.Pixi.History.init(pixi.state.allocator),
        .buffers = pixi.storage.Internal.Pixi.Buffers.init(pixi.state.allocator),
        .temporary_layer = undefined,
        .selection_layer = undefined,
    };

    try internal.createBackground();

    internal.temporary_layer = .{
        .name = "Temporary",
        .texture = try pixi.gfx.Texture.createEmpty(internal.width, internal.height, .{}),
    };

    internal.selection_layer = .{
        .name = "Selection",
        .texture = try pixi.gfx.Texture.createEmpty(internal.width, internal.height, .{}),
    };

    var new_layer: pixi.storage.Internal.Layer = .{
        .name = try std.fmt.allocPrintZ(pixi.state.allocator, "{s}", .{"Layer 0"}),
        .texture = undefined,
        .id = internal.newId(),
    };

    if (import_path) |import| {
        new_layer.texture = try pixi.gfx.Texture.loadFromFile(import, .{});
    } else {
        new_layer.texture = try pixi.gfx.Texture.createEmpty(internal.width, internal.height, .{});
    }

    try internal.layers.append(new_layer);

    internal.keyframe_animation_texture = try pixi.gfx.Texture.createEmpty(internal.width, internal.height, .{});
    internal.keyframe_transform_texture = .{
        .vertices = .{.{ .position = zmath.f32x4s(0.0) }} ** 4,
        .texture = internal.layers.items[0].texture,
    };

    // Create sprites for all tiles.
    {
        const base_name = std.fs.path.basename(path);
        const ext = std.fs.path.extension(base_name);
        const ext_ind = if (std.mem.indexOf(u8, base_name, ext)) |index| index else base_name.len - 1;

        const tiles = @as(usize, @intCast(pixi.state.popups.file_setup_tiles[0] * pixi.state.popups.file_setup_tiles[1]));
        var i: usize = 0;
        while (i < tiles) : (i += 1) {
            const sprite: pixi.storage.Internal.Sprite = .{
                .name = try std.fmt.allocPrintZ(pixi.state.allocator, "{s}_{d}", .{ base_name[0..ext_ind], i }),
                .index = i,
            };
            try internal.sprites.append(sprite);
        }
    }

    try pixi.state.open_files.insert(0, internal);
    pixi.editor.setActiveFile(0);

    pixi.state.allocator.free(path);

    return true;
}

/// Returns true if png was imported and new file created.
pub fn importPng(path: [:0]const u8, new_file_path: [:0]const u8) !bool {
    defer pixi.state.allocator.free(path);
    if (!std.mem.eql(u8, std.fs.path.extension(path)[0..4], ".png"))
        return false;

    if (!std.mem.eql(u8, std.fs.path.extension(new_file_path)[0..5], ".pixi"))
        return false;

    return try newFile(new_file_path, path);
}

pub fn loadFileAsync(path: [:0]const u8) !?pixi.storage.Internal.Pixi {
    std.log.warn("loadFileAsync not implemented!", .{});
    _ = path;
}

pub fn loadFile(path: [:0]const u8) !?pixi.storage.Internal.Pixi {
    if (!std.mem.eql(u8, std.fs.path.extension(path[0..path.len]), ".pixi"))
        return null;

    if (zip.zip_open(path.ptr, 0, 'r')) |pixi_file| {
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

        var parsed = std.json.parseFromSlice(pixi.storage.External.Pixi, pixi.state.allocator, content, options) catch unreachable;
        defer parsed.deinit();

        const external = parsed.value;

        var internal: pixi.storage.Internal.Pixi = .{
            .path = try pixi.state.allocator.dupeZ(u8, path),
            .width = external.width,
            .height = external.height,
            .tile_width = external.tile_width,
            .tile_height = external.tile_height,
            .layers = std.ArrayList(pixi.storage.Internal.Layer).init(pixi.state.allocator),
            .deleted_layers = std.ArrayList(pixi.storage.Internal.Layer).init(pixi.state.allocator),
            .deleted_heightmap_layers = std.ArrayList(pixi.storage.Internal.Layer).init(pixi.state.allocator),
            .sprites = std.ArrayList(pixi.storage.Internal.Sprite).init(pixi.state.allocator),
            .selected_sprites = std.ArrayList(usize).init(pixi.state.allocator),
            .animations = std.ArrayList(pixi.storage.Internal.Animation).init(pixi.state.allocator),
            .keyframe_animations = std.ArrayList(pixi.storage.Internal.KeyframeAnimation).init(pixi.state.allocator),
            .keyframe_animation_texture = undefined,
            .keyframe_transform_texture = undefined,
            .deleted_animations = std.ArrayList(pixi.storage.Internal.Animation).init(pixi.state.allocator),
            .background = undefined,
            .history = pixi.storage.Internal.Pixi.History.init(pixi.state.allocator),
            .buffers = pixi.storage.Internal.Pixi.Buffers.init(pixi.state.allocator),
            .temporary_layer = undefined,
            .selection_layer = undefined,
        };

        try internal.createBackground();

        internal.temporary_layer = .{
            .name = "Temporary",
            .texture = try pixi.gfx.Texture.createEmpty(internal.width, internal.height, .{}),
            .visible = true,
        };

        internal.selection_layer = .{
            .name = "Selection",
            .texture = try pixi.gfx.Texture.createEmpty(internal.width, internal.height, .{}),
            .visible = true,
        };

        for (external.layers) |layer| {
            const layer_image_name = try std.fmt.allocPrintZ(pixi.state.allocator, "{s}.png", .{layer.name});
            defer pixi.state.allocator.free(layer_image_name);

            var img_buf: ?*anyopaque = null;
            var img_len: usize = 0;

            if (zip.zip_entry_open(pixi_file, layer_image_name.ptr) == 0) {
                _ = zip.zip_entry_read(pixi_file, &img_buf, &img_len);

                if (img_buf) |data| {
                    const pipeline_layout_default = pixi.state.pipeline_default.getBindGroupLayout(0);
                    defer pipeline_layout_default.release();

                    var new_layer: pixi.storage.Internal.Layer = .{
                        .name = try pixi.state.allocator.dupeZ(u8, layer.name),
                        .texture = try pixi.gfx.Texture.loadFromMemory(@as([*]u8, @ptrCast(data))[0..img_len], .{}),
                        .id = internal.newId(),
                        .visible = layer.visible,
                        .collapse = layer.collapse,
                        .transform_bindgroup = undefined,
                    };

                    new_layer.transform_bindgroup = core.device.createBindGroup(
                        &mach.gpu.BindGroup.Descriptor.init(.{
                            .layout = pipeline_layout_default,
                            .entries = &.{
                                if (pixi.build_options.use_sysgpu)
                                    mach.gpu.BindGroup.Entry.buffer(0, pixi.state.uniform_buffer_default, 0, @sizeOf(pixi.gfx.UniformBufferObject), 0)
                                else
                                    mach.gpu.BindGroup.Entry.buffer(0, pixi.state.uniform_buffer_default, 0, @sizeOf(pixi.gfx.UniformBufferObject)),
                                mach.gpu.BindGroup.Entry.textureView(1, new_layer.texture.view_handle),
                                mach.gpu.BindGroup.Entry.sampler(2, new_layer.texture.sampler_handle),
                            },
                        }),
                    );
                    try internal.layers.append(new_layer);
                }
            }
            _ = zip.zip_entry_close(pixi_file);
        }

        internal.keyframe_animation_texture = try pixi.gfx.Texture.createEmpty(internal.width, internal.height, .{});

        internal.keyframe_transform_texture = .{
            .vertices = .{.{ .position = zmath.f32x4s(0.0) }} ** 4,
            .texture = internal.layers.items[0].texture,
        };

        const heightmap_image_name = try std.fmt.allocPrintZ(pixi.state.allocator, "{s}.png", .{"heightmap"});
        defer pixi.state.allocator.free(heightmap_image_name);

        if (zip.zip_entry_open(pixi_file, heightmap_image_name.ptr) == 0) {
            var img_buf: ?*anyopaque = null;
            var img_len: usize = 0;

            _ = zip.zip_entry_read(pixi_file, &img_buf, &img_len);

            if (img_buf) |data| {
                var new_layer: pixi.storage.Internal.Layer = .{
                    .name = try pixi.state.allocator.dupeZ(u8, "heightmap"),
                    .texture = undefined,
                };

                new_layer.texture = try pixi.gfx.Texture.loadFromMemory(@as([*]u8, @ptrCast(data))[0..img_len], .{});
                new_layer.id = internal.newId();

                internal.heightmap.layer = new_layer;
            }
        }
        _ = zip.zip_entry_close(pixi_file);

        for (external.sprites, 0..) |sprite, i| {
            try internal.sprites.append(.{
                .name = try pixi.state.allocator.dupeZ(u8, sprite.name),
                .index = i,
                .origin_x = @as(f32, @floatFromInt(sprite.origin[0])),
                .origin_y = @as(f32, @floatFromInt(sprite.origin[1])),
            });
        }

        for (external.animations) |animation| {
            try internal.animations.append(.{
                .name = try pixi.state.allocator.dupeZ(u8, animation.name),
                .start = animation.start,
                .length = animation.length,
                .fps = animation.fps,
            });
        }
        return internal;
    }
    return error.FailedToOpenFile;
}

/// Returns true if a new file was opened.
pub fn openFile(path: [:0]const u8) !bool {
    if (!std.mem.eql(u8, std.fs.path.extension(path[0..path.len]), ".pixi"))
        return false;

    for (pixi.state.open_files.items, 0..) |file, i| {
        if (std.mem.eql(u8, file.path, path)) {
            setActiveFile(i);
            return false;
        }
    }

    if (try loadFile(path)) |file| {
        try pixi.state.open_files.insert(0, file);
        setActiveFile(0);
        return true;
    }
    return error.FailedToOpenFile;
}

pub fn openReference(path: [:0]const u8) !bool {
    for (pixi.state.open_references.items, 0..) |reference, i| {
        if (std.mem.eql(u8, reference.path, path)) {
            setActiveReference(i);
            return false;
        }
    }

    const texture = try pixi.gfx.Texture.loadFromFile(path, .{});

    const reference: pixi.storage.Internal.Reference = .{
        .path = try pixi.state.allocator.dupeZ(u8, path),
        .texture = texture,
    };

    try pixi.state.open_references.insert(0, reference);
    setActiveReference(0);

    if (!pixi.state.popups.references)
        pixi.state.popups.references = true;

    return true;
}

pub fn setActiveFile(index: usize) void {
    if (index >= pixi.state.open_files.items.len) return;
    const file = &pixi.state.open_files.items[index];
    if (file.heightmap.layer == null) {
        if (pixi.state.tools.current == .heightmap)
            pixi.state.tools.current = .pointer;
    }
    if (file.transform_texture != null and pixi.state.tools.current != .pointer) {
        pixi.state.tools.set(.pointer);
    }
    pixi.state.open_file_index = index;
}

pub fn setCopyFile(index: usize) void {
    if (index >= pixi.state.open_files.items.len) return;
    const file = &pixi.state.open_files.items[index];
    if (file.heightmap.layer == null) {
        if (pixi.state.tools.current == .heightmap)
            pixi.state.tools.current = .pointer;
    }
    pixi.state.copy_file_index = index;
}

pub fn setActiveReference(index: usize) void {
    if (index >= pixi.state.open_references.items.len) return;
    pixi.state.open_reference_index = index;
}

pub fn getFileIndex(path: [:0]const u8) ?usize {
    for (pixi.state.open_files.items, 0..) |file, i| {
        if (std.mem.eql(u8, file.path, path))
            return i;
    }
    return null;
}

pub fn getFile(index: usize) ?*pixi.storage.Internal.Pixi {
    if (pixi.state.open_files.items.len == 0) return null;
    if (index >= pixi.state.open_files.items.len) return null;

    return &pixi.state.open_files.items[index];
}

pub fn getReference(index: usize) ?*pixi.storage.Internal.Reference {
    if (pixi.state.open_references.items.len == 0) return null;
    if (index >= pixi.state.open_references.items.len) return null;

    return &pixi.state.open_references.items[index];
}

pub fn forceCloseFile(index: usize) !void {
    if (getFile(index)) |file| {
        _ = file;
        return rawCloseFile(index);
    }
}

pub fn forceCloseAllFiles() !void {
    const len: usize = pixi.state.open_files.items.len;
    var i: usize = 0;
    while (i < len) : (i += 1) {
        try forceCloseFile(0);
    }
}

pub fn saveAllFiles() !void {
    for (pixi.state.open_files.items) |*file| {
        _ = try file.save();
    }
}

pub fn closeFile(index: usize) !void {
    // Handle confirm close if file is dirty
    {
        const file = pixi.state.open_files.items[index];
        if (file.dirty()) {
            pixi.state.popups.file_confirm_close = true;
            pixi.state.popups.file_confirm_close_state = .one;
            pixi.state.popups.file_confirm_close_index = index;
            return;
        }
    }

    try rawCloseFile(index);
}

pub fn rawCloseFile(index: usize) !void {
    pixi.state.open_file_index = 0;
    var file: pixi.storage.Internal.Pixi = pixi.state.open_files.orderedRemove(index);
    deinitFile(&file);
}

pub fn closeReference(index: usize) !void {
    pixi.state.open_reference_index = 0;
    var reference: pixi.storage.Internal.Reference = pixi.state.open_references.orderedRemove(index);
    deinitReference(&reference);
}

pub fn deinitReference(reference: *pixi.storage.Internal.Reference) void {
    reference.texture.deinit();
    pixi.state.allocator.free(reference.path);
}

pub fn deinitFile(file: *pixi.storage.Internal.Pixi) void {
    file.history.deinit();
    file.buffers.deinit();
    file.background.deinit();
    file.temporary_layer.texture.deinit();
    file.selection_layer.texture.deinit();
    if (file.heightmap.layer) |*layer| {
        layer.texture.deinit();
        pixi.state.allocator.free(layer.name);
    }
    if (file.transform_texture) |*texture| {
        texture.texture.deinit();
    }

    for (file.keyframe_animations.items) |*animation| {
        // TODO: uncomment this when names are allocated
        //pixi.state.allocator.free(animation.name);

        for (animation.keyframes.items) |*keyframe| {
            keyframe.frames.deinit();
        }
        animation.keyframes.deinit();
    }
    file.keyframe_animations.deinit();

    if (file.transform_bindgroup) |bindgroup| {
        bindgroup.release();
    }
    if (file.transform_compute_bindgroup) |bindgroup| {
        bindgroup.release();
    }
    if (file.transform_compute_buffer) |buffer| {
        buffer.release();
    }
    if (file.transform_staging_buffer) |buffer| {
        buffer.release();
    }
    for (file.deleted_heightmap_layers.items) |*layer| {
        layer.texture.deinit();
        pixi.state.allocator.free(layer.name);
    }
    for (file.layers.items) |*layer| {
        layer.texture.deinit();
        pixi.state.allocator.free(layer.name);
        if (layer.transform_bindgroup) |bindgroup|
            bindgroup.release();
    }
    for (file.deleted_layers.items) |*layer| {
        layer.texture.deinit();
        pixi.state.allocator.free(layer.name);
        if (layer.transform_bindgroup) |bindgroup|
            bindgroup.release();
    }
    for (file.sprites.items) |*sprite| {
        pixi.state.allocator.free(sprite.name);
    }
    for (file.animations.items) |*animation| {
        pixi.state.allocator.free(animation.name);
    }
    for (file.deleted_animations.items) |*animation| {
        pixi.state.allocator.free(animation.name);
    }

    file.keyframe_animation_texture.deinit();
    file.layers.deinit();
    file.deleted_layers.deinit();
    file.deleted_heightmap_layers.deinit();
    file.sprites.deinit();
    file.selected_sprites.deinit();
    file.animations.deinit();
    file.deleted_animations.deinit();
    pixi.state.allocator.free(file.path);
}

pub fn deinit() void {
    for (pixi.state.open_files.items) |_| {
        try closeFile(0);
    }
    pixi.state.open_files.deinit();

    for (pixi.state.open_references.items) |*reference| {
        reference.deinit();
    }
    pixi.state.open_references.deinit();

    if (pixi.state.project_folder) |folder| {
        pixi.state.allocator.free(folder);
    }
}
