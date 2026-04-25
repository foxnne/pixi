const std = @import("std");
const builtin = @import("builtin");
const icons = @import("icons");
const assets = @import("assets");
const known_folders = @import("known-folders");
const objc = @import("objc");
const sdl3 = @import("backend").c;

const cozette_ttf = assets.files.fonts.@"CozetteVector.ttf";
const cozette_bold_ttf = assets.files.fonts.@"CozetteVectorBold.ttf";

const comfortaa_ttf = assets.files.fonts.@"Comfortaa-Regular.ttf";
const comfortaa_bold_ttf = assets.files.fonts.@"Comfortaa-Bold.ttf";

const noto_sans_ttf = assets.files.fonts.@"NotoSans-Light.ttf";
const noto_sans_bold_ttf = assets.files.fonts.@"NotoSans-Bold.ttf";

const pixi = @import("../pixi.zig");
const dvui = @import("dvui");

const App = pixi.App;
const Editor = @This();

pub const Colors = @import("Colors.zig");
pub const Project = @import("Project.zig");
pub const Recents = @import("Recents.zig");
pub const Settings = @import("Settings.zig");
pub const Tools = @import("Tools.zig");
pub const Dialogs = @import("dialogs/Dialogs.zig");

pub const Transform = @import("Transform.zig");
pub const Keybinds = @import("Keybinds.zig");

pub const Workspace = @import("Workspace.zig");
pub const Explorer = @import("explorer/Explorer.zig");
pub const Panel = @import("panel/Panel.zig");
pub const Sidebar = @import("Sidebar.zig");
pub const Infobar = @import("Infobar.zig");
pub const Menu = @import("Menu.zig");

/// This arena is for small per-frame editor allocations, such as path joins, null terminations and labels.
/// Do not free these allocations, instead, this allocator will be .reset(.retain_capacity) each frame
arena: std.heap.ArenaAllocator,

config_folder: []const u8,
palette_folder: []const u8,

atlas: pixi.Internal.Atlas,

settings: Settings = undefined,
recents: Recents = undefined,

explorer: *Explorer,
panel: *Panel,

last_titlebar_color: dvui.Color,
dim_titlebar: bool = false,

/// Workspaces stored by their grouping ID
workspaces: std.AutoArrayHashMap(u64, Workspace) = undefined,
sidebar: Sidebar,
infobar: Infobar,

/// The root folder that will be searched for files and a .pixiproject file
folder: ?[]const u8 = null,
project: ?Project = null,

themes: std.array_list.Managed(dvui.Theme) = undefined,

open_files: std.AutoArrayHashMap(u64, pixi.Internal.File) = undefined,

// The actively focused workspace grouping ID
// This will contain tabs for all open files with a matching grouping ID
open_workspace_grouping: u64 = 0,

tools: Tools,
colors: Colors = .{},

grouping_id_counter: u64 = 0,
file_id_counter: u64 = 0,

sprite_clipboard: ?SpriteClipboard = null,

window_opacity: f32 = 1.0,

pending_native_menu_actions: [16]pixi.backend.NativeMenuAction = undefined,
pending_native_menu_actions_len: u8 = 0,

/// When set, next `tick` runs `warmupDrawingComposites` on the active file (after open or drawing-tool select).
pending_composite_warmup: bool = false,

/// Filled from the async SDL save dialog callback, then applied inside `tick` (when `currentWindow` is valid).
pending_save_as_path: ?[]u8 = null,

pub const SpriteClipboard = struct {
    source: dvui.ImageSource,
    offset: dvui.Point,
};

const embedded_fonts: []const dvui.Font.Source = &.{
    .{
        .family = dvui.Font.array("CozetteVector"),
        .bytes = cozette_ttf,
    },
    .{
        .family = dvui.Font.array("CozetteVector"),
        .bytes = cozette_bold_ttf,
        .weight = .bold,
    },

    .{
        .family = dvui.Font.array("Comfortaa"),
        .bytes = comfortaa_ttf,
    },
    .{
        .family = dvui.Font.array("Comfortaa"),
        .bytes = comfortaa_bold_ttf,
        .weight = .bold,
    },

    .{
        .family = dvui.Font.array("NotoSans"),
        .bytes = noto_sans_ttf,
    },
    .{
        .family = dvui.Font.array("NotoSans"),
        .bytes = noto_sans_bold_ttf,
        .weight = .bold,
    },
};

pub fn init(
    app: *App,
) !Editor {
    const config_folder = std.fs.path.join(pixi.app.allocator, &.{
        try known_folders.getPath(dvui.currentWindow().arena(), .local_configuration) orelse app.root_path,
        "Pixi",
    }) catch app.root_path;
    const palette_folder = std.fs.path.join(pixi.app.allocator, &.{ config_folder, "Palettes" }) catch config_folder;

    var pixi_dark = dvui.themeGet();
    pixi_dark.embedded_fonts = embedded_fonts;

    pixi_dark.window = .{
        .fill = .{ .r = 28, .g = 29, .b = 36, .a = 255 },
        .border = .{ .r = 34, .g = 35, .b = 42, .a = 255 },
        .text = .{ .r = 206, .g = 163, .b = 127, .a = 255 },
    };

    pixi_dark.control = .{
        .fill = .{ .r = 28, .g = 29, .b = 36, .a = 255 },
        .border = .{ .r = 34, .g = 35, .b = 42, .a = 255 },
        .text = .{ .r = 134, .g = 138, .b = 148, .a = 255 },
    };

    pixi_dark.highlight = .{
        .fill = .{ .r = 47, .g = 179, .b = 135, .a = 255 },
        .border = .{ .r = 47, .g = 179, .b = 135, .a = 255 },
        .text = pixi_dark.window.fill,
    };

    pixi_dark.err = .{
        .fill = .{ .r = 109, .g = 35, .b = 54, .a = 255 },
    };

    // theme.content
    pixi_dark.fill = .{ .r = 42, .g = 44, .b = 54, .a = 255 };
    pixi_dark.text = pixi_dark.window.text.?;
    pixi_dark.focus = pixi_dark.highlight.fill.?;

    pixi_dark.dark = true;
    pixi_dark.name = "Pixi Dark";
    pixi_dark.font_body = .find(.{ .family = "Comfortaa", .size = 8, .weight = .bold });
    pixi_dark.font_title = .find(.{ .family = "NotoSans", .size = 10, .weight = .bold });
    pixi_dark.font_heading = .find(.{ .family = "NotoSans", .size = 8, .weight = .bold });
    pixi_dark.font_mono = .find(.{ .family = "CozetteVector", .size = 10 });

    dvui.themeSet(pixi_dark);

    var moi: dvui.Theme = pixi_dark;
    moi.name = "Moi";
    moi.window = .{
        .fill = .{ .r = 84, .g = 12, .b = 26, .a = 255 },
        .border = .{ .r = 104, .g = 62, .b = 72, .a = 255 },
        .text = .{ .r = 255, .g = 190, .b = 190, .a = 240 },
    };

    moi.control = .{
        .fill = moi.window.fill.?.lighten(10),
        .border = .{ .r = 104, .g = 62, .b = 72, .a = 255 },
        .text = .{ .r = 255, .g = 235, .b = 235, .a = 200 },
    };
    moi.highlight = .{
        .fill = moi.window.fill.?.lighten(10),
    };

    moi.fill = moi.control.fill.?;
    moi.text = moi.window.text.?;
    moi.focus = moi.highlight.fill.?;

    var pixi_light = pixi_dark;
    pixi_light.dark = false;
    pixi_light.name = "Pixi Light";

    pixi_light.window = .{
        .fill = .{ .r = 240, .g = 240, .b = 245, .a = 255 },
        .border = dvui.Theme.builtin.adwaita_light.window.border,
        .text = .{ .r = 120, .g = 70, .b = 65, .a = 255 },
    };

    pixi_light.control = dvui.Theme.builtin.adwaita_light.control;

    pixi_light.highlight = .{
        .fill = .{ .r = 170, .g = 130, .b = 140, .a = 255 },
        .text = pixi_light.window.fill,
    };

    pixi_light.err = .{
        .fill = .{ .r = 109, .g = 35, .b = 54, .a = 255 },
    };

    // theme.content
    pixi_light.fill = .{ .r = 200, .g = 200, .b = 205, .a = 255 };
    pixi_light.text = .{ .r = 40, .g = 40, .b = 45, .a = 255 };
    pixi_light.focus = pixi_light.highlight.fill.?;

    var editor: Editor = .{
        .config_folder = config_folder,
        .palette_folder = palette_folder,
        .explorer = try app.allocator.create(Explorer),
        .panel = try app.allocator.create(Panel),
        .sidebar = try .init(),
        .infobar = try .init(),
        .arena = .init(std.heap.page_allocator),
        .last_titlebar_color = dvui.themeGet().color(.control, .fill),
        .atlas = .{
            .data = try .loadFromBytes(app.allocator, assets.files.@"pixi.atlas"),
            .source = try pixi.image.fromImageFileBytes("pixi.png", assets.files.@"pixi.png", .ptr),
        },
        .tools = try .init(app.allocator),
        .themes = .init(app.allocator),
    };

    editor.themes.append(pixi_dark) catch {
        dvui.log.err("Failed to append theme", .{});
        return error.FailedToAppendTheme;
    };

    editor.themes.append(moi) catch {
        dvui.log.err("Failed to append moi theme", .{});
        return error.FailedToAppendMoiTheme;
    };

    editor.themes.append(pixi_light) catch {
        dvui.log.err("Failed to append pixi light theme", .{});
        return error.FailedToAppendPixiLightTheme;
    };

    for (dvui.Theme.builtins) |b| {
        editor.themes.append(b) catch {
            dvui.log.err("Failed to append builtin theme", .{});
            return error.FailedToAppendBuiltinTheme;
        };
    }

    var valid_path: bool = true;
    if (std.fs.path.isAbsolute(editor.config_folder)) {
        std.fs.accessAbsolute(editor.config_folder, .{ .mode = .read_only }) catch {
            valid_path = false;
        };

        if (!valid_path) {
            std.fs.makeDirAbsolute(editor.config_folder) catch |err| dvui.log.err("Failed to create config folder: {s}: {any}", .{ editor.config_folder, err });
        }
    }

    valid_path = true;
    if (std.fs.path.isAbsolute(editor.palette_folder)) {
        std.fs.accessAbsolute(editor.palette_folder, .{ .mode = .read_only }) catch {
            valid_path = false;
        };

        if (!valid_path) {
            std.fs.makeDirAbsolute(editor.palette_folder) catch |err| dvui.log.err("Failed to create palette folder: {s}: {any}", .{ editor.palette_folder, err });
        }
    }

    editor.settings = Settings.load(app.allocator, try std.fs.path.join(app.allocator, &.{ editor.config_folder, "settings.json" })) catch .{
        .theme = try app.allocator.dupe(u8, "pixi_dark.json"),
    };
    pixi.perf.console_logging_enabled = editor.settings.perf_logging;
    editor.recents = Recents.load(app.allocator, try std.fs.path.join(app.allocator, &.{ editor.config_folder, "recents.json" })) catch .{
        .folders = .init(app.allocator),
    };

    pixi.backend.setTitlebarColor(dvui.currentWindow(), pixi_dark.fill.opacity(if (dvui.themeGet().dark) editor.settings.window_opacity_dark else editor.settings.window_opacity_light));

    editor.explorer.* = .init();
    editor.panel.* = .init();
    editor.open_files = .init(pixi.app.allocator);
    editor.workspaces = .init(pixi.app.allocator);
    editor.workspaces.put(0, .init(0)) catch |err| {
        std.log.err("Failed to create workspace: {s}", .{@errorName(err)});
        return err;
    };

    editor.colors.file_tree_palette = pixi.Internal.Palette.loadFromBytes(app.allocator, "pixi.hex", assets.files.palettes.@"pixi.hex") catch null;
    editor.colors.palette = pixi.Internal.Palette.loadFromBytes(app.allocator, "pixi.hex", assets.files.palettes.@"pixi.hex") catch null;

    try Keybinds.register();

    return editor;
}

pub fn currentGroupingID(editor: *Editor) u64 {
    return editor.open_workspace_grouping;
}

pub fn newGroupingID(editor: *Editor) u64 {
    editor.grouping_id_counter += 1;
    return editor.grouping_id_counter;
}

pub fn newFileID(editor: *Editor) u64 {
    editor.file_id_counter += 1;
    return editor.file_id_counter;
}

const handle_size = 10;
const handle_dist = 60;

pub fn tick(editor: *Editor) !dvui.App.Result {
    editor.window_opacity = if (dvui.themeGet().dark) editor.settings.window_opacity_dark else editor.settings.window_opacity_light;

    if (pixi.backend.pollPendingNativeMenuAction()) |action| {
        editor.queueNativeMenuAction(action);
    }

    defer editor.dim_titlebar = false;
    editor.setTitlebarColor();
    editor.setWindowStyle();

    editor.rebuildWorkspaces() catch {
        dvui.log.err("Failed to rebuild workspaces", .{});
    };

    pixi.render.frame_index +%= 1;
    if (pixi.perf.record) pixi.perf.beginFrame();
    defer if (pixi.perf.record) pixi.perf.endFrameAndMaybeLog();

    if (editor.pending_composite_warmup) {
        editor.pending_composite_warmup = false;
        if (editor.activeFile()) |file| {
            const w = file.width();
            const h = file.height();
            if (w > 0 and h > 0) {
                const area = @as(u64, w) * @as(u64, h);
                // Skip tiny canvases; large docs benefit most from moving split-target work off the first stroke.
                if (area >= 512 * 512) {
                    pixi.render.warmupDrawingComposites(file) catch |err| {
                        dvui.log.err("Composite warmup failed: {any}", .{err});
                    };
                }
            }
        }
    }

    {
        var any_drawing = false;
        pixi.perf.draw_stroke_buf_count = 0; // no active stroke → 0; else first active file's map size
        for (editor.open_files.values()) |*file| {
            if (file.editor.active_drawing) {
                any_drawing = true;
                pixi.perf.draw_stroke_buf_count = file.buffers.stroke.pixels.count();
                break;
            }
        }
        pixi.perf.drawFrameBegin(any_drawing);
    }
    defer pixi.perf.drawFrameEnd();

    // TODO: Does this need to be here for touchscreen zooming? Or does that belong in canvas?
    // var scaler = dvui.scale(
    //     @src(),
    //     .{ .scale = &dvui.currentWindow().content_scale, .pinch_zoom = .global },
    //     .{ .expand = .both },
    // );
    // defer scaler.deinit();

    {

        // First, window color is set to the opaque color.
        var window_color = dvui.themeGet().color(.content, .fill);

        switch (builtin.os.tag) {
            .macos => {
                window_color = if (!pixi.backend.isMaximized(dvui.currentWindow())) window_color.opacity(editor.window_opacity).lighten((1.0 - editor.window_opacity) * 4.0) else window_color;
            },
            .windows => {
                window_color = if (!pixi.backend.isMaximized(dvui.currentWindow())) window_color.opacity(editor.window_opacity).lighten((1.0 - editor.window_opacity) * 4.0) else window_color;
            },
            else => {},
        }

        var overall_box = dvui.box(
            @src(),
            .{ .dir = .vertical },
            .{
                .expand = .both,
                .background = true,
                .color_fill = window_color,
            },
        );
        defer overall_box.deinit();

        // Non-macOS: a thin strip below the top edge so the in-window title row (menu, etc.) is not flush
        // against the window border (complements the system caption area on Windows 11).
        if (builtin.os.tag != .macos) {
            var top_inset = dvui.box(
                @src(),
                .{ .dir = .horizontal },
                .{
                    .expand = .horizontal,
                    .background = false,
                    .min_size_content = .{ .w = 1, .h = pixi.editor.settings.titlebar_top_buffer },
                    .max_size_content = .{ .w = std.math.floatMax(f32), .h = pixi.editor.settings.titlebar_top_buffer },
                },
            );
            defer top_inset.deinit();
        }

        // Title bar handling:
        //  - macOS (not maximized): render an empty horizontal strip so AppKit's traffic lights have visual
        //    breathing room at the top-left. AppKit handles dragging natively.
        //  - Windows: the main UI (sidebar, menu) starts below `titlebar_top_buffer`. A floating overlay
        //    at the top-right corner (y=0) hosts the min/max/close buttons; a drag rect is pushed across the top so
        //    empty space (gaps between widgets) drags the window. Menu items and sidebar buttons push
        //    themselves as interactive rects so clicks on them still reach DVUI.
        if (builtin.os.tag == .windows) {
            pixi.backend.resetTitleBarHints();

            const window_rect_natural = dvui.windowRect();
            const scale = dvui.windowNaturalScale();
            const title_strip_h = pixi.editor.settings.titlebar_top_buffer + pixi.editor.settings.titlebar_height;
            pixi.backend.pushTitleBarDragRect(.{
                .x = 0,
                .y = 0,
                .w = window_rect_natural.w * scale,
                .h = title_strip_h * scale,
            });
        } else if (builtin.os.tag == .macos and !pixi.backend.isMaximized(dvui.currentWindow())) {
            var titlebar_box = dvui.box(
                @src(),
                .{ .dir = .horizontal },
                .{
                    .expand = .horizontal,
                    .background = false,
                    .min_size_content = .{ .w = 1, .h = pixi.editor.settings.titlebar_height },
                    .max_size_content = .{ .w = std.math.floatMax(f32), .h = pixi.editor.settings.titlebar_height },
                },
            );
            defer titlebar_box.deinit();
        }

        // Windows-only top-right overlay: minimize / maximize / close. Lives in a FloatingWidget
        // (a subwindow) so it doesn't take any space in the vertical overall_box layout — the main
        // UI below fills the entire window. Caption-button rects are pushed to the backend so
        // WM_NCHITTEST returns HTMINBUTTON/HTMAXBUTTON/HTCLOSE for them (snap-layouts + click).
        if (builtin.os.tag == .windows) {
            const button_w: f32 = 46;
            const button_h = pixi.editor.settings.titlebar_height;
            const overlay_w: f32 = button_w * 3;
            const win_rect = dvui.windowRect();

            var fw: dvui.FloatingWidget = undefined;
            fw.init(@src(), .{ .mouse_events = true }, .{
                .rect = .{ .x = win_rect.w - overlay_w, .y = 0, .w = overlay_w, .h = button_h },
            });
            defer fw.deinit();

            var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .both });
            defer row.deinit();

            const hovered = pixi.backend.getHoveredTitleBarButton();
            const stroke = dvui.themeGet().color(.control, .text);
            const hover_fill = dvui.themeGet().color(.control, .fill_hover).lighten(if (dvui.themeGet().dark) 3 else -3);
            const close_hover_fill = dvui.Color{ .r = 232, .g = 17, .b = 35, .a = 255 };
            const close_hover_stroke = dvui.Color{ .r = 255, .g = 255, .b = 255, .a = 255 };

            // minimize
            {
                const is_hover = hovered == .minimize;
                var b = dvui.box(@src(), .{ .dir = .horizontal }, .{
                    .min_size_content = .{ .w = button_w, .h = button_h },
                    .expand = .vertical,
                    .background = is_hover,
                    .color_fill = hover_fill,
                });
                defer b.deinit();
                pixi.backend.setTitleBarCaptionButtonRect(.minimize, b.data().rectScale().r);
                dvui.icon(@src(), "win_min", icons.tvg.feather.minus, .{ .stroke_color = stroke }, .{
                    .expand = .ratio,
                    .padding = .all(7),
                    .margin = .all(0),
                    .gravity_x = 0.5,
                });
            }
            // maximize / restore
            {
                const is_hover = hovered == .maximize;
                var b = dvui.box(@src(), .{ .dir = .horizontal }, .{
                    .min_size_content = .{ .w = button_w, .h = button_h },
                    .expand = .vertical,
                    .background = is_hover,
                    .color_fill = hover_fill,
                });
                defer b.deinit();
                pixi.backend.setTitleBarCaptionButtonRect(.maximize, b.data().rectScale().r);
                dvui.icon(@src(), "win_max", icons.tvg.lucide.square, .{ .stroke_color = stroke }, .{
                    .expand = .ratio,
                    .padding = .all(9),
                    .margin = .all(0),
                    .gravity_x = 0.5,
                });
            }
            // close
            {
                const is_hover = hovered == .close;
                var b = dvui.box(@src(), .{ .dir = .horizontal }, .{
                    .min_size_content = .{ .w = button_w, .h = button_h },
                    .expand = .vertical,
                    .background = is_hover,
                    .color_fill = close_hover_fill.opacity(0.5),
                });
                defer b.deinit();
                pixi.backend.setTitleBarCaptionButtonRect(.close, b.data().rectScale().r);
                dvui.icon(@src(), "win_close", icons.tvg.heroicons.outline.@"x-mark", .{
                    .stroke_color = if (is_hover) close_hover_stroke else stroke,
                }, .{
                    .expand = .ratio,
                    .padding = .all(5),
                    .margin = .all(0),
                    .gravity_x = 0.5,
                });
            }
        }

        var base_box = dvui.box(
            @src(),
            .{ .dir = .horizontal },
            .{
                .expand = .both,
            },
        );
        defer base_box.deinit();

        // Advance the animation frame if we are in play mode
        if (editor.activeFile()) |file| {
            if (file.editor.playing) {
                if (file.selected_animation_index) |index| {
                    const animation = file.animations.get(index);

                    if (animation.frames.len > 0) {
                        if (dvui.timerDoneOrNone(base_box.data().id)) {
                            if (file.selected_animation_frame_index >= animation.frames.len - 1) {
                                file.selected_animation_frame_index = 0;
                            } else {
                                file.selected_animation_frame_index += 1;
                            }
                            const millis_per_frame = animation.frames[file.selected_animation_frame_index].ms;

                            dvui.timer(base_box.data().id, @intCast(millis_per_frame * 1000));
                        }
                    }
                }
            }
        }

        // Always reset the peek layer index back, but we need to do this outside of the file widget so
        // other editor windows can use it
        defer for (editor.open_files.values()) |*file| {
            if (file.editor.isolate_layer) {
                file.peek_layer_index = file.selected_layer_index;
            } else {
                file.peek_layer_index = null;
            }
        };

        // Sidebar area
        // Since sidebar is drawn before the explorer, and we want to allow expanding the explorer
        // from clicking a sidebar option, we need to check if the sidebar was pressed
        const sidebar_pressed = editor.sidebar.draw() catch {
            dvui.log.err("Failed to draw sidebar", .{});
            return false;
        };

        var explorer_paned_box = dvui.box(
            @src(),
            .{ .dir = .vertical },
            .{
                .expand = .both,
                .background = false,
            },
        );
        defer explorer_paned_box.deinit();

        // Draw the infobar, but draw it at the bottom of the paned box (gravity_y = 1.0)
        {
            editor.infobar.draw() catch {
                dvui.log.err("Failed to draw infobar", .{});
            };
        }

        // Draw the explorer paned widget, which will recursively draw the workspaces in the second pane
        editor.explorer.paned = pixi.dvui.paned(@src(), .{
            .direction = .horizontal,
            .collapsed_size = pixi.editor.settings.min_window_size[0] + 1,
            .handle_size = handle_size,
            .handle_dynamic = .{
                .handle_size_max = handle_size,
                .distance_max = handle_dist,
            },
            .uncollapse_ratio = pixi.editor.settings.explorer_ratio,
        }, .{
            .expand = .both,
            .background = false,
        });
        defer editor.explorer.paned.deinit();

        editor.flushQueuedNativeMenuActions();
        editor.processPendingSaveAs();

        if (dvui.firstFrame(editor.explorer.paned.wd.id)) {
            editor.explorer.paned.split_ratio.* = 0.0;
            editor.explorer.paned.animateSplit(pixi.editor.settings.explorer_ratio, dvui.easing.outBack);

            if (pixi.editor.settings.explorer_ratio < 0.01) {
                editor.explorer.closed = true;
            }
        } else if (editor.explorer.paned.dragging) {
            editor.settings.explorer_ratio = editor.explorer.paned.split_ratio.*;
        }

        if (sidebar_pressed) {
            editor.explorer.open();
        }

        if (editor.explorer.paned.showFirst()) {

            // Explorer area
            {
                const result = try editor.explorer.draw();
                if (result != .ok) {
                    return result;
                }
            }
        }

        if (editor.explorer.paned.showSecond()) {
            const bg_box = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both });
            defer bg_box.deinit();

            // On macOS, the menu is handled natively, so we don't need to draw it here
            if (builtin.os.tag != .macos) {
                const result = try Menu.draw();
                if (result != .ok) {
                    return result;
                }
            }

            const workspace_vbox = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both, .background = false, .padding = .{ .w = handle_size } });
            defer workspace_vbox.deinit();

            editor.panel.paned = pixi.dvui.paned(@src(), .{
                .direction = .vertical,
                .collapsed_size = pixi.editor.settings.min_window_size[1] + 1,
                .handle_size = handle_size,
                .handle_dynamic = .{ .handle_size_max = handle_size, .distance_max = handle_dist },
                .uncollapse_ratio = 1.0,
            }, .{
                .expand = .both,
                .background = false,
            });
            defer editor.panel.paned.deinit();

            if (!editor.panel.paned.dragging) {
                if (editor.activeFile()) |_| {
                    if ((editor.panel.paned.split_ratio.* == 1.0 and !editor.panel.paned.collapsed()) and pixi.editor.settings.panel_ratio > 0.0) {
                        editor.panel.paned.animateSplit(1.0 - pixi.editor.settings.panel_ratio, dvui.easing.outQuint);
                    }
                } else {
                    if (!editor.panel.paned.animating and editor.panel.paned.split_ratio.* < 1.0) {
                        editor.panel.paned.animateSplit(1.0, dvui.easing.outQuint);
                    }
                }
            } else {
                pixi.editor.settings.panel_ratio = 1.0 - editor.panel.paned.split_ratio.*;
            }

            if (editor.panel.paned.showSecond()) {
                const vbox = dvui.box(@src(), .{ .dir = .vertical }, .{
                    .expand = .both,
                    .background = false,
                    .gravity_y = 0.0,
                });
                defer vbox.deinit();

                const result = try editor.panel.draw();
                if (result != .ok) {
                    return result;
                }
            }

            if (editor.panel.paned.showFirst()) {
                const result = try editor.drawWorkspaces(0);
                if (result != .ok) {
                    return result;
                }
            }
        }

        { // Radial Menu

            Keybinds.tick() catch {
                dvui.log.err("Failed to tick hotkeys", .{});
            };

            for (dvui.events()) |*e| {
                switch (e.evt) {
                    .mouse => |me| {
                        editor.tools.radial_menu.mouse_position = me.p;
                    },
                    else => {},
                }
            }

            if (editor.tools.radial_menu.visible) {
                editor.drawRadialMenu() catch {
                    dvui.log.err("Failed to draw radial menu", .{});
                };
            }
        }
    }

    // look at demo() for examples of dvui widgets, shows in a floating window
    dvui.Examples.demo(.full);

    _ = editor.arena.reset(.retain_capacity);

    return .ok;
}

fn queueNativeMenuAction(editor: *Editor, action: pixi.backend.NativeMenuAction) void {
    if (editor.pending_native_menu_actions_len >= editor.pending_native_menu_actions.len) {
        // If we ever overflow, drop the action rather than crashing.
        return;
    }
    editor.pending_native_menu_actions[editor.pending_native_menu_actions_len] = action;
    editor.pending_native_menu_actions_len += 1;
}

fn flushQueuedNativeMenuActions(editor: *Editor) void {
    if (editor.pending_native_menu_actions_len == 0) return;
    const len: usize = editor.pending_native_menu_actions_len;
    editor.pending_native_menu_actions_len = 0;

    var i: usize = 0;
    while (i < len) : (i += 1) {
        editor.handleNativeMenuAction(editor.pending_native_menu_actions[i]) catch |err| {
            dvui.log.err("Native menu action failed: {any}", .{err});
        };
    }
}

pub fn handleNativeMenuAction(editor: *Editor, action: pixi.backend.NativeMenuAction) !void {
    switch (action) {
        .open_folder => {
            if (try dvui.dialogNativeFolderSelect(dvui.currentWindow().arena(), .{ .title = "Open Project Folder" })) |folder| {
                try editor.setProjectFolder(folder);
            }
        },
        .open_files => {
            if (try dvui.dialogNativeFileOpenMultiple(dvui.currentWindow().arena(), .{
                .title = "Open Files...",
                .filter_description = ".pixi, .png, .jpg, .jpeg",
                .filters = &.{ "*.pixi", "*.png", "*.jpg", "*.jpeg" },
            })) |files| {
                for (files) |file| {
                    _ = editor.openFilePath(file, editor.open_workspace_grouping) catch {
                        std.log.err("Failed to open file: {s}", .{file});
                    };
                }
            }
        },
        .save => {
            editor.save() catch {
                std.log.err("Failed to save", .{});
            };
        },
        .new_file => {
            editor.requestNewFileDialog();
        },
        .save_as => {
            editor.requestSaveAs();
        },
        .copy => {
            if (editor.activeFile() != null) {
                editor.copy() catch {
                    std.log.err("Failed to copy", .{});
                };
            }
        },
        .paste => {
            if (editor.activeFile() != null) {
                editor.paste() catch {
                    std.log.err("Failed to paste", .{});
                };
            }
        },
        .undo => {
            if (editor.activeFile()) |file| {
                file.history.undoRedo(file, .undo) catch {
                    std.log.err("Failed to undo", .{});
                };
            }
        },
        .redo => {
            if (editor.activeFile()) |file| {
                file.history.undoRedo(file, .redo) catch {
                    std.log.err("Failed to redo", .{});
                };
            }
        },
        .transform => {
            if (editor.activeFile() != null) {
                editor.transform() catch {
                    std.log.err("Failed to transform", .{});
                };
            }
        },
        .toggle_explorer => {
            // Use .closed, not paned.split_ratio — split_ratio is only valid during draw
            if (editor.explorer.closed) {
                editor.explorer.open();
            } else {
                editor.explorer.close();
            }
            // Native menu does not go through SDL events; request a frame so the paned animates immediately.
            dvui.refresh(null, @src(), dvui.currentWindow().data().id);
        },
        .show_dvui_demo => {
            dvui.Examples.show_demo_window = !dvui.Examples.show_demo_window;
        },
    }
}

pub fn setTitlebarColor(editor: *Editor) void {
    const color = if (editor.dim_titlebar) dvui.themeGet().color(.control, .fill).lerp(.black, if (dvui.themeGet().dark) 60.0 / 255.0 else 80.0 / 255.0) else dvui.themeGet().color(.control, .fill);

    if (!std.mem.eql(u8, &editor.last_titlebar_color.toRGBA(), &color.toRGBA())) {
        editor.last_titlebar_color = color;
        pixi.backend.setTitlebarColor(dvui.currentWindow(), color.opacity(if (dvui.themeGet().dark) editor.settings.window_opacity_dark else editor.settings.window_opacity_light));
    }
}

pub fn setWindowStyle(_: *Editor) void {
    pixi.backend.setWindowStyle(dvui.currentWindow());
}

pub fn drawRadialMenu(editor: *Editor) !void {
    var fw: dvui.FloatingWidget = undefined;
    fw.init(@src(), .{}, .{
        .rect = .cast(dvui.windowRect()),
    });
    defer fw.deinit();

    const menu_color = dvui.themeGet().color(.content, .fill).lighten(4.0);

    if (dvui.firstFrame(fw.data().id)) {
        editor.tools.radial_menu.center = editor.tools.radial_menu.mouse_position;
    }

    const center = fw.data().rectScale().pointFromPhysical(editor.tools.radial_menu.center);

    const tool_count: usize = std.meta.fields(Editor.Tools.Tool).len;

    const radius: f32 = 50.0;
    const width: f32 = radius * 2.0;
    const height: f32 = radius * 2.0;
    const step: f32 = (2.0 * std.math.pi) / @as(f32, @floatFromInt(tool_count));

    var angle: f32 = 180.0;

    var outer_anim = dvui.animate(@src(), .{ .duration = 400_000, .kind = .horizontal, .easing = dvui.easing.outBack }, .{});

    const temp_radius: f32 = 3.0 * radius * (outer_anim.val orelse 1.0);

    var outer_rect = dvui.Rect.fromPoint(center);
    outer_rect.w = temp_radius;
    outer_rect.h = temp_radius;
    outer_rect.x -= outer_rect.w / 2.0;
    outer_rect.y -= outer_rect.h / 2.0;

    var box = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .rect = outer_rect,
        .expand = .none,
        .background = true,
        .corner_radius = dvui.Rect.all(100000),
        .box_shadow = .{
            .color = .black,
            .offset = .{ .x = -4.0, .y = 4.0 },
            .fade = 8.0,
            .alpha = 0.35,
        },
        .color_fill = menu_color.opacity(0.75),
        .border = dvui.Rect.all(0.0),
    });

    box.deinit();

    outer_anim.deinit();

    for (0..tool_count) |i| {
        var anim = dvui.animate(@src(), .{ .duration = 100_000 + 50_000 * @as(i32, @intCast(i)), .kind = .alpha, .easing = dvui.easing.linear }, .{
            .id_extra = i,
        });
        defer anim.deinit();

        if (anim.val) |val| {
            angle += ((1 - val) * 100.0) * 0.015;
        }

        var color = dvui.themeGet().color(.control, .fill_hover);
        if (pixi.editor.colors.file_tree_palette) |*palette| {
            color = palette.getDVUIColor(i);
        }

        const x: f32 = std.math.round(width / 2.0 + radius * std.math.cos(angle) - width / 2.0);
        const y: f32 = std.math.round(height / 2.0 + radius * std.math.sin(angle) - height / 2.0);

        const new_center = center.plus(.{ .x = x, .y = y });

        { // Draw line along pie slice
            // const line_x: f32 = std.math.round(width / 2.0 + radius * std.math.cos(angle + step / 2.0) - width / 2.0);
            // const line_y: f32 = std.math.round(height / 2.0 + radius * std.math.sin(angle + step / 2.0) - height / 2.0);

            // const new_line_center = center.plus((dvui.Point{ .x = line_x, .y = line_y }).normalize().scale(radius * 1.5, dvui.Point));

            // dvui.Path.stroke(.{ .points = &.{ center.scale(scale, dvui.Point.Physical), new_line_center.scale(scale, dvui.Point.Physical) } }, .{
            //     .color = dvui.themeGet().color(.control, .text),
            //     .thickness = 1.0,
            // });
        }

        var rect = dvui.Rect.fromPoint(new_center);

        rect.w = 40.0;
        rect.h = 40.0;
        rect.x -= rect.w / 2.0;
        rect.y -= rect.h / 2.0;

        const tool = @as(Editor.Tools.Tool, @enumFromInt(i));

        var button: dvui.ButtonWidget = undefined;
        button.init(@src(), .{}, .{
            .rect = rect,
            .id_extra = i,
            .corner_radius = dvui.Rect.all(1000.0),
            .color_fill = if (tool == editor.tools.current) dvui.themeGet().color(.content, .fill) else .transparent,
            .box_shadow = if (tool == editor.tools.current) .{
                .color = .black,
                .offset = .{ .x = -2.5, .y = 2.5 },
                .fade = 4.0,
                .alpha = 0.25,
                .corner_radius = dvui.Rect.all(1000),
            } else null,
            .padding = .all(0),
            .margin = .all(0),
        });

        {
            editor.tools.drawTooltip(tool, button.data().rectScale().r, i) catch {};
        }

        const selection_sprite = switch (editor.tools.selection_mode) {
            .box => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.box_selection_default],
            .pixel => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.pixel_selection_default],
            .color => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.color_selection_default],
        };

        const sprite = switch (@as(Editor.Tools.Tool, @enumFromInt(i))) {
            .pointer => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.cursor_default],
            .pencil => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.pencil_default],
            .eraser => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.eraser_default],
            .bucket => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.bucket_default],
            .selection => selection_sprite,
        };
        const size: dvui.Size = dvui.imageSize(pixi.editor.atlas.source) catch .{ .w = 0, .h = 0 };

        const uv = dvui.Rect{
            .x = @as(f32, @floatFromInt(sprite.source[0])) / size.w,
            .y = @as(f32, @floatFromInt(sprite.source[1])) / size.h,
            .w = @as(f32, @floatFromInt(sprite.source[2])) / size.w,
            .h = @as(f32, @floatFromInt(sprite.source[3])) / size.h,
        };

        button.processEvents();
        button.drawBackground();

        var rs = button.data().contentRectScale();

        const w = @as(f32, @floatFromInt(sprite.source[2])) * rs.s;
        const h = @as(f32, @floatFromInt(sprite.source[3])) * rs.s;

        rs.r.x += (rs.r.w - w) / 2.0;
        rs.r.y += (rs.r.h - h) / 2.0;
        rs.r.w = w;
        rs.r.h = h;

        dvui.renderImage(pixi.editor.atlas.source, rs, .{
            .uv = uv,
            .fade = 0.0,
        }) catch {
            std.log.err("Failed to render image", .{});
        };
        angle += step;

        if (button.clicked() or button.hovered()) {
            editor.tools.set(tool);
        }

        button.deinit();
    }

    { // Center play/pause button

        var anim = dvui.animate(@src(), .{ .duration = 100_000, .kind = .alpha, .easing = dvui.easing.linear }, .{
            .id_extra = tool_count + 1,
        });
        defer anim.deinit();

        var rect = dvui.Rect.fromPoint(center);

        rect.w = 40.0;
        rect.h = 40.0;
        rect.x -= rect.w / 2.0;
        rect.y -= rect.h / 2.0;

        {
            if (editor.activeFile()) |file| {
                if (dvui.buttonIcon(@src(), "Play", if (file.editor.playing) icons.tvg.entypo.pause else icons.tvg.entypo.play, .{}, .{}, .{
                    .expand = .none,
                    .corner_radius = dvui.Rect.all(1000),
                    .box_shadow = .{
                        .color = .black,
                        .offset = .{ .x = -2.5, .y = 2.5 },
                        .fade = 4.0,
                        .alpha = 0.25,
                        .corner_radius = dvui.Rect.all(1000),
                    },
                    .color_fill = dvui.themeGet().color(.control, .fill_hover),
                    .rect = rect,
                })) {
                    file.editor.playing = !file.editor.playing;
                }
            }
        }
    }
}

pub fn rebuildWorkspaces(editor: *Editor) !void {

    // Create workspaces for each grouping ID
    for (editor.open_files.values()) |*file| {
        if (!editor.workspaces.contains(file.editor.grouping)) {
            var workspace: pixi.Editor.Workspace = .init(file.editor.grouping);
            for (editor.open_files.values()) |*f| {
                if (f.editor.grouping == file.editor.grouping) {
                    workspace.open_file_index = editor.open_files.getIndex(f.id) orelse 0;
                }
            }

            editor.workspaces.put(file.editor.grouping, workspace) catch |err| {
                std.log.err("Failed to create workspace: {s}", .{@errorName(err)});
                return err;
            };
        }
    }

    // Remove workspaces that are no longer needed
    for (editor.workspaces.values()) |*workspace| {
        if (editor.workspaces.count() == 1) {
            break;
        }

        var contains: bool = false;
        for (editor.open_files.values()) |*file| {
            if (file.editor.grouping == workspace.grouping) {
                contains = true;
                break;
            }
        }

        if (!contains) {
            if (editor.open_workspace_grouping == workspace.grouping) {
                for (editor.workspaces.values()) |*w| {
                    if (w.grouping != workspace.grouping) {
                        editor.open_workspace_grouping = w.grouping;
                        break;
                    }
                }
            }

            _ = editor.workspaces.orderedRemove(workspace.grouping);
            break;
        }
    }

    // Ensure the selected file for each workspace is still valid
    for (editor.workspaces.values()) |*workspace| {
        if (editor.getFile(workspace.open_file_index)) |file| {
            if (file.editor.grouping == workspace.grouping) {
                continue;
            }
        }

        var i: usize = editor.open_files.count();
        while (i > 0) {
            i -= 1;

            if (editor.getFile(i)) |file| {
                if (file.editor.grouping == workspace.grouping) {
                    workspace.open_file_index = i;
                    break;
                }
            }
        }
    }
}

pub fn drawWorkspaces(editor: *Editor, index: usize) !dvui.App.Result {
    if (index >= editor.workspaces.count()) return .ok;

    var s = pixi.dvui.paned(@src(), .{
        .direction = .horizontal,
        .collapsed_size = if (index == editor.workspaces.count() - 1) std.math.floatMax(f32) else 0,
        .handle_size = handle_size,
        .handle_dynamic = .{ .handle_size_max = handle_size, .distance_max = handle_dist },
    }, .{
        .expand = .both,
        .background = false,
    });
    defer s.deinit();

    const dragging = editor.panel.paned.dragging or s.dragging;

    if (!dragging) {
        if (index + 1 < editor.workspaces.count()) {
            editor.workspaces.values()[index + 1].center = (s.animating and s.split_ratio.* < 1.0) or (editor.panel.paned.animating and editor.panel.paned.split_ratio.* < 1.0);
        } else if (editor.workspaces.count() == 1) {
            editor.workspaces.values()[index].center = (editor.panel.paned.animating and editor.panel.paned.split_ratio.* < 1.0);
        }
    }

    // Ens
    if (s.collapsing and s.split_ratio.* < 0.5) {
        s.animateSplit(1.0, dvui.easing.outBack);
    }

    if (!s.dragging and !s.animating and !s.collapsing and !s.collapsed_state) {
        if (index == editor.workspaces.count() - 1) {
            if (s.split_ratio.* != 1.0) {
                s.animateSplit(1.0, dvui.easing.outBack);
            }
        } else {
            if (dvui.firstFrame(s.wd.id)) {
                s.split_ratio.* = 1.0;
                s.animateSplit(0.5, dvui.easing.outBack);
            }
        }
    }

    if (s.showFirst()) {
        const result = try editor.workspaces.values()[index].draw();
        if (result != .ok) {
            return result;
        }
    }

    if (s.showSecond()) {
        const result = try drawWorkspaces(editor, index + 1);
        if (result != .ok) {
            return result;
        }
    }

    return .ok;
}

pub fn close(app: *App, editor: *Editor) void {
    var should_close = true;
    for (editor.open_files.items) |file| {
        if (file.dirty()) {
            should_close = false;
        }
    }

    if (!should_close and !editor.popups.file_confirm_close_exit) {
        editor.popups.file_confirm_close = true;
        editor.popups.file_confirm_close_state = .all;
        editor.popups.file_confirm_close_exit = true;
    }
    app.should_close = should_close;
}

pub fn setProjectFolder(editor: *Editor, path: []const u8) !void {
    if (editor.folder) |folder| {
        if (editor.project) |*project| {
            project.save() catch {
                dvui.log.err("Failed to save project", .{});
            };
        }
        pixi.app.allocator.free(folder);
    }
    editor.folder = try pixi.app.allocator.dupe(u8, path);
    try editor.recents.appendFolder(try pixi.app.allocator.dupe(u8, path));
    editor.explorer.pane = .files;

    editor.project = Project.load(pixi.app.allocator) catch null;
}

pub fn saving(editor: *Editor) bool {
    for (editor.open_files.items) |file| {
        if (file.saving) return true;
    }
    return false;
}

/// Returns true if a new file was opened.
/// The editor doesn't care what type of file is being opened,
/// File.fromPath will handle the file type
pub fn openFilePath(editor: *Editor, path: []const u8, grouping: u64) !bool {
    for (editor.open_files.values(), 0..) |*file, i| {
        if (std.mem.eql(u8, file.path, path)) {
            editor.setActiveFile(i);
            return false;
        }
    }

    if (pixi.Internal.File.fromPath(path) catch null) |file| {
        try editor.open_files.put(file.id, file);
        if (editor.open_files.getPtr(file.id)) |f| {
            f.editor.grouping = grouping;
        }

        // At this point, if the workspace grouping doesn't exist, it will next frame
        // once the workspaces are rebuilt. Since we cant wait on that, go ahead and set it now
        //editor.open_workspace_grouping = grouping;

        // If the workspace grouping does exist, go ahead and set the active file
        editor.setActiveFile(editor.open_files.count() - 1);
        editor.pending_composite_warmup = true;
        return true;
    }
    return error.FailedToOpenFile;
}

pub fn requestCompositeWarmup(editor: *Editor) void {
    editor.pending_composite_warmup = true;
}

pub fn newFile(editor: *Editor, path: []const u8, options: pixi.Internal.File.InitOptions) !*pixi.Internal.File {
    if (editor.getFileFromPath(path)) |_| {
        return error.FileAlreadyExists;
    }

    const file = pixi.Internal.File.init(path, options) catch {
        dvui.log.err("Failed to create file: {s}", .{path});
        return error.FailedToCreateFile;
    };

    try editor.open_files.put(file.id, file);
    editor.setActiveFile(editor.open_files.count() - 1);
    editor.pending_composite_warmup = true;

    return editor.open_files.getPtr(file.id) orelse return error.FailedToCreateFile;
}

/// Heap-owned path like `untitled-1`, unique among `open_files` basenames.
pub fn allocNextUntitledPath(editor: *Editor) ![]u8 {
    var max_n: u32 = 0;
    for (editor.open_files.values()) |f| {
        const base = std.fs.path.basename(f.path);
        if (std.mem.startsWith(u8, base, "untitled-")) {
            const suffix = base["untitled-".len..];
            const n = std.fmt.parseUnsigned(u32, suffix, 10) catch continue;
            max_n = @max(max_n, n);
        } else if (std.mem.eql(u8, base, "untitled")) {
            max_n = @max(max_n, 1);
        }
    }
    return std.fmt.allocPrint(pixi.app.allocator, "untitled-{d}", .{max_n + 1});
}

/// Opens the New File dimensions dialog; on confirm, creates an in-memory `untitled-n` document (or on-disk from explorer when `_parent_path` is set).
pub fn requestNewFileDialog(_: *Editor) void {
    var mutex = pixi.dvui.dialog(@src(), .{
        .displayFn = Dialogs.NewFile.dialog,
        .callafterFn = Dialogs.NewFile.callAfter,
        .title = "New File...",
        .ok_label = "Create",
        .cancel_label = "Cancel",
        .resizeable = false,
        .default = .ok,
    });
    mutex.mutex.unlock();
}

pub fn setActiveFile(editor: *Editor, index: usize) void {
    if (index >= editor.open_files.values().len) return;
    const file = editor.open_files.values()[index];
    const grouping = file.editor.grouping;

    if (editor.workspaces.getPtr(grouping)) |workspace| {
        editor.open_workspace_grouping = grouping;
        workspace.open_file_index = index;
    }
}

/// Returns the actively focused file, through workspace grouping.
pub fn activeFile(editor: *Editor) ?*pixi.Internal.File {
    if (editor.workspaces.get(editor.open_workspace_grouping)) |workspace| {
        return editor.getFile(workspace.open_file_index);
    }

    return null;
}

pub fn getFile(editor: *Editor, index: usize) ?*pixi.Internal.File {
    if (editor.open_files.values().len == 0) return null;
    if (index >= editor.open_files.values().len) return null;

    return &editor.open_files.values()[index];
}

pub fn getFileFromPath(editor: *Editor, path: []const u8) ?*pixi.Internal.File {
    if (editor.open_files.values().len == 0) return null;

    for (editor.open_files.values()) |*file| {
        if (std.mem.eql(u8, file.path, path)) {
            return file;
        }
    }

    return null;
}

pub fn forceCloseFile(editor: *Editor, index: usize) !void {
    if (editor.getFile(index) != null) {
        return editor.rawCloseFile(index);
    }
}

pub fn accept(editor: *Editor) !void {
    if (editor.activeFile()) |file| {
        if (file.editor.transform) |*t| {
            t.accept();
        }
    }
}

pub fn cancel(editor: *Editor) !void {
    if (editor.activeFile()) |file| {
        if (file.editor.transform) |*t| {
            t.cancel();
        }

        if (file.editor.selected_sprites.count() > 0) {
            file.clearSelectedSprites();
        }

        if (file.selected_animation_index != null) {
            file.selected_animation_index = null;
        }
    }
}

pub fn copy(editor: *Editor) !void {
    if (editor.activeFile()) |file| {
        if (file.editor.transform != null) return;

        if (editor.sprite_clipboard) |*clipboard| {
            pixi.app.allocator.free(pixi.image.bytes(clipboard.source));
            editor.sprite_clipboard = null;
        }

        file.editor.transform_layer.clear();

        var selected_layer = file.layers.get(file.selected_layer_index);
        switch (editor.tools.current) {
            .selection => {
                // We are in the selection tool, so we should assume that the user has painted a selection
                // into the selection layer mask, we need to copy the pixels into the transform layer itself for reducing
                var pixel_iterator = file.editor.selection_layer.mask.iterator(.{ .kind = .set, .direction = .forward });
                while (pixel_iterator.next()) |pixel_index| {
                    @memcpy(&file.editor.transform_layer.pixels()[pixel_index], &selected_layer.pixels()[pixel_index]);
                    file.editor.transform_layer.mask.set(pixel_index);
                }
            },
            else => {
                if (file.editor.selected_sprites.count() > 0) {
                    var sprite_iterator = file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
                    while (sprite_iterator.next()) |index| {
                        const source_rect = file.spriteRect(index);
                        if (selected_layer.pixelsFromRect(
                            dvui.currentWindow().arena(),
                            source_rect,
                        )) |source_pixels| {
                            file.editor.transform_layer.blit(
                                source_pixels,
                                source_rect,
                                .{ .transparent = true, .mask = true },
                            );
                        }
                    }
                } else {
                    if (file.editor.canvas.hovered) {
                        if (file.spriteIndex(file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt))) |sprite_index| {
                            const rect = file.spriteRect(sprite_index);
                            if (selected_layer.pixelsFromRect(
                                dvui.currentWindow().arena(),
                                rect,
                            )) |source_pixels| {
                                file.editor.transform_layer.blit(
                                    source_pixels,
                                    rect,
                                    .{ .transparent = true, .mask = true },
                                );
                            }
                        }
                    } else if (file.selected_animation_index) |animation_index| {
                        const animation = file.animations.get(animation_index);
                        if (file.selected_animation_frame_index < animation.frames.len) {
                            const rect = file.spriteRect(animation.frames[file.selected_animation_frame_index].sprite_index);
                            if (selected_layer.pixelsFromRect(
                                dvui.currentWindow().arena(),
                                rect,
                            )) |source_pixels| {
                                file.editor.transform_layer.blit(
                                    source_pixels,
                                    rect,
                                    .{ .transparent = true, .mask = true },
                                );
                            }
                        }
                    }
                }
            },
        }

        const source_rect = dvui.Rect.fromSize(file.editor.transform_layer.size());
        if (file.editor.transform_layer.reduce(source_rect)) |reduced_data_rect| {
            const sprite_tl = file.spritePoint(reduced_data_rect.topLeft());

            editor.sprite_clipboard = .{
                .source = pixi.image.fromPixelsPMA(
                    @ptrCast(file.editor.transform_layer.pixelsFromRect(pixi.app.allocator, reduced_data_rect)),
                    @intFromFloat(reduced_data_rect.w),
                    @intFromFloat(reduced_data_rect.h),
                    .ptr,
                ) catch return error.MemoryAllocationFailed,
                .offset = reduced_data_rect.topLeft().diff(sprite_tl),
            };

            // Show a toast so its evident a copy action was completed
            {
                const id_mutex = dvui.toastAdd(dvui.currentWindow(), @src(), 0, file.editor.canvas.id, pixi.dvui.toastDisplay, 2_000_000);
                const id = id_mutex.id;
                const message = std.fmt.allocPrint(dvui.currentWindow().arena(), "Copied selection", .{}) catch "Copied selection.";
                dvui.dataSetSlice(dvui.currentWindow(), id, "_message", message);
                id_mutex.mutex.unlock();
            }
        }
    }
}

pub fn paste(editor: *Editor) !void {
    if (editor.sprite_clipboard) |*clipboard| {
        if (editor.activeFile()) |file| {
            const active_layer = file.layers.get(file.selected_layer_index);

            var dst_rect: dvui.Rect = .fromSize(pixi.image.size(clipboard.source));

            var sprite_iterator = file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
            while (sprite_iterator.next()) |sprite_index| {
                const sprite_rect = file.spriteRect(sprite_index);

                dst_rect.x = sprite_rect.x + clipboard.offset.x;
                dst_rect.y = sprite_rect.y + clipboard.offset.y;

                file.editor.transform = .{
                    .target_texture = dvui.textureCreateTarget(file.width(), file.height(), .nearest, .rgba_8_8_8_8) catch {
                        dvui.log.err("Failed to create target texture", .{});
                        return;
                    },
                    .file_id = file.id,
                    .layer_id = active_layer.id,
                    .data_points = .{
                        dst_rect.topLeft(),
                        dst_rect.topRight(),
                        dst_rect.bottomRight(),
                        dst_rect.bottomLeft(),
                        dst_rect.center(),
                        dst_rect.center(),
                    },
                    .source = clipboard.source,
                };

                for (file.editor.transform.?.data_points[0..4]) |*point| {
                    const d = point.diff(file.editor.transform.?.point(.pivot).*);
                    if (d.length() > file.editor.transform.?.radius) {
                        file.editor.transform.?.radius = d.length() + 4;
                    }
                }

                return;
            }

            dst_rect.x = clipboard.offset.x;
            dst_rect.y = clipboard.offset.y;

            if (file.spriteIndex(file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt))) |sprite_index| {
                const rect = file.spriteRect(sprite_index);
                dst_rect.x = rect.x + clipboard.offset.x;
                dst_rect.y = rect.y + clipboard.offset.y;
            } else if (file.selected_animation_index) |animation_index| {
                const animation = file.animations.get(animation_index);

                if (file.selected_animation_frame_index < animation.frames.len) {
                    const rect = file.spriteRect(animation.frames[file.selected_animation_frame_index].sprite_index);
                    dst_rect.x = rect.x + clipboard.offset.x;
                    dst_rect.y = rect.y + clipboard.offset.y;

                    file.editor.transform = .{
                        .target_texture = dvui.textureCreateTarget(file.width(), file.height(), .nearest, .rgba_8_8_8_8) catch {
                            dvui.log.err("Failed to create target texture", .{});
                            return;
                        },
                        .file_id = file.id,
                        .layer_id = active_layer.id,
                        .data_points = .{
                            dst_rect.topLeft(),
                            dst_rect.topRight(),
                            dst_rect.bottomRight(),
                            dst_rect.bottomLeft(),
                            dst_rect.center(),
                            dst_rect.center(),
                        },
                        .source = clipboard.source,
                    };

                    for (file.editor.transform.?.data_points[0..4]) |*point| {
                        const d = point.diff(file.editor.transform.?.point(.pivot).*);
                        if (d.length() > file.editor.transform.?.radius) {
                            file.editor.transform.?.radius = d.length() + 4;
                        }
                    }

                    return;
                }
            }

            file.editor.transform = .{
                .target_texture = dvui.textureCreateTarget(file.width(), file.height(), .nearest, .rgba_8_8_8_8) catch {
                    dvui.log.err("Failed to create target texture", .{});
                    return;
                },
                .file_id = file.id,
                .layer_id = active_layer.id,
                .data_points = .{
                    dst_rect.topLeft(),
                    dst_rect.topRight(),
                    dst_rect.bottomRight(),
                    dst_rect.bottomLeft(),
                    dst_rect.center(),
                    dst_rect.center(),
                },
                .source = clipboard.source,
            };

            for (file.editor.transform.?.data_points[0..4]) |*point| {
                const d = point.diff(file.editor.transform.?.point(.pivot).*);
                if (d.length() > file.editor.transform.?.radius) {
                    file.editor.transform.?.radius = d.length() + 4;
                }
            }
        }
    }
}

pub fn deleteSelectedContents(editor: *Editor) void {
    if (editor.activeFile()) |file| {
        file.deleteSelectedContents();
    }
}

/// Begins a transform operation on the currently active file.
pub fn transform(editor: *Editor) !void {
    if (editor.activeFile()) |file| {
        if (file.editor.transform) |*t| {
            t.cancel();
        }

        var selected_layer = file.layers.get(file.selected_layer_index);

        switch (editor.tools.current) {
            .selection => {
                file.editor.transform_layer.clear();
                // We are in the selection tool, so we should assume that the user has painted a selection
                // into the selection layer mask, we need to copy the pixels into the transform layer itself for reducing
                var pixel_iterator = file.editor.selection_layer.mask.iterator(.{ .kind = .set, .direction = .forward });
                while (pixel_iterator.next()) |pixel_index| {
                    @memcpy(&file.editor.transform_layer.pixels()[pixel_index], &selected_layer.pixels()[pixel_index]);
                    selected_layer.pixels()[pixel_index] = .{ 0, 0, 0, 0 };
                    file.editor.transform_layer.mask.set(pixel_index);
                }
                selected_layer.invalidate();
            },
            else => {
                // Current tool is the pointer, so we potentially have a sprite selection in
                // selected sprites that we need to copy to the selection layer.
                file.editor.transform_layer.clear();

                if (file.editor.selected_sprites.count() > 0) {
                    var sprite_iterator = file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });

                    while (sprite_iterator.next()) |index| {
                        const source_rect = file.spriteRect(index);
                        if (selected_layer.pixelsFromRect(
                            dvui.currentWindow().arena(),
                            source_rect,
                        )) |source_pixels| {
                            file.editor.transform_layer.blit(
                                source_pixels,
                                source_rect,
                                .{ .transparent = true, .mask = true },
                            );
                            selected_layer.clearRect(source_rect);
                        }
                    }
                } else {
                    if (file.editor.canvas.hovered) {
                        if (file.spriteIndex(file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt))) |sprite_index| {
                            const rect = file.spriteRect(sprite_index);
                            if (selected_layer.pixelsFromRect(
                                dvui.currentWindow().arena(),
                                rect,
                            )) |source_pixels| {
                                file.editor.transform_layer.blit(
                                    source_pixels,
                                    rect,
                                    .{ .transparent = true, .mask = true },
                                );
                                selected_layer.clearRect(rect);
                            }
                        }
                    } else if (file.selected_animation_index) |animation_index| {
                        const animation = file.animations.get(animation_index);
                        if (file.selected_animation_frame_index < animation.frames.len) {
                            const source_rect = file.spriteRect(animation.frames[file.selected_animation_frame_index].sprite_index);
                            if (selected_layer.pixelsFromRect(
                                dvui.currentWindow().arena(),
                                source_rect,
                            )) |source_pixels| {
                                file.editor.transform_layer.blit(
                                    source_pixels,
                                    source_rect,
                                    .{ .transparent = true, .mask = true },
                                );
                                selected_layer.clearRect(source_rect);
                            }
                        }
                    }
                }
            },
        }

        // We now have a transform layer that contains:
        // 1. the unaltered colored pixels of the active transform
        // 2. a mask containing bits for the pixels of the selection being transformed
        const source_rect = dvui.Rect.fromSize(file.editor.transform_layer.size());
        if (file.editor.transform_layer.reduce(source_rect)) |reduced_data_rect| {
            defer file.editor.selection_layer.clearMask();
            file.editor.transform = .{
                .target_texture = dvui.textureCreateTarget(file.width(), file.height(), .nearest, .rgba_8_8_8_8) catch {
                    dvui.log.err("Failed to create target texture", .{});
                    return;
                },
                .file_id = file.id,
                .layer_id = selected_layer.id,
                .data_points = .{
                    reduced_data_rect.topLeft(),
                    reduced_data_rect.topRight(),
                    reduced_data_rect.bottomRight(),
                    reduced_data_rect.bottomLeft(),
                    reduced_data_rect.center(),
                    reduced_data_rect.center(), // This point constantly moves
                },
                .source = pixi.image.fromPixelsPMA(
                    @ptrCast(file.editor.transform_layer.pixelsFromRect(pixi.app.allocator, reduced_data_rect)),
                    @intFromFloat(reduced_data_rect.w),
                    @intFromFloat(reduced_data_rect.h),
                    .ptr,
                ) catch return error.MemoryAllocationFailed,
            };

            for (file.editor.transform.?.data_points[0..4]) |*point| {
                const d = point.diff(file.editor.transform.?.point(.pivot).*);
                if (d.length() > file.editor.transform.?.radius) {
                    file.editor.transform.?.radius = d.length() + 4;
                }
            }
        }
    }
}

/// Performs a save operation on the currently open file.
/// Paths without a recognized on-disk extension (e.g. in-memory `untitled-n`) open Save As instead.
pub fn save(editor: *Editor) !void {
    const file = editor.activeFile() orelse return;
    if (!pixi.Internal.File.hasRecognizedSaveExtension(file.path)) {
        editor.requestSaveAs();
        return;
    }
    try file.saveAsync();
}

const save_as_dialog_filters: [3]sdl3.SDL_DialogFileFilter = .{
    .{ .name = "Pixi", .pattern = "pixi" },
    .{ .name = "PNG", .pattern = "png" },
    .{ .name = "JPEG", .pattern = "jpg;jpeg" },
};

/// Opens a Save As dialog: `.pixi` (all layers) or flat `.png` / `.jpg` / `.jpeg` (visible layers composited).
pub fn requestSaveAs(_: *Editor) void {
    const active = pixi.editor.activeFile() orelse return;
    const def = pixi.Internal.File.defaultSaveAsFilename(pixi.app.allocator, active.path) catch {
        std.log.err("Failed to build default save-as name", .{});
        return;
    };
    defer pixi.app.allocator.free(def);
    const current_file_dir: ?[]const u8 = std.fs.path.dirname(active.path);
    pixi.backend.showSaveFileDialog(saveAsDialogCallback, &save_as_dialog_filters, def, current_file_dir);
}

/// Save dialog may invoke this from AppKit outside `Window.begin` / `end`; do not use `currentWindow` here.
pub fn saveAsDialogCallback(paths: ?[][:0]const u8) void {
    if (paths) |p| {
        if (p.len == 0) return;
        const path0 = p[0];
        if (path0.len == 0) return;
        if (pixi.editor.pending_save_as_path) |old| {
            pixi.app.allocator.free(old);
        }
        pixi.editor.pending_save_as_path = pixi.app.allocator.dupe(u8, path0[0..path0.len]) catch {
            dvui.log.err("Save As: out of memory queuing path", .{});
            return;
        };
    }
}

fn processPendingSaveAs(editor: *Editor) void {
    const path = editor.pending_save_as_path orelse return;
    editor.pending_save_as_path = null;
    defer pixi.app.allocator.free(path);

    const ext = std.fs.path.extension(path);
    if (editor.activeFile()) |file| {
        if (std.mem.eql(u8, ext, ".pixi")) {
            file.saveAsPixi(path, dvui.currentWindow()) catch |err| {
                dvui.log.err("Save As: {any}", .{err});
            };
        } else if (std.mem.eql(u8, ext, ".png") or
            std.mem.eql(u8, ext, ".jpg") or
            std.mem.eql(u8, ext, ".jpeg"))
        {
            file.saveAsFlattened(path, dvui.currentWindow()) catch |err| {
                dvui.log.err("Save As: {any}", .{err});
            };
        } else {
            dvui.log.err("Save As: choose extension .pixi, .png, .jpg, or .jpeg (got {s})", .{ext});
        }
    }
}

pub fn undo(editor: *Editor) !void {
    if (editor.activeFile()) |file| {
        try file.history.undoRedo(file, .undo);
    }
}

pub fn redo(editor: *Editor) !void {
    if (editor.activeFile()) |file| {
        try file.history.undoRedo(file, .redo);
    }
}

pub fn openInFileBrowser(_: *Editor, path: []const u8) !void {
    const cmd = if (builtin.os.tag == .macos) "open" else if (builtin.os.tag == .linux) "xdg-open" else "start";
    _ = std.process.Child.run(.{ .argv = &.{ cmd, path }, .allocator = pixi.app.allocator }) catch {
        dvui.log.err("Failed to open file browser", .{});
        return;
    };
}

pub fn closeFileID(editor: *Editor, id: u64) !void {
    if (editor.open_files.get(id)) |file| {
        if (file.dirty()) {
            std.log.debug("closeFile: {d} is dirty", .{id});
            return error.FileIsDirty;
        }
        try editor.rawCloseFileID(id);
    }
}

pub fn closeFile(editor: *Editor, index: usize) !void {
    // Handle confirm close if file is dirty
    {
        const file = editor.open_files.values()[index];
        if (file.dirty()) {
            std.log.debug("closeFile: {d} is dirty", .{index});
            // editor.popups.file_confirm_close = true;
            // editor.popups.file_confirm_close_state = .one;
            // editor.popups.file_confirm_close_index = index;
            return;
        }
    }

    try editor.rawCloseFile(index);
}

pub fn rawCloseFile(editor: *Editor, index: usize) !void {
    //editor.open_file_index = 0;
    var file = editor.open_files.values()[index];

    if (editor.workspaces.getPtr(file.editor.grouping)) |workspace| {
        if (workspace.open_file_index == pixi.editor.open_files.getIndex(file.id)) {
            for (pixi.editor.open_files.values(), 0..) |f, i| {
                if (f.grouping == workspace.grouping and f.id != file.id) {
                    workspace.open_file_index = i;
                    break;
                }
            }
        }
    }

    file.deinit();
    editor.open_files.orderedRemoveAt(index);
}

pub fn rawCloseFileID(editor: *Editor, id: u64) !void {
    if (editor.open_files.getPtr(id)) |file| {

        //editor.open_file_index = 0;
        if (editor.workspaces.getPtr(file.editor.grouping)) |workspace| {
            if (workspace.open_file_index == pixi.editor.open_files.getIndex(file.id)) {
                for (pixi.editor.open_files.values(), 0..) |f, i| {
                    if (f.editor.grouping == workspace.grouping and f.id != file.id) {
                        workspace.open_file_index = i;
                        break;
                    }
                }
            }
        }
        file.deinit();
        _ = editor.open_files.orderedRemove(id);
    }
}

pub fn closeReference(editor: *Editor, index: usize) !void {
    editor.open_reference_index = 0;
    var reference: pixi.Internal.Reference = editor.open_references.orderedRemove(index);
    reference.deinit();
}

pub fn deinit(editor: *Editor) !void {
    if (editor.pending_save_as_path) |p| {
        pixi.app.allocator.free(p);
        editor.pending_save_as_path = null;
    }

    if (editor.colors.palette) |*palette| palette.deinit();
    if (editor.colors.file_tree_palette) |*palette| palette.deinit();

    editor.recents.save(pixi.app.allocator, try std.fs.path.join(pixi.app.allocator, &.{ editor.config_folder, "recents.json" })) catch {
        dvui.log.err("Failed to save recents", .{});
    };
    editor.recents.deinit();

    try editor.settings.save(pixi.app.allocator, try std.fs.path.join(pixi.app.allocator, &.{ editor.config_folder, "settings.json" }));
    editor.settings.deinit(pixi.app.allocator);

    if (editor.project) |*project| {
        project.save() catch {
            dvui.log.err("Failed to save project file", .{});
        };
        project.deinit(pixi.app.allocator);
    }

    editor.explorer.deinit();

    editor.tools.deinit(pixi.app.allocator);

    if (editor.folder) |folder| pixi.app.allocator.free(folder);
    editor.arena.deinit();
}
