// These are functions specific to the backend, which is currently SDL3
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

pub fn showSaveFileDialog(cb: *const fn (?[][:0]const u8) void, filters: []const sdl3.SDL_DialogFileFilter, default_location: [*:0]const u8) void {
    sdl3.SDL_ShowSaveFileDialog(GenericDialogCallback, @ptrCast(@alignCast(@constCast(cb))), dvui.currentWindow().backend.impl.window, filters.ptr, @intCast(filters.len), default_location);
}

pub fn showOpenFileDialog(cb: *const fn (?[][:0]const u8) void, filters: []const sdl3.SDL_DialogFileFilter, default_location: []const u8) void {
    sdl3.SDL_ShowOpenFileDialog(GenericDialogCallback, @ptrCast(@alignCast(@constCast(cb))), dvui.currentWindow().backend.impl.window, filters.ptr, @intCast(filters.len), default_location.ptr);
}

pub fn showOpenFolderDialog(cb: *const fn (?[][:0]const u8) void, default_location: []const u8) void {
    sdl3.SDL_ShowOpenFolderDialog(GenericDialogCallback, @ptrCast(@alignCast(@constCast(cb))), dvui.currentWindow().backend.impl.window, default_location.ptr);
}

fn GenericDialogCallback(cb: ?*anyopaque, files: [*c]const [*c]const u8, _: c_int) callconv(.c) void {
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

    callback(zig_files);
}
