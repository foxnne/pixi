const std = @import("std");

const pixi = @import("../../pixi.zig");
const zstbi = @import("zstbi");

const Core = @import("mach").Core;
const App = pixi.App;
const Editor = pixi.Editor;
const Assets = pixi.Assets;

const Popups = @This();

pub const mach_module = .popups;
pub const mach_systems = .{ .init, .deinit, .draw };

pub const popup_rename = @import("rename.zig");
pub const popup_folder = @import("folder.zig");
pub const popup_file_setup = @import("file_setup.zig");
pub const popup_about = @import("about.zig");
pub const popup_file_confirm_close = @import("file_confirm_close.zig");
pub const popup_layer_setup = @import("layer_setup.zig");
pub const popup_print = @import("print.zig");
pub const popup_animation = @import("animation.zig");
pub const popup_heightmap = @import("heightmap.zig");
pub const popup_references = @import("references.zig");

// Renaming
rename: bool = false,
rename_state: RenameState = .none,
rename_path: [Editor.Constants.max_path_len:0]u8 = undefined,
rename_old_path: [Editor.Constants.max_path_len:0]u8 = undefined,

// New Folder
folder: bool = false,
folder_path: [Editor.Constants.max_path_len:0]u8 = undefined,

// File setup
file_setup: bool = false,
file_setup_state: SetupState = .none,
file_setup_path: [Editor.Constants.max_path_len:0]u8 = undefined,
file_setup_png_path: [Editor.Constants.max_path_len:0]u8 = undefined,
file_setup_tile_size: [2]i32 = .{ 32, 32 },
file_setup_tiles: [2]i32 = .{ 32, 32 },
file_setup_width: i32 = 0,
file_setup_height: i32 = 0,
// File close
file_confirm_close: bool = false,
file_confirm_close_index: usize = 0,
file_confirm_close_state: CloseState = .none,
file_confirm_close_exit: bool = false,
// Layer Setup
layer_setup: bool = false,
layer_setup_state: RenameState = .none,
layer_setup_name: [Editor.Constants.max_name_len:0]u8 = undefined,
layer_setup_index: usize = 0,
// Print
print: bool = false,
print_state: PrintState = .selected_sprite,
print_scale: u32 = 1,
print_preserve_names: bool = false,
print_animation_gif: bool = true,
// Animation
animation: bool = false,
animation_index: usize = 0,
animation_state: AnimationState = .none,
animation_start: usize = 0,
animation_length: usize = 0,
animation_name: [Editor.Constants.max_name_len:0]u8 = undefined,
animation_fps: usize = 0,

heightmap: bool = false,
about: bool = false,
references: bool = false,

file_dialog_request: ?FileDialogRequest = null,
file_dialog_response: ?FileDialogResponse = null,

pub const SetupState = enum { none, new, slice, import_png };
pub const RenameState = enum { none, rename, duplicate };
pub const PrintState = enum { selected_sprite, selected_animation, selected_layer, all_layers, full_image };
pub const CloseState = enum { none, one, all };
pub const AnimationState = enum { none, create, edit };
pub const UserState = enum { file, folder, save };
pub const UserPathType = enum {
    project,
    export_sprite,
    export_animation,
    export_layer,
    export_all_layers,
    export_full_image,
    new_png,
    export_atlas,
    export_theme,
};

pub const FileDialogRequest = struct {
    state: UserState,
    type: UserPathType,
    initial: ?[:0]const u8 = null,
    filter: ?[:0]const u8 = null,
};

pub const FileDialogResponse = struct {
    path: [:0]const u8,
    type: UserPathType,
};

pub fn init(popups: *Popups) !void {
    popups.* = .{};
}

pub fn draw(popups: *Popups, app: *App, editor: *Editor, assets: *Assets) !void {
    try popup_rename.draw(popups, app, editor);
    try popup_folder.draw(popups, app);
    try popup_file_setup.draw(editor);
    try popup_about.draw(editor, assets);
    try popup_file_confirm_close.draw(editor);
    try popup_layer_setup.draw(editor);
    try popup_print.draw(editor);
    try popup_animation.draw(editor);
    try popup_heightmap.draw(editor);
    try popup_references.draw(editor);
}

pub fn deinit() void {
    // TODO: Free memory
}

pub fn anyPopupOpen(popups: *Popups) bool {
    return popups.rename or
        popups.file_setup or
        popups.file_confirm_close or
        popups.layer_setup or
        popups.print or
        popups.animation or
        popups.about or
        popups.heightmap;
}

pub fn fileSetupNew(popups: *Popups, new_file_path: [:0]const u8) void {
    popups.file_setup = true;
    popups.file_setup_state = .new;
    popups.file_setup_path = [_:0]u8{0} ** std.fs.max_path_bytes;
    @memcpy(popups.file_setup_path[0..new_file_path.len :0], new_file_path);
}

pub fn fileSetupSlice(popups: *Popups, path: [:0]const u8) void {
    popups.file_setup = true;
    popups.file_setup_state = .slice;
    popups.file_setup_path = [_:0]u8{0} ** std.fs.max_path_bytes;
    @memcpy(popups.file_setup_path[0..path.len :0], path);

    if (pixi.editor.getFileIndex(path)) |index| {
        if (pixi.editor.getFile(index)) |file| {
            popups.file_setup_tile_size = .{ @as(i32, @intCast(file.tile_width)), @as(i32, @intCast(file.tile_height)) };
            popups.file_setup_tiles = .{ @as(i32, @intCast(@divExact(file.width, file.tile_width))), @as(i32, @intCast(@divExact(file.height, file.tile_height))) };
            popups.file_setup_width = @as(i32, @intCast(file.width));
            popups.file_setup_height = @as(i32, @intCast(file.height));
        }
    }
}

pub fn fileSetupClose(popups: *Popups) void {
    popups.file_setup = false;
    popups.file_setup_state = .none;
}

pub fn fileSetupImportPng(popups: *Popups, new_file_path: [:0]const u8, png_path: [:0]const u8) void {
    popups.file_setup = true;
    popups.file_setup_state = .import_png;
    popups.file_setup_path = [_:0]u8{0} ** std.fs.max_path_bytes;
    popups.file_setup_png_path = [_:0]u8{0} ** std.fs.max_path_bytes;
    @memcpy(popups.file_setup_path[0..new_file_path.len :0], new_file_path);
    @memcpy(popups.file_setup_png_path[0..png_path.len :0], png_path);

    if (std.mem.eql(u8, std.fs.path.extension(png_path), ".png")) {
        const png_info = zstbi.Image.info(png_path);
        popups.file_setup_width = @as(i32, @intCast(png_info.width));
        popups.file_setup_height = @as(i32, @intCast(png_info.height));
        popups.file_setup_tile_size = .{ popups.file_setup_width, popups.file_setup_height };
        popups.file_setup_tiles = .{ 1, 1 };
    }
}
