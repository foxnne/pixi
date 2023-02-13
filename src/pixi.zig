const std = @import("std");
const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const zgui = @import("zgui");
const zstbi = @import("zstbi");
const zm = @import("zmath");

// TODO: Add build instructions to readme, and note requires xcode for nativefiledialogs to build.
// TODO: Nativefiledialogs requires xcode appkit frameworks.

pub const name: [:0]const u8 = "Pixi";
pub const Settings = @import("settings.zig");

pub const editor = @import("editor/editor.zig");

pub const assets = @import("assets.zig");
pub const shaders = @import("shaders.zig");

pub const fs = @import("tools/fs.zig");
pub const math = @import("math/math.zig");
pub const gfx = @import("gfx/gfx.zig");
pub const input = @import("input/input.zig");
pub const storage = @import("storage/storage.zig");

pub const fa = @import("tools/font_awesome.zig");

test {
    _ = zstbi;
    _ = math;
    _ = gfx;
    _ = input;
}

pub var state: *PixiState = undefined;

/// Holds the global game state.
pub const PixiState = struct {
    allocator: std.mem.Allocator,
    gctx: *zgpu.GraphicsContext,
    settings: Settings = .{},
    controls: input.Controls = .{},
    window: Window,
    sidebar: Sidebar = .files,
    style: editor.Style = .{},
    project_folder: ?[:0]const u8 = null,
    background_logo: gfx.Texture,
    open_files: std.ArrayList(storage.Internal.Pixi),
    open_file_index: usize = 0,
    popups: Popups = .{},
};

pub const Sidebar = enum {
    files,
    tools,
    layers,
    sprites,
    settings,
};

pub const Popups = struct {
    rename: bool = false,
    rename_path: [std.fs.MAX_PATH_BYTES]u8 = undefined,
    rename_old_path: [std.fs.MAX_PATH_BYTES]u8 = undefined,
    new: bool = false,
    new_buf: [256]u8 = undefined,
};

pub const Window = struct { size: zm.F32x4, scale: zm.F32x4 };

fn init(allocator: std.mem.Allocator, window: *zglfw.Window) !*PixiState {
    const gctx = try zgpu.GraphicsContext.create(allocator, window);

    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    zstbi.init(arena);
    defer zstbi.deinit();

    var open_files = std.ArrayList(storage.Internal.Pixi).init(allocator);
    const background_logo = try gfx.Texture.initFromFile(gctx, assets.Icon1024_png.path, .{});

    const window_size = window.getSize();
    const window_scale = window.getContentScale();
    const state_window: Window = .{
        .size = zm.f32x4(@intToFloat(f32, window_size[0]), @intToFloat(f32, window_size[1]), 0, 0),
        .scale = zm.f32x4(window_scale[0], window_scale[1], 0, 0),
    };

    state = try allocator.create(PixiState);
    state.* = .{
        .allocator = allocator,
        .gctx = gctx,
        .window = state_window,
        .background_logo = background_logo,
        .open_files = open_files,
    };

    return state;
}

fn deinit(allocator: std.mem.Allocator) void {
    editor.deinit();
    zgui.backend.deinit();
    zgui.deinit();
    zstbi.deinit();
    state.gctx.destroy(allocator);
    allocator.destroy(state);
}

fn update() void {
    zgui.backend.newFrame(state.gctx.swapchain_descriptor.width, state.gctx.swapchain_descriptor.height);
    editor.draw();
    //zgui.showDemoWindow(null);
}

fn draw() void {
    const swapchain_texv = state.gctx.swapchain.getCurrentTextureView();
    defer swapchain_texv.release();

    const zgui_commands = commands: {
        const encoder = state.gctx.device.createCommandEncoder(null);
        defer encoder.release();

        // Gui pass.
        {
            const pass = zgpu.beginRenderPassSimple(encoder, .load, swapchain_texv, null, null, null);
            defer zgpu.endReleasePass(pass);
            zgui.backend.draw(pass);
        }

        break :commands encoder.finish(null);
    };
    defer zgui_commands.release();

    state.gctx.submit(&.{zgui_commands});

    if (state.gctx.present() == .swap_chain_resized) {
        const window_size = state.gctx.window.getSize();
        const window_scale = state.gctx.window.getContentScale();
        state.window = .{
            .size = zm.f32x4(@intToFloat(f32, window_size[0]), @intToFloat(f32, window_size[1]), 0, 0),
            .scale = zm.f32x4(window_scale[0], window_scale[1], 0, 0),
        };
        state.settings.initial_window_width = @intCast(u32, window_size[0]);
        state.settings.initial_window_height = @intCast(u32, window_size[1]);
    }
}

pub fn main() !void {
    try zglfw.init();
    defer zglfw.terminate();

    // TODO: Load settings.json if available
    const settings: Settings = .{};

    // Create window
    const window = try zglfw.Window.create(settings.initial_window_width, settings.initial_window_height, name, null);
    defer window.destroy();
    window.setSizeLimits(400, 400, -1, -1);

    // Set callbacks
    window.setCursorPosCallback(input.callbacks.cursor);
    window.setScrollCallback(input.callbacks.scroll);
    window.setKeyCallback(input.callbacks.key);
    window.setMouseButtonCallback(input.callbacks.button);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    state = try init(allocator, window);
    defer deinit(allocator);

    state.settings = settings;

    zstbi.init(std.heap.c_allocator);

    const scale_factor = scale_factor: {
        const scale = window.getContentScale();
        break :scale_factor std.math.max(scale[0], scale[1]);
    };

    zgui.init(allocator);
    zgui.io.setIniFilename(assets.root ++ "imgui.ini");
    _ = zgui.io.addFontFromFile(assets.root ++ "fonts/CozetteVector.ttf", state.settings.font_size * scale_factor);
    var config = zgui.FontConfig.init();
    config.merge_mode = true;
    const ranges: []const u16 = &.{ 0xf000, 0xf976, 0 };
    _ = zgui.io.addFontFromFileWithConfig(assets.root ++ "fonts/fa-solid-900.ttf", state.settings.font_size * scale_factor * 1.1, config, ranges.ptr);
    _ = zgui.io.addFontFromFileWithConfig(assets.root ++ "fonts/fa-regular-400.ttf", state.settings.font_size * scale_factor * 1.1, config, ranges.ptr);
    zgui.backend.initWithConfig(window, state.gctx.device, @enumToInt(zgpu.GraphicsContext.swapchain_format), .{ .texture_filter_mode = .nearest });

    // Base style
    state.style.set();

    while (!window.shouldClose()) {
        zglfw.pollEvents();
        update();
        draw();
    }
}
