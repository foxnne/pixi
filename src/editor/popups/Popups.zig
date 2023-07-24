const std = @import("std");
const Popups = @This();
const pixi = @import("../../pixi.zig");
const editor = pixi.editor;
const zstbi = @import("zstbi");

// Renaming
rename: bool = false,
rename_state: RenameState = .none,
rename_path: [std.fs.MAX_PATH_BYTES]u8 = undefined,
rename_old_path: [std.fs.MAX_PATH_BYTES]u8 = undefined,
// File setup
file_setup: bool = false,
file_setup_state: SetupState = .none,
file_setup_path: [std.fs.MAX_PATH_BYTES]u8 = undefined,
file_setup_png_path: [std.fs.MAX_PATH_BYTES]u8 = undefined,
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
layer_setup_name: [128:0]u8 = undefined,
layer_setup_index: usize = 0,
// Export to png
export_to_png: bool = false,
export_to_png_state: ExportToPngState = .selected_sprite,
export_to_png_scale: u32 = 1,
export_to_png_preserve_names: bool = true,
// Animation
animation: bool = false,
animation_index: usize = 0,
animation_state: AnimationState = .none,
animation_start: usize = 0,
animation_length: usize = 0,
animation_name: [128:0]u8 = undefined,
animation_fps: usize = 0,
// Heightmap
heightmap: bool = false,
// About
about: bool = false,
// User
user_state: UserState = .none,
user_filter: ?[:0]const u8 = null,
user_path: ?[:0]const u8 = null,
user_path_type: UserPathType = .none,

pub const SetupState = enum { none, new, slice, import_png };
pub const RenameState = enum { none, rename, duplicate };
pub const ExportToPngState = enum { selected_sprite, selected_animation, selected_layer, all_layers, full_image };
pub const CloseState = enum { none, one, all };
pub const AnimationState = enum { none, create, edit };
pub const UserState = enum { none, file, folder, save };
pub const UserPathType = enum {
    none,
    project,
    export_sprite,
    export_animation,
    export_layer,
    export_all_layers,
    export_full_image,
    new_png,
};

pub fn anyPopupOpen(popups: *Popups) bool {
    return popups.rename or popups.file_setup or popups.file_confirm_close or popups.layer_setup or popups.export_to_png or popups.animation;
}

pub fn fileSetupNew(popups: *Popups, new_file_path: [:0]const u8) void {
    popups.file_setup = true;
    popups.file_setup_state = .new;
    popups.file_setup_path = [_]u8{0} ** std.fs.MAX_PATH_BYTES;
    std.mem.copy(u8, popups.file_setup_path[0..], new_file_path);
}

pub fn fileSetupSlice(popups: *Popups, path: [:0]const u8) void {
    popups.file_setup = true;
    popups.file_setup_state = .slice;
    popups.file_setup_path = [_]u8{0} ** std.fs.MAX_PATH_BYTES;
    std.mem.copy(u8, popups.file_setup_path[0..], path);

    if (editor.getFileIndex(path)) |index| {
        if (editor.getFile(index)) |file| {
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
    popups.file_setup_path = [_]u8{0} ** std.fs.MAX_PATH_BYTES;
    popups.file_setup_png_path = [_]u8{0} ** std.fs.MAX_PATH_BYTES;
    std.mem.copy(u8, popups.file_setup_path[0..], new_file_path);
    std.mem.copy(u8, popups.file_setup_png_path[0..], png_path);

    if (std.mem.eql(u8, std.fs.path.extension(png_path), ".png")) {
        const png_info = zstbi.Image.info(png_path);
        popups.file_setup_width = @as(i32, @intCast(png_info.width));
        popups.file_setup_height = @as(i32, @intCast(png_info.height));
        popups.file_setup_tile_size = .{ popups.file_setup_width, popups.file_setup_height };
        popups.file_setup_tiles = .{ 1, 1 };
    }
}
