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

const DWMWA_SYSTEM_BACKDROP_TYPE: c_ulong = 20;
const DWMWA_SYSTEM_BACKDROP_TYPE_DEFAULT: c_ulong = 0;
const DWMWA_SYSTEM_BACKDROP_TYPE_ACRYLIC: c_ulong = 1;
const DWMWA_SYSTEM_BACKDROP_TYPE_NONE: c_ulong = 2;
const DWMWA_SYSTEM_BACKDROP_TYPE_TRANSPARENT: c_ulong = 3;
const DWMWA_SYSTEM_BACKDROP_TYPE_BLUR_BEHIND: c_ulong = 4;
const DWMWA_SYSTEM_BACKDROP_TYPE_ACRYLIC_LIGHT: c_ulong = 5;
const DWMWA_SYSTEM_BACKDROP_TYPE_ACRYLIC_DARK: c_ulong = 6;

// Windows 11 (Build 22621+): System backdrop and extended frame for title bar drawing.
const DWMWA_SYSTEMBACKDROP_TYPE: u32 = 38; // Windows 11 SDK
const DWMSBT_MAINWINDOW: u32 = 2; // Mica
const DWMSBT_TRANSIENTWINDOW: u32 = 3; // Acrylic (frosted glass) — more visible blur than Mica

// Layered window for whole-window opacity (LWA_ALPHA). Works with SDL's GPU renderer.
const WS_EX_LAYERED: u32 = 0x00080000;

// Undocumented user32 API for acrylic blur (used by Start menu, taskbar). Loaded at runtime.
const WCA_ACCENT_POLICY: u32 = 19;
const ACCENT_ENABLE_ACRYLICBLURBEHIND: u32 = 4;
const WINCOMPATTR_DATA = struct {
    attrib: u32,
    pv_data: *const anyopaque,
    cb_data: usize,
};
const ACCENT_POLICY = struct {
    accent_state: u32,
    accent_flags: u32,
    gradient_color: u32, // ABGR
    animation_id: u32,
};

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

fn getWin32Hwnd(win: *dvui.Window) ?*anyopaque {
    const raw = sdl3.SDL_GetPointerProperty(
        sdl3.SDL_GetWindowProperties(win.backend.impl.window),
        sdl3.SDL_PROP_WINDOW_WIN32_HWND_POINTER,
        null,
    );
    return if (raw != null) @ptrCast(raw) else null;
}

// Full-window Mica margins for DwmExtendFrameIntoClientArea (-1 = "sheet of glass").
const win32_mica_margins = win32.ui.controls.MARGINS{
    .cxLeftWidth = -1,
    .cxRightWidth = -1,
    .cyTopHeight = -1,
    .cyBottomHeight = -1,
};

const win32_mica_subclass_id: usize = 0x50584931; // "PXI1"

/// Applies the undocumented SetWindowCompositionAttribute accent policy for acrylic blur (frosted glass).
/// Safe to call; no-ops if user32 or the API is unavailable.
fn applyWin32AcrylicAccent(hwnd: win32.foundation.HWND) void {
    var user32 = std.DynLib.open("user32.dll") catch return;
    defer user32.close();
    const SetWindowCompositionAttribute = user32.lookup(*const fn (win32.foundation.HWND, *const WINCOMPATTR_DATA) callconv(.winapi) i32, "SetWindowCompositionAttribute") orelse return;
    var policy = ACCENT_POLICY{
        .accent_state = ACCENT_ENABLE_ACRYLICBLURBEHIND,
        .accent_flags = 0,
        .gradient_color = 0xE6_00_00_00, // ABGR: dark tint so blur is visible
        .animation_id = 0,
    };
    var data = WINCOMPATTR_DATA{
        .attrib = WCA_ACCENT_POLICY,
        .pv_data = @ptrCast(&policy),
        .cb_data = @sizeOf(ACCENT_POLICY),
    };
    _ = SetWindowCompositionAttribute(hwnd, &data);
}

fn win32MicaSubclassProc(
    hWnd: ?win32.foundation.HWND,
    uMsg: u32,
    wParam: win32.foundation.WPARAM,
    lParam: win32.foundation.LPARAM,
    uIdSubclass: usize,
    dwRefData: usize,
) callconv(.winapi) win32.foundation.LRESULT {
    _ = uIdSubclass;
    _ = dwRefData;
    // DWM requires the frame extension to be applied in WM_ACTIVATE (and when composition changes)
    // for the backdrop to show correctly instead of staying opaque.
    if (uMsg == win32.ui.windows_and_messaging.WM_ACTIVATE or
        uMsg == win32.ui.windows_and_messaging.WM_DWMCOMPOSITIONCHANGED)
    {
        _ = win32.graphics.dwm.DwmExtendFrameIntoClientArea(hWnd, &win32_mica_margins);
    }
    return win32.ui.shell.DefSubclassProc(hWnd, uMsg, wParam, lParam);
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
    } else if (builtin.os.tag == .windows) {
        const hwnd = getWin32Hwnd(win) orelse return;
        const hwnd_h = @as(win32.foundation.HWND, @ptrCast(hwnd));

        // Windows 11: Apply Acrylic (frosted glass) backdrop so title bar and extended frame show blur. Requires Build 22621+.
        // DWMSBT_TRANSIENTWINDOW = Acrylic is more visible than Mica; use MAINWINDOW for subtler Mica.
        const backdrop_type: u32 = DWMSBT_TRANSIENTWINDOW;
        _ = win32.graphics.dwm.DwmSetWindowAttribute(
            hwnd_h,
            @as(win32.graphics.dwm.DWMWINDOWATTRIBUTE, @enumFromInt(DWMWA_SYSTEMBACKDROP_TYPE)),
            &backdrop_type,
            @sizeOf(u32),
        );

        // Subclass so we can re-apply frame extension in WM_ACTIVATE (required by DWM for backdrop to show).
        _ = win32.ui.shell.SetWindowSubclass(hwnd_h, win32MicaSubclassProc, win32_mica_subclass_id, 0);

        // Extend the DWM frame (Acrylic) into the entire client area so the backdrop material shows there.
        _ = win32.graphics.dwm.DwmExtendFrameIntoClientArea(hwnd_h, &win32_mica_margins);

        // Optional: undocumented accent API for extra acrylic blur (Start menu / taskbar use this). May improve frosted look.
        applyWin32AcrylicAccent(hwnd_h);

        // Per MSDN: for backdrop to render, the client area background must be transparent or a black brush.
        // BLACK_BRUSH (4) lets DWM draw the backdrop material; a null brush can leave the area undefined.
        const black_brush = win32.graphics.gdi.GetStockObject(win32.graphics.gdi.GET_STOCK_OBJECT_FLAGS.BLACK_BRUSH);
        _ = win32.ui.windows_and_messaging.SetClassLongPtrW(
            hwnd_h,
            win32.ui.windows_and_messaging.GCLP_HBRBACKGROUND,
            @as(isize, @bitCast(@intFromPtr(black_brush))),
        );

        // Enable layered window so SetLayeredWindowAttributes(..., LWA_ALPHA) can set whole-window opacity (see setTitlebarColor).
        const exstyle = win32.ui.windows_and_messaging.GetWindowLongPtrW(hwnd_h, win32.ui.windows_and_messaging.GWL_EXSTYLE);
        _ = win32.ui.windows_and_messaging.SetWindowLongPtrW(hwnd_h, win32.ui.windows_and_messaging.GWL_EXSTYLE, exstyle | WS_EX_LAYERED);
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
        const hwnd = getWin32Hwnd(win) orelse return;
        const hwnd_h = @as(win32.foundation.HWND, @ptrCast(hwnd));

        setWindowStyle(win);

        // Use COLOR_NONE so the title bar uses the same look as the client area (no solid theme overlay).
        const color_none: u32 = win32.graphics.dwm.DWMWA_COLOR_NONE;
        _ = win32.graphics.dwm.DwmSetWindowAttribute(hwnd_h, win32.graphics.dwm.DWMWA_CAPTION_COLOR, &color_none, @sizeOf(u32));
        _ = win32.graphics.dwm.DwmSetWindowAttribute(hwnd_h, win32.graphics.dwm.DWMWA_BORDER_COLOR, &color_none, @sizeOf(u32));

        // Keep window fully opaque on Windows. LWA_ALPHA applies to the entire window (title bar + all UI),
        // so using color.a would make content invisible; per-pixel alpha would require UpdateLayeredWindow (not supported by SDL).
        _ = win32.ui.windows_and_messaging.SetLayeredWindowAttributes(
            hwnd_h,
            0,
            255,
            win32.ui.windows_and_messaging.LWA_ALPHA,
        );
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
