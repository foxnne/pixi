const std = @import("std");

const mach = @import("core");
const gpu = mach.gpu;

const zgui = @import("zgui").MachImgui(mach);
const zstbi = @import("zstbi");
const zm = @import("zmath");

pub const App = @This();

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

core: mach.Core,
timer: mach.Timer,

// TODO: Add build instructions to readme, and note requires xcode for nativefiledialogs to build.
// TODO: Nativefiledialogs requires xcode appkit frameworks.

pub const name: [:0]const u8 = "Pixi";
pub const version: []const u8 = "0.0.1";
pub const Settings = @import("settings.zig");
pub const Popups = @import("editor/popups/Popups.zig");
pub const Window = struct { size: zm.F32x4, scale: zm.F32x4 };
pub const Hotkeys = @import("input/Hotkeys.zig");

pub const Packer = @import("tools/Packer.zig");

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

pub var application: *App = undefined;
pub var state: *PixiState = undefined;
pub var content_scale: [2]f32 = undefined;

/// Holds the global game state.
pub const PixiState = struct {
    allocator: std.mem.Allocator = undefined,
    settings: Settings = .{},
    controls: input.Controls = .{},
    hotkeys: Hotkeys,
    sidebar: Sidebar = .files,
    style: editor.Style = .{},
    project_folder: ?[:0]const u8 = null,
    background_logo: gfx.Texture,
    fox_logo: gfx.Texture,
    open_files: std.ArrayList(storage.Internal.Pixi),
    pack_open_files: std.ArrayList(storage.Internal.Pixi),
    pack_files: PackFiles = .project,
    pack_camera: gfx.Camera = .{},
    test_texture: ?gfx.Texture = null,
    packer: Packer,
    atlas: storage.Internal.Atlas = .{},
    open_file_index: usize = 0,
    tools: Tools = .{},
    popups: Popups = .{},
    should_close: bool = false,
    fonts: Fonts = .{},
    cursors: Cursors,
    colors: Colors,
    delta_time: f32 = 0.0,
};

pub const Sidebar = enum {
    files,
    tools,
    layers,
    sprites,
    animations,
    pack,
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

    pub fn deinit(cursors: *Cursors) void {
        cursors.pencil.deinit();
        cursors.eraser.deinit();
    }
};

pub const Tool = enum {
    pointer,
    pencil,
    eraser,
    animation,
    heightmap,
    bucket,
};

pub const Tools = struct {
    current: Tool = .pointer,
    previous: Tool = .pointer,

    pub fn set(tools: *Tools, tool: Tool) void {
        if (tools.current != tool) {
            if (tool == .heightmap) {
                if (editor.getFile(state.open_file_index)) |file| {
                    if (file.heightmap_layer == null) {
                        state.popups.heightmap = true;
                        return;
                    }
                } else return;
            }
            tools.previous = tools.current;
            tools.current = tool;
        }
    }
};

pub const Colors = struct {
    primary: [4]u8 = .{ 255, 255, 255, 255 },
    secondary: [4]u8 = .{ 0, 0, 0, 255 },
    height: u8 = 0,
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

pub const PackFiles = enum {
    project,
    all_open,
    single_open,
};

pub fn init(app: *App) !void {
    try app.core.init(gpa.allocator(), .{});
    application = app;

    const allocator = gpa.allocator();

    zstbi.init(allocator);

    var open_files = std.ArrayList(storage.Internal.Pixi).init(allocator);
    var pack_open_files = std.ArrayList(storage.Internal.Pixi).init(allocator);

    // Logos
    const background_logo = try gfx.Texture.loadFromFile(app.core.device(), assets.icon1024_png.path, .{});
    const fox_logo = try gfx.Texture.loadFromFile(app.core.device(), assets.fox1024_png.path, .{});

    const descriptor = app.core.descriptor();
    const window_size = app.core.size();
    content_scale = .{
        @floatFromInt(descriptor.width / window_size.width),
        @floatFromInt(descriptor.height / window_size.height),
    };
    const scale_factor = content_scale[1];

    // Cursors
    const pencil = try gfx.Texture.loadFromFile(app.core.device(), if (scale_factor > 1) assets.pencil64_png.path else assets.pencil32_png.path, .{});
    const eraser = try gfx.Texture.loadFromFile(app.core.device(), if (scale_factor > 1) assets.eraser64_png.path else assets.eraser32_png.path, .{});

    const hotkeys = try Hotkeys.initDefault(allocator);

    const packer = try Packer.init(allocator);

    zgui.init(allocator);
    zgui.mach_backend.init(&app.core, app.core.device(), .rgba8_unorm, .{});
    zgui.io.setIniFilename(assets.root ++ "imgui.ini");
    _ = zgui.io.addFontFromFile(assets.root ++ "fonts/CozetteVector.ttf", state.settings.font_size * scale_factor);
    var config = zgui.FontConfig.init();
    config.merge_mode = true;
    const ranges: []const u16 = &.{ 0xf000, 0xf976, 0 };
    state.fonts.fa_standard_solid = zgui.io.addFontFromFileWithConfig(assets.root ++ "fonts/fa-solid-900.ttf", state.settings.font_size * scale_factor, config, ranges.ptr);
    state.fonts.fa_standard_regular = zgui.io.addFontFromFileWithConfig(assets.root ++ "fonts/fa-regular-400.ttf", state.settings.font_size * scale_factor, config, ranges.ptr);
    state.fonts.fa_small_solid = zgui.io.addFontFromFileWithConfig(assets.root ++ "fonts/fa-solid-900.ttf", 10 * scale_factor, config, ranges.ptr);
    state.fonts.fa_small_regular = zgui.io.addFontFromFileWithConfig(assets.root ++ "fonts/fa-regular-400.ttf", 10 * scale_factor, config, ranges.ptr);

    state = try gpa.allocator().create(PixiState);
    state.style.set();

    state.* = .{
        .allocator = allocator,
        .background_logo = background_logo,
        .fox_logo = fox_logo,
        .open_files = open_files,
        .pack_open_files = pack_open_files,
        .cursors = .{
            .pencil = pencil,
            .eraser = eraser,
        },
        .colors = try Colors.load(),
        .hotkeys = hotkeys,
        .packer = packer,
    };

    app.* = .{
        .core = app.core,
        .timer = try mach.Timer.start(),
    };
}

pub fn update(app: *App) !bool {
    state.delta_time = app.timer.lap();

    var iter = app.core.pollEvents();
    while (iter.next()) |event| {
        switch (event) {
            .key_press => |key_press| {
                state.hotkeys.setHotkeyState(key_press.key, key_press.mods, .press);
            },
            .close => return true,
            else => {},
        }
    }

    const descriptor = app.core.descriptor();
    zgui.mach_backend.newFrame();

    const window_size = app.core.size();
    content_scale = .{
        @floatFromInt(descriptor.width / window_size.width),
        @floatFromInt(descriptor.height / window_size.height),
    };

    input.process() catch unreachable;

    editor.draw();

    for (state.hotkeys.hotkeys) |*hotkey| {
        hotkey.previous_state = hotkey.state;
    }

    state.controls.mouse.primary.previous_state = state.controls.mouse.primary.state;
    state.controls.mouse.secondary.previous_state = state.controls.mouse.secondary.state;
    state.controls.mouse.previous_position = state.controls.mouse.position;

    if (app.core.swapChain().getCurrentTextureView()) |back_buffer_view| {
        defer back_buffer_view.release();

        const zgui_commands = commands: {
            const encoder = app.core.device().createCommandEncoder(null);
            defer encoder.release();

            // Gui pass.
            {
                const color_attachment = gpu.RenderPassColorAttachment{
                    .view = back_buffer_view,
                    .clear_value = std.mem.zeroes(gpu.Color),
                    .load_op = .clear,
                    .store_op = .store,
                };

                const render_pass_info = gpu.RenderPassDescriptor.init(.{
                    .color_attachments = &.{color_attachment},
                });
                const pass = encoder.beginRenderPass(&render_pass_info);
                defer pass.end();
                zgui.mach_backend.draw(pass);
            }

            break :commands encoder.finish(null);
        };
        defer zgui_commands.release();

        app.core.device().getQueue().submit(&.{zgui_commands});
        app.core.swapChain().present();
    }
    return false;
}

pub fn deinit(_: *App) void {
    state.allocator.free(state.hotkeys.hotkeys);
    state.background_logo.deinit();
    state.fox_logo.deinit();
    state.cursors.deinit();
    state.colors.deinit();
    state.packer.deinit();
    if (state.atlas.external) |*atlas| {
        for (atlas.sprites) |sprite| {
            state.allocator.free(sprite.name);
        }

        for (atlas.animations) |animation| {
            state.allocator.free(animation.name);
        }

        state.allocator.free(atlas.sprites);
        state.allocator.free(atlas.animations);
    }
    if (state.atlas.diffusemap) |*diffusemap| diffusemap.deinit();
    if (state.atlas.heightmap) |*heightmap| heightmap.deinit();
    editor.deinit();
    zgui.mach_backend.deinit();
    zgui.deinit();
    zstbi.deinit();
    state.allocator.destroy(state);
}
