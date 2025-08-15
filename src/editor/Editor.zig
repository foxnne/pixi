const std = @import("std");
const builtin = @import("builtin");

const pixi = @import("../pixi.zig");
const dvui = @import("dvui");

const App = pixi.App;
const Editor = @This();

pub const Colors = @import("Colors.zig");
pub const Project = @import("Project.zig");
pub const Recents = @import("Recents.zig");
pub const Settings = @import("Settings.zig");
//pub const Theme = @import("Theme.zig");
pub const Tools = @import("Tools.zig");

pub const Hotkeys = @import("Hotkeys.zig");

const zstbi = @import("zstbi");
const nfd = @import("nfd");
const zmath = @import("zmath");

// Modules
pub const Artboard = @import("Artboard.zig");
pub const Explorer = @import("explorer/Explorer.zig");
//pub const Popups = @import("popups/Popups.zig");
pub const Sidebar = @import("Sidebar.zig");
pub const Menu = @import("Menu.zig");

/// This arena is for small per-frame editor allocations, such as path joins, null terminations and labels.
/// Do not free these allocations, instead, this allocator will be .reset(.retain_capacity) each frame
arena: std.heap.ArenaAllocator,
//allocator: std.mem.Allocator,

atlas: pixi.Internal.Atlas,

//theme: Theme,
settings: Settings,
//hotkeys: pixi.input.Hotkeys,
//mouse: pixi.input.Mouse,
recents: Recents,

// Module pointers
explorer: *Explorer,
//popups: *Popups,
artboard: *Artboard,

/// Artboards stored by their grouping ID
artboards: std.AutoArrayHashMap(u64, Artboard) = undefined,
sidebar: Sidebar,

/// The root folder that will be searched for files and a .pixiproject file
folder: ?[:0]const u8 = null,
/// The current project which, if present, handles export paths
project: ?Project = null,
/// Backing allocations for the project paths
//buffers: Buffers = .{},

//previous_atlas_export: ?[:0]const u8 = null,
//open_files: std.ArrayList(pixi.Internal.File) = undefined,
open_files: std.AutoArrayHashMap(u64, pixi.Internal.File) = undefined,
//open_references: std.ArrayList(pixi.Internal.Reference) = undefined,

open_artboard_grouping: u64 = 0,

open_file_index: usize = 0,
open_reference_index: usize = 0,

tools: Tools,
colors: Colors = .{},

grouping_id_counter: u64 = 0,
file_id_counter: u64 = 0,

//selection_time: f32 = 0.0,
//selection_invert: bool = false,

//clipboard_image: ?zstbi.Image = null,
//clipboard_position: [2]u32 = .{ 0, 0 },

//counter: u64 = 0,

// pub const Buffers = struct {
//     atlas_path: [std.fs.max_path_bytes + 1:0]u8 = [_:0]u8{0} ** (std.fs.max_path_bytes + 1),
//     texture_path: [std.fs.max_path_bytes + 1:0]u8 = [_:0]u8{0} ** (std.fs.max_path_bytes + 1),
//     heightmap_path: [std.fs.max_path_bytes + 1:0]u8 = [_:0]u8{0} ** (std.fs.max_path_bytes + 1),
// };

pub fn init(
    app: *App,
) !Editor {
    var editor: Editor = .{
        //.theme = undefined, // Leave theme undefined for now since settings need to load first
        .explorer = try app.allocator.create(Explorer),
        .artboard = try app.allocator.create(Artboard),
        .sidebar = try .init(),
        .settings = try .load(app.allocator),
        .recents = try .load(app.allocator),
        .arena = .init(std.heap.page_allocator),
        .atlas = .{
            .data = try .loadFromFile(app.allocator, pixi.paths.@"pixi.atlas"),
            .source = try pixi.image.fromImageFilePath(pixi.paths.@"pixi.png", pixi.paths.@"pixi.png", .ptr),
        },
        .tools = try .init(app.allocator),
        //.allocator = app.allocator,
    };

    editor.explorer.* = .init();
    editor.artboard.* = .init(0);
    editor.open_files = .init(pixi.app.allocator);
    editor.artboards = .init(pixi.app.allocator);
    editor.artboards.put(0, .init(0)) catch |err| {
        std.log.err("Failed to create artboard: {s}", .{@errorName(err)});
        return err;
    };
    //editor.open_references = std.ArrayList(pixi.Internal.Reference).init(editor.allocator);

    editor.colors.file_tree_palette = try pixi.Internal.Palette.loadFromFile(pixi.paths.@"pear36.hex");

    try Hotkeys.register();

    return editor;
}

pub fn currentGroupingID(editor: *Editor) u64 {
    return editor.open_artboard_grouping;
}

pub fn newGroupingID(editor: *Editor) u64 {
    editor.grouping_id_counter += 1;
    return editor.grouping_id_counter;
}

pub fn newFileID(editor: *Editor) u64 {
    editor.file_id_counter += 1;
    return editor.file_id_counter;
}

// pub fn loadTheme(editor: *Editor) !void {
//     _ = editor; // autofix
//     //const theme_path = try std.fs.path.joinZ(editor.arena, &.{ pixi.paths.themes, editor.settings.theme });

//     //editor.theme = try Theme.loadOrDefault(theme_path);
//     //editor.theme.init();
// }

// pub fn processDialogRequest(editor: *Editor) !void {
//     if (editor.popups.file_dialog_request) |request| {
//         defer editor.popups.file_dialog_request = null;
//         const initial = if (request.initial) |initial| initial else editor.folder;

//         if (switch (request.state) {
//             .file => try nfd.openFileDialog(request.filter, initial),
//             .folder => try nfd.openFolderDialog(initial),
//             .save => try nfd.saveFileDialog(request.filter, initial),
//         }) |path| {
//             editor.popups.file_dialog_response = .{
//                 .path = path,
//                 .type = request.type,
//             };
//         }
//     }
// }

const handle_size = 10;
const handle_dist = 60;

pub fn tick(editor: *Editor) !dvui.App.Result {
    try Hotkeys.tick();

    editor.rebuildArtboards() catch {
        dvui.log.err("Failed to rebuild artboards", .{});
    };

    { // Radial Menu
        for (dvui.events()) |*e| {
            switch (e.evt) {
                .mouse => |me| {
                    editor.tools.radial_menu.mouse_position = me.p;
                },
                else => {},
            }
        }

        if (editor.tools.radial_menu.visible) {
            var fw = dvui.FloatingWidget.init(@src(), .{
                .rect = .cast(dvui.windowRect()),
                .background = false,
            });
            defer fw.deinit();
            fw.install();

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

                var rect = dvui.Rect.fromPoint(new_center);

                rect.w = 48.0;
                rect.h = 48.0;
                rect.x -= rect.w / 2.0;
                rect.y -= rect.h / 2.0;

                const tool = @as(Editor.Tools.Tool, @enumFromInt(i));

                var button = dvui.ButtonWidget.init(@src(), .{}, .{
                    .rect = rect,
                    .id_extra = i,
                    .corner_radius = dvui.Rect.all(1000.0),
                    .color_fill = if (tool == editor.tools.current) dvui.themeGet().color(.control, .fill_hover) else dvui.themeGet().color(.control, .fill),
                    .box_shadow = .{
                        .color = .black,
                        .offset = .{ .x = -4.0, .y = 4.0 },
                        .fade = 8.0,
                        .alpha = 0.25,
                    },
                    .border = dvui.Rect.all(1.0),
                    .color_border = color,
                });

                const sprite = switch (@as(Editor.Tools.Tool, @enumFromInt(i))) {
                    .pointer => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.dropper_default],
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

                button.install();
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
        }
    }

    var scaler = dvui.scale(
        @src(),
        .{ .scale = &dvui.currentWindow().content_scale, .pinch_zoom = .global },
        .{ .expand = .both },
    );
    defer scaler.deinit();

    var explorer_artboard = pixi.dvui.paned(@src(), .{
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
        .background = true,
        //.min_size_content = .{ .h = 100, .w = 100 },
        .color_fill = dvui.themeGet().color(.control, .fill),
    });
    defer explorer_artboard.deinit();

    if (dvui.firstFrame(explorer_artboard.wd.id)) {
        explorer_artboard.split_ratio.* = 0.0;
        explorer_artboard.animateSplit(pixi.editor.settings.explorer_ratio);
    } else if (!explorer_artboard.collapsing and !explorer_artboard.collapsed_state) {
        editor.settings.explorer_ratio = explorer_artboard.split_ratio.*;
    }

    if (explorer_artboard.showFirst()) {
        const hbox = dvui.box(
            @src(),
            .{ .dir = .horizontal },
            .{
                .expand = .both,
                .background = false,
                //.color_fill = dvui.themeGet().color(.control, .fill),
            },
        );
        defer hbox.deinit();

        // Sidebar area
        {
            const result = try editor.sidebar.draw();
            if (result != .ok) {
                return result;
            }
        }

        // Explorer area
        {
            const result = try editor.explorer.draw();
            if (result != .ok) {
                return result;
            }
        }
    }

    if (explorer_artboard.showSecond()) {
        const artboard_vbox = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both, .background = false });
        defer artboard_vbox.deinit();

        {
            const result = try Menu.draw();
            if (result != .ok) {
                return result;
            }
        }

        var canvas_flipbook = pixi.dvui.paned(@src(), .{
            .direction = .vertical,
            .collapsed_size = pixi.editor.settings.min_window_size[1] + 1,
            .handle_size = handle_size,
            .handle_dynamic = .{ .handle_size_max = handle_size, .distance_max = handle_dist },
            .uncollapse_ratio = pixi.editor.settings.flipbook_ratio,
        }, .{
            .expand = .both,
            .background = false,
            //.min_size_content = .{ .h = 100, .w = 100 },
        });
        defer canvas_flipbook.deinit();

        if (dvui.firstFrame(canvas_flipbook.wd.id)) {
            canvas_flipbook.collapsed_state = false;
            canvas_flipbook.collapsing = false;
            canvas_flipbook.split_ratio.* = 1.0;
            canvas_flipbook.animateSplit(pixi.editor.settings.flipbook_ratio);
        } else if (!canvas_flipbook.collapsing and !canvas_flipbook.collapsed_state) {
            pixi.editor.settings.flipbook_ratio = canvas_flipbook.split_ratio.*;
        }

        if (canvas_flipbook.showFirst()) {
            // Artboard Area

            const result = try editor.drawArtboards(0);
            if (result != .ok) {
                return result;
            }

            //                     if (result != .ok) {
            //                         return result;
            //                     }

            //const artboard_count = editor.artboards.count();
            //var iterator = editor.artboards.iterator();

            //var previous_split: ?*pixi.dvui.PanedWidget = null;

            // var splits: std.ArrayList(*pixi.dvui.PanedWidget) = std.ArrayList(*pixi.dvui.PanedWidget).init(pixi.app.allocator);
            // defer splits.deinit();

            // for (editor.artboards.values(), 0..) |*artboard, i| {
            //     if (artboard_count > 1) {
            //         if (splits.pop()) |split| {
            //             defer split.deinit();

            //             if (split.showSecond()) {
            //                 if (i < artboard_count - 1) {
            //                     var artboard_split = pixi.dvui.paned(@src(), .{
            //                         .direction = .horizontal,
            //                         .collapsed_size = pixi.editor.settings.min_window_size[1] + 1,
            //                         .handle_size = handle_size,
            //                         .handle_dynamic = .{ .handle_size_max = handle_size, .distance_max = handle_dist },
            //                     }, .{
            //                         .expand = .both,
            //                         .id_extra = artboard.grouping,
            //                     });
            //                     splits.append(artboard_split) catch {
            //                         return error.OutOfMemory;
            //                     };

            //                     if (artboard_split.showFirst()) {
            //                         const result = try artboard.draw();
            //                         if (result != .ok) {
            //                             return result;
            //                         }
            //                     }
            //                 } else {
            //                     const result = try artboard.draw();
            //                     if (result != .ok) {
            //                         return result;
            //                     }
            //                 }
            //             }
            //         } else {
            //             var artboard_split = pixi.dvui.paned(@src(), .{
            //                 .direction = .horizontal,
            //                 .collapsed_size = pixi.editor.settings.min_window_size[1] + 1,
            //                 .handle_size = handle_size,
            //                 .handle_dynamic = .{ .handle_size_max = handle_size, .distance_max = handle_dist },
            //             }, .{
            //                 .expand = .both,
            //                 .id_extra = artboard.grouping,
            //             });
            //             splits.append(artboard_split) catch {
            //                 return error.OutOfMemory;
            //             };

            //             if (artboard_split.showFirst()) {
            //                 const result = try artboard.draw();
            //                 if (result != .ok) {
            //                     return result;
            //                 }
            //             }
            //         }
            //     } else {
            //         const result = try artboard.draw();
            //         if (result != .ok) {
            //             return result;
            //         }
            //     }

            //for (editor.artboards.(), 0..) |grouping_id, i| {

            // if (artboard_count > 1) {
            //     if (i > 0) {
            //         var artboard_split = pixi.dvui.paned(@src(), .{
            //             .direction = .vertical,
            //             .collapsed_size = pixi.editor.settings.min_window_size[1] + 1,
            //             .handle_size = handle_size,
            //             .handle_dynamic = .{ .handle_size_max = handle_size, .distance_max = handle_dist },
            //         }, .{
            //             .expand = .both,
            //             .background = false,
            //             //.min_size_content = .{ .h = 100, .w = 100 },
            //         });
            //         defer artboard_split.deinit();

            //     }
            // } else {
            //     const result = try artboard.draw();
            //     if (result != .ok) {
            //         return result;
            //     }
            // }

        }

        if (canvas_flipbook.showSecond()) {
            const vbox = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both, .background = true, .gravity_y = 0.0 });
            defer vbox.deinit();

            {
                var rs = vbox.data().contentRectScale();
                rs.r.w = 20.0;

                var path: dvui.Path.Builder = .init(dvui.currentWindow().arena());
                path.addRect(rs.r, dvui.Rect.Physical.all(5));

                var triangles = try path.build().fillConvexTriangles(dvui.currentWindow().arena(), .{ .center = rs.r.center(), .color = .white });

                const black: dvui.Color = .black;
                const ca0 = black.opacity(0.1);
                const ca1 = black.opacity(0);

                for (triangles.vertexes) |*v| {
                    const t = std.math.clamp((v.pos.x - rs.r.x) / rs.r.w, 0.0, 1.0);
                    v.col = v.col.multiply(.fromColor(dvui.Color.lerp(ca0, ca1, t)));
                }
                try dvui.renderTriangles(triangles, null);

                triangles.deinit(dvui.currentWindow().arena());
                path.deinit();
            }

            // Flipbook area
            {
                var rs = vbox.data().contentRectScale();
                rs.r.h = 20.0;

                var path: dvui.Path.Builder = .init(dvui.currentWindow().arena());
                path.addRect(rs.r, dvui.Rect.Physical.all(5));

                var triangles = try path.build().fillConvexTriangles(dvui.currentWindow().arena(), .{ .center = rs.r.center(), .color = .white });

                const black: dvui.Color = .black;
                const ca0 = black.opacity(0.1);
                const ca1 = black.opacity(0);

                for (triangles.vertexes) |*v| {
                    const t = std.math.clamp((v.pos.y - rs.r.y) / rs.r.h, 0.0, 1.0);
                    v.col = v.col.multiply(.fromColor(dvui.Color.lerp(ca0, ca1, t)));
                }

                try dvui.renderTriangles(triangles, null);

                triangles.deinit(dvui.currentWindow().arena());
                path.deinit();
            }
        }
    }

    // look at demo() for examples of dvui widgets, shows in a floating window
    dvui.Examples.demo();

    _ = editor.arena.reset(.retain_capacity);

    return .ok;
}

pub fn rebuildArtboards(editor: *Editor) !void {
    {
        // Create artboards for each grouping ID
        for (editor.open_files.values()) |*file| {
            if (!editor.artboards.contains(file.grouping)) {
                editor.artboards.put(file.grouping, .init(file.grouping)) catch |err| {
                    std.log.err("Failed to create artboard: {s}", .{@errorName(err)});
                    return err;
                };
            }
        }

        // Remove artboards that are no longer needed
        for (editor.artboards.values()) |*artboard| {
            if (editor.artboards.count() == 1) {
                break;
            }

            var contains: bool = false;
            for (editor.open_files.values()) |*file| {
                if (file.grouping == artboard.grouping) {
                    contains = true;
                    break;
                }
            }

            if (!contains) {
                if (editor.open_artboard_grouping == artboard.grouping) {
                    const new_index: usize = if (editor.artboards.getIndex(artboard.grouping)) |index| if (index > 0) index - 1 else 0 else 0;
                    editor.open_artboard_grouping = new_index;
                }

                _ = editor.artboards.orderedRemove(artboard.grouping);
                break;
            }
        }
    }
}

pub fn drawArtboards(editor: *Editor, index: usize) !dvui.App.Result {
    if (index >= editor.artboards.count()) return .ok;

    if (index <= editor.artboards.count() - 1) {
        var s = pixi.dvui.paned(@src(), .{
            .direction = .horizontal,
            .collapsed_size = if (index == editor.artboards.count() - 1) std.math.floatMax(f32) else 0,
            .handle_size = handle_size,
            .handle_dynamic = .{ .handle_size_max = handle_size, .distance_max = handle_dist },
        }, .{
            .expand = .both,
        });
        defer s.deinit();

        if (index == editor.artboards.count() - 1) {
            s.split_ratio.* = 1.0;
        }

        if (s.showFirst()) {
            const result = try editor.artboards.values()[index].draw();
            if (result != .ok) {
                return result;
            }
        }

        if (s.showSecond()) {
            const result = try drawArtboards(editor, index + 1);
            if (result != .ok) {
                return result;
            }
        }
    } else {
        const result = try editor.artboards.values()[index].draw();
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
        pixi.app.allocator.free(folder);
    }
    editor.folder = try pixi.app.allocator.dupeZ(u8, path);
    try editor.recents.appendFolder(try pixi.app.allocator.dupeZ(u8, path));
    editor.explorer.pane = .files;

    editor.project = Project.load(pixi.app.allocator) catch null;
}

pub fn saving(editor: *Editor) bool {
    for (editor.open_files.items) |file| {
        if (file.saving) return true;
    }
    return false;
}

/// Returns true if a new file was created.
pub fn newFile(editor: *Editor, path: [:0]const u8, import_path: ?[:0]const u8) !bool {
    for (editor.open_files.items, 0..) |file, i| {
        if (std.mem.eql(u8, file.path, path)) {
            editor.setActiveFile(i);
            return false;
        }
    }

    var internal: pixi.Internal.File = .{
        .path = try pixi.app.allocator.dupeZ(u8, path),
        .width = @as(u32, @intCast(editor.popups.file_setup_tiles[0] * editor.popups.file_setup_tile_size[0])),
        .height = @as(u32, @intCast(editor.popups.file_setup_tiles[1] * editor.popups.file_setup_tile_size[1])),
        .tile_width = @as(u32, @intCast(editor.popups.file_setup_tile_size[0])),
        .tile_height = @as(u32, @intCast(editor.popups.file_setup_tile_size[1])),
        .layers = .{},
        .deleted_layers = .{},
        .deleted_heightmap_layers = .{},
        .sprites = .{},
        .selected_sprites = std.ArrayList(usize).init(pixi.app.allocator),
        .animations = .{},
        .keyframe_animations = .{},
        .keyframe_animation_texture = undefined,
        .keyframe_transform_texture = undefined,
        .deleted_animations = .{},
        .background = undefined,
        .history = pixi.Internal.File.History.init(pixi.app.allocator),
        .buffers = pixi.Internal.File.Buffers.init(pixi.app.allocator),
        .temporary_layer = undefined,
        .selection_layer = undefined,
    };

    try internal.createBackground();

    internal.temporary_layer = .{
        .name = "Temporary",
        .texture = try pixi.gfx.Texture.createEmpty(internal.width, internal.height, .{}),
    };

    internal.selection_layer = .{
        .name = "Selection",
        .texture = try pixi.gfx.Texture.createEmpty(internal.width, internal.height, .{}),
    };

    var new_layer: pixi.Internal.Layer = .{
        .name = try std.fmt.allocPrintZ(pixi.app.allocator, "{s}", .{"Layer 0"}),
        .texture = undefined,
        .id = internal.newId(),
    };

    if (import_path) |import| {
        new_layer.texture = try pixi.gfx.Texture.loadFromFile(import, .{});
    } else {
        new_layer.texture = try pixi.gfx.Texture.createEmpty(internal.width, internal.height, .{});
    }

    try internal.layers.append(pixi.app.allocator, new_layer);

    internal.keyframe_animation_texture = try pixi.gfx.Texture.createEmpty(internal.width, internal.height, .{});
    internal.keyframe_transform_texture = .{
        .vertices = .{pixi.Internal.File.TransformVertex{ .position = zmath.f32x4s(0.0) }} ** 4,
        .texture = internal.layers.items(.texture)[0],
    };

    // Create sprites for all tiles.
    {
        const tiles = @as(usize, @intCast(editor.popups.file_setup_tiles[0] * editor.popups.file_setup_tiles[1]));
        try internal.sprites.setCapacity(pixi.app.allocator, tiles);

        var i: usize = 0;
        while (i < tiles) : (i += 1) {
            internal.sprites.appendAssumeCapacity(.{});
        }
    }

    try editor.open_files.insert(0, internal);
    editor.setActiveFile(0);

    return true;
}

/// Returns true if png was imported and new file created.
pub fn importPng(editor: *Editor, png_path: [:0]const u8, new_file_path: [:0]const u8) !bool {
    if (!std.mem.eql(u8, std.fs.path.extension(png_path)[0..4], ".png"))
        return false;

    if (!std.mem.eql(u8, std.fs.path.extension(new_file_path)[0..5], ".pixi"))
        return false;

    return try editor.newFile(new_file_path, png_path);
}

/// Returns true if a new file was opened.
pub fn openFile(editor: *Editor, path: []const u8, grouping: u64) !bool {
    if (!std.mem.eql(u8, std.fs.path.extension(path[0..path.len]), ".pixi"))
        return false;

    for (editor.open_files.values(), 0..) |*file, i| {
        if (std.mem.eql(u8, file.path, path)) {
            editor.setActiveFile(i);
            return false;
        }
    }

    if (editor.artboards.contains(grouping)) {
        editor.open_artboard_grouping = grouping;
    }

    if (try pixi.Internal.File.load(path)) |file| {
        try editor.open_files.put(file.id, file);
        if (editor.open_files.getPtr(file.id)) |f| {
            f.grouping = grouping;
        }

        editor.rebuildArtboards() catch {
            dvui.log.err("Failed to rebuild artboards", .{});
        };

        editor.setActiveFile(editor.open_files.count() - 1);

        return true;
    }
    return error.FailedToOpenFile;
}

// pub fn openReference(editor: *Editor, path: [:0]const u8) !bool {
//     for (editor.open_references.items, 0..) |reference, i| {
//         if (std.mem.eql(u8, reference.path, path)) {
//             editor.setActiveReference(i);
//             return false;
//         }
//     }

//     const texture = try pixi.gfx.Texture.loadFromFile(path, .{});

//     const reference: pixi.Internal.Reference = .{
//         .path = try pixi.app.allocator.dupeZ(u8, path),
//         .texture = texture,
//     };

//     try editor.open_references.insert(0, reference);
//     editor.setActiveReference(0);

//     if (!editor.popups.references)
//         editor.popups.references = true;

//     return true;
// }

pub fn setActiveFile(editor: *Editor, index: usize) void {
    if (index >= editor.open_files.values().len) return;
    const grouping = editor.open_files.values()[index].grouping;

    if (editor.artboards.getPtr(grouping)) |artboard| {
        editor.open_artboard_grouping = grouping;
        artboard.open_file_index = index;
    }

    //const file = &editor.open_files.values()[index];
    // if (file.heightmap.layer == null) {
    //     if (editor.tools.current == .heightmap)
    //         editor.tools.current = .pointer;
    // }
    // if (file.transform_texture != null and editor.tools.current != .pointer) {
    //     editor.tools.set(.pointer);
    // }
    //editor.open_file_index = index;
}

pub fn setCopyFile(editor: *Editor, index: usize) void {
    if (index >= editor.open_files.values().len) return;
    const file = &editor.open_files.values()[index];
    if (file.heightmap.layer == null) {
        if (editor.tools.current == .heightmap)
            editor.tools.current = .pointer;
    }
    editor.copy_file_index = index;
}

pub fn setActiveReference(editor: *Editor, index: usize) void {
    if (index >= editor.open_references.items.len) return;
    editor.open_reference_index = index;
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

pub fn getReference(editor: *Editor, index: usize) ?*pixi.Internal.Reference {
    if (editor.open_references.items.len == 0) return null;
    if (index >= editor.open_references.items.len) return null;

    return &editor.open_references.items[index];
}

pub fn forceCloseFile(editor: *Editor, index: usize) !void {
    if (editor.getFile(index)) |file| {
        _ = file;
        return editor.rawCloseFile(index);
    }
}

pub fn forceCloseAllFiles(editor: *Editor) !void {
    const len: usize = editor.open_files.items.len;
    var i: usize = 0;
    while (i < len) : (i += 1) {
        try editor.forceCloseFile(0);
    }
}

/// Performs a save operation on the currently open file.
/// Also will perform a full project pack and export if project.pack_on_save is true
pub fn save(editor: *Editor) !void {
    // if (editor.folder) |project_folder| {
    //     if (editor.project) |*project| {
    //         if (project.pack_on_save) {
    //             try pixi.packer.appendProject();
    //             try pixi.packer.packAndClear();
    //             try project.exportAssets(project_folder);
    //         }
    //     }
    // }

    if (editor.open_files.values().len == 0) return;
    var file = &editor.open_files.values()[editor.open_file_index];
    try file.saveAsync();
}

pub fn saveAllFiles(editor: *Editor) !void {
    for (editor.open_files.items) |*file| {
        _ = try file.save();
    }
}

pub fn closeFileID(editor: *Editor, id: u64) !void {
    if (editor.open_files.get(id)) |file| {
        if (file.dirty()) {
            std.log.debug("closeFile: {d} is dirty", .{id});
            return;
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

    if (editor.artboards.getPtr(file.grouping)) |artboard| {
        artboard.open_file_index = 0;
    }

    file.deinit();
    editor.open_files.orderedRemoveAt(index);

    editor.rebuildArtboards() catch {
        dvui.log.err("Failed to rebuild artboards", .{});
    };
}

pub fn rawCloseFileID(editor: *Editor, id: u64) !void {
    if (editor.open_files.getPtr(id)) |file| {
        //editor.open_file_index = 0;
        if (editor.artboards.getPtr(file.grouping)) |artboard| {
            artboard.open_file_index = 0;
        }
        file.deinit();
        _ = editor.open_files.orderedRemove(id);

        editor.rebuildArtboards() catch {
            dvui.log.err("Failed to rebuild artboards", .{});
        };
    }
}

pub fn closeReference(editor: *Editor, index: usize) !void {
    editor.open_reference_index = 0;
    var reference: pixi.Internal.Reference = editor.open_references.orderedRemove(index);
    reference.deinit();
}

pub fn deinit(editor: *Editor) !void {
    // for (editor.open_files.items) |_| try editor.closeFile(0);
    // editor.open_files.deinit();

    // for (editor.open_references.items) |*reference| reference.deinit();
    // editor.open_references.deinit();

    //if (editor.atlas.data) |*data| data.deinit(editor.allocator);
    //if (editor.previous_atlas_export) |path| editor.allocator.free(path);

    //if (editor.atlas.texture) |*texture| texture.deinit();
    //if (editor.atlas.heightmap) |*heightmap| heightmap.deinit();
    if (editor.colors.palette) |*palette| palette.deinit();
    if (editor.colors.file_tree_palette) |*palette| palette.deinit();

    // editor.allocator.free(editor.hotkeys.hotkeys);
    // editor.allocator.free(editor.mouse.buttons);

    //if (editor.clipboard_image) |*image| image.deinit();

    try editor.recents.save();
    editor.recents.deinit();

    try editor.settings.save(pixi.app.allocator);
    editor.settings.deinit(pixi.app.allocator);

    if (editor.project) |*project| {
        project.save() catch {
            dvui.log.err("Failed to save project file", .{});
        };
        project.deinit(pixi.app.allocator);
    }

    if (editor.folder) |folder| pixi.app.allocator.free(folder);
    editor.arena.deinit();
}
