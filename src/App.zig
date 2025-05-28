const std = @import("std");
const builtin = @import("builtin");
const zmath = @import("zmath");
const dvui = @import("dvui");
const objc = @import("objc");

//const mach = @import("mach");
//const gpu = mach.gpu;

const imgui = @import("zig-imgui");
const imgui_mach = imgui.backends.mach;

const pixi = @import("pixi.zig");

// Modules
//const Core = mach.Core;
const App = @This();
const Editor = pixi.Editor;
const Packer = pixi.Packer;
const Assets = pixi.Assets;

// Mach module, systems, and main
// pub const mach_module = .app;
// pub const mach_systems = .{ .main, .init, .setup, .tick, .render, .deinit };

// mach entrypoint module runs this schedule
// pub const main = mach.schedule(.{
//     .{ Core, .init },
//     .{ App, .init },
//     .{ Assets, .init },
//     .{ Editor, .init },
//     .{ Packer, .init },
//     .{ Core, .main },
// });

// App fields
allocator: std.mem.Allocator = undefined,
//batcher: pixi.gfx.Batcher = undefined,
content_scale: [2]f32 = undefined,
delta_time: f32 = 0.0,
framebuffer_size: [2]f32 = undefined,

//pipeline_compute: *gpu.ComputePipeline = undefined,
//pipeline_default: *gpu.RenderPipeline = undefined,
root_path: [:0]const u8 = undefined,
should_close: bool = false,
//timer: mach.time.Timer,
total_time: f32 = 0.0,
//uniform_buffer_default: *gpu.Buffer = undefined,
//window: mach.ObjectID,
window: dvui.Window = undefined,
window_size: [2]f32 = undefined,

// These are the only two assets pixi needs outside of fonts
//texture_id: mach.ObjectID = 0,
//atlas_id: mach.ObjectID = 0,

var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
var elapsed_time: f32 = 0.0;
var framerate_capture: f32 = 0.0;

// To be a dvui App:
// * declare "dvui_app"
// * expose the backend's main function
// * use the backend's log function
pub const dvui_app: dvui.App = .{ .config = .{ .options = .{
    .size = .{ .w = 800.0, .h = 600.0 },
    .min_size = .{ .w = 250.0, .h = 350.0 },
    .title = "Pixi",
} }, .frameFn = AppFrame, .initFn = AppInit, .deinitFn = AppDeinit };

pub const main = dvui.App.main;
pub const panic = dvui.App.panic;
pub const std_options: std.Options = .{
    .logFn = dvui.App.logFn,
};

pub fn setTitlebarColor(win: *dvui.Window, color: [4]f32) void {
    if (builtin.os.tag == .macos) {
        // This sets the native window titlebar color on macos
        const native_window: ?*objc.app_kit.Window = @ptrCast(dvui.backend.c.SDL_GetPointerProperty(
            dvui.backend.c.SDL_GetWindowProperties(win.backend.ctx.window),
            dvui.backend.c.SDL_PROP_WINDOW_COCOA_WINDOW_POINTER,
            null,
        ));

        if (native_window) |window| {
            window.setTitlebarAppearsTransparent(true);
            const new_color = objc.app_kit.Color.colorWithRed_green_blue_alpha(
                color[0],
                color[1],
                color[2],
                color[3],
            );
            window.setBackgroundColor(new_color);
        }
    }
}

// Runs before the first frame, after backend and dvui.Window.init()
pub fn AppInit(win: *dvui.Window) void {
    setTitlebarColor(win, .{ 0.1647, 0.17254, 0.21176, 1.0 });
}

// Run as app is shutting down before dvui.Window.deinit()
pub fn AppDeinit() void {}

// Run each frame to do normal UI
pub fn AppFrame() !dvui.App.Result {
    var theme = dvui.themeGet();

    theme.color_fill = .{ .r = 39, .g = 40, .b = 48, .a = 255 };
    theme.color_fill_window = .{ .r = 42, .g = 44, .b = 54, .a = 255 };
    theme.color_text = .{ .r = 206, .g = 163, .b = 127, .a = 255 };
    theme.color_text_press = .{ .r = 186, .g = 143, .b = 107, .a = 255 };
    theme.color_fill_control = .{ .r = 42, .g = 44, .b = 54, .a = 255 };
    theme.color_fill_hover = .{ .r = 48, .g = 52, .b = 62, .a = 255 };
    theme.color_border = .{ .r = 48, .g = 52, .b = 62, .a = 255 };
    theme.color_fill_press = .{ .r = 42, .g = 44, .b = 54, .a = 255 };

    dvui.themeSet(theme);

    return frame();
}

const width = 450;

pub fn frame() !dvui.App.Result {
    var scaler = try dvui.scale(@src(), .{ .scale = &dvui.currentWindow().content_scale, .pinch_zoom = .global }, .{ .expand = .both });
    defer scaler.deinit();

    // const box = dvui.box(@src(), .horizontal, .{ .expand = .both, .color_fill = .{ .color = .{ .r = 128, .g = 0, .b = 0, .a = 255 } } });
    // defer box.deinit()

    var paned = try dvui.paned(@src(), .{ .direction = .horizontal, .collapsed_size = width + 1 }, .{ .expand = .both, .background = true, .min_size_content = .{ .h = 100, .w = 100 }, .color_fill = .fill_window });
    defer paned.deinit();

    if (paned.showFirst()) {
        var tl = try dvui.textLayout(@src(), .{}, .{ .expand = .horizontal, .font_style = .title_4, .background = false });
        const lorem = "This is a dvui.App example that can compile on multiple backends.";
        try tl.addText(lorem, .{});
        try tl.addText("\n\n", .{});
        try tl.format("Current backend: {s}", .{@tagName(dvui.backend.kind)}, .{});
        if (dvui.backend.kind == .web) {
            try tl.format(" : {s}", .{if (dvui.backend.wasm.wasm_about_webgl2() == 1) "webgl2" else "webgl (no mipmaps)"}, .{});
        }
        tl.deinit();
    }

    if (paned.showSecond()) {
        const vbox = try dvui.box(@src(), .vertical, .{ .expand = .both, .background = false });
        defer vbox.deinit();

        {
            var m = try dvui.menu(@src(), .horizontal, .{});
            defer m.deinit();

            if (try dvui.menuItemLabel(@src(), "File", .{ .submenu = true }, .{ .expand = .horizontal })) |r| {
                var fw = try dvui.floatingMenu(@src(), .{ .from = r }, .{});
                defer fw.deinit();

                try dvui.Examples.submenus();

                if (try dvui.menuItemLabel(@src(), "Dialog", .{}, .{ .expand = .horizontal }) != null) {
                    fw.close();
                }

                if (try dvui.menuItemLabel(@src(), "Close Menu", .{}, .{ .expand = .horizontal }) != null) {
                    fw.close();
                }
            }

            if (try dvui.menuItemLabel(@src(), "Edit", .{ .submenu = true }, .{ .expand = .horizontal })) |r| {
                var fw = try dvui.floatingMenu(@src(), .{ .from = r }, .{});
                defer fw.deinit();
                _ = try dvui.menuItemLabel(@src(), "Dummy", .{}, .{ .expand = .horizontal });
                _ = try dvui.menuItemLabel(@src(), "Dummy Long", .{}, .{ .expand = .horizontal });
                _ = try dvui.menuItemLabel(@src(), "Dummy Super Long", .{}, .{ .expand = .horizontal });
            }
        }

        var second_paned = try dvui.paned(@src(), .{ .direction = .vertical, .collapsed_size = 150 }, .{ .expand = .both, .background = false, .min_size_content = .{ .h = 100, .w = 100 } });
        defer second_paned.deinit();

        if (second_paned.showFirst()) {
            const hbox = try dvui.box(@src(), .horizontal, .{ .expand = .both, .background = true });
            defer hbox.deinit();

            const vbox2 = try dvui.box(@src(), .vertical, .{ .expand = .both, .background = true, .gravity_y = 0.5 });
            defer vbox2.deinit();

            const label = if (dvui.Examples.show_demo_window) "Hide Demo Window" else "Show Demo Window";
            if (try dvui.button(@src(), label, .{}, .{ .tag = "show-demo-btn", .gravity_y = 0.5 })) {
                dvui.Examples.show_demo_window = !dvui.Examples.show_demo_window;
            }

            //if (try dvui.button(@src(), "Panic", .{}, .{})) {
            //std.debug.panic("This is a panic message after {d}s", .{@divTrunc(dvui.currentWindow().frame_time_ns, std.time.ns_per_s)});
            //}
            if (dvui.backend.kind != .web) {
                if (try dvui.button(@src(), "Close", .{}, .{})) {
                    return .close;
                }
            }
        }

        if (second_paned.showSecond()) {
            // const menu = try dvui.menu(@src(), .horizontal, .{ .expand = .horizontal, .background = false });
            // defer menu.deinit();

            // if (try dvui.menuItemLabel(@src(), "File", .{ .submenu = true }, .{ .expand = .none, .background = false })) |rect| {
            //     _ = rect; // autofix
            // }

            const vbox2 = try dvui.box(@src(), .vertical, .{ .expand = .both, .background = true });
            defer vbox2.deinit();
        }
    }

    // var tl2 = try dvui.textLayout(@src(), .{}, .{ .expand = .horizontal });
    // try tl2.addText(
    //     \\DVUI
    //     \\- paints the entire window
    //     \\- can show floating windows and dialogs
    //     \\- rest of the window is a scroll area
    // , .{});
    // try tl2.addText("\n\n", .{});
    // try tl2.addText("Framerate is variable and adjusts as needed for input events and animations.", .{});
    // try tl2.addText("\n\n", .{});
    // try tl2.addText("Framerate is capped by vsync.", .{});
    // try tl2.addText("\n\n", .{});
    // try tl2.addText("Cursor is always being set by dvui.", .{});
    // try tl2.addText("\n\n", .{});
    // if (dvui.useFreeType) {
    //     try tl2.addText("Fonts are being rendered by FreeType 2.", .{});
    // } else {
    //     try tl2.addText("Fonts are being rendered by stb_truetype.", .{});
    // }
    // tl2.deinit();

    // look at demo() for examples of dvui widgets, shows in a floating window
    try dvui.Examples.demo();

    return .ok;
}

// pub fn init(
//     app: *App,
//     core: *Core,
//     editor: *Editor,
//     packer: *Packer,
//     assets: *Assets,
//     app_mod: mach.Mod(App),
// ) !void {
//     // Store our global pointers so we can access them from non-mach functions for now
//     pixi.app = app;
//     pixi.core = core;
//     pixi.editor = editor;
//     pixi.packer = packer;
//     pixi.assets = assets;

//     pixi.core.on_tick = app_mod.id.tick;
//     pixi.core.on_exit = app_mod.id.deinit;

//     const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

//     // Run from the directory where the executable is located so relative assets can be found.
//     var buffer: [1024]u8 = undefined;
//     const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
//     std.posix.chdir(path) catch {};

//     // Here we have access to all the initial fields of the window
//     const window = try pixi.core.windows.new(.{
//         .title = "Pixi",
//         //.on_tick = if (builtin.os.tag == .macos) app_mod.id.render else null,
//         .power_preference = .low_power,
//     });

//     app.* = .{
//         .allocator = allocator,
//         .timer = try mach.time.Timer.start(),
//         .window = window,
//         .root_path = try allocator.dupeZ(u8, path),
//     };
// }

// /// This is called from the event fired when the window is done being
// /// initialized by the platform
// pub fn setup(
//     app: *App,
//     core: *Core,
//     assets: *Assets,
//     editor_mod: mach.Mod(Editor),
// ) !void {
//     const window = pixi.core.windows.getValue(app.window);

//     // Now that we have a valid device, we can initialize our pipelines
//     try pixi.gfx.init(app);

//     // Load our atlas and texture
//     if (try assets.loadTexture(pixi.paths.@"pixi.png", .{})) |texture_id| {
//         app.texture_id = texture_id;
//         // Add our auto_reload tag for automatic asset reload
//         try assets.textures.setTag(texture_id, Assets, .auto_reload, null);
//     }
//     if (try assets.loadAtlas(pixi.paths.@"pixi.atlas")) |atlas_id| {
//         app.atlas_id = atlas_id;
//         // Add our auto_reload tag for automatic asset reload
//         try assets.atlases.setTag(atlas_id, Assets, .auto_reload, null);
//     }

//     // This will spawn a thread for watching our asset paths for changes,
//     // and reloading individual assets if they change on disk
//     try assets.watch();

//     // Setup batcher
//     app.batcher = try pixi.gfx.Batcher.init(app.allocator, 1000);

//     // Store information about the window in float format
//     app.window_size = .{ @floatFromInt(window.width), @floatFromInt(window.height) };
//     app.framebuffer_size = .{ @floatFromInt(window.framebuffer_width), @floatFromInt(window.framebuffer_height) };
//     app.content_scale = .{
//         app.framebuffer_size[0] / app.window_size[0],
//         app.framebuffer_size[1] / app.window_size[1],
//     };

//     // Setup imgui
//     imgui.setZigAllocator(&app.allocator);
//     _ = imgui.createContext(null);
//     try imgui_mach.init(core, app.allocator, window.device, .{
//         .mag_filter = .nearest,
//         .min_filter = .nearest,
//         .mipmap_filter = .nearest,
//         .color_format = window.framebuffer_format,
//     });

//     // Setup fonts
//     var io = imgui.getIO();
//     io.config_flags |= imgui.ConfigFlags_NavEnableKeyboard;
//     io.display_framebuffer_scale = .{ .x = app.content_scale[0], .y = app.content_scale[1] };
//     io.font_global_scale = 1.0;

//     var cozette_config: imgui.FontConfig = std.mem.zeroes(imgui.FontConfig);
//     cozette_config.font_data_owned_by_atlas = true;
//     cozette_config.oversample_h = 2;
//     cozette_config.oversample_v = 1;
//     cozette_config.glyph_max_advance_x = std.math.floatMax(f32);
//     cozette_config.rasterizer_multiply = 1.0;
//     cozette_config.rasterizer_density = 1.0;
//     cozette_config.ellipsis_char = imgui.UNICODE_CODEPOINT_MAX;

//     _ = io.fonts.?.addFontFromFileTTF(pixi.paths.@"CozetteVector.ttf", pixi.editor.settings.font_size, &cozette_config, null);

//     var fa_config: imgui.FontConfig = std.mem.zeroes(imgui.FontConfig);
//     fa_config.merge_mode = true;
//     fa_config.font_data_owned_by_atlas = true;
//     fa_config.oversample_h = 2;
//     fa_config.oversample_v = 1;
//     fa_config.glyph_max_advance_x = std.math.floatMax(f32);
//     fa_config.rasterizer_multiply = 1.0;
//     fa_config.rasterizer_density = 1.0;
//     fa_config.ellipsis_char = imgui.UNICODE_CODEPOINT_MAX;
//     const ranges: []const u16 = &.{ 0xf000, 0xf976, 0 };

//     _ = io.fonts.?.addFontFromFileTTF(pixi.paths.@"fa-solid-900.ttf", pixi.editor.settings.font_size, &fa_config, @ptrCast(ranges.ptr)).?;
//     _ = io.fonts.?.addFontFromFileTTF(pixi.paths.@"fa-regular-400.ttf", pixi.editor.settings.font_size, &fa_config, @ptrCast(ranges.ptr)).?;

//     // This will load our theme
//     editor_mod.call(.loadTheme);
// }

// pub var updated_editor: bool = false;
// pub var update_render_time: f32 = 0.0;

// pub fn render(core: *Core, app: *App, editor: *Editor, editor_mod: mach.Mod(Editor)) !void {
//     if (!(update_render_time < editor.settings.editor_animation_time or editor.anyAnimationPlaying()))
//         return;

//     // Update times
//     app.delta_time = app.timer.lap();
//     app.total_time += app.delta_time;

//     // New imgui frame
//     try imgui_mach.newFrame();
//     imgui.newFrame();

//     // Process editor tick
//     editor_mod.call(.tick);
//     updated_editor = true;

//     // Render imgui
//     imgui.render();

//     const label = @tagName(mach_module) ++ ".render";
//     var window = core.windows.getValue(app.window);

//     blk_render: {
//         const back_buffer_view = window.swap_chain.getCurrentTextureView() orelse break :blk_render;

//         // Pass commands to the window queue for presenting

//         defer back_buffer_view.release();

//         const draw_data = imgui.getDrawData() orelse break :blk_render;

//         const imgui_commands = commands: {
//             const encoder = window.device.createCommandEncoder(&.{ .label = label });
//             defer encoder.release();

//             const background: gpu.Color = .{
//                 .r = @floatCast(editor.theme.foreground.value[0]),
//                 .g = @floatCast(editor.theme.foreground.value[1]),
//                 .b = @floatCast(editor.theme.foreground.value[2]),
//                 .a = 1.0,
//             };

//             // Gui pass.
//             {
//                 const color_attachment = gpu.RenderPassColorAttachment{
//                     .view = back_buffer_view,
//                     .clear_value = background,
//                     .load_op = .clear,
//                     .store_op = .store,
//                 };

//                 const render_pass_info = gpu.RenderPassDescriptor.init(.{
//                     .color_attachments = &.{color_attachment},
//                 });
//                 const pass = encoder.beginRenderPass(&render_pass_info);

//                 imgui_mach.renderDrawData(draw_data, pass) catch {};
//                 pass.end();
//                 pass.release();
//             }

//             break :commands encoder.finish(&.{ .label = label });
//         };
//         defer imgui_commands.release();

//         if (app.batcher.empty) {
//             window.queue.submit(&.{imgui_commands});
//         } else {
//             const batcher_commands = try app.batcher.finish();
//             defer batcher_commands.release();
//             window.queue.submit(&.{ batcher_commands, imgui_commands });
//         }

//         mach.sysgpu.Impl.deviceTick(window.device);

//         window.swap_chain.present();
//     }
// }

// /// This is a mach-called function, and the parameters are automatically injected.
// pub fn tick(core: *Core, app: *App, editor: *Editor, app_mod: mach.Mod(App), editor_mod: mach.Mod(Editor)) !void {

//     // Process dialog requests
//     editor_mod.call(.processDialogRequest);
//     // Process events
//     while (core.nextEvent()) |event| {
//         switch (event) {
//             .window_open => app_mod.call(.setup),

//             .key_press => |key_press| {
//                 editor.hotkeys.setHotkeyState(key_press.key, key_press.mods, .press);
//                 try pixi.input.process();
//             },
//             .key_repeat => |key_repeat| {
//                 editor.hotkeys.setHotkeyState(key_repeat.key, key_repeat.mods, .repeat);
//                 try pixi.input.process();
//             },
//             .key_release => |key_release| {
//                 editor.hotkeys.setHotkeyState(key_release.key, key_release.mods, .release);
//                 try pixi.input.process();
//             },
//             .mouse_scroll => |mouse_scroll| {
//                 // TODO: Fix this in the editor code, we dont want to block mouse input based on popups
//                 if (!editor.popups.anyPopupOpen()) { // Only record mouse scrolling for canvases when popups are closed
//                     editor.mouse.scroll_x = mouse_scroll.xoffset;
//                     editor.mouse.scroll_y = mouse_scroll.yoffset;
//                 }
//             },
//             .zoom_gesture => |gesture| editor.mouse.magnify = gesture.zoom,
//             .mouse_motion => |mouse_motion| {
//                 editor.mouse.position = .{ @floatCast(mouse_motion.pos.x), @floatCast(mouse_motion.pos.y) };
//             },
//             .mouse_press => |mouse_press| editor.mouse.setButtonState(mouse_press.button, mouse_press.mods, .press),
//             .mouse_release => |mouse_release| editor.mouse.setButtonState(mouse_release.button, mouse_release.mods, .release),
//             .close => {
//                 // Currently, just pass along this message to the editor
//                 // and allow the editor to set the app.should_close or not
//                 editor_mod.call(.close);
//             },
//             .window_resize => |resize| {
//                 const window = core.windows.getValue(app.window);
//                 app.window_size = .{ @floatFromInt(resize.size.width), @floatFromInt(resize.size.height) };
//                 app.framebuffer_size = .{ @floatFromInt(window.framebuffer_width), @floatFromInt(window.framebuffer_height) };
//                 app.content_scale = .{
//                     app.framebuffer_size[0] / app.window_size[0],
//                     app.framebuffer_size[1] / app.window_size[1],
//                 };
//             },
//             else => {},
//         }

//         if (!app.should_close) {
//             if (imgui.getCurrentContext() != null) {
//                 _ = imgui_mach.processEvent(event);
//             }
//         }
//         update_render_time = 0.0;
//     }

//     // if (core.windows.get(app.window, .on_tick) == null) {
//     app_mod.call(.render);
//     // }

//     // Only update cursor and push previous input states if we recently updated the editor
//     // These are things that must be run on the main thread but are affected by the timing of
//     // the render thread.
//     if (updated_editor) {
//         update_render_time += app.delta_time;

//         updated_editor = false;
//         imgui_mach.updateCursor();

//         core.windows.set(app.window, .decoration_color, .{
//             .r = editor.theme.foreground.value[0],
//             .g = editor.theme.foreground.value[1],
//             .b = editor.theme.foreground.value[2],
//             .a = editor.theme.foreground.value[3],
//         });
//     }
//     core.frame.target = 1000;
//     std.Thread.sleep(core.frame.delay_ns);

//     // Finally, close if we should and aren't in the middle of saving
//     if (app.should_close and !editor.saving()) {
//         core.exit();
//     }
// }

// /// This is a mach-called function, and the parameters are automatically injected.
// pub fn deinit(app: *App, packer_mod: mach.Mod(Packer), editor_mod: mach.Mod(Editor), assets_mod: mach.Mod(Assets)) !void {
//     editor_mod.call(.deinit);

//     app.batcher.deinit();
//     app.pipeline_default.release();
//     app.pipeline_compute.release();
//     app.uniform_buffer_default.release();

//     imgui_mach.shutdown();
//     imgui.getIO().fonts.?.clear();
//     imgui.destroyContext(null);

//     assets_mod.call(.deinit);
//     packer_mod.call(.deinit);

//     app.allocator.free(app.root_path);

//     _ = gpa.detectLeaks();
//     _ = gpa.deinit();
// }
