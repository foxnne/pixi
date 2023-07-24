const std = @import("std");

const mach = @import("core");
const gpu = mach.gpu;

const zgui = @import("zgui").MachImgui(mach);
const zstbi = @import("zstbi");
const zm = @import("zmath");
const nfd = @import("nfd");

pub const App = @This();

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

core: mach.Core,
timer: mach.Timer,

pub const name: [:0]const u8 = "Pixi";
pub const version: []const u8 = "0.0.1";
pub const Settings = @import("settings.zig");
pub const Popups = @import("editor/popups/Popups.zig");
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
pub var window_size: [2]f32 = undefined;
pub var framebuffer_size: [2]f32 = undefined;

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
    try app.core.init(gpa.allocator(), .{
        .title = name,
        .size = .{ .width = 1400, .height = 800 },
    });
    application = app;

    const descriptor = app.core.descriptor();
    window_size = .{ @floatFromInt(app.core.size().width), @floatFromInt(app.core.size().height) };
    framebuffer_size = .{ @floatFromInt(descriptor.width), @floatFromInt(descriptor.height) };
    content_scale = .{
        // type inference doesn't like this, but the important part is to make sure we're dividing
        // as floats not integers.
        framebuffer_size[0] / window_size[0],
        framebuffer_size[1] / window_size[1],
    };

    const scale_factor = content_scale[1];

    const allocator = gpa.allocator();

    zstbi.init(allocator);

    var open_files = std.ArrayList(storage.Internal.Pixi).init(allocator);
    var pack_open_files = std.ArrayList(storage.Internal.Pixi).init(allocator);

    // Logos
    const background_logo = try gfx.Texture.loadFromFile(app.core.device(), assets.icon1024_png.path, .{});
    const fox_logo = try gfx.Texture.loadFromFile(app.core.device(), assets.fox1024_png.path, .{});

    // Cursors
    const pencil = try gfx.Texture.loadFromFile(app.core.device(), if (scale_factor > 1) assets.pencil64_png.path else assets.pencil32_png.path, .{});
    const eraser = try gfx.Texture.loadFromFile(app.core.device(), if (scale_factor > 1) assets.eraser64_png.path else assets.eraser32_png.path, .{});

    const hotkeys = try Hotkeys.initDefault(allocator);

    const packer = try Packer.init(allocator);

    state = try gpa.allocator().create(PixiState);

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

    zgui.init(allocator);
    zgui.mach_backend.init(&app.core, app.core.device(), app.core.descriptor().format, .{});
    zgui.io.setIniFilename(assets.root ++ "imgui.ini");
    _ = zgui.io.addFontFromFile(assets.root ++ "fonts/CozetteVector.ttf", state.settings.font_size * scale_factor);
    var config = zgui.FontConfig.init();
    config.merge_mode = true;
    const ranges: []const u16 = &.{ 0xf000, 0xf976, 0 };
    state.fonts.fa_standard_solid = zgui.io.addFontFromFileWithConfig(assets.root ++ "fonts/fa-solid-900.ttf", state.settings.font_size * scale_factor, config, ranges.ptr);
    state.fonts.fa_standard_regular = zgui.io.addFontFromFileWithConfig(assets.root ++ "fonts/fa-regular-400.ttf", state.settings.font_size * scale_factor, config, ranges.ptr);
    state.fonts.fa_small_solid = zgui.io.addFontFromFileWithConfig(assets.root ++ "fonts/fa-solid-900.ttf", 10 * scale_factor, config, ranges.ptr);
    state.fonts.fa_small_regular = zgui.io.addFontFromFileWithConfig(assets.root ++ "fonts/fa-regular-400.ttf", 10 * scale_factor, config, ranges.ptr);
    state.style.set();
}

pub fn updateMainThread(_: *App) !bool {
    input.process() catch unreachable;

    state.popups.user_path = switch (state.popups.user_state) {
        .none => state.popups.user_path,
        .file => if (try nfd.openFileDialog(if (state.popups.user_filter) |filter| blk: {
            break :blk filter;
        } else null, null)) |path| blk: {
            state.popups.user_state = .none;
            break :blk path;
        } else blk: {
            state.popups.user_state = .none;
            break :blk null;
        },
        .folder => if (try nfd.openFolderDialog(null)) |path| blk: {
            state.popups.user_state = .none;
            break :blk path;
        } else blk: {
            state.popups.user_state = .none;
            break :blk null;
        },
        .save => if (try nfd.saveFileDialog(if (state.popups.user_filter) |filter| filter else null, null)) |path| blk: {
            state.popups.user_state = .none;
            break :blk path;
        } else blk: {
            state.popups.user_state = .none;
            break :blk null;
        },
    };
    return false;
}

pub fn update(app: *App) !bool {
    zgui.mach_backend.newFrame();
    state.delta_time = app.timer.lap();
    const descriptor = app.core.descriptor();
    window_size = .{ @floatFromInt(app.core.size().width), @floatFromInt(app.core.size().height) };
    framebuffer_size = .{ @floatFromInt(descriptor.width), @floatFromInt(descriptor.height) };
    content_scale = .{
        // type inference doesn't like this, but the important part is to make sure we're dividing
        // as floats not integers.
        framebuffer_size[0] / window_size[0],
        framebuffer_size[1] / window_size[1],
    };

    var iter = app.core.pollEvents();
    while (iter.next()) |event| {
        switch (event) {
            .key_press => |key_press| {
                state.hotkeys.setHotkeyState(key_press.key, key_press.mods, .press);
            },
            .key_repeat => |key_repeat| {
                state.hotkeys.setHotkeyState(key_repeat.key, key_repeat.mods, .repeat);
            },
            .key_release => |key_release| {
                state.hotkeys.setHotkeyState(key_release.key, key_release.mods, .release);
            },
            .mouse_scroll => |mouse_scroll| {
                state.controls.mouse.scroll_x = mouse_scroll.xoffset;
                state.controls.mouse.scroll_y = mouse_scroll.yoffset;
            },
            .mouse_motion => |mouse_motion| {
                state.controls.mouse.position = .{ .x = @floatCast(mouse_motion.pos.x * content_scale[0]), .y = @floatCast(mouse_motion.pos.y * content_scale[1]) };
            },
            .mouse_press => |mouse_press| {
                switch (mouse_press.button) {
                    .left => {
                        state.controls.mouse.primary.state = true;
                        state.controls.mouse.clicked_position = .{ .x = @floatCast(mouse_press.pos.x * content_scale[0]), .y = @floatCast(mouse_press.pos.y * content_scale[1]) };
                    },
                    .right => {
                        state.controls.mouse.secondary.state = true;
                    },
                    else => {},
                }
            },
            .mouse_release => |mouse_release| {
                switch (mouse_release.button) {
                    .left => {
                        state.controls.mouse.primary.state = false;
                    },
                    .right => {
                        state.controls.mouse.secondary.state = false;
                    },
                    else => {},
                }
            },
            .close => {
                var should_close = true;
                for (state.open_files.items) |file| {
                    if (file.dirty()) {
                        should_close = false;
                    }
                }

                if (!should_close and !state.popups.file_confirm_close_exit) {
                    state.popups.file_confirm_close = true;
                    state.popups.file_confirm_close_state = .all;
                    state.popups.file_confirm_close_exit = true;
                }
                state.should_close = should_close;
            },
            else => {},
        }
        zgui.mach_backend.passEvent(event, content_scale);
    }

    editor.draw();

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
                    .load_op = .load,
                    .store_op = .store,
                };

                const render_pass_info = gpu.RenderPassDescriptor.init(.{
                    .color_attachments = &.{color_attachment},
                });
                const pass = encoder.beginRenderPass(&render_pass_info);

                zgui.mach_backend.draw(pass);
                pass.end();
                pass.release();
            }

            break :commands encoder.finish(null);
        };
        defer zgui_commands.release();

        app.core.device().getQueue().submit(&.{zgui_commands});
        app.core.swapChain().present();
    }

    for (state.hotkeys.hotkeys) |*hotkey| {
        hotkey.previous_state = hotkey.state;
    }

    state.controls.mouse.primary.previous_state = state.controls.mouse.primary.state;
    state.controls.mouse.secondary.previous_state = state.controls.mouse.secondary.state;
    state.controls.mouse.previous_position = state.controls.mouse.position;
    if (state.should_close and !editor.saving())
        return true;

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

fn createVertexState(vs_module: *gpu.ShaderModule) gpu.VertexState {
    return gpu.VertexState{
        .module = vs_module,
        .entry_point = "main",
    };
}

fn createFragmentState(fs_module: *gpu.ShaderModule, targets: []const gpu.ColorTargetState) gpu.FragmentState {
    return gpu.FragmentState.init(.{
        .module = fs_module,
        .entry_point = "main",
        .targets = targets,
    });
}

fn createColorTargetState(format: gpu.Texture.Format) gpu.ColorTargetState {
    const blend = gpu.BlendState{};
    const color_target = gpu.ColorTargetState{
        .format = format,
        .blend = &blend,
        .write_mask = gpu.ColorWriteMaskFlags.all,
    };

    return color_target;
}
