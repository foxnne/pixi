const std = @import("std");
const builtin = @import("builtin");
const icons = @import("icons");
const assets = @import("assets");
const known_folders = @import("known-folders");
const objc = @import("objc");
const sdl3 = @import("backend").c;

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

pub const SpriteClipboard = struct {
    source: dvui.ImageSource,
    offset: dvui.Point,
};

pub fn init(
    app: *App,
) !Editor {
    const config_folder = std.fs.path.join(pixi.app.allocator, &.{
        try known_folders.getPath(dvui.currentWindow().arena(), .local_configuration) orelse app.root_path,
        "Pixi",
    }) catch app.root_path;
    const palette_folder = std.fs.path.join(pixi.app.allocator, &.{ config_folder, "Palettes" }) catch config_folder;

    var theme = dvui.themeGet();

    theme.window = .{
        .fill = .{ .r = 34, .g = 35, .b = 42, .a = 255 },
        .fill_hover = .{ .r = 62, .g = 64, .b = 74, .a = 255 },
        .fill_press = .{ .r = 32, .g = 34, .b = 44, .a = 255 },
        //.fill_hover = .{ .r = 64, .g = 68, .b = 78, .a = 255 },
        //.fill_press = theme.window.fill,
        .border = .{ .r = 48, .g = 52, .b = 62, .a = 255 },
        .text = .{ .r = 206, .g = 163, .b = 127, .a = 255 },
        .text_hover = theme.window.text,
        .text_press = theme.window.text,
    };

    theme.control = .{
        .fill = .{ .r = 42, .g = 44, .b = 54, .a = 255 },
        .fill_hover = .{ .r = 62, .g = 64, .b = 74, .a = 255 },
        .fill_press = .{ .r = 32, .g = 34, .b = 44, .a = 255 },
        .border = .{ .r = 48, .g = 52, .b = 62, .a = 255 },
        .text = .{ .r = 134, .g = 138, .b = 148, .a = 255 },
        .text_hover = .{ .r = 124, .g = 128, .b = 138, .a = 255 },
        .text_press = .{ .r = 124, .g = 128, .b = 138, .a = 255 },
    };

    theme.highlight = .{
        .fill = .{ .r = 47, .g = 179, .b = 135, .a = 255 },
        //.fill_hover = theme.highlight.fill.?.average(theme.control.fill_hover.?),
        //.fill_press = theme.highlight.fill.?.average(theme.control.fill_press.?),
        .border = .{ .r = 48, .g = 52, .b = 62, .a = 255 },
        .text = theme.window.fill,
        .text_hover = theme.window.fill,
        .text_press = theme.window.fill,
    };

    // theme.content
    theme.fill = theme.window.fill.?;
    theme.border = theme.window.border.?;
    theme.fill_hover = theme.control.fill_hover.?;
    theme.fill_press = theme.control.fill_press.?;
    theme.text = theme.window.text.?;
    theme.text_hover = theme.window.text_hover.?;
    theme.text_press = theme.window.text_press.?;
    theme.focus = theme.highlight.fill.?;

    theme.dark = true;
    theme.name = "Pixi Dark";
    theme.font_body = .find(.{ .family = "Vera Sans", .size = 8 });
    theme.font_title = .find(.{ .family = "Vera Sans", .size = 10, .weight = .bold });
    theme.font_heading = .find(.{ .family = "Vera Sans", .size = 8, .style = .italic });
    theme.font_mono = .find(.{ .family = "CozetteVector", .size = 10 });

    dvui.themeSet(theme);

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

    editor.themes.append(theme) catch {
        dvui.log.err("Failed to append theme", .{});
        return error.FailedToAppendTheme;
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
    editor.recents = Recents.load(app.allocator, try std.fs.path.join(app.allocator, &.{ editor.config_folder, "recents.json" })) catch .{
        .folders = .init(app.allocator),
    };

    pixi.backend.setTitlebarColor(dvui.currentWindow(), theme.control.fill.?.opacity(editor.settings.window_opacity));

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
    defer editor.dim_titlebar = false;
    editor.setTitlebarColor();

    editor.rebuildWorkspaces() catch {
        dvui.log.err("Failed to rebuild workspaces", .{});
    };

    // TODO: Does this need to be here for touchscreen zooming? Or does that belong in canvas?
    // var scaler = dvui.scale(
    //     @src(),
    //     .{ .scale = &dvui.currentWindow().content_scale, .pinch_zoom = .global },
    //     .{ .expand = .both },
    // );
    // defer scaler.deinit();

    {
        var base_box = dvui.box(
            @src(),
            .{ .dir = .horizontal },
            .{
                .expand = .both,
                .background = if (builtin.os.tag == .macos) false else true,
                .color_fill = dvui.themeGet().color(.control, .fill),
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

        if (dvui.firstFrame(editor.explorer.paned.wd.id)) {
            editor.explorer.paned.split_ratio.* = 0.0;
            editor.explorer.paned.animateSplit(pixi.editor.settings.explorer_ratio);

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

            {
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
                        editor.panel.paned.animateSplit(1.0 - pixi.editor.settings.panel_ratio);
                    }
                } else {
                    if (!editor.panel.paned.animating and editor.panel.paned.split_ratio.* < 1.0) {
                        editor.panel.paned.animateSplit(1.0);
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
    dvui.Examples.demo();

    _ = editor.arena.reset(.retain_capacity);

    return .ok;
}

pub fn setTitlebarColor(editor: *Editor) void {
    const color = if (editor.dim_titlebar) dvui.themeGet().color(.control, .fill).lerp(.black, if (dvui.themeGet().dark) 60.0 / 255.0 else 80.0 / 255.0) else dvui.themeGet().color(.control, .fill);

    if (!std.mem.eql(u8, &editor.last_titlebar_color.toRGBA(), &color.toRGBA())) {
        editor.last_titlebar_color = color;
        pixi.backend.setTitlebarColor(dvui.currentWindow(), color.opacity(editor.settings.window_opacity));
    }
}

pub fn drawRadialMenu(editor: *Editor) !void {
    var fw: dvui.FloatingWidget = undefined;
    fw.init(@src(), .{}, .{
        .rect = .cast(dvui.windowRect()),
    });
    defer fw.deinit();

    const menu_color = dvui.themeGet().color(.control, .fill).lighten(4.0);

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
            .alpha = 0.25,
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
            .color_fill = if (tool == editor.tools.current) dvui.themeGet().color(.control, .fill_hover) else menu_color,
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

        const sprite = switch (@as(Editor.Tools.Tool, @enumFromInt(i))) {
            .pointer => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.cursor_default],
            .pencil => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.pencil_default],
            .eraser => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.eraser_default],
            .bucket => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.bucket_default],
            .selection => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.selection_default],
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
        .color_fill = dvui.themeGet().color(.window, .fill),
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
        s.animateSplit(1.0);
    }

    if (!s.dragging and !s.animating and !s.collapsing and !s.collapsed_state) {
        if (index == editor.workspaces.count() - 1) {
            if (s.split_ratio.* != 1.0) {
                s.animateSplit(1.0);
            }
        } else {
            if (dvui.firstFrame(s.wd.id)) {
                s.split_ratio.* = 1.0;
                s.animateSplit(0.5);
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
        return true;
    }
    return error.FailedToOpenFile;
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

    return editor.open_files.getPtr(file.id) orelse return error.FailedToCreateFile;
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
pub fn save(editor: *Editor) !void {
    if (editor.activeFile()) |file| {
        try file.saveAsync();
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

    if (editor.folder) |folder| pixi.app.allocator.free(folder);
    editor.arena.deinit();
}
