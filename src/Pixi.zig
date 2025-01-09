// Imports
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
    .{ Core, .main },
});

// App fields
timer: mach.time.Timer,
window: mach.ObjectID,

allocator: std.mem.Allocator = undefined,
arena_allocator: std.heap.ArenaAllocator = undefined,

settings: Settings = undefined,
hotkeys: input.Hotkeys = undefined,
mouse: input.Mouse = undefined,
sidebar: Sidebar = .files,
project_folder: ?[:0]const u8 = null,
root_path: [:0]const u8 = undefined,
recents: Recents = undefined,
previous_atlas_export: ?[:0]const u8 = null,
open_files: std.ArrayList(storage.Internal.PixiFile) = undefined,
open_references: std.ArrayList(storage.Internal.Reference) = undefined,
packer: Packer = undefined,
atlas: storage.Internal.Atlas = .{},
open_file_index: usize = 0,
open_reference_index: usize = 0,
tools: Tools = .{},
popups: Popups = .{},
should_close: bool = false,
fonts: Fonts = .{},
colors: Colors = .{},
delta_time: f32 = 0.0,
total_time: f32 = 0.0,
selection_time: f32 = 0.0,
selection_invert: bool = false,
loaded_assets: LoadedAssets = undefined,
clipboard_image: ?zstbi.Image = null,
clipboard_position: [2]u32 = .{ 0, 0 },
batcher: gfx.Batcher = undefined,
pipeline_default: *gpu.RenderPipeline = undefined,
pipeline_compute: *gpu.ComputePipeline = undefined,
uniform_buffer_default: *gpu.Buffer = undefined,
content_scale: [2]f32 = undefined,
window_size: [2]f32 = undefined,
framebuffer_size: [2]f32 = undefined,

pub const version: std.SemanticVersion = .{ .major = 0, .minor = 2, .patch = 0 };

pub const Popups = @import("editor/popups/Popups.zig");
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

pub const Colors = @import("Colors.zig");
pub const Recents = @import("Recents.zig");
pub const Tools = @import("Tools.zig");
pub const Settings = @import("Settings.zig");

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

pub const Sidebar = enum(u32) {
    files,
    tools,
    sprites,
    animations,
    keyframe_animations,
    pack,
    settings,
};

pub const Fonts = struct {
    fa_standard_regular: *imgui.Font = undefined,
    fa_standard_solid: *imgui.Font = undefined,
};

pub fn init(_app: *App, _core: *Core, app_mod: mach.Mod(App), _editor: *Editor) !void {
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

    std.log.debug("Root path: {s}", .{path});

    const window = try core.windows.new(.{
        .title = "Pixi",
        .vsync_mode = .double,
    });

    _app.* = .{
        .allocator = allocator,
        .timer = try mach.time.Timer.start(),
        .window = window,
        .root_path = try allocator.dupeZ(u8, path),
    };
}

/// This is called from the event fired when the window is done being
/// initialized by the platform
pub fn lateInit(editor_mod: mach.Mod(Editor)) !void {
    const window = core.windows.getValue(app.window);

    app.arena_allocator = std.heap.ArenaAllocator.init(app.allocator);
    app.settings = try Settings.init(app.arena_allocator.allocator());

    zstbi.init(app.allocator);

    app.open_files = std.ArrayList(storage.Internal.PixiFile).init(app.allocator);
    app.open_references = std.ArrayList(storage.Internal.Reference).init(app.allocator);

    app.colors.keyframe_palette = try storage.Internal.Palette.loadFromFile(assets.pear36_hex.path);

    app.hotkeys = try input.Hotkeys.initDefault(app.allocator);

    app.loaded_assets = try LoadedAssets.init(app.allocator);
    app.mouse = try input.Mouse.initDefault(app.allocator);

    app.packer = try Packer.init(app.allocator);
    app.recents = try Recents.init(app.allocator);

    app.batcher = try gfx.Batcher.init(app.allocator, 1000);

    app.window_size = .{ @floatFromInt(window.width), @floatFromInt(window.height) };
    app.framebuffer_size = .{ @floatFromInt(window.framebuffer_width), @floatFromInt(window.framebuffer_height) };
    app.content_scale = .{
        app.framebuffer_size[0] / app.window_size[0],
        app.framebuffer_size[1] / app.window_size[1],
    };
    // TODO: Remove usage of content_scale if it isn't needed
    app.content_scale = .{ 1.0, 1.0 };

    const scale_factor = app.content_scale[1];

    try gfx.init(app);

    imgui.setZigAllocator(&app.allocator);

    _ = imgui.createContext(null);
    try imgui_mach.init(core, app.allocator, window.device, .{
        .mag_filter = .nearest,
        .min_filter = .nearest,
        .mipmap_filter = .nearest,
        .color_format = window.framebuffer_format,
    });

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

    _ = io.fonts.?.addFontFromFileTTF(assets.root ++ "fonts/CozetteVector.ttf", app.settings.font_size * scale_factor, &cozette_config, null);

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

    app.fonts.fa_standard_solid = io.fonts.?.addFontFromFileTTF(assets.root ++ "fonts/fa-solid-900.ttf", app.settings.font_size * scale_factor, &fa_config, @ptrCast(ranges.ptr)).?;
    app.fonts.fa_standard_regular = io.fonts.?.addFontFromFileTTF(assets.root ++ "fonts/fa-regular-400.ttf", app.settings.font_size * scale_factor, &fa_config, @ptrCast(ranges.ptr)).?;

    // Initialize the editor which loads our theme
    editor_mod.call(.init);
}

pub fn tick(app_mod: mach.Mod(App), editor_mod: mach.Mod(Editor)) !void {
    if (app.popups.file_dialog_request) |request| {
        defer app.popups.file_dialog_request = null;
        const initial = if (request.initial) |initial| initial else app.project_folder;

        if (switch (request.state) {
            .file => try nfd.openFileDialog(request.filter, initial),
            .folder => try nfd.openFolderDialog(initial),
            .save => try nfd.saveFileDialog(request.filter, initial),
        }) |path| {
            app.popups.file_dialog_response = .{
                .path = path,
                .type = request.type,
            };
        }
    }

    // Process events
    while (core.nextEvent()) |event| {
        switch (event) {
            .window_open => {
                app_mod.call(.lateInit);
            },
            .key_press => |key_press| {
                app.hotkeys.setHotkeyState(key_press.key, key_press.mods, .press);
            },
            .key_repeat => |key_repeat| {
                app.hotkeys.setHotkeyState(key_repeat.key, key_repeat.mods, .repeat);
            },
            .key_release => |key_release| {
                app.hotkeys.setHotkeyState(key_release.key, key_release.mods, .release);
            },
            .mouse_scroll => |mouse_scroll| {
                if (!app.popups.anyPopupOpen()) { // Only record mouse scrolling for canvases when popups are closed
                    app.mouse.scroll_x = mouse_scroll.xoffset;
                    app.mouse.scroll_y = mouse_scroll.yoffset;
                }
            },
            .zoom_gesture => |gesture| {
                app.mouse.magnify = gesture.zoom;
            },
            .mouse_motion => |mouse_motion| {
                app.mouse.position = .{ @floatCast(mouse_motion.pos.x * app.content_scale[0]), @floatCast(mouse_motion.pos.y * app.content_scale[1]) };
            },
            .mouse_press => |mouse_press| {
                app.mouse.setButtonState(mouse_press.button, mouse_press.mods, .press);
            },
            .mouse_release => |mouse_release| {
                app.mouse.setButtonState(mouse_release.button, mouse_release.mods, .release);
            },
            .close => {
                var should_close = true;
                for (app.open_files.items) |file| {
                    if (file.dirty()) {
                        should_close = false;
                    }
                }

                if (!should_close and !app.popups.file_confirm_close_exit) {
                    app.popups.file_confirm_close = true;
                    app.popups.file_confirm_close_state = .all;
                    app.popups.file_confirm_close_exit = true;
                }
                app.should_close = should_close;
            },
            .window_resize => |resize| {
                const window = core.windows.gsetValue(app.window);
                app.window_size = .{ @floatFromInt(resize.size.width), @floatFromInt(resize.size.height) };
                app.framebuffer_size = .{ @floatFromInt(window.framebuffer_width), @floatFromInt(window.framebuffer_height) };
                app.content_scale = .{
                    app.framebuffer_size[0] / app.window_size[0],
                    app.framebuffer_size[1] / app.window_size[1],
                };

                // TODO:
                // Currently content scale is set to 1.0x1.0 because the scaling is handled by
                // zig-imgui. Tested both on Windows (1.0 content scale) and macOS (2.0 content scale)
                // If we can confirm that this is not needed, we can purge the use of content_scale from editor files
                app.content_scale = .{ 1.0, 1.0 };
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
    app.delta_time = app.timer.lap();
    app.total_time += app.delta_time;

    // Process input
    try input.process();

    // Process editor tick
    editor_mod.call(.tick);

    // Render imgui
    imgui.render();

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

    // Accept transformations
    {
        for (app.open_files.items) |*file| {
            if (file.transform_texture) |*transform_texture| {
                if (transform_texture.confirm) {
                    // Blit temp layer to selected layer
                    if (file.transform_staging_buffer) |staging_buffer| {
                        const buffer_size: usize = @as(usize, @intCast(file.width * file.height));

                        var response: gpu.Buffer.MapAsyncStatus = undefined;
                        const callback = (struct {
                            pub inline fn callback(ctx: *gpu.Buffer.MapAsyncStatus, status: gpu.Buffer.MapAsyncStatus) void {
                                ctx.* = status;
                            }
                        }).callback;

                        staging_buffer.mapAsync(.{ .read = true }, 0, buffer_size * @sizeOf([4]f32), &response, callback);
                        while (true) {
                            if (response == gpu.Buffer.MapAsyncStatus.success) {
                                break;
                            } else {
                                window.device.tick();
                            }
                        }

                        const layer_index = file.selected_layer_index;
                        const write_layer = file.layers.get(file.selected_layer_index);

                        if (staging_buffer.getConstMappedRange([4]f32, 0, buffer_size)) |buffer_mapped| {
                            for (write_layer.pixels(), buffer_mapped, 0..) |*p, b, i| {
                                if (b[3] != 0.0) {
                                    try file.buffers.stroke.append(i, p.*);

                                    const out: [4]u8 = .{
                                        @as(u8, @intFromFloat(b[0] * 255.0)),
                                        @as(u8, @intFromFloat(b[1] * 255.0)),
                                        @as(u8, @intFromFloat(b[2] * 255.0)),
                                        @as(u8, @intFromFloat(b[3] * 255.0)),
                                    };
                                    p.* = out;
                                }
                            }
                        }

                        // Submit the stroke change buffer
                        if (file.buffers.stroke.indices.items.len > 0) {
                            const change = try file.buffers.stroke.toChange(@intCast(layer_index));
                            try file.history.append(change);
                        }

                        staging_buffer.unmap();

                        var texture: *gfx.Texture = &file.layers.items(.texture)[file.selected_layer_index];
                        texture.update(window.device);
                    }

                    transform_texture.texture.deinit();
                    file.transform_texture = null;
                }
            }
        }
    }

    for (app.hotkeys.hotkeys) |*hotkey| {
        hotkey.previous_state = hotkey.state;
    }

    for (app.mouse.buttons) |*button| {
        button.previous_state = button.state;
    }

    app.mouse.previous_position = app.mouse.position;

    if (app.should_close and !Editor.saving()) {
        // Close!
        core.exit();
    }
}

pub fn deinit(editor_mod: mach.Mod(Editor)) !void {
    //deinit and save settings
    app.settings.save(app.arena_allocator.allocator());
    app.settings.deinit(app.arena_allocator.allocator());

    app.allocator.free(editor.theme.name);

    app.allocator.free(app.hotkeys.hotkeys);
    app.allocator.free(app.mouse.buttons);
    app.packer.deinit();
    app.recents.deinit();

    app.batcher.deinit();
    app.pipeline_default.release();
    app.uniform_buffer_default.release();

    app.pipeline_compute.release();

    if (app.atlas.external) |*atlas| {
        for (atlas.sprites) |sprite| {
            app.allocator.free(sprite.name);
        }

        for (atlas.animations) |animation| {
            app.allocator.free(animation.name);
        }

        app.allocator.free(atlas.sprites);
        app.allocator.free(atlas.animations);
    }
    if (app.previous_atlas_export) |path| {
        app.allocator.free(path);
    }
    if (app.atlas.diffusemap) |*diffusemap| diffusemap.deinit();
    if (app.atlas.heightmap) |*heightmap| heightmap.deinit();
    if (app.colors.palette) |*palette| palette.deinit();
    if (app.colors.keyframe_palette) |*keyframe_palette| keyframe_palette.deinit();

    if (app.clipboard_image) |*image| image.deinit();

    editor_mod.call(.deinit);
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
