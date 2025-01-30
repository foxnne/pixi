const std = @import("std");

const mach = @import("mach");
const pixi = @import("../pixi.zig");

const App = pixi.App;
const Core = mach.Core;

pub const Settings = @import("Settings.zig");
pub const Colors = @import("Colors.zig");
pub const Recents = @import("Recents.zig");
pub const Tools = @import("Tools.zig");
pub const Theme = @import("Theme.zig");

pub const Constants = @import("Constants.zig");

const zip = @import("zip");
const zstbi = @import("zstbi");
const zgpu = @import("zgpu");
const nfd = @import("nfd");
const imgui = @import("zig-imgui");
const zmath = @import("zmath");

pub const Editor = @This();

// Modules
pub const Explorer = @import("explorer/Explorer.zig");
pub const Popups = @import("popups/Popups.zig");
pub const Artboard = @import("artboard/Artboard.zig");
pub const Sidebar = @import("Sidebar.zig");

pub const mach_module = .editor;
pub const mach_systems = .{
    .init,
    .lateInit,
    .processDialogRequest,
    .tick,
    .close,
    .deinit,
};

/// This arena is for small per-frame editor allocations, such as path joins, null terminations and labels.
/// Do not free these allocations, instead, this allocator will be .reset(.retain_capacity) each frame
arena: std.heap.ArenaAllocator,

theme: Theme,
settings: Settings,
hotkeys: pixi.input.Hotkeys,
recents: Recents,

// Module pointers
explorer: *Explorer,
popups: *Popups,
artboard: *Artboard,
sidebar: *Sidebar,

project_folder: ?[:0]const u8 = null,

previous_atlas_export: ?[:0]const u8 = null,
open_files: std.ArrayList(pixi.Internal.File) = undefined,
open_references: std.ArrayList(pixi.Internal.Reference) = undefined,
open_file_index: usize = 0,
open_reference_index: usize = 0,

atlas: pixi.Internal.Atlas = .{},
tools: Tools = .{},

colors: Colors = .{},

selection_time: f32 = 0.0,
selection_invert: bool = false,

clipboard_image: ?zstbi.Image = null,
clipboard_position: [2]u32 = .{ 0, 0 },

pub fn init(
    app: *App,
    editor: *Editor,
    _popups: *Popups,
    _explorer: *Explorer,
    _artboard: *Artboard,
    _sidebar: *Sidebar,
    sidebar_mod: mach.Mod(Sidebar),
    explorer_mod: mach.Mod(Explorer),
    artboard_mod: mach.Mod(Artboard),
    popups_mod: mach.Mod(Popups),
) !void {
    editor.* = .{
        .theme = undefined, // Leave theme undefined for now since settings need to load first
        .popups = _popups,
        .explorer = _explorer,
        .artboard = _artboard,
        .sidebar = _sidebar,
        .settings = try Settings.loadOrDefault(app.allocator),
        .hotkeys = try pixi.input.Hotkeys.initDefault(app.allocator),
        .recents = try Recents.load(app.allocator),
        .arena = std.heap.ArenaAllocator.init(std.heap.page_allocator),
    };

    editor.open_files = std.ArrayList(pixi.Internal.File).init(app.allocator);
    editor.open_references = std.ArrayList(pixi.Internal.Reference).init(app.allocator);

    editor.colors.keyframe_palette = try pixi.Internal.Palette.loadFromFile(pixi.paths.pear36_hex.path);

    sidebar_mod.call(.init);
    explorer_mod.call(.init);
    artboard_mod.call(.init);
    popups_mod.call(.init);
}

pub fn lateInit(core: *Core, app: *App, editor: *Editor) !void {
    const theme_path = try std.fs.path.joinZ(app.allocator, &.{ pixi.paths.themes, editor.settings.theme });
    defer app.allocator.free(theme_path);

    editor.theme = try Theme.loadOrDefault(theme_path);
    editor.theme.init(core, app);
}

pub fn processDialogRequest(editor: *Editor) !void {
    if (editor.popups.file_dialog_request) |request| {
        defer editor.popups.file_dialog_request = null;
        const initial = if (request.initial) |initial| initial else editor.project_folder;

        if (switch (request.state) {
            .file => try nfd.openFileDialog(request.filter, initial),
            .folder => try nfd.openFolderDialog(initial),
            .save => try nfd.saveFileDialog(request.filter, initial),
        }) |path| {
            editor.popups.file_dialog_response = .{
                .path = path,
                .type = request.type,
            };
        }
    }
}

pub fn tick(
    core: *Core,
    app: *App,
    editor: *Editor,
    sidebar_mod: mach.Mod(Sidebar),
    explorer_mod: mach.Mod(Explorer),
    artboard_mod: mach.Mod(Artboard),
    popups_mod: mach.Mod(Popups),
) !void {
    imgui.pushStyleVarImVec2(imgui.StyleVar_SeparatorTextAlign, .{ .x = editor.settings.explorer_title_align, .y = 0.5 });
    defer imgui.popStyleVar();

    editor.theme.push(core, app);
    defer editor.theme.pop();

    sidebar_mod.call(.draw);
    explorer_mod.call(.draw);
    artboard_mod.call(.draw);
    popups_mod.call(.draw);

    // Accept transformations
    {
        const window = core.windows.getValue(app.window);
        for (editor.open_files.items) |*file| {
            if (file.transform_texture) |*transform_texture| {
                if (transform_texture.confirm) {
                    // Blit temp layer to selected layer
                    if (file.transform_staging_buffer) |staging_buffer| {
                        const buffer_size: usize = @as(usize, @intCast(file.width * file.height));

                        var response: mach.gpu.Buffer.MapAsyncStatus = undefined;
                        const callback = (struct {
                            pub inline fn callback(ctx: *mach.gpu.Buffer.MapAsyncStatus, status: mach.gpu.Buffer.MapAsyncStatus) void {
                                ctx.* = status;
                            }
                        }).callback;

                        staging_buffer.mapAsync(.{ .read = true }, 0, buffer_size * @sizeOf([4]f32), &response, callback);
                        while (true) {
                            if (response == mach.gpu.Buffer.MapAsyncStatus.success) {
                                break;
                            } else {
                                window.device.tick();
                            }
                        }

                        const layer_index = file.selected_layer_index;
                        const write_layer = file.layers.get(file.selected_layer_index);

                        if (staging_buffer.getConstMappedRange([4]f32, 0, buffer_size)) |buffer_mapped| {
                            for (write_layer.pixels(), buffer_mapped, 0..) |*p, b, i| {
                                if (b[3] != 0.0) {
                                    try file.buffers.stroke.append(i, p.*);

                                    const out: [4]u8 = .{
                                        @as(u8, @intFromFloat(b[0] * 255.0)),
                                        @as(u8, @intFromFloat(b[1] * 255.0)),
                                        @as(u8, @intFromFloat(b[2] * 255.0)),
                                        @as(u8, @intFromFloat(b[3] * 255.0)),
                                    };
                                    p.* = out;
                                }
                            }
                        }

                        // Submit the stroke change buffer
                        if (file.buffers.stroke.indices.items.len > 0) {
                            const change = try file.buffers.stroke.toChange(@intCast(layer_index));
                            try file.history.append(change);
                        }

                        staging_buffer.unmap();

                        var texture: *pixi.gfx.Texture = &file.layers.items(.texture)[file.selected_layer_index];
                        texture.update(window.device);
                    }

                    transform_texture.texture.deinit();
                    file.transform_texture = null;
                }
            }
        }
    }

    for (editor.hotkeys.hotkeys) |*hotkey| {
        hotkey.previous_state = hotkey.state;
    }

    // Reset the arena but keep the memory from the last frame available
    _ = editor.arena.reset(.retain_capacity);
}

pub fn close(app: *App, editor: *Editor) void {
    var should_close = true;
    for (editor.open_files.items) |file| {
        if (file.dirty()) {
            should_close = false;
        }
    }

    if (!should_close and !editor.popups.file_confirm_close_exit) {
        editor.popups.file_confirm_close = true;
        editor.popups.file_confirm_close_state = .all;
        editor.popups.file_confirm_close_exit = true;
    }
    app.should_close = should_close;
}

pub fn setProjectFolder(editor: *Editor, path: [:0]const u8) !void {
    if (editor.project_folder) |folder| {
        pixi.app.allocator.free(folder);
    }
    editor.project_folder = try pixi.app.allocator.dupeZ(u8, path);
    try editor.recents.appendFolder(try pixi.app.allocator.dupeZ(u8, path));
    editor.explorer.pane = .files;
}

pub fn saving(editor: *Editor) bool {
    for (editor.open_files.items) |file| {
        if (file.saving) return true;
    }
    return false;
}

/// Returns true if a new file was created.
pub fn newFile(editor: *Editor, path: [:0]const u8, import_path: ?[:0]const u8) !bool {
    for (editor.open_files.items, 0..) |file, i| {
        if (std.mem.eql(u8, file.path, path)) {
            editor.setActiveFile(i);
            return false;
        }
    }

    var internal: pixi.Internal.File = .{
        .path = try pixi.app.allocator.dupeZ(u8, path),
        .width = @as(u32, @intCast(editor.popups.file_setup_tiles[0] * editor.popups.file_setup_tile_size[0])),
        .height = @as(u32, @intCast(editor.popups.file_setup_tiles[1] * editor.popups.file_setup_tile_size[1])),
        .tile_width = @as(u32, @intCast(editor.popups.file_setup_tile_size[0])),
        .tile_height = @as(u32, @intCast(editor.popups.file_setup_tile_size[1])),
        .layers = .{},
        .deleted_layers = .{},
        .deleted_heightmap_layers = .{},
        .sprites = .{},
        .selected_sprites = std.ArrayList(usize).init(pixi.app.allocator),
        .animations = .{},
        .keyframe_animations = .{},
        .keyframe_animation_texture = undefined,
        .keyframe_transform_texture = undefined,
        .deleted_animations = .{},
        .background = undefined,
        .history = pixi.Internal.File.History.init(pixi.app.allocator),
        .buffers = pixi.Internal.File.Buffers.init(pixi.app.allocator),
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

    var new_layer: pixi.Internal.Layer = .{
        .name = try std.fmt.allocPrintZ(pixi.app.allocator, "{s}", .{"Layer 0"}),
        .texture = undefined,
        .id = internal.newId(),
    };

    if (import_path) |import| {
        new_layer.texture = try pixi.gfx.Texture.loadFromFile(import, .{});
    } else {
        new_layer.texture = try pixi.gfx.Texture.createEmpty(internal.width, internal.height, .{});
    }

    try internal.layers.append(pixi.app.allocator, new_layer);

    internal.keyframe_animation_texture = try pixi.gfx.Texture.createEmpty(internal.width, internal.height, .{});
    internal.keyframe_transform_texture = .{
        .vertices = .{pixi.Internal.File.TransformVertex{ .position = zmath.f32x4s(0.0) }} ** 4,
        .texture = internal.layers.items(.texture)[0],
    };

    // Create sprites for all tiles.
    {
        const tiles = @as(usize, @intCast(editor.popups.file_setup_tiles[0] * editor.popups.file_setup_tiles[1]));
        var i: usize = 0;
        while (i < tiles) : (i += 1) {
            const sprite: pixi.Internal.Sprite = .{
                .index = i,
            };
            try internal.sprites.append(pixi.app.allocator, sprite);
        }
    }

    try editor.open_files.insert(0, internal);
    editor.setActiveFile(0);

    return true;
}

/// Returns true if png was imported and new file created.
pub fn importPng(editor: *Editor, png_path: [:0]const u8, new_file_path: [:0]const u8) !bool {
    if (!std.mem.eql(u8, std.fs.path.extension(png_path)[0..4], ".png"))
        return false;

    if (!std.mem.eql(u8, std.fs.path.extension(new_file_path)[0..5], ".pixi"))
        return false;

    return try editor.newFile(new_file_path, png_path);
}

/// Returns true if a new file was opened.
pub fn openFile(editor: *Editor, path: [:0]const u8) !bool {
    if (!std.mem.eql(u8, std.fs.path.extension(path[0..path.len]), ".pixi"))
        return false;

    for (editor.open_files.items, 0..) |file, i| {
        if (std.mem.eql(u8, file.path, path)) {
            editor.setActiveFile(i);
            return false;
        }
    }

    if (try pixi.Internal.File.load(path)) |file| {
        try editor.open_files.insert(0, file);
        editor.setActiveFile(0);
        return true;
    }
    return error.FailedToOpenFile;
}

pub fn openReference(editor: *Editor, path: [:0]const u8) !bool {
    for (editor.open_references.items, 0..) |reference, i| {
        if (std.mem.eql(u8, reference.path, path)) {
            editor.setActiveReference(i);
            return false;
        }
    }

    const texture = try pixi.gfx.Texture.loadFromFile(path, .{});

    const reference: pixi.Internal.Reference = .{
        .path = try pixi.app.allocator.dupeZ(u8, path),
        .texture = texture,
    };

    try editor.open_references.insert(0, reference);
    editor.setActiveReference(0);

    if (!editor.popups.references)
        editor.popups.references = true;

    return true;
}

pub fn setActiveFile(editor: *Editor, index: usize) void {
    if (index >= editor.open_files.items.len) return;
    const file = &editor.open_files.items[index];
    if (file.heightmap.layer == null) {
        if (editor.tools.current == .heightmap)
            editor.tools.current = .pointer;
    }
    if (file.transform_texture != null and editor.tools.current != .pointer) {
        editor.tools.set(.pointer);
    }
    editor.open_file_index = index;
}

pub fn setCopyFile(editor: *Editor, index: usize) void {
    if (index >= editor.open_files.items.len) return;
    const file = &editor.open_files.items[index];
    if (file.heightmap.layer == null) {
        if (editor.tools.current == .heightmap)
            editor.tools.current = .pointer;
    }
    editor.copy_file_index = index;
}

pub fn setActiveReference(editor: *Editor, index: usize) void {
    if (index >= editor.open_references.items.len) return;
    editor.open_reference_index = index;
}

pub fn getFileIndex(editor: *Editor, path: [:0]const u8) ?usize {
    for (editor.open_files.items, 0..) |file, i| {
        if (std.mem.eql(u8, file.path, path))
            return i;
    }
    return null;
}

pub fn getFile(editor: *Editor, index: usize) ?*pixi.Internal.File {
    if (editor.open_files.items.len == 0) return null;
    if (index >= editor.open_files.items.len) return null;

    return &editor.open_files.items[index];
}

pub fn getReference(editor: *Editor, index: usize) ?*pixi.Internal.Reference {
    if (editor.open_references.items.len == 0) return null;
    if (index >= editor.open_references.items.len) return null;

    return &editor.open_references.items[index];
}

pub fn forceCloseFile(editor: *Editor, index: usize) !void {
    if (editor.getFile(index)) |file| {
        _ = file;
        return editor.rawCloseFile(index);
    }
}

pub fn forceCloseAllFiles(editor: *Editor) !void {
    const len: usize = editor.open_files.items.len;
    var i: usize = 0;
    while (i < len) : (i += 1) {
        try editor.forceCloseFile(0);
    }
}

pub fn saveAllFiles(editor: *Editor) !void {
    for (editor.open_files.items) |*file| {
        _ = try file.save();
    }
}

pub fn closeFile(editor: *Editor, index: usize) !void {
    // Handle confirm close if file is dirty
    {
        const file = editor.open_files.items[index];
        if (file.dirty()) {
            editor.popups.file_confirm_close = true;
            editor.popups.file_confirm_close_state = .one;
            editor.popups.file_confirm_close_index = index;
            return;
        }
    }

    try editor.rawCloseFile(index);
}

pub fn rawCloseFile(editor: *Editor, index: usize) !void {
    editor.open_file_index = 0;
    var file: pixi.Internal.File = editor.open_files.orderedRemove(index);
    file.deinit();
}

pub fn closeReference(editor: *Editor, index: usize) !void {
    editor.open_reference_index = 0;
    var reference: pixi.Internal.Reference = editor.open_references.orderedRemove(index);
    reference.deinit();
}

pub fn deinit(editor: *Editor, app: *App) !void {
    for (editor.open_files.items) |_| try editor.closeFile(0);
    editor.open_files.deinit();

    for (editor.open_references.items) |*reference| reference.deinit();
    editor.open_references.deinit();

    if (editor.atlas.data) |*data| data.deinit(app.allocator);
    if (editor.previous_atlas_export) |path| app.allocator.free(path);

    if (editor.atlas.texture) |*texture| texture.deinit();
    if (editor.atlas.heightmap) |*heightmap| heightmap.deinit();
    if (editor.colors.palette) |*palette| palette.deinit();
    if (editor.colors.keyframe_palette) |*keyframe_palette| keyframe_palette.deinit();

    app.allocator.free(editor.hotkeys.hotkeys);

    if (editor.clipboard_image) |*image| image.deinit();

    try editor.recents.save();
    editor.recents.deinit();

    try editor.settings.save(app.allocator);
    editor.settings.deinit(app.allocator);

    if (editor.project_folder) |folder| app.allocator.free(folder);

    editor.arena.deinit();
}
