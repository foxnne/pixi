// These are functions specific to the backend, which is currently SDL3
const pixi = @import("pixi.zig");
const std = @import("std");
const builtin = @import("builtin");
const dvui = @import("dvui");
const sdl3 = @import("backend").c;
const objc = @import("objc");
const win32 = @import("win32");

pub fn setTitlebarColor(win: *dvui.Window, color: dvui.Color) void {
    if (builtin.os.tag == .macos) {
        const native_window: ?*objc.app_kit.Window = @ptrCast(sdl3.SDL_GetPointerProperty(
            sdl3.SDL_GetWindowProperties(win.backend.impl.window),
            sdl3.SDL_PROP_WINDOW_COCOA_WINDOW_POINTER,
            null,
        ));

        if (native_window) |window| {
            window.setTitlebarAppearsTransparent(true);
            const new_color = objc.app_kit.Color.colorWithRed_green_blue_alpha(
                @as(f32, @floatFromInt(color.r)) / 255.0,
                @as(f32, @floatFromInt(color.g)) / 255.0,
                @as(f32, @floatFromInt(color.b)) / 255.0,
                @as(f32, @floatFromInt(color.a)) / 255.0,
            );
            window.setBackgroundColor(new_color);

            window.setHasShadow(true);
        }
    } else if (builtin.os.tag == .windows) {
        const colorref = @as(u32, @intCast(color.r)) |
            (@as(u32, @intCast(color.g)) << 8) |
            (@as(u32, @intCast(color.b)) << 16);

        // Set both caption color and border color
        _ = win32.graphics.dwm.DwmSetWindowAttribute(@ptrCast(sdl3.SDL_GetPointerProperty(
            sdl3.SDL_GetWindowProperties(win.backend.impl.window),
            sdl3.SDL_PROP_WINDOW_WIN32_HWND_POINTER,
            null,
        )), win32.graphics.dwm.DWMWA_CAPTION_COLOR, &colorref, @sizeOf(u32));

        _ = win32.graphics.dwm.DwmSetWindowAttribute(@ptrCast(sdl3.SDL_GetPointerProperty(
            sdl3.SDL_GetWindowProperties(win.backend.impl.window),
            sdl3.SDL_PROP_WINDOW_WIN32_HWND_POINTER,
            null,
        )), win32.graphics.dwm.DWMWA_BORDER_COLOR, &colorref, @sizeOf(u32));
    }
}

pub fn showSimpleMessage(title: [:0]const u8, message: [:0]const u8) void {
    if (sdl3.SDL_ShowSimpleMessageBox(sdl3.SDL_MESSAGEBOX_INFORMATION, title, message, dvui.currentWindow().backend.impl.window)) {
        std.log.debug("true!", .{});
    }
}

pub fn showSaveFileDialog(cb: *const fn (?[][:0]const u8) void, filters: []const sdl3.SDL_DialogFileFilter, default_filename: []const u8, default_folder: ?[]const u8) void {
    const default: [:0]const u8 = blk: {
        if (default_folder) |folder| {
            break :blk std.fs.path.joinZ(pixi.app.allocator, &.{ folder, default_filename }) catch "untitled";
        } else if (pixi.editor.recents.last_save_folder) |last_save_folder| {
            break :blk std.fs.path.joinZ(pixi.app.allocator, &.{ last_save_folder, default_filename }) catch "untitled";
        } else {
            break :blk std.fs.path.joinZ(pixi.app.allocator, &.{ pixi.editor.folder orelse "", default_filename }) catch "untitled";
        }
    };
    defer pixi.app.allocator.free(default);
    sdl3.SDL_ShowSaveFileDialog(GenericSaveDialogCallback, @ptrCast(@alignCast(@constCast(cb))), dvui.currentWindow().backend.impl.window, filters.ptr, @intCast(filters.len), default);
}

pub fn showOpenFileDialog(cb: *const fn (?[][:0]const u8) void, filters: []const sdl3.SDL_DialogFileFilter, default_filename: []const u8, default_folder: ?[]const u8) void {
    const default: [:0]const u8 = blk: {
        if (default_folder) |folder| {
            break :blk std.fs.path.joinZ(pixi.app.allocator, &.{ folder, default_filename }) catch "untitled";
        } else if (pixi.editor.recents.last_open_folder) |last_open_folder| {
            break :blk std.fs.path.joinZ(pixi.app.allocator, &.{ last_open_folder, default_filename }) catch "untitled";
        } else {
            break :blk std.fs.path.joinZ(pixi.app.allocator, &.{ pixi.editor.folder orelse "", default_filename }) catch "untitled";
        }
    };
    defer pixi.app.allocator.free(default);
    sdl3.SDL_ShowOpenFileDialog(GenericOpenDialogCallback, @ptrCast(@alignCast(@constCast(cb))), dvui.currentWindow().backend.impl.window, filters.ptr, @intCast(filters.len), default.ptr, true);
}

pub fn showOpenFolderDialog(cb: *const fn (?[][:0]const u8) void, default_folder: ?[]const u8) void {
    const default: [:0]const u8 = blk: {
        if (default_folder) |folder| {
            break :blk std.fmt.allocPrintSentinel(pixi.app.allocator, "{s}", .{folder}, 0) catch "untitled";
        } else {
            if (pixi.editor.recents.last_open_folder) |last_open_folder| {
                break :blk std.fmt.allocPrintSentinel(pixi.app.allocator, "{s}", .{last_open_folder}, 0) catch "untitled";
            } else {
                break :blk std.fmt.allocPrintSentinel(pixi.app.allocator, "{s}", .{pixi.editor.folder orelse ""}, 0) catch "untitled";
            }
        }
    };
    defer pixi.app.allocator.free(default);
    sdl3.SDL_ShowOpenFolderDialog(GenericOpenDialogCallback, @ptrCast(@alignCast(@constCast(cb))), dvui.currentWindow().backend.impl.window, default.ptr, false);
}

fn GenericSaveDialogCallback(cb: ?*anyopaque, files: [*c]const [*c]const u8, _: c_int) callconv(.c) void {
    GenericDialogCallback(cb, files, .save);
}

fn GenericOpenDialogCallback(cb: ?*anyopaque, files: [*c]const [*c]const u8, _: c_int) callconv(.c) void {
    GenericDialogCallback(cb, files, .open);
}

fn GenericDialogCallback(cb: ?*anyopaque, files: [*c]const [*c]const u8, mode: enum { save, open }) void {
    const callback: *const fn (?[][:0]const u8) void = @ptrCast(@alignCast(@constCast(cb)));

    // Try to count the number of files until we hit a null pointer.
    var path_count: usize = 0;
    while (files[path_count] != null) : (path_count += 1) {}

    const zig_files: [][:0]const u8 = blk: {
        var result: [100][:0]const u8 = undefined; // Arbitrary max; refine as needed
        var i: usize = 0;
        while (i < path_count) : (i += 1) {
            result[i] = std.mem.span(files[i]);
        }
        break :blk result[0..path_count];
    };

    if (zig_files.len == 0) {
        callback(null);
        return;
    }

    { // Save the open or save folder for the next time the dialog is shown
        if (std.fs.path.dirname(zig_files[0])) |dir| {
            if (mode == .save) {
                if (pixi.editor.recents.last_save_folder) |last_save_folder| {
                    pixi.app.allocator.free(last_save_folder);
                }
                pixi.editor.recents.last_save_folder = pixi.app.allocator.dupe(u8, dir) catch {
                    dvui.log.err("Failed to dupe directory {s}", .{dir});
                    return;
                };
            } else {
                if (pixi.editor.recents.last_open_folder) |last_open_folder| {
                    pixi.app.allocator.free(last_open_folder);
                }
                pixi.editor.recents.last_open_folder = pixi.app.allocator.dupe(u8, dir) catch {
                    dvui.log.err("Failed to dupe directory {s}", .{dir});
                    return;
                };
            }
        }
    }

    callback(zig_files);
}
