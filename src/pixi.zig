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
pub const version: []const u8 = "0.0.1";
pub const Settings = @import("settings.zig");
pub const Popups = @import("editor/popups/Popups.zig");
pub const Window = struct { size: zm.F32x4, scale: zm.F32x4 };
pub const Hotkeys = @import("input/Hotkeys.zig");

pub const editor = @import("editor/editor.zig");

pub const assets = @import("assets.zig");
pub const shaders = @import("shaders.zig");

pub const fs = @import("tools/fs.zig");
pub const fa = @import("tools/font_awesome.zig");
pub const math = @import("math/math.zig");
pub const gfx = @import("gfx/gfx.zig");
pub const input = @import("input/input.zig");
pub const storage = @import("storage/storage.zig");

pub const algorithms = @import("algorithms/algorithms.zig");

test {
    _ = zstbi;
    _ = math;
    _ = gfx;
    _ = input;
}

pub var state: *PixiState = undefined;
pub var window: *zglfw.Window = undefined;

/// Holds the global game state.
pub const PixiState = struct {
    allocator: std.mem.Allocator,
    gctx: *zgpu.GraphicsContext,
    settings: Settings = .{},
    controls: input.Controls = .{},
    hotkeys: Hotkeys,
    window: Window,
    sidebar: Sidebar = .files,
    style: editor.Style = .{},
    project_folder: ?[:0]const u8 = null,
    background_logo: gfx.Texture,
    fox_logo: gfx.Texture,
    open_files: std.ArrayList(storage.Internal.Pixi),
    open_file_index: usize = 0,
    tools: Tools = .{},
    popups: Popups = .{},
    should_close: bool = false,
    fonts: Fonts = .{},
    cursors: Cursors,
    colors: Colors,
};

pub const Sidebar = enum {
    files,
    tools,
    layers,
    sprites,
    animations,
    settings,
};

pub const Fonts = struct {
    fa_standard_regular: zgui.Font = undefined,
    fa_standard_solid: zgui.Font = undefined,
    fa_small_regular: zgui.Font = undefined,
    fa_small_solid: zgui.Font = undefined,
};

pub const Cursors = struct {
    pencil: gfx.Texture,
    eraser: gfx.Texture,

    pub fn deinit(cursors: *Cursors, gctx: *zgpu.GraphicsContext) void {
        cursors.pencil.deinit(gctx);
        cursors.eraser.deinit(gctx);
    }
};

pub const Tool = enum {
    pointer,
    pencil,
    eraser,
    animation,
};

pub const Tools = struct {
    current: Tool = .pointer,
    previous: Tool = .pointer,

    pub fn set(tools: *Tools, tool: Tool) void {
        if (tools.current != tool) {
            tools.previous = tools.current;
            tools.current = tool;
        }
    }
};

pub const Colors = struct {
    primary: [4]u8 = .{ 255, 255, 255, 255 },
    secondary: [4]u8 = .{ 0, 0, 0, 255 },
    palettes: std.ArrayList(storage.Internal.Palette),
    selected_palette_index: usize = 0,

    pub fn load() !Colors {
        var palettes = std.ArrayList(storage.Internal.Palette).init(state.allocator);
        var dir = std.fs.cwd().openIterableDir(assets.palettes, .{ .access_sub_paths = false }) catch unreachable;
        defer dir.close();
        var iter = dir.iterate();
        while (iter.next() catch unreachable) |entry| {
            if (entry.kind == .file) {
                const ext = std.fs.path.extension(entry.name);
                if (std.mem.eql(u8, ext, ".hex")) {
                    const abs_path = try std.fs.path.joinZ(state.allocator, &.{ assets.palettes, entry.name });
                    defer state.allocator.free(abs_path);
                    try palettes.append(try storage.Internal.Palette.loadFromFile(abs_path));
                }
            }
        }
        return .{
            .palettes = palettes,
        };
    }

    pub fn deinit(self: *Colors) void {
        for (self.palettes.items) |*palette| {
            state.allocator.free(palette.name);
            state.allocator.free(palette.colors);
        }
        self.palettes.deinit();
    }
};

fn init(allocator: std.mem.Allocator) !*PixiState {
    const gctx = try zgpu.GraphicsContext.create(allocator, window);

    var open_files = std.ArrayList(storage.Internal.Pixi).init(allocator);

    const window_size = window.getSize();
    const window_scale = window.getContentScale();
    const state_window: Window = .{
        .size = zm.f32x4(@intToFloat(f32, window_size[0]), @intToFloat(f32, window_size[1]), 0, 0),
        .scale = zm.f32x4(window_scale[0], window_scale[1], 0, 0),
    };

    const scale_factor = scale_factor: {
        break :scale_factor @max(window_scale[0], window_scale[1]);
    };

    // Logos
    const background_logo = try gfx.Texture.loadFromFile(gctx, assets.icon1024_png.path, .{});
    const fox_logo = try gfx.Texture.loadFromFile(gctx, assets.fox1024_png.path, .{});

    // Cursors
    const pencil = try gfx.Texture.loadFromFile(gctx, if (scale_factor > 1) assets.pencil64_png.path else assets.pencil32_png.path, .{});
    const eraser = try gfx.Texture.loadFromFile(gctx, if (scale_factor > 1) assets.eraser64_png.path else assets.eraser32_png.path, .{});

    const hotkeys = try Hotkeys.initDefault(allocator);

    state = try allocator.create(PixiState);
    state.* = .{
        .allocator = allocator,
        .gctx = gctx,
        .window = state_window,
        .background_logo = background_logo,
        .fox_logo = fox_logo,
        .open_files = open_files,
        .cursors = .{
            .pencil = pencil,
            .eraser = eraser,
        },
        .colors = try Colors.load(),
        .hotkeys = hotkeys,
    };

    return state;
}

fn deinit(allocator: std.mem.Allocator) void {
    allocator.free(state.hotkeys.hotkeys);
    state.background_logo.deinit(state.gctx);
    state.fox_logo.deinit(state.gctx);
    state.cursors.deinit(state.gctx);
    state.colors.deinit();
    editor.deinit();
    zgui.backend.deinit();
    zgui.deinit();
    zstbi.deinit();
    state.gctx.destroy(allocator);
    allocator.destroy(state);
}

fn update() void {
    zgui.backend.newFrame(state.gctx.swapchain_descriptor.width, state.gctx.swapchain_descriptor.height);

    input.process() catch unreachable;

    if (window.shouldClose()) {
        var should_close = true;
        for (state.open_files.items) |file| {
            if (file.dirty()) {
                should_close = false;
            }
        }

        if (!should_close) {
            state.popups.file_confirm_close = true;
            state.popups.file_confirm_close_state = .all;
            state.popups.file_confirm_close_exit = true;
        }
        state.should_close = should_close;
        window.setShouldClose(should_close);
    }
}

fn draw() void {
    editor.draw();

    for (state.hotkeys.hotkeys) |*hotkey| {
        hotkey.previous_state = hotkey.state;
    }

    state.controls.mouse.primary.previous_state = state.controls.mouse.primary.state;
    state.controls.mouse.secondary.previous_state = state.controls.mouse.secondary.state;
    state.controls.mouse.previous_position = state.controls.mouse.position;

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
    // Change current working directory to where the executable is located.
    {
        var buffer: [1024]u8 = undefined;
        const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
        std.os.chdir(path) catch {};
    }

    try zglfw.init();
    defer zglfw.terminate();

    // TODO: Load settings.json if available
    const settings: Settings = .{};

    // Create window
    window = try zglfw.Window.create(settings.initial_window_width, settings.initial_window_height, name, null);
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

    zstbi.init(allocator);

    state = try init(allocator);
    defer deinit(allocator);

    state.settings = settings;

    const scale_factor = scale_factor: {
        const scale = window.getContentScale();
        break :scale_factor @max(scale[0], scale[1]);
    };

    zgui.init(allocator);
    zgui.io.setIniFilename(assets.root ++ "imgui.ini");
    _ = zgui.io.addFontFromFile(assets.root ++ "fonts/CozetteVector.ttf", state.settings.font_size * scale_factor);
    var config = zgui.FontConfig.init();
    config.merge_mode = true;
    const ranges: []const u16 = &.{ 0xf000, 0xf976, 0 };
    state.fonts.fa_standard_solid = zgui.io.addFontFromFileWithConfig(assets.root ++ "fonts/fa-solid-900.ttf", state.settings.font_size * scale_factor, config, ranges.ptr);
    state.fonts.fa_standard_regular = zgui.io.addFontFromFileWithConfig(assets.root ++ "fonts/fa-regular-400.ttf", state.settings.font_size * scale_factor, config, ranges.ptr);
    state.fonts.fa_small_solid = zgui.io.addFontFromFileWithConfig(assets.root ++ "fonts/fa-solid-900.ttf", 10 * scale_factor, config, ranges.ptr);
    state.fonts.fa_small_regular = zgui.io.addFontFromFileWithConfig(assets.root ++ "fonts/fa-regular-400.ttf", 10 * scale_factor, config, ranges.ptr);
    zgui.backend.initWithConfig(window, state.gctx.device, @enumToInt(zgpu.GraphicsContext.swapchain_format), .{ .texture_filter_mode = .nearest });

    // Base style
    state.style.set();

    while (!state.should_close or editor.saving()) {
        zglfw.pollEvents();
        update();
        draw();
    }
}
