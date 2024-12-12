const std = @import("std");

const mach = @import("mach");
const Core = mach.Core;
const gpu = mach.gpu;

const zstbi = @import("zstbi");
const zm = @import("zmath");
const nfd = @import("nfd");

const imgui = @import("zig-imgui");
const imgui_mach = imgui.backends.mach;

pub const App = @This();

pub const mach_module = .app;

pub const mach_systems = .{ .main, .init, .tick, .deinit };

pub const main = mach.schedule(.{
    .{ Core, .init },
    .{ App, .init },
    .{ Core, .main },
});

timer: mach.time.Timer,
window: mach.ObjectID,

//pub const name: [:0]const u8 = "Pixi";
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
    device: *gpu.Device = undefined,
    queue: *gpu.Queue = undefined,
    swap_chain: *gpu.SwapChain = undefined,
    settings: Settings = undefined,
    hotkeys: input.Hotkeys = undefined,
    mouse: input.Mouse = undefined,
    sidebar: Sidebar = .files,
    theme: editor.Theme = undefined,
    project_folder: ?[:0]const u8 = null,
    root_path: [:0]const u8 = undefined,
    recents: Recents = undefined,
    previous_atlas_export: ?[:0]const u8 = null,
    open_files: std.ArrayList(storage.Internal.PixiFile) = undefined,
    open_references: std.ArrayList(storage.Internal.Reference) = undefined,
    pack_target: PackTarget = .project,
    pack_camera: gfx.Camera = .{},
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
    json_allocator: std.heap.ArenaAllocator = undefined,
    assets: Assets = undefined,
    clipboard_image: ?zstbi.Image = null,
    clipboard_position: [2]u32 = .{ 0, 0 },
    batcher: gfx.Batcher = undefined,
    pipeline_default: *gpu.RenderPipeline = undefined,
    pipeline_compute: *gpu.ComputePipeline = undefined,
    uniform_buffer_default: *gpu.Buffer = undefined,
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
    sprites,
    animations,
    keyframe_animations,
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

pub fn init(app: *App, core: *Core, app_mod: mach.Mod(App)) !void {
    core.on_tick = app_mod.id.tick;
    core.on_exit = app_mod.id.deinit;

    const allocator = gpa.allocator();

    var buffer: [1024]u8 = undefined;
    const root_path = std.fs.selfExeDirPath(buffer[0..]) catch ".";

    state = try allocator.create(PixiState);
    state.* = .{ .root_path = try allocator.dupeZ(u8, root_path) };

    state.allocator = allocator;

    const window = try core.windows.new(.{
        .title = "Pixi",
        .vsync_mode = .double,
    });

    app.* = .{
        .timer = try mach.time.Timer.start(),
        .window = window,
    };

    //core.setSizeLimit(.{ .min = .{ .width = @divTrunc(state.settings.initial_window_width, 2), .height = @divTrunc(state.settings.initial_window_height, 2) }, .max = .{ .width = null, .height = null } });
}

fn lateInit(pixi: *App, core: *Core) !void {
    const window = core.windows.getValue(pixi.window);
    //defer core.windows.setValue(app.window, window);

    state.device = window.device;
    state.queue = window.queue;
    state.swap_chain = window.swap_chain;

    state.json_allocator = std.heap.ArenaAllocator.init(state.allocator);
    state.settings = try Settings.init(state.json_allocator.allocator());

    const theme_path = try std.fs.path.joinZ(state.allocator, &.{ assets.themes, state.settings.theme });
    defer state.allocator.free(theme_path);

    state.theme = try editor.Theme.loadFromFile(theme_path);

    window_size = .{ @floatFromInt(window.width), @floatFromInt(window.height) };
    framebuffer_size = .{ @floatFromInt(window.framebuffer_width), @floatFromInt(window.framebuffer_height) };
    content_scale = .{
        framebuffer_size[0] / window_size[0],
        framebuffer_size[1] / window_size[1],
    };
    content_scale = .{ 1.0, 1.0 };

    const scale_factor = content_scale[1];

    zstbi.init(core.allocator);

    state.open_files = std.ArrayList(storage.Internal.PixiFile).init(state.allocator);
    state.open_references = std.ArrayList(storage.Internal.Reference).init(state.allocator);

    state.colors.keyframe_palette = try storage.Internal.Palette.loadFromFile(assets.pear36_hex.path);

    state.hotkeys = try input.Hotkeys.initDefault(state.allocator);

    state.assets = try Assets.init(state.allocator);
    state.mouse = try input.Mouse.initDefault(state.allocator);

    state.packer = try Packer.init(state.allocator);
    state.recents = try Recents.init(state.allocator);

    state.batcher = try gfx.Batcher.init(state.allocator, 1000);

    try gfx.init(state);

    imgui.setZigAllocator(&state.allocator);

    _ = imgui.createContext(null);
    try imgui_mach.init(core, state.allocator, window.device, .{
        .mag_filter = .nearest,
        .min_filter = .nearest,
        .mipmap_filter = .nearest,
        .color_format = window.framebuffer_format,
    });

    var io = imgui.getIO();
    io.config_flags |= imgui.ConfigFlags_NavEnableKeyboard;
    io.display_framebuffer_scale = .{ .x = content_scale[0], .y = content_scale[1] };
    io.font_global_scale = 1.0;
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

    state.theme.init(core, pixi);
}

pub fn tick(app: *App, core: *Core) !void {
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

    while (core.nextEvent()) |event| {
        switch (event) {
            .window_open => {
                try lateInit(app, core);
            },
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
            .magnify => |magnify| {
                state.mouse.magnify = magnify.magnification;
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
            .window_resize => |resize| {
                const window = core.windows.getValue(app.window);
                window_size = .{ @floatFromInt(resize.size.width), @floatFromInt(resize.size.height) };
                framebuffer_size = .{ @floatFromInt(window.framebuffer_width), @floatFromInt(window.framebuffer_height) };
                content_scale = .{
                    framebuffer_size[0] / window_size[0],
                    framebuffer_size[1] / window_size[1],
                };
                content_scale = .{ 1.0, 1.0 };
            },

            else => {},
        }

        if (!state.should_close)
            _ = imgui_mach.processEvent(event);
    }
    var window = core.windows.getValue(app.window);
    state.swap_chain = window.swap_chain;

    try imgui_mach.newFrame();
    imgui.newFrame();
    state.delta_time = app.timer.lap();
    state.total_time += state.delta_time;

    try input.process();

    state.theme.push(core, app);

    //imgui.showDemoWindow(null);

    editor.draw(core);

    state.theme.pop();

    imgui.render();

    // TODO: Fix title when mach supports it
    // if (editor.getFile(state.open_file_index)) |file| {
    //     @memset(core.title[0..], 0);
    //     @memcpy(core.title[0 .. name.len + 3], name ++ " - ");
    //     const base_name = std.fs.path.basename(file.path);
    //     @memcpy(core.title[name.len + 3 .. base_name.len + name.len + 3], base_name);
    //     core.setTitle(&core.title);
    // } else {
    //     @memset(core.title[0..], 0);
    //     @memcpy(core.title[0..name.len], name);
    //     core.setTitle(&core.title);
    // }
    if (window.swap_chain.getCurrentTextureView()) |back_buffer_view| {
        defer back_buffer_view.release();

        const imgui_commands = commands: {
            const encoder = window.device.createCommandEncoder(null);
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

        if (state.batcher.empty) {
            window.queue.submit(&.{imgui_commands});
        } else {
            const batcher_commands = try state.batcher.finish();
            defer batcher_commands.release();
            window.queue.submit(&.{ batcher_commands, imgui_commands });
        }
    }

    // Accept transformations
    {
        for (state.open_files.items) |*file| {
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
                                state.device.tick();
                            }
                        }

                        const layer_index = file.selected_layer_index;
                        const write_layer = &file.layers.items[file.selected_layer_index];

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

                        write_layer.texture.update(state.device);
                    }

                    transform_texture.texture.deinit();
                    file.transform_texture = null;
                }
            }
        }
    }

    for (state.hotkeys.hotkeys) |*hotkey| {
        hotkey.previous_state = hotkey.state;
    }

    for (state.mouse.buttons) |*button| {
        button.previous_state = button.state;
    }

    state.mouse.previous_position = state.mouse.position;

    if (state.should_close and !editor.saving()) {
        // Close!
        core.exit();
    }
}

pub fn deinit(_: *App, _: *Core) void {
    //deinit and save settings
    state.settings.deinit(state.json_allocator.allocator());

    //free everything allocated by the json_allocator
    state.json_allocator.deinit();

    state.allocator.free(state.theme.name);

    state.allocator.free(state.hotkeys.hotkeys);
    state.allocator.free(state.mouse.buttons);
    state.packer.deinit();
    state.recents.deinit();

    state.batcher.deinit();
    state.pipeline_default.release();
    state.uniform_buffer_default.release();

    state.pipeline_compute.release();

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
    if (state.colors.keyframe_palette) |*keyframe_palette| keyframe_palette.deinit();

    if (state.clipboard_image) |*image| image.deinit();

    editor.deinit();
    state.assets.deinit(state.allocator);

    imgui_mach.shutdown();
    imgui.getIO().fonts.?.clear();
    imgui.destroyContext(null);

    zstbi.deinit();
    state.allocator.free(state.root_path);
    state.allocator.destroy(state);

    //uncomment this line to check for memory leaks on program shutdown
    _ = gpa.detectLeaks();
    _ = gpa.deinit();
}
