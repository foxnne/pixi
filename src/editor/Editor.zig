const std = @import("std");

const Pixi = @import("../Pixi.zig");
const mach = @import("mach");
const Core = mach.Core;

const zip = @import("zip");
const zstbi = @import("zstbi");
const zgpu = @import("zgpu");
const nfd = @import("nfd");
const imgui = @import("zig-imgui");
const zmath = @import("zmath");

pub const Editor = @This();

pub const Sidebar = @import("Sidebar.zig");
pub const Explorer = @import("explorer/Explorer.zig");
pub const Artboard = @import("artboard/Artboard.zig");
pub const Popups = @import("popups/Popups.zig");

pub const mach_module = .editor;
pub const mach_systems = .{ .init, .lateInit, .tick, .deinit };

pub const Theme = @import("Theme.zig");

theme: Theme,
popups: *Popups,

pub fn init(
    editor: *Editor,
    _popups: *Popups,
    sidebar_mod: mach.Mod(Sidebar),
    explorer_mod: mach.Mod(Explorer),
    artboard_mod: mach.Mod(Artboard),
    popups_mod: mach.Mod(Popups),
) !void {
    editor.* = .{
        .theme = undefined,
        .popups = _popups,
    };

    sidebar_mod.call(.init);
    explorer_mod.call(.init);
    artboard_mod.call(.init);
    popups_mod.call(.init);
}

pub fn lateInit(core: *Core, app: *Pixi, editor: *Editor) !void {
    const theme_path = try std.fs.path.joinZ(app.allocator, &.{ Pixi.assets.themes, app.settings.theme });
    defer app.allocator.free(theme_path);

    editor.theme = try Theme.loadFromFile(theme_path);
    editor.theme.init(core, app);
}

pub fn tick(
    core: *Core,
    app: *Pixi,
    editor: *Editor,
    sidebar_mod: mach.Mod(Sidebar),
    explorer_mod: mach.Mod(Explorer),
    artboard_mod: mach.Mod(Artboard),
    popups_mod: mach.Mod(Popups),
) !void {
    imgui.pushStyleVarImVec2(imgui.StyleVar_SeparatorTextAlign, .{ .x = app.settings.explorer_title_align, .y = 0.5 });
    defer imgui.popStyleVar();

    editor.theme.push(core, app);
    defer editor.theme.pop();

    sidebar_mod.call(.draw);
    explorer_mod.call(.draw);
    artboard_mod.call(.draw);
    popups_mod.call(.draw);
}

pub fn setProjectFolder(path: [:0]const u8) !void {
    if (Pixi.app.project_folder) |folder| {
        Pixi.app.allocator.free(folder);
    }
    Pixi.app.project_folder = try Pixi.app.allocator.dupeZ(u8, path);
    try Pixi.app.recents.appendFolder(try Pixi.app.allocator.dupeZ(u8, path));
    try Pixi.app.recents.save();
    Pixi.app.sidebar = .files;
}

pub fn saving() bool {
    for (Pixi.app.open_files.items) |file| {
        if (file.saving) return true;
    }
    return false;
}

/// Returns true if a new file was created.
pub fn newFile(path: [:0]const u8, import_path: ?[:0]const u8) !bool {
    for (Pixi.app.open_files.items, 0..) |file, i| {
        if (std.mem.eql(u8, file.path, path)) {
            // Free path since we aren't adding it to open files again.
            Pixi.app.allocator.free(path);
            setActiveFile(i);
            return false;
        }
    }

    var internal: Pixi.storage.Internal.PixiFile = .{
        .path = try Pixi.app.allocator.dupeZ(u8, path),
        .width = @as(u32, @intCast(Pixi.editor.popups.file_setup_tiles[0] * Pixi.editor.popups.file_setup_tile_size[0])),
        .height = @as(u32, @intCast(Pixi.editor.popups.file_setup_tiles[1] * Pixi.editor.popups.file_setup_tile_size[1])),
        .tile_width = @as(u32, @intCast(Pixi.editor.popups.file_setup_tile_size[0])),
        .tile_height = @as(u32, @intCast(Pixi.editor.popups.file_setup_tile_size[1])),
        .layers = .{},
        .deleted_layers = .{},
        .deleted_heightmap_layers = .{},
        .sprites = .{},
        .selected_sprites = std.ArrayList(usize).init(Pixi.app.allocator),
        .animations = .{},
        .keyframe_animations = .{},
        .keyframe_animation_texture = undefined,
        .keyframe_transform_texture = undefined,
        .deleted_animations = .{},
        .background = undefined,
        .history = Pixi.storage.Internal.PixiFile.History.init(Pixi.app.allocator),
        .buffers = Pixi.storage.Internal.PixiFile.Buffers.init(Pixi.app.allocator),
        .temporary_layer = undefined,
        .selection_layer = undefined,
    };

    try internal.createBackground();

    internal.temporary_layer = .{
        .name = "Temporary",
        .texture = try Pixi.gfx.Texture.createEmpty(internal.width, internal.height, .{}),
    };

    internal.selection_layer = .{
        .name = "Selection",
        .texture = try Pixi.gfx.Texture.createEmpty(internal.width, internal.height, .{}),
    };

    var new_layer: Pixi.storage.Internal.Layer = .{
        .name = try std.fmt.allocPrintZ(Pixi.app.allocator, "{s}", .{"Layer 0"}),
        .texture = undefined,
        .id = internal.newId(),
    };

    if (import_path) |import| {
        new_layer.texture = try Pixi.gfx.Texture.loadFromFile(import, .{});
    } else {
        new_layer.texture = try Pixi.gfx.Texture.createEmpty(internal.width, internal.height, .{});
    }

    try internal.layers.append(Pixi.app.allocator, new_layer);

    internal.keyframe_animation_texture = try Pixi.gfx.Texture.createEmpty(internal.width, internal.height, .{});
    internal.keyframe_transform_texture = .{
        .vertices = .{Pixi.storage.Internal.PixiFile.TransformVertex{ .position = zmath.f32x4s(0.0) }} ** 4,
        .texture = internal.layers.items(.texture)[0],
    };

    // Create sprites for all tiles.
    {
        const base_name = std.fs.path.basename(path);
        const ext = std.fs.path.extension(base_name);
        const ext_ind = if (std.mem.indexOf(u8, base_name, ext)) |index| index else base_name.len - 1;

        const tiles = @as(usize, @intCast(Pixi.editor.popups.file_setup_tiles[0] * Pixi.editor.popups.file_setup_tiles[1]));
        var i: usize = 0;
        while (i < tiles) : (i += 1) {
            const sprite: Pixi.storage.Internal.Sprite = .{
                .name = try std.fmt.allocPrintZ(Pixi.app.allocator, "{s}_{d}", .{ base_name[0..ext_ind], i }),
                .index = i,
            };
            try internal.sprites.append(Pixi.app.allocator, sprite);
        }
    }

    try Pixi.app.open_files.insert(0, internal);
    Pixi.Editor.setActiveFile(0);

    Pixi.app.allocator.free(path);

    return true;
}

/// Returns true if png was imported and new file created.
pub fn importPng(path: [:0]const u8, new_file_path: [:0]const u8) !bool {
    defer Pixi.app.allocator.free(path);
    if (!std.mem.eql(u8, std.fs.path.extension(path)[0..4], ".png"))
        return false;

    if (!std.mem.eql(u8, std.fs.path.extension(new_file_path)[0..5], ".pixi"))
        return false;

    return try newFile(new_file_path, path);
}

pub fn loadFileAsync(path: [:0]const u8) !?Pixi.storage.Internal.PixiFile {
    std.log.warn("loadFileAsync not implemented!", .{});
    _ = path;
}

pub fn loadFile(path: [:0]const u8) !?Pixi.storage.Internal.PixiFile {
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

        var parsed = try std.json.parseFromSlice(Pixi.storage.External.Pixi, Pixi.app.allocator, content, options);
        defer parsed.deinit();

        const external = parsed.value;

        var internal: Pixi.storage.Internal.PixiFile = .{
            .path = try Pixi.app.allocator.dupeZ(u8, path),
            .width = external.width,
            .height = external.height,
            .tile_width = external.tile_width,
            .tile_height = external.tile_height,
            .layers = .{},
            .deleted_layers = .{},
            .deleted_heightmap_layers = .{},
            .sprites = .{},
            .selected_sprites = std.ArrayList(usize).init(Pixi.app.allocator),
            .animations = .{},
            .keyframe_animations = .{},
            .keyframe_animation_texture = undefined,
            .keyframe_transform_texture = undefined,
            .deleted_animations = .{},
            .background = undefined,
            .history = Pixi.storage.Internal.PixiFile.History.init(Pixi.app.allocator),
            .buffers = Pixi.storage.Internal.PixiFile.Buffers.init(Pixi.app.allocator),
            .temporary_layer = undefined,
            .selection_layer = undefined,
        };

        try internal.createBackground();

        internal.temporary_layer = .{
            .name = "Temporary",
            .texture = try Pixi.gfx.Texture.createEmpty(internal.width, internal.height, .{}),
            .visible = true,
        };

        internal.selection_layer = .{
            .name = "Selection",
            .texture = try Pixi.gfx.Texture.createEmpty(internal.width, internal.height, .{}),
            .visible = true,
        };

        for (external.layers) |layer| {
            const layer_image_name = try std.fmt.allocPrintZ(Pixi.app.arena_allocator.allocator(), "{s}.png", .{layer.name});

            var img_buf: ?*anyopaque = null;
            var img_len: usize = 0;

            if (zip.zip_entry_open(pixi_file, layer_image_name.ptr) == 0) {
                _ = zip.zip_entry_read(pixi_file, &img_buf, &img_len);

                if (img_buf) |data| {
                    const pipeline_layout_default = Pixi.app.pipeline_default.getBindGroupLayout(0);
                    defer pipeline_layout_default.release();

                    var new_layer: Pixi.storage.Internal.Layer = .{
                        .name = try Pixi.app.allocator.dupeZ(u8, layer.name),
                        .texture = try Pixi.gfx.Texture.loadFromMemory(@as([*]u8, @ptrCast(data))[0..img_len], .{}),
                        .id = internal.newId(),
                        .visible = layer.visible,
                        .collapse = layer.collapse,
                        .transform_bindgroup = undefined,
                    };

                    const device: *mach.gpu.Device = Pixi.core.windows.get(Pixi.app.window, .device);

                    new_layer.transform_bindgroup = device.createBindGroup(
                        &mach.gpu.BindGroup.Descriptor.init(.{
                            .layout = pipeline_layout_default,
                            .entries = &.{
                                mach.gpu.BindGroup.Entry.initBuffer(0, Pixi.app.uniform_buffer_default, 0, @sizeOf(Pixi.gfx.UniformBufferObject), 0),
                                mach.gpu.BindGroup.Entry.initTextureView(1, new_layer.texture.view_handle),
                                mach.gpu.BindGroup.Entry.initSampler(2, new_layer.texture.sampler_handle),
                            },
                        }),
                    );
                    try internal.layers.append(Pixi.app.allocator, new_layer);
                }
            }
            _ = zip.zip_entry_close(pixi_file);
        }

        internal.keyframe_animation_texture = try Pixi.gfx.Texture.createEmpty(internal.width, internal.height, .{});

        internal.keyframe_transform_texture = .{
            .vertices = .{Pixi.storage.Internal.PixiFile.TransformVertex{ .position = zmath.f32x4s(0.0) }} ** 4,
            .texture = internal.layers.items(.texture)[0],
        };

        if (zip.zip_entry_open(pixi_file, "heightmap.png") == 0) {
            var img_buf: ?*anyopaque = null;
            var img_len: usize = 0;

            _ = zip.zip_entry_read(pixi_file, &img_buf, &img_len);

            if (img_buf) |data| {
                var new_layer: Pixi.storage.Internal.Layer = .{
                    .name = try Pixi.app.allocator.dupeZ(u8, "heightmap"),
                    .texture = undefined,
                };

                new_layer.texture = try Pixi.gfx.Texture.loadFromMemory(@as([*]u8, @ptrCast(data))[0..img_len], .{});
                new_layer.id = internal.newId();

                internal.heightmap.layer = new_layer;
            }
        }
        _ = zip.zip_entry_close(pixi_file);

        for (external.sprites, 0..) |sprite, i| {
            try internal.sprites.append(Pixi.app.allocator, .{
                .name = try Pixi.app.allocator.dupeZ(u8, sprite.name),
                .index = i,
                .origin_x = @as(f32, @floatFromInt(sprite.origin[0])),
                .origin_y = @as(f32, @floatFromInt(sprite.origin[1])),
            });
        }

        for (external.animations) |animation| {
            try internal.animations.append(Pixi.app.allocator, .{
                .name = try Pixi.app.allocator.dupeZ(u8, animation.name),
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

    for (Pixi.app.open_files.items, 0..) |file, i| {
        if (std.mem.eql(u8, file.path, path)) {
            setActiveFile(i);
            return false;
        }
    }

    if (try loadFile(path)) |file| {
        try Pixi.app.open_files.insert(0, file);
        setActiveFile(0);
        return true;
    }
    return error.FailedToOpenFile;
}

pub fn openReference(path: [:0]const u8) !bool {
    for (Pixi.app.open_references.items, 0..) |reference, i| {
        if (std.mem.eql(u8, reference.path, path)) {
            setActiveReference(i);
            return false;
        }
    }

    const texture = try Pixi.gfx.Texture.loadFromFile(path, .{});

    const reference: Pixi.storage.Internal.Reference = .{
        .path = try Pixi.app.allocator.dupeZ(u8, path),
        .texture = texture,
    };

    try Pixi.app.open_references.insert(0, reference);
    setActiveReference(0);

    if (!Pixi.editor.popups.references)
        Pixi.editor.popups.references = true;

    return true;
}

pub fn setActiveFile(index: usize) void {
    if (index >= Pixi.app.open_files.items.len) return;
    const file = &Pixi.app.open_files.items[index];
    if (file.heightmap.layer == null) {
        if (Pixi.app.tools.current == .heightmap)
            Pixi.app.tools.current = .pointer;
    }
    if (file.transform_texture != null and Pixi.app.tools.current != .pointer) {
        Pixi.app.tools.set(.pointer);
    }
    Pixi.app.open_file_index = index;
}

pub fn setCopyFile(index: usize) void {
    if (index >= Pixi.app.open_files.items.len) return;
    const file = &Pixi.app.open_files.items[index];
    if (file.heightmap.layer == null) {
        if (Pixi.app.tools.current == .heightmap)
            Pixi.app.tools.current = .pointer;
    }
    Pixi.app.copy_file_index = index;
}

pub fn setActiveReference(index: usize) void {
    if (index >= Pixi.app.open_references.items.len) return;
    Pixi.app.open_reference_index = index;
}

pub fn getFileIndex(path: [:0]const u8) ?usize {
    for (Pixi.app.open_files.items, 0..) |file, i| {
        if (std.mem.eql(u8, file.path, path))
            return i;
    }
    return null;
}

pub fn getFile(index: usize) ?*Pixi.storage.Internal.PixiFile {
    if (Pixi.app.open_files.items.len == 0) return null;
    if (index >= Pixi.app.open_files.items.len) return null;

    return &Pixi.app.open_files.items[index];
}

pub fn getReference(index: usize) ?*Pixi.storage.Internal.Reference {
    if (Pixi.app.open_references.items.len == 0) return null;
    if (index >= Pixi.app.open_references.items.len) return null;

    return &Pixi.app.open_references.items[index];
}

pub fn forceCloseFile(index: usize) !void {
    if (getFile(index)) |file| {
        _ = file;
        return rawCloseFile(index);
    }
}

pub fn forceCloseAllFiles() !void {
    const len: usize = Pixi.app.open_files.items.len;
    var i: usize = 0;
    while (i < len) : (i += 1) {
        try forceCloseFile(0);
    }
}

pub fn saveAllFiles() !void {
    for (Pixi.app.open_files.items) |*file| {
        _ = try file.save();
    }
}

pub fn closeFile(index: usize) !void {
    // Handle confirm close if file is dirty
    {
        const file = Pixi.app.open_files.items[index];
        if (file.dirty()) {
            Pixi.editor.popups.file_confirm_close = true;
            Pixi.editor.popups.file_confirm_close_state = .one;
            Pixi.editor.popups.file_confirm_close_index = index;
            return;
        }
    }

    try rawCloseFile(index);
}

pub fn rawCloseFile(index: usize) !void {
    Pixi.app.open_file_index = 0;
    var file: Pixi.storage.Internal.PixiFile = Pixi.app.open_files.orderedRemove(index);
    deinitFile(&file);
}

pub fn closeReference(index: usize) !void {
    Pixi.app.open_reference_index = 0;
    var reference: Pixi.storage.Internal.Reference = Pixi.app.open_references.orderedRemove(index);
    deinitReference(&reference);
}

pub fn deinitReference(reference: *Pixi.storage.Internal.Reference) void {
    reference.texture.deinit();
    Pixi.app.allocator.free(reference.path);
}

pub fn deinitFile(file: *Pixi.storage.Internal.PixiFile) void {
    file.history.deinit();
    file.buffers.deinit();
    file.background.deinit();
    file.temporary_layer.texture.deinit();
    file.selection_layer.texture.deinit();
    if (file.heightmap.layer) |*layer| {
        layer.texture.deinit();
        Pixi.app.allocator.free(layer.name);
    }
    if (file.transform_texture) |*texture| {
        texture.texture.deinit();
    }

    for (file.keyframe_animations.items(.keyframes)) |*keyframes| {
        // TODO: uncomment this when names are allocated
        //Pixi.app.allocator.free(animation.name);

        for (keyframes.items) |*keyframe| {
            keyframe.frames.deinit();
        }
    }
    file.keyframe_animations.deinit(Pixi.app.allocator);

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

    for (file.deleted_heightmap_layers.items(.texture)) |*texture| {
        texture.deinit();
    }
    for (file.deleted_layers.items(.texture)) |*texture| {
        texture.deinit();
    }
    for (file.layers.items(.texture)) |*texture| {
        texture.deinit();
    }
    for (file.layers.items(.name), 0..) |_, index| {
        Pixi.app.allocator.free(file.layers.items(.name)[index]);
    }
    for (file.layers.items(.transform_bindgroup)) |bindgroup| {
        if (bindgroup) |b|
            b.release();
    }
    for (file.deleted_layers.items(.name), 0..) |_, index| {
        Pixi.app.allocator.free(file.deleted_layers.items(.name)[index]);
    }
    for (file.deleted_layers.items(.texture)) |*texture| {
        texture.deinit();
    }
    for (file.deleted_layers.items(.transform_bindgroup)) |bindgroup| {
        if (bindgroup) |b|
            b.release();
    }
    for (file.sprites.items(.name), 0..) |_, index| {
        Pixi.app.allocator.free(file.sprites.items(.name)[index]);
    }
    for (file.animations.items(.name), 0..) |_, index| {
        Pixi.app.allocator.free(file.animations.items(.name)[index]);
    }
    for (file.deleted_animations.items(.name), 0..) |_, index| {
        Pixi.app.allocator.free(file.deleted_animations.items(.name)[index]);
    }

    file.keyframe_animation_texture.deinit();
    file.layers.deinit(Pixi.app.allocator);
    file.deleted_layers.deinit(Pixi.app.allocator);
    file.deleted_heightmap_layers.deinit(Pixi.app.allocator);
    file.sprites.deinit(Pixi.app.allocator);
    file.selected_sprites.deinit();
    file.animations.deinit(Pixi.app.allocator);
    file.deleted_animations.deinit(Pixi.app.allocator);
    Pixi.app.allocator.free(file.path);
}

pub fn deinit() !void {
    for (Pixi.app.open_files.items) |_| {
        try closeFile(0);
    }
    Pixi.app.open_files.deinit();

    for (Pixi.app.open_references.items) |*reference| {
        reference.deinit();
    }
    Pixi.app.open_references.deinit();

    if (Pixi.app.project_folder) |folder| {
        Pixi.app.allocator.free(folder);
    }
}
