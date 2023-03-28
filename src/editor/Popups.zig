const std = @import("std");
const Popups = @This();
const pixi = @import("root");
const editor = pixi.editor;
const zstbi = @import("zstbi");

// Renaming
rename: bool = false,
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
// About
about: bool = false,

pub const SetupState = enum {
    none,
    new,
    slice,
    import_png,
};

pub fn setupFileNew(popups: *Popups, new_file_path: [:0]const u8) void {
    popups.file_setup = true;
    popups.file_setup_state = .new;
    popups.file_setup_path = [_]u8{0} ** std.fs.MAX_PATH_BYTES;
    std.mem.copy(u8, popups.file_setup_path[0..], new_file_path);
}

pub fn setupFileSlice(popups: *Popups, path: [:0]const u8) void {
    popups.file_setup = true;
    popups.file_setup_state = .slice;
    popups.file_setup_path = [_]u8{0} ** std.fs.MAX_PATH_BYTES;
    std.mem.copy(u8, popups.file_setup_path[0..], path);

    if (editor.getFileIndex(path)) |index| {
        if (editor.getFile(index)) |file| {
            popups.file_setup_tile_size = .{ @intCast(i32, file.tile_width), @intCast(i32, file.tile_height) };
            popups.file_setup_tiles = .{ @intCast(i32, @divExact(file.width, file.tile_width)), @intCast(i32, @divExact(file.height, file.tile_height)) };
            popups.file_setup_width = @intCast(i32, file.width);
            popups.file_setup_height = @intCast(i32, file.height);
        }
    }
}

pub fn setupFileClose(popups: *Popups) void {
    popups.file_setup = false;
    popups.file_setup_state = .none;
}

pub fn setupFileImportPng(popups: *Popups, new_file_path: [:0]const u8, png_path: [:0]const u8) void {
    popups.file_setup = true;
    popups.file_setup_state = .import_png;
    popups.file_setup_path = [_]u8{0} ** std.fs.MAX_PATH_BYTES;
    popups.file_setup_png_path = [_]u8{0} ** std.fs.MAX_PATH_BYTES;
    std.mem.copy(u8, popups.file_setup_path[0..], new_file_path);
    std.mem.copy(u8, popups.file_setup_png_path[0..], png_path);

    if (std.mem.eql(u8, std.fs.path.extension(png_path), ".png")) {
        const png_info = zstbi.Image.info(png_path);
        popups.file_setup_width = @intCast(i32, png_info.width);
        popups.file_setup_height = @intCast(i32, png_info.height);
        popups.file_setup_tile_size = .{ popups.file_setup_width, popups.file_setup_height };
        popups.file_setup_tiles = .{ 1, 1 };
    }
}
