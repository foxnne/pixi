// These are functions specific to the backend, which is currently SDL3
const pixi = @import("pixi.zig");
const std = @import("std");
const builtin = @import("builtin");
const dvui = @import("dvui");
const sdl3 = @import("backend").c;
const objc = @import("objc");
const win32 = @import("win32");

// AppKit geometry types for NSView frame/bounds (same layout as Foundation).
const NSPoint = extern struct { x: f64, y: f64 };
const NSSize = extern struct { width: f64, height: f64 };
const NSRect = extern struct { origin: NSPoint, size: NSSize };

// NSWindowStyleMaskFullSizeContentView = 1 << 15 — content view extends under titlebar so vibrancy can cover it.
const NSWindowStyleMaskFullSizeContentView: c_ulong = 1 << 15;

const ns_visual_effect_material: c_long = 15;

/// Wraps the window's content view in an NSVisualEffectView so the window gets
/// vibrancy (blur of the desktop behind it). Safe to call multiple times;
/// only wraps once per window. Caller should set full-size content view style
/// mask and titlebarAppearsTransparent before calling so the effect covers the titlebar.
fn wrapContentViewWithVibrancy(window: objc.Object) void {
    const content_view = window.msgSend(objc.Object, "contentView", .{});
    if (content_view.value == 0) return;

    const NSVisualEffectViewClass = objc.getClass("NSVisualEffectView") orelse return;
    const already_wrapped = content_view.msgSend(bool, "isKindOfClass:", .{NSVisualEffectViewClass.value});
    if (already_wrapped) {
        content_view.msgSend(void, "setMaterial:", .{ns_visual_effect_material});
        return;
    }

    // [[NSVisualEffectView alloc] init]
    const effect_view = NSVisualEffectViewClass.msgSend(objc.Object, "alloc", .{}).msgSend(objc.Object, "init", .{});
    if (effect_view.value == 0) return;

    // Blur content behind the window (desktop, other windows).
    // NSVisualEffectBlendingModeBehindWindow = 0
    effect_view.msgSend(void, "setBlendingMode:", .{@as(c_long, 0)});
    // NSVisualEffectStateActive = 1 — keep vibrant when window loses focus (0 = followsWindowActiveState).
    effect_view.msgSend(void, "setState:", .{@as(c_long, 1)});
    effect_view.msgSend(void, "setMaterial:", .{ns_visual_effect_material});

    // Replace window's content view with the effect view, then put the original view inside it.
    window.msgSend(void, "setContentView:", .{effect_view.value});
    effect_view.msgSend(void, "addSubview:", .{content_view.value});

    // Make the original content view fill the effect view.
    const bounds = effect_view.msgSend(NSRect, "bounds", .{});
    content_view.msgSend(void, "setFrame:", .{bounds});
    // NSViewWidthSizable | NSViewHeightSizable = 2 | 16 = 18
    content_view.msgSend(void, "setAutoresizingMask:", .{@as(c_ulong, 18)});
}

pub fn setWindowStyle(win: *dvui.Window) void {
    if (builtin.os.tag == .macos) {
        const raw_ptr = sdl3.SDL_GetPointerProperty(
            sdl3.SDL_GetWindowProperties(win.backend.impl.window),
            sdl3.SDL_PROP_WINDOW_COCOA_WINDOW_POINTER,
            null,
        );
        if (raw_ptr != null) {
            const window = objc.Object.fromId(raw_ptr);

            // Allow content view to extend under the titlebar so vibrancy covers it.
            const style_mask = window.msgSend(c_ulong, "styleMask", .{});
            window.msgSend(void, "setStyleMask:", .{style_mask | NSWindowStyleMaskFullSizeContentView});
            // This sets the titlebar to transparent so our effect view shows through.
            window.msgSend(void, "setTitlebarAppearsTransparent:", .{true});
        }
    }
}

pub fn setTitlebarColor(win: *dvui.Window, color: dvui.Color) void {
    if (builtin.os.tag == .macos) {
        const raw_ptr = sdl3.SDL_GetPointerProperty(
            sdl3.SDL_GetWindowProperties(win.backend.impl.window),
            sdl3.SDL_PROP_WINDOW_COCOA_WINDOW_POINTER,
            null,
        );
        if (raw_ptr != null) {
            const window = objc.Object.fromId(raw_ptr);

            setWindowStyle(win);

            // Wrap content view in NSVisualEffectView once for vibrancy (blur behind window).
            wrapContentViewWithVibrancy(window);

            const NSColor = objc.getClass("NSColor").?;
            const new_color = NSColor.msgSend(objc.Object, "colorWithRed:green:blue:alpha:", .{
                @as(f64, @floatFromInt(color.r)) / 255.0,
                @as(f64, @floatFromInt(color.g)) / 255.0,
                @as(f64, @floatFromInt(color.b)) / 255.0,
                @as(f64, @floatFromInt(color.a)) / 255.0,
            });
            // This sets both the titlebar and the window background color.
            window.msgSend(void, "setBackgroundColor:", .{new_color.value});

            // TODO: Figure out how to use the constants for the appearance name
            // This currently causes a segfault and doesnt work
            // const NSAppearance = objc.getClass("NSAppearance").?;
            // const NSString = objc.getClass("NSString").?;
            // const appearance_name_str = if (dvui.themeGet().dark)
            //     NSString.msgSend(objc.Object, "stringWithUTF8String:", .{"NSAppearanceNameVibrantDark"})
            // else
            //     NSString.msgSend(objc.Object, "stringWithUTF8String:", .{"NSAppearanceNameVibrantLight"});
            // const appearance = NSAppearance.msgSend(?objc.c.id, "appearanceNamed:", .{appearance_name_str.value});
            // if (appearance) |app| {
            //     window.msgSend(void, "setAppearance:", .{app});
            // }

            // // SDL3 currently removes the shadow when the transparency flag for the window is set. This brings it back.
            window.msgSend(void, "setHasShadow:", .{true});
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
