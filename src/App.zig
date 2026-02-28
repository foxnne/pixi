const std = @import("std");
const builtin = @import("builtin");
const zmath = @import("zmath");
const dvui = @import("dvui");

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
    .transparent = if (builtin.os.tag == .macos or builtin.os.tag == .windows) true else false,
} }, .frameFn = AppFrame, .initFn = AppInit, .deinitFn = AppDeinit };

pub const main = dvui.App.main;
pub const panic = dvui.App.panic;
pub const std_options: std.Options = .{
    .logFn = dvui.App.logFn,
};

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
}

// Run as app is shutting down before dvui.Window.deinit()
pub fn AppDeinit() void {
    pixi.editor.deinit() catch unreachable;
}

// Run each frame to do normal UI
pub fn AppFrame() !dvui.App.Result {
    return try pixi.editor.tick();
}
