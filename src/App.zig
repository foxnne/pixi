const std = @import("std");
const builtin = @import("builtin");
const zmath = @import("zmath");
const dvui = @import("dvui");
const objc = @import("objc");
const win32 = @import("win32");
const assets = @import("assets");

const icon = assets.files.@"icon.png";

const cozette_ttf = assets.files.fonts.@"CozetteVector.ttf";
const cozette_bold_ttf = assets.files.fonts.@"CozetteVectorBold.ttf";

const pixi = @import("pixi.zig");

const App = @This();
const Editor = pixi.Editor;
const Packer = pixi.Packer;
//const Assets = pixi.Assets;

// App fields
allocator: std.mem.Allocator = undefined,

//delta_time: f32 = 0.0,

root_path: [:0]const u8 = undefined,
should_close: bool = false,
window: *dvui.Window = undefined,

var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;

// To be a dvui App:
// * declare "dvui_app"
// * expose the backend's main function
// * use the backend's log function
pub const dvui_app: dvui.App = .{ .config = .{ .options = .{
    .size = .{ .w = 1200.0, .h = 800.0 },
    .min_size = .{ .w = 640.0, .h = 480.0 },
    .title = "Pixi",
    .icon = icon,
} }, .frameFn = AppFrame, .initFn = AppInit, .deinitFn = AppDeinit };

pub const main = dvui.App.main;
pub const panic = dvui.App.panic;
pub const std_options: std.Options = .{
    .logFn = dvui.App.logFn,
};

pub fn setTitlebarColor(win: *dvui.Window, color: dvui.Color) void {
    if (builtin.os.tag == .macos) {
        const native_window: ?*objc.app_kit.Window = @ptrCast(dvui.backend.c.SDL_GetPointerProperty(
            dvui.backend.c.SDL_GetWindowProperties(win.backend.impl.window),
            dvui.backend.c.SDL_PROP_WINDOW_COCOA_WINDOW_POINTER,
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
        _ = win32.graphics.dwm.DwmSetWindowAttribute(@ptrCast(dvui.backend.c.SDL_GetPointerProperty(
            dvui.backend.c.SDL_GetWindowProperties(win.backend.impl.window),
            dvui.backend.c.SDL_PROP_WINDOW_WIN32_HWND_POINTER,
            null,
        )), win32.graphics.dwm.DWMWA_CAPTION_COLOR, &colorref, @sizeOf(u32));

        _ = win32.graphics.dwm.DwmSetWindowAttribute(@ptrCast(dvui.backend.c.SDL_GetPointerProperty(
            dvui.backend.c.SDL_GetWindowProperties(win.backend.impl.window),
            dvui.backend.c.SDL_PROP_WINDOW_WIN32_HWND_POINTER,
            null,
        )), win32.graphics.dwm.DWMWA_BORDER_COLOR, &colorref, @sizeOf(u32));
    }
}

// Runs before the first frame, after backend and dvui.Window.init()
pub fn AppInit(win: *dvui.Window) !void {
    const allocator = gpa.allocator();

    // Run from the directory where the executable is located so relative assets can be found.
    var buffer: [1024]u8 = undefined;
    const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
    std.posix.chdir(path) catch {};

    pixi.app = try allocator.create(App);
    pixi.app.* = .{
        .allocator = allocator,
        .window = win,
        .root_path = allocator.dupeZ(u8, path) catch ".",
    };

    pixi.editor = try allocator.create(Editor);
    pixi.editor.* = Editor.init(pixi.app) catch unreachable;

    pixi.packer = try allocator.create(Packer);
    pixi.packer.* = Packer.init(allocator) catch unreachable;

    dvui.addFont("CozetteVector", cozette_ttf, null) catch {};
    dvui.addFont("CozetteVectorBold", cozette_bold_ttf, null) catch {};

    var theme = dvui.themeGet();

    theme.window = .{
        .fill = .{ .r = 34, .g = 35, .b = 42, .a = 255 },
        .fill_hover = .{ .r = 62, .g = 64, .b = 74, .a = 255 },
        .fill_press = .{ .r = 32, .g = 34, .b = 44, .a = 255 },
        //.fill_hover = .{ .r = 64, .g = 68, .b = 78, .a = 255 },
        //.fill_press = theme.window.fill,
        .border = .{ .r = 48, .g = 52, .b = 62, .a = 255 },
        .text = .{ .r = 206, .g = 163, .b = 127, .a = 255 },
        .text_hover = theme.window.text,
        .text_press = theme.window.text,
    };

    theme.control = .{
        .fill = .{ .r = 42, .g = 44, .b = 54, .a = 255 },
        .fill_hover = .{ .r = 62, .g = 64, .b = 74, .a = 255 },
        .fill_press = .{ .r = 32, .g = 34, .b = 44, .a = 255 },
        .border = .{ .r = 48, .g = 52, .b = 62, .a = 255 },
        .text = .{ .r = 134, .g = 138, .b = 148, .a = 255 },
        .text_hover = .{ .r = 124, .g = 128, .b = 138, .a = 255 },
        .text_press = .{ .r = 124, .g = 128, .b = 138, .a = 255 },
    };

    theme.highlight = .{
        .fill = .{ .r = 47, .g = 179, .b = 135, .a = 255 },
        //.fill_hover = theme.highlight.fill.?.average(theme.control.fill_hover.?),
        //.fill_press = theme.highlight.fill.?.average(theme.control.fill_press.?),
        .border = .{ .r = 48, .g = 52, .b = 62, .a = 255 },
        .text = theme.window.fill,
        .text_hover = theme.window.fill,
        .text_press = theme.window.fill,
    };

    //setTitlebarColor(win, .{ 0.1647, 0.17254, 0.21176, 1.0 });
    setTitlebarColor(win, theme.control.fill.?);

    // theme.content
    theme.fill = theme.window.fill.?;
    theme.border = theme.window.border.?;
    theme.fill_hover = theme.control.fill_hover.?;
    theme.fill_press = theme.control.fill_press.?;
    theme.text = theme.window.text.?;
    theme.text_hover = theme.window.text_hover.?;
    theme.text_press = theme.window.text_press.?;
    theme.focus = theme.highlight.fill.?;

    theme.dark = true;
    theme.name = "Pixi Dark";
    theme.font_body = .find(.{ .family = "Vera Sans", .size = 13 });
    theme.font_title = .find(.{ .family = "Vera Sans", .size = 18, .weight = .bold });
    theme.font_heading = .find(.{ .family = "Vera Sans", .size = 13, .style = .italic });
    theme.font_mono = .find(.{ .family = "Vera Sans Mono", .size = 16 });

    dvui.themeSet(theme);
}

// Run as app is shutting down before dvui.Window.deinit()
pub fn AppDeinit() void {
    pixi.editor.deinit() catch unreachable;
}

// Run each frame to do normal UI
pub fn AppFrame() !dvui.App.Result {
    return try pixi.editor.tick();
}
