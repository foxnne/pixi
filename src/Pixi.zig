const std = @import("std");

const mach = @import("mach");
const gpu = mach.gpu;

const zstbi = @import("zstbi");
const zm = @import("zmath");
const nfd = @import("nfd");

const imgui = @import("zig-imgui");
const imgui_mach = imgui.backends.mach;

// Modules
const Core = mach.Core;
pub const App = @This();
pub const Editor = @import("editor/Editor.zig");

// Global pointers
pub var core: *Core = undefined;
pub var app: *App = undefined;
pub var editor: *Editor = undefined;

// Mach module, systems, and main
pub const mach_module = .app;
pub const mach_systems = .{ .main, .init, .lateInit, .tick, .deinit };
pub const main = mach.schedule(.{
    .{ Core, .init },
    .{ App, .init },
    .{ Editor, .init },
    .{ Core, .main },
});

// App fields
timer: mach.time.Timer,
window: mach.ObjectID,

allocator: std.mem.Allocator = undefined,
arena_allocator: std.heap.ArenaAllocator = undefined,
mouse: input.Mouse = undefined,
root_path: [:0]const u8 = undefined,
delta_time: f32 = 0.0,
total_time: f32 = 0.0,
loaded_assets: LoadedAssets = undefined,
fonts: Fonts = .{},
batcher: gfx.Batcher = undefined,
packer: Packer = undefined,
pipeline_default: *gpu.RenderPipeline = undefined,
pipeline_compute: *gpu.ComputePipeline = undefined,
uniform_buffer_default: *gpu.Buffer = undefined,
content_scale: [2]f32 = undefined,
window_size: [2]f32 = undefined,
framebuffer_size: [2]f32 = undefined,
should_close: bool = false,

pub const version: std.SemanticVersion = .{ .major = 0, .minor = 2, .patch = 0 };

pub const Packer = @import("tools/Packer.zig");

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

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub const LoadedAssets = struct {
    atlas_png: gfx.Texture,
    atlas: gfx.Atlas,

    pub fn init(allocator: std.mem.Allocator) !LoadedAssets {
        return .{
            .atlas_png = try gfx.Texture.loadFromFile(assets.pixi_png.path, .{}),
            .atlas = try gfx.Atlas.loadFromFile(allocator, assets.pixi_atlas.path),
        };
    }

    pub fn deinit(self: *LoadedAssets, allocator: std.mem.Allocator) void {
        self.atlas_png.deinit();
        self.atlas.deinit(allocator);
    }
};

pub const Fonts = struct {
    fa_standard_regular: *imgui.Font = undefined,
    fa_standard_solid: *imgui.Font = undefined,
};

/// This is a mach-called function, and the parameters are automatically injected.
pub fn init(
    _app: *App,
    _core: *Core,
    _editor: *Editor,
    app_mod: mach.Mod(App),
) !void {
    // Store our global pointers so we can access them from non-mach functions for now
    app = _app;
    core = _core;
    editor = _editor;

    core.on_tick = app_mod.id.tick;
    core.on_exit = app_mod.id.deinit;

    const allocator = gpa.allocator();

    // Run from the directory where the executable is located so relative assets can be found.
    var buffer: [1024]u8 = undefined;
    const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
    std.posix.chdir(path) catch {};

    // Here we have access to all the initial fields of the window
    const window = try core.windows.new(.{
        .title = "Pixi",
        .vsync_mode = .double,
    });

    app.* = .{
        .allocator = allocator,
        .arena_allocator = std.heap.ArenaAllocator.init(allocator),
        .timer = try mach.time.Timer.start(),
        .window = window,
        .root_path = try allocator.dupeZ(u8, path),
    };
}

/// This is called from the event fired when the window is done being
/// initialized by the platform
pub fn lateInit(editor_mod: mach.Mod(Editor)) !void {
    const window = core.windows.getValue(app.window);

    // Now that we have a valid device, we can initialize our pipelines
    try gfx.init(app);

    // Initialize zstbi to load assets
    zstbi.init(app.allocator);

    // Load assets
    app.loaded_assets = try LoadedAssets.init(app.allocator);

    // Setup
    app.mouse = try input.Mouse.initDefault(app.allocator);
    app.packer = try Packer.init(app.allocator);
    app.batcher = try gfx.Batcher.init(app.allocator, 1000);

    // Store information about the window in float format
    app.window_size = .{ @floatFromInt(window.width), @floatFromInt(window.height) };
    app.framebuffer_size = .{ @floatFromInt(window.framebuffer_width), @floatFromInt(window.framebuffer_height) };
    app.content_scale = .{
        app.framebuffer_size[0] / app.window_size[0],
        app.framebuffer_size[1] / app.window_size[1],
    };

    // Setup imgui
    imgui.setZigAllocator(&app.allocator);
    _ = imgui.createContext(null);
    try imgui_mach.init(core, app.allocator, window.device, .{
        .mag_filter = .nearest,
        .min_filter = .nearest,
        .mipmap_filter = .nearest,
        .color_format = window.framebuffer_format,
    });

    // Setup fonts
    var io = imgui.getIO();
    io.config_flags |= imgui.ConfigFlags_NavEnableKeyboard;
    io.display_framebuffer_scale = .{ .x = app.content_scale[0], .y = app.content_scale[1] };
    io.font_global_scale = 1.0;

    var cozette_config: imgui.FontConfig = std.mem.zeroes(imgui.FontConfig);
    cozette_config.font_data_owned_by_atlas = true;
    cozette_config.oversample_h = 2;
    cozette_config.oversample_v = 1;
    cozette_config.glyph_max_advance_x = std.math.floatMax(f32);
    cozette_config.rasterizer_multiply = 1.0;
    cozette_config.rasterizer_density = 1.0;
    cozette_config.ellipsis_char = imgui.UNICODE_CODEPOINT_MAX;

    _ = io.fonts.?.addFontFromFileTTF(assets.root ++ "fonts/CozetteVector.ttf", editor.settings.font_size, &cozette_config, null);

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

    app.fonts.fa_standard_solid = io.fonts.?.addFontFromFileTTF(assets.root ++ "fonts/fa-solid-900.ttf", editor.settings.font_size, &fa_config, @ptrCast(ranges.ptr)).?;
    app.fonts.fa_standard_regular = io.fonts.?.addFontFromFileTTF(assets.root ++ "fonts/fa-regular-400.ttf", editor.settings.font_size, &fa_config, @ptrCast(ranges.ptr)).?;

    // This will load our theme
    editor_mod.call(.lateInit);
}

/// This is a mach-called function, and the parameters are automatically injected.
pub fn tick(app_mod: mach.Mod(App), editor_mod: mach.Mod(Editor)) !void {
    // Process dialog requests
    editor_mod.call(.processDialogRequest);

    // Process events
    while (core.nextEvent()) |event| {
        switch (event) {
            .window_open => {
                app_mod.call(.lateInit);
            },
            .key_press => |key_press| {
                editor.hotkeys.setHotkeyState(key_press.key, key_press.mods, .press);
            },
            .key_repeat => |key_repeat| {
                editor.hotkeys.setHotkeyState(key_repeat.key, key_repeat.mods, .repeat);
            },
            .key_release => |key_release| {
                editor.hotkeys.setHotkeyState(key_release.key, key_release.mods, .release);
            },
            .mouse_scroll => |mouse_scroll| {
                // TODO: Fix this in the editor code, we dont want to block mouse input based on popups
                if (!editor.popups.anyPopupOpen()) { // Only record mouse scrolling for canvases when popups are closed
                    app.mouse.scroll_x = mouse_scroll.xoffset;
                    app.mouse.scroll_y = mouse_scroll.yoffset;
                }
            },
            .zoom_gesture => |gesture| {
                app.mouse.magnify = gesture.zoom;
            },
            .mouse_motion => |mouse_motion| {
                app.mouse.position = .{ @floatCast(mouse_motion.pos.x), @floatCast(mouse_motion.pos.y) };
            },
            .mouse_press => |mouse_press| {
                app.mouse.setButtonState(mouse_press.button, mouse_press.mods, .press);
            },
            .mouse_release => |mouse_release| {
                app.mouse.setButtonState(mouse_release.button, mouse_release.mods, .release);
            },
            .close => {
                // Currently, just pass along this message to the editor
                // and allow the editor to set the app.should_close or not
                editor_mod.call(.close);
            },
            .window_resize => |resize| {
                const window = core.windows.getValue(app.window);
                app.window_size = .{ @floatFromInt(resize.size.width), @floatFromInt(resize.size.height) };
                app.framebuffer_size = .{ @floatFromInt(window.framebuffer_width), @floatFromInt(window.framebuffer_height) };
                app.content_scale = .{
                    app.framebuffer_size[0] / app.window_size[0],
                    app.framebuffer_size[1] / app.window_size[1],
                };
            },

            else => {},
        }

        if (!app.should_close)
            _ = imgui_mach.processEvent(event);
    }
    var window = core.windows.getValue(app.window);

    // New imgui frame
    try imgui_mach.newFrame();
    imgui.newFrame();

    // Update times
    app.delta_time = app.timer.lap();
    app.total_time += app.delta_time;

    // Process input
    try input.process();

    // Process editor tick
    editor_mod.call(.tick);

    // Render imgui
    imgui.render();

    // Pass commands to the window queue for presenting
    if (window.swap_chain.getCurrentTextureView()) |back_buffer_view| {
        defer back_buffer_view.release();

        const imgui_commands = commands: {
            const encoder = window.device.createCommandEncoder(null);
            defer encoder.release();

            const background: gpu.Color = .{
                .r = @floatCast(editor.theme.foreground.value[0]),
                .g = @floatCast(editor.theme.foreground.value[1]),
                .b = @floatCast(editor.theme.foreground.value[2]),
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

        if (app.batcher.empty) {
            window.queue.submit(&.{imgui_commands});
        } else {
            const batcher_commands = try app.batcher.finish();
            defer batcher_commands.release();
            window.queue.submit(&.{ batcher_commands, imgui_commands });
        }
    }

    for (app.mouse.buttons) |*button| {
        button.previous_state = button.state;
    }

    app.mouse.previous_position = app.mouse.position;

    // Finally, close if we should and aren't in the middle of saving
    if (app.should_close and !editor.saving()) {
        core.exit();
    }
}

/// This is a mach-called function, and the parameters are automatically injected.
pub fn deinit(editor_mod: mach.Mod(Editor)) !void {
    editor_mod.call(.deinit);

    app.allocator.free(app.mouse.buttons);

    app.packer.deinit();

    app.batcher.deinit();
    app.pipeline_default.release();
    app.pipeline_compute.release();
    app.uniform_buffer_default.release();

    app.loaded_assets.deinit(app.allocator);

    imgui_mach.shutdown();
    imgui.getIO().fonts.?.clear();
    imgui.destroyContext(null);

    zstbi.deinit();
    app.allocator.free(app.root_path);
    app.arena_allocator.deinit();

    _ = gpa.detectLeaks();
    _ = gpa.deinit();
}
