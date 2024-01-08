const std = @import("std");
const build_options = @import("build-options");

const core = @import("mach-core");
const gpu = core.gpu;

const zstbi = @import("zstbi");
const zm = @import("zmath");
const nfd = @import("nfd");

const imgui = @import("zig-imgui");
const imgui_mach = imgui.backends.mach;

pub const App = @This();

pub const mach_core_options = core.ComptimeOptions{
    .use_wgpu = !build_options.use_sysgpu,
    .use_dgpu = build_options.use_sysgpu,
};

timer: core.Timer,

pub const name: [:0]const u8 = "Pixi";
pub const version: std.SemanticVersion = .{ .major = 0, .minor = 1, .patch = 0 };

pub const Popups = @import("editor/popups/Popups.zig");
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

pub var state: *PixiState = undefined;
pub var content_scale: [2]f32 = undefined;
pub var window_size: [2]f32 = undefined;
pub var framebuffer_size: [2]f32 = undefined;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub const Colors = @import("Colors.zig");
pub const Recents = @import("Recents.zig");
pub const Tools = @import("Tools.zig");
pub const Settings = @import("Settings.zig");

/// Holds the global game state.
pub const PixiState = struct {
    allocator: std.mem.Allocator = undefined,
    settings: Settings = undefined,
    hotkeys: input.Hotkeys = undefined,
    mouse: input.Mouse = undefined,
    sidebar: Sidebar = .files,
    theme: editor.Theme = undefined,
    project_folder: ?[:0]const u8 = null,
    root_path: [:0]const u8 = undefined,
    recents: Recents = undefined,
    previous_atlas_export: ?[:0]const u8 = null,
    open_files: std.ArrayList(storage.Internal.Pixi) = undefined,
    pack_target: PackTarget = .project,
    pack_camera: gfx.Camera = .{},
    packer: Packer = undefined,
    atlas: storage.Internal.Atlas = .{},
    open_file_index: usize = 0,
    tools: Tools = .{},
    popups: Popups = .{},
    should_close: bool = false,
    fonts: Fonts = .{},
    colors: Colors = .{},
    delta_time: f32 = 0.0,
    json_allocator: std.heap.ArenaAllocator = undefined,
    assets: Assets = undefined,
};

pub const Assets = struct {
    atlas_png: gfx.Texture,
    atlas: gfx.Atlas,

    pub fn init(allocator: std.mem.Allocator) !Assets {
        return .{
            .atlas_png = try gfx.Texture.loadFromFile(assets.pixi_png.path, .{}),
            .atlas = try gfx.Atlas.loadFromFile(allocator, assets.pixi_atlas.path),
        };
    }

    pub fn deinit(self: *Assets, allocator: std.mem.Allocator) void {
        self.atlas_png.deinit();
        self.atlas.deinit(allocator);
    }
};

pub const Sidebar = enum(u32) {
    files,
    tools,
    layers,
    sprites,
    animations,
    pack,
    settings,
};

pub const Fonts = struct {
    fa_standard_regular: *imgui.Font = undefined,
    fa_standard_solid: *imgui.Font = undefined,
    fa_small_regular: *imgui.Font = undefined,
    fa_small_solid: *imgui.Font = undefined,
};

pub const PackTarget = enum {
    project,
    all_open,
    single_open,
};

pub fn init(app: *App) !void {
    const allocator = gpa.allocator();

    var buffer: [1024]u8 = undefined;
    const root_path = std.fs.selfExeDirPath(buffer[0..]) catch ".";

    state = try allocator.create(PixiState);
    state.* = .{ .root_path = try allocator.dupeZ(u8, root_path) };

    state.allocator = allocator;

    state.json_allocator = std.heap.ArenaAllocator.init(allocator);
    state.settings = try Settings.init(state.json_allocator.allocator());
    const theme_path = try std.fs.path.joinZ(allocator, &.{ assets.themes, state.settings.theme });
    defer allocator.free(theme_path);

    state.theme = try editor.Theme.loadFromFile(theme_path);

    try core.init(.{
        .title = name,
        .size = .{ .width = state.settings.initial_window_width, .height = state.settings.initial_window_height },
    });

    const descriptor = core.descriptor;
    window_size = .{ @floatFromInt(core.size().width), @floatFromInt(core.size().height) };
    framebuffer_size = .{ @floatFromInt(descriptor.width), @floatFromInt(descriptor.height) };
    content_scale = .{
        framebuffer_size[0] / window_size[0],
        framebuffer_size[1] / window_size[1],
    };

    const scale_factor = content_scale[1];

    zstbi.init(allocator);

    state.open_files = std.ArrayList(storage.Internal.Pixi).init(allocator);

    state.hotkeys = try input.Hotkeys.initDefault(allocator);
    state.assets = try Assets.init(allocator);
    state.mouse = try input.Mouse.initDefault(allocator);

    state.packer = try Packer.init(allocator);
    state.recents = try Recents.init(allocator);

    state.allocator = allocator;

    app.* = .{
        .timer = try core.Timer.start(),
    };

    imgui.setZigAllocator(&state.allocator);
    _ = imgui.createContext(null);
    try imgui_mach.init(allocator, core.device, .{
        .mag_filter = .nearest,
        .min_filter = .nearest,
        .mipmap_filter = .nearest,
    });

    var io = imgui.getIO();
    io.config_flags |= imgui.ConfigFlags_NavEnableKeyboard;
    io.font_global_scale = 1.0 / io.display_framebuffer_scale.y;
    var cozette_config: imgui.FontConfig = std.mem.zeroes(imgui.FontConfig);
    cozette_config.font_data_owned_by_atlas = true;
    cozette_config.oversample_h = 2;
    cozette_config.oversample_v = 1;
    cozette_config.glyph_max_advance_x = std.math.floatMax(f32);
    cozette_config.rasterizer_multiply = 1.0;
    cozette_config.rasterizer_density = 1.0;
    cozette_config.ellipsis_char = imgui.UNICODE_CODEPOINT_MAX;

    _ = io.fonts.?.addFontFromFileTTF(assets.root ++ "fonts/CozetteVector.ttf", state.settings.font_size * scale_factor, &cozette_config, null);

    var fa_config: imgui.FontConfig = std.mem.zeroes(imgui.FontConfig);
    fa_config.merge_mode = true;
    fa_config.font_data_owned_by_atlas = true;
    fa_config.oversample_h = 2;
    fa_config.oversample_v = 1;
    fa_config.glyph_max_advance_x = std.math.floatMax(f32);
    fa_config.rasterizer_multiply = 1.0;
    fa_config.rasterizer_density = 1.0;
    fa_config.ellipsis_char = imgui.UNICODE_CODEPOINT_MAX;
    const ranges: []const u16 = &.{ 0xf000, 0xf976, 0 };

    state.fonts.fa_standard_solid = io.fonts.?.addFontFromFileTTF(assets.root ++ "fonts/fa-solid-900.ttf", state.settings.font_size * scale_factor, &fa_config, @ptrCast(ranges.ptr)).?;
    state.fonts.fa_standard_regular = io.fonts.?.addFontFromFileTTF(assets.root ++ "fonts/fa-regular-400.ttf", state.settings.font_size * scale_factor, &fa_config, @ptrCast(ranges.ptr)).?;
    state.fonts.fa_small_solid = io.fonts.?.addFontFromFileTTF(assets.root ++ "fonts/fa-solid-900.ttf", 10 * scale_factor, &fa_config, @ptrCast(ranges.ptr)).?;
    state.fonts.fa_small_regular = io.fonts.?.addFontFromFileTTF(assets.root ++ "fonts/fa-regular-400.ttf", 10 * scale_factor, &fa_config, @ptrCast(ranges.ptr)).?;

    state.theme.init();
}

pub fn updateMainThread(_: *App) !bool {
    if (state.popups.file_dialog_request) |request| {
        const initial = if (request.initial) |initial| initial else state.project_folder;

        if (switch (request.state) {
            .file => try nfd.openFileDialog(request.filter, initial),
            .folder => try nfd.openFolderDialog(initial),
            .save => try nfd.saveFileDialog(request.filter, initial),
        }) |path| {
            state.popups.file_dialog_response = .{
                .path = path,
                .type = request.type,
            };
        }
        state.popups.file_dialog_request = null;
    }

    return false;
}

pub fn update(app: *App) !bool {
    try imgui_mach.newFrame();
    imgui.newFrame();
    state.delta_time = app.timer.lap();

    const descriptor = core.descriptor;
    window_size = .{ @floatFromInt(core.size().width), @floatFromInt(core.size().height) };
    framebuffer_size = .{ @floatFromInt(descriptor.width), @floatFromInt(descriptor.height) };
    content_scale = .{
        framebuffer_size[0] / window_size[0],
        framebuffer_size[1] / window_size[1],
    };
    content_scale = .{ 1.0, 1.0 };

    var iter = core.pollEvents();
    while (iter.next()) |event| {
        if (!state.should_close)
            _ = imgui_mach.processEvent(event);

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
                if (!state.popups.anyPopupOpen()) { // Only record mouse scrolling for canvases when popups are closed
                    state.mouse.scroll_x = mouse_scroll.xoffset;
                    state.mouse.scroll_y = mouse_scroll.yoffset;
                }
            },
            .mouse_motion => |mouse_motion| {
                state.mouse.position = .{ @floatCast(mouse_motion.pos.x * content_scale[0]), @floatCast(mouse_motion.pos.y * content_scale[1]) };
            },
            .mouse_press => |mouse_press| {
                state.mouse.setButtonState(mouse_press.button, mouse_press.mods, .press);
            },
            .mouse_release => |mouse_release| {
                state.mouse.setButtonState(mouse_release.button, mouse_release.mods, .release);
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
    }

    try input.process();

    state.theme.set();

    imgui.showDemoWindow(null);

    editor.draw();
    state.theme.unset();

    imgui.render();

    if (editor.getFile(state.open_file_index)) |file| {
        @memset(core.title[0..], 0);
        @memcpy(core.title[0 .. name.len + 3], name ++ " - ");
        const base_name = std.fs.path.basename(file.path);
        @memcpy(core.title[name.len + 3 .. base_name.len + name.len + 3], base_name);
        core.setTitle(&core.title);
    } else {
        @memset(core.title[0..], 0);
        @memcpy(core.title[0..name.len], name);
        core.setTitle(&core.title);
    }

    if (core.swap_chain.getCurrentTextureView()) |back_buffer_view| {
        defer back_buffer_view.release();

        const imgui_commands = commands: {
            const encoder = core.device.createCommandEncoder(null);
            defer encoder.release();

            const background: gpu.Color = .{
                .r = @floatCast(state.theme.foreground.value[0]),
                .g = @floatCast(state.theme.foreground.value[1]),
                .b = @floatCast(state.theme.foreground.value[2]),
                .a = 1.0,
            };

            // Gui pass.
            {
                const color_attachment = gpu.RenderPassColorAttachment{
                    .view = back_buffer_view,
                    .clear_value = background,
                    .load_op = .clear,
                    .store_op = .store,
                };

                const render_pass_info = gpu.RenderPassDescriptor.init(.{
                    .color_attachments = &.{color_attachment},
                });
                const pass = encoder.beginRenderPass(&render_pass_info);
                imgui_mach.renderDrawData(imgui.getDrawData().?, pass) catch {};
                pass.end();
                pass.release();
            }

            break :commands encoder.finish(null);
        };
        defer imgui_commands.release();

        core.queue.submit(&.{imgui_commands});
        core.swap_chain.present();
    }

    for (state.hotkeys.hotkeys) |*hotkey| {
        hotkey.previous_state = hotkey.state;
    }

    for (state.mouse.buttons) |*button| {
        button.previous_state = button.state;
    }

    state.mouse.previous_position = state.mouse.position;

    if (state.should_close and !editor.saving()) {
        return true;
    }

    return false;
}

pub fn deinit(_: *App) void {
    //deinit and save settings
    state.settings.deinit(state.json_allocator.allocator());

    //free everything allocated by the json_allocator
    state.json_allocator.deinit();

    state.allocator.free(state.theme.name);

    state.allocator.free(state.hotkeys.hotkeys);
    state.allocator.free(state.mouse.buttons);
    state.packer.deinit();
    state.recents.deinit();
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
    if (state.previous_atlas_export) |path| {
        state.allocator.free(path);
    }
    if (state.atlas.diffusemap) |*diffusemap| diffusemap.deinit();
    if (state.atlas.heightmap) |*heightmap| heightmap.deinit();
    if (state.colors.palette) |*palette| palette.deinit();

    editor.deinit();
    state.assets.deinit(state.allocator);

    imgui_mach.shutdown();
    imgui.getIO().fonts.?.clear();
    imgui.destroyContext(null);

    zstbi.deinit();
    state.allocator.free(state.root_path);
    state.allocator.destroy(state);

    core.deinit();

    //uncomment this line to check for memory leaks on program shutdown
    _ = gpa.detectLeaks();
    _ = gpa.deinit();
}
