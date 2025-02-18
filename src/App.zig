const std = @import("std");
const builtin = @import("builtin");

const mach = @import("mach");
const gpu = mach.gpu;

const imgui = @import("zig-imgui");
const imgui_mach = imgui.backends.mach;

const pixi = @import("pixi.zig");

// Modules
const Core = mach.Core;
const App = @This();
const Editor = pixi.Editor;
const Packer = pixi.Packer;
const Assets = pixi.Assets;

// Mach module, systems, and main
pub const mach_module = .app;
pub const mach_systems = .{ .main, .init, .lateInit, .tick, .deinit };

// mach entrypoint module runs this schedule
pub const main = mach.schedule(.{
    .{ Core, .init },
    .{ App, .init },
    .{ Assets, .init },
    .{ Editor, .init },
    .{ Packer, .init },
    .{ Core, .main },
});

// App fields
allocator: std.mem.Allocator = undefined,
batcher: pixi.gfx.Batcher = undefined,
content_scale: [2]f32 = undefined,
delta_time: f32 = 0.0,
framebuffer_size: [2]f32 = undefined,
mouse: pixi.input.Mouse = undefined,
pipeline_compute: *gpu.ComputePipeline = undefined,
pipeline_default: *gpu.RenderPipeline = undefined,
root_path: [:0]const u8 = undefined,
should_close: bool = false,
timer: mach.time.Timer,
total_time: f32 = 0.0,
uniform_buffer_default: *gpu.Buffer = undefined,
window: mach.ObjectID,
window_size: [2]f32 = undefined,

// These are the only two assets pixi needs outside of fonts
texture_id: mach.ObjectID = 0,
atlas_id: mach.ObjectID = 0,

var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;

/// This is a mach-called function, and the parameters are automatically injected.
pub fn init(
    app: *App,
    core: *Core,
    editor: *Editor,
    packer: *Packer,
    assets: *Assets,
    app_mod: mach.Mod(App),
) !void {
    // Store our global pointers so we can access them from non-mach functions for now
    pixi.app = app;
    pixi.core = core;
    pixi.editor = editor;
    pixi.packer = packer;
    pixi.assets = assets;

    pixi.core.on_tick = app_mod.id.tick;
    pixi.core.on_exit = app_mod.id.deinit;

    const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

    // Run from the directory where the executable is located so relative assets can be found.
    var buffer: [1024]u8 = undefined;
    const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
    std.posix.chdir(path) catch {};

    // Here we have access to all the initial fields of the window
    const window = try pixi.core.windows.new(.{
        .title = "Pixi",
        .vsync_mode = .double,
    });

    app.* = .{
        .allocator = allocator,
        .timer = try mach.time.Timer.start(),
        .window = window,
        .root_path = try allocator.dupeZ(u8, path),
    };
}

/// This is called from the event fired when the window is done being
/// initialized by the platform
pub fn lateInit(
    app: *App,
    core: *Core,
    assets: *Assets,
    editor_mod: mach.Mod(Editor),
) !void {
    const window = pixi.core.windows.getValue(app.window);

    // Now that we have a valid device, we can initialize our pipelines
    try pixi.gfx.init(app);

    // Load our atlas and texture
    if (try assets.loadTexture(pixi.paths.@"pixi.png", .{})) |texture_id| {
        app.texture_id = texture_id;
        // Add our auto_reload tag for automatic asset reload
        try assets.textures.setTag(texture_id, Assets, .auto_reload, null);
    }
    if (try assets.loadAtlas(pixi.paths.@"pixi.atlas")) |atlas_id| {
        app.atlas_id = atlas_id;
        // Add our auto_reload tag for automatic asset reload
        try assets.atlases.setTag(atlas_id, Assets, .auto_reload, null);
    }

    // This will spawn a thread for watching our asset paths for changes,
    // and reloading individual assets if they change on disk
    try assets.watch();

    // Setup
    app.mouse = try pixi.input.Mouse.initDefault(app.allocator);
    app.batcher = try pixi.gfx.Batcher.init(app.allocator, 1000);

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

    _ = io.fonts.?.addFontFromFileTTF(pixi.paths.@"CozetteVector.ttf", pixi.editor.settings.font_size, &cozette_config, null);

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

    _ = io.fonts.?.addFontFromFileTTF(pixi.paths.@"fa-solid-900.ttf", pixi.editor.settings.font_size, &fa_config, @ptrCast(ranges.ptr)).?;
    _ = io.fonts.?.addFontFromFileTTF(pixi.paths.@"fa-regular-400.ttf", pixi.editor.settings.font_size, &fa_config, @ptrCast(ranges.ptr)).?;

    // This will load our theme
    editor_mod.call(.lateInit);
}

/// This is a mach-called function, and the parameters are automatically injected.
pub fn tick(core: *Core, app: *App, editor: *Editor, app_mod: mach.Mod(App), editor_mod: mach.Mod(Editor)) !void {
    const label = @tagName(mach_module) ++ ".tick";
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

        if (!app.should_close) {
            if (imgui.getCurrentContext() != null) {
                _ = imgui_mach.processEvent(event);
            }
        }
    }
    var window = core.windows.getValue(app.window);

    // New imgui frame
    try imgui_mach.newFrame();
    imgui.newFrame();

    // Update times
    app.delta_time = app.timer.lap();
    app.total_time += app.delta_time;

    // Process input
    try pixi.input.process();

    // Process editor tick
    editor_mod.call(.tick);

    // Render imgui
    imgui.render();

    // Pass commands to the window queue for presenting
    if (window.swap_chain.getCurrentTextureView()) |back_buffer_view| {
        defer back_buffer_view.release();

        const imgui_commands = commands: {
            const encoder = window.device.createCommandEncoder(&.{ .label = label });
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

            break :commands encoder.finish(&.{ .label = label });
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
pub fn deinit(app: *App, packer_mod: mach.Mod(Packer), editor_mod: mach.Mod(Editor), assets_mod: mach.Mod(Assets)) !void {
    editor_mod.call(.deinit);

    app.allocator.free(app.mouse.buttons);

    app.batcher.deinit();
    app.pipeline_default.release();
    app.pipeline_compute.release();
    app.uniform_buffer_default.release();

    imgui_mach.shutdown();
    imgui.getIO().fonts.?.clear();
    imgui.destroyContext(null);

    assets_mod.call(.deinit);
    packer_mod.call(.deinit);

    app.allocator.free(app.root_path);

    _ = gpa.detectLeaks();
    _ = gpa.deinit();
}
