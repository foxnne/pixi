const std = @import("std");

const dvui = @import("dvui");
const pixi = @import("../pixi.zig");
const icons = @import("icons");

const App = pixi.App;
const Editor = pixi.Editor;

/// Workspaces are drawn recursively inside of the explorer paned widget
/// second pane, and contains drag/drop enabled tabs. Tabs can freely be dragged to
/// panes or other tab bars.
/// Workspaces can potentially draw open files, the project logo, or the project pane
/// containing the packed atlas.
pub const Workspace = @This();

open_file_index: usize = 0,
grouping: u64 = 0,
center: bool = false,

tabs_drag_index: ?usize = null,
tabs_removed_index: ?usize = null,
tabs_insert_before_index: ?usize = null,

columns_drag_index: ?usize = null,
columns_removed_index: ?usize = null,
columns_insert_before_index: ?usize = null,

rows_drag_index: ?usize = null,
rows_removed_index: ?usize = null,
rows_insert_before_index: ?usize = null,

horizontal_scroll_info: dvui.ScrollInfo = .{ .vertical = .given, .horizontal = .given },
vertical_scroll_info: dvui.ScrollInfo = .{ .vertical = .given, .horizontal = .given },

pub fn init(grouping: u64) Workspace {
    return .{ .grouping = grouping };
}

const handle_size = 10;
const handle_dist = 60;

const opacity = 128;

const color_0 = pixi.math.Color.initBytes(0, 0, 0, 0);
const color_1 = pixi.math.Color.initBytes(230, 175, 137, opacity);
const color_2 = pixi.math.Color.initBytes(216, 145, 115, opacity);
const color_3 = pixi.math.Color.initBytes(41, 23, 41, opacity);
const color_4 = pixi.math.Color.initBytes(194, 109, 92, opacity);
const color_5 = pixi.math.Color.initBytes(180, 89, 76, opacity);

const logo_colors: [15]pixi.math.Color = [_]pixi.math.Color{
    color_0, color_1, color_1,
    color_2, color_3, color_2,
    color_4, color_4, color_4,
    color_5, color_3, color_3,
    color_3, color_0, color_0,
};

var dragging: bool = false;

pub fn draw(self: *Workspace) !dvui.App.Result {
    // Canvas Area
    var vbox = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .both,
        .background = true,
        .gravity_y = 0.0,
        .id_extra = self.grouping,
        .color_fill = dvui.themeGet().color(.window, .fill),
    });
    defer vbox.deinit();

    // Set the active workspace grouping when the user clicks on the workspace rect
    for (dvui.events()) |*e| {
        if (!vbox.matchEvent(e)) {
            continue;
        }

        if (e.evt == .mouse) {
            if (e.evt.mouse.action == .press or (e.evt.mouse.action == .position and e.evt.mouse.mod.matchBind("ctrl/cmd"))) {
                pixi.editor.open_workspace_grouping = self.grouping;
            }
        }
    }

    if (pixi.editor.explorer.pane == .project) {
        self.drawProject();
    } else {
        self.drawTabs();
        try self.drawCanvas();
    }

    return .ok;
}

fn drawProject(self: *Workspace) void {
    var canvas_vbox = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both, .id_extra = self.grouping });
    defer canvas_vbox.deinit();

    if (pixi.packer.atlas) |*atlas| {
        var image_widget = pixi.dvui.ImageWidget.init(@src(), .{
            .source = atlas.source,
            .canvas = &atlas.canvas,
        }, .{
            .id_extra = self.grouping,
            .expand = .both,
        });
        defer image_widget.deinit();

        image_widget.processEvents();
    }
}

fn drawTabs(self: *Workspace) void {
    if (pixi.editor.open_files.values().len == 0) return;

    // Handle dragging of tabs between workspace reorderables (tab bars)
    defer self.processTabsDrag();

    var tabs_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .color_fill = dvui.themeGet().color(.window, .fill),
        .corner_radius = dvui.Rect.all(0),
        .margin = dvui.Rect.all(0),
        .padding = dvui.Rect.all(0),
        .id_extra = self.grouping,
    });
    defer tabs_box.deinit();

    var scroll_area = dvui.scrollArea(@src(), .{ .horizontal = .auto, .horizontal_bar = .hide }, .{
        .expand = .horizontal,
        .background = false,
        .corner_radius = dvui.Rect.all(0),
        .id_extra = self.grouping,
    });
    defer scroll_area.deinit();

    var tabs = dvui.reorder(@src(), .{ .drag_name = "tab_drag" }, .{
        .expand = .horizontal,
    });
    defer tabs.deinit();

    var tabs_hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .background = false,
        .corner_radius = dvui.Rect.all(0),
        .margin = dvui.Rect.all(0),
        .padding = dvui.Rect.all(0),
        .id_extra = self.grouping,
    });
    defer tabs_hbox.deinit();

    for (pixi.editor.open_files.values(), 0..) |file, i| {
        const is_pixi_file = std.mem.endsWith(u8, file.path, ".pixi");

        if (file.editor.grouping != self.grouping) continue;

        var reorderable = tabs.reorderable(@src(), .{}, .{
            .expand = .vertical,
            .id_extra = i,
            .padding = dvui.Rect.all(0),
            .margin = dvui.Rect.all(0),
        });
        defer reorderable.deinit();

        const selected = self.open_file_index == i and pixi.editor.open_workspace_grouping == self.grouping;

        var hbox: dvui.BoxWidget = undefined;
        hbox.init(@src(), .{ .dir = .horizontal }, .{
            .expand = .none,
            .border = .{ .h = 1 },
            .color_border = if (selected) dvui.themeGet().color(.window, .text) else dvui.themeGet().color(.window, .fill),
            .color_fill = if (selected) dvui.themeGet().color(.control, .fill) else dvui.themeGet().color(.window, .fill),
            .background = true,
            .id_extra = i,
            .padding = dvui.Rect.all(2),
            .margin = dvui.Rect.all(0),
        });

        defer hbox.deinit();

        var hovered = false;
        if (pixi.dvui.hovered(hbox.data())) {
            hovered = true;
            hbox.data().options.color_fill = dvui.themeGet().color(.control, .fill);
            if (!selected)
                hbox.data().options.color_border = dvui.themeGet().color(.control, .fill);
        }
        hbox.drawBackground();

        if (reorderable.floating()) {
            self.tabs_drag_index = i;
        }

        if (reorderable.removed()) {
            self.tabs_removed_index = i;
        } else if (reorderable.insertBefore()) {
            self.tabs_insert_before_index = i;
        }

        if (is_pixi_file) {
            _ = pixi.dvui.sprite(@src(), .{
                .source = pixi.editor.atlas.source,
                .sprite = pixi.editor.atlas.data.sprites[pixi.atlas.sprites.logo_default],
                .scale = 2.0,
            }, .{
                .gravity_y = 0.5,
                .padding = dvui.Rect.all(4),
            });
        } else {
            dvui.icon(@src(), "file_icon", icons.tvg.lucide.file, .{
                .stroke_color = if (is_pixi_file) .transparent else dvui.themeGet().color(.control, .text),
            }, .{
                .gravity_y = 0.5,
                .padding = dvui.Rect.all(4),
            });
        }

        dvui.label(@src(), "{s}", .{std.fs.path.basename(file.path)}, .{
            .color_text = if (selected) dvui.themeGet().color(.window, .text) else dvui.themeGet().color(.control, .text),
            .padding = dvui.Rect.all(4),
            .gravity_y = 0.5,
        });

        const status_close_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .min_size_content = .{ .w = 18, .h = 18 },
            .max_size_content = .{ .w = 18, .h = 18 },
            .expand = .none,
            .padding = dvui.Rect.all(2),
        });
        defer status_close_box.deinit();

        if (hovered) {
            if (dvui.buttonIcon(@src(), "close", icons.tvg.lucide.x, .{ .draw_focus = false }, .{}, .{
                .gravity_y = 0.5,
                .padding = dvui.Rect.all(0),
                .corner_radius = dvui.Rect.all(1000),
                .style = .err,
                .expand = .both,
            })) {
                pixi.editor.closeFileID(file.id) catch |err| {
                    dvui.log.err("closeFile: {d} failed: {s}", .{ i, @errorName(err) });
                };
                break;
            }
        } else if (file.dirty()) {
            dvui.icon(@src(), "dirty_icon", icons.tvg.lucide.@"circle-small", .{
                .stroke_color = dvui.themeGet().color(.window, .text),
            }, .{
                .expand = .both,
                .gravity_y = 0.5,
                .padding = dvui.Rect.all(2),
            });
        }

        loop: for (dvui.events()) |*e| {
            if (!hbox.matchEvent(e)) {
                continue;
            }

            switch (e.evt) {
                .mouse => |me| {
                    if (me.action == .press and me.button.pointer()) {
                        pixi.editor.setActiveFile(i);
                        dvui.refresh(null, @src(), hbox.data().id);

                        e.handle(@src(), hbox.data());
                        dvui.captureMouse(hbox.data(), e.num);
                        dvui.dragPreStart(me.p, .{ .size = reorderable.data().rectScale().r.size(), .offset = reorderable.data().rectScale().r.topLeft().diff(me.p) });
                    } else if (me.action == .release and me.button.pointer()) {
                        dvui.captureMouse(null, e.num);
                        dvui.dragEnd();
                    } else if (me.action == .motion) {
                        if (dvui.captured(hbox.data().id)) {
                            e.handle(@src(), hbox.data());
                            if (dvui.dragging(me.p, null)) |_| {
                                reorderable.reorder.dragStart(reorderable.data().id.asUsize(), me.p, 0); // reorder grabs capture
                                break :loop;
                            }
                        }
                    }
                },

                else => {},
            }
        }
    }
    if (tabs.finalSlot()) {
        self.tabs_insert_before_index = pixi.editor.open_files.values().len;
    }
}

pub fn processTabsDrag(self: *Workspace) void {
    if (self.tabs_insert_before_index) |insert_before| {
        if (self.tabs_removed_index) |removed| { // Dragging from this workspace

            if (removed > pixi.editor.open_files.count()) return;
            if (removed > insert_before) {
                std.mem.swap(pixi.Internal.File, &pixi.editor.open_files.values()[removed], &pixi.editor.open_files.values()[insert_before]);
                std.mem.swap(u64, &pixi.editor.open_files.keys()[removed], &pixi.editor.open_files.keys()[insert_before]);
                pixi.editor.setActiveFile(insert_before);
            } else {
                if (insert_before > 0) {
                    std.mem.swap(pixi.Internal.File, &pixi.editor.open_files.values()[removed], &pixi.editor.open_files.values()[insert_before - 1]);
                    std.mem.swap(u64, &pixi.editor.open_files.keys()[removed], &pixi.editor.open_files.keys()[insert_before - 1]);
                    pixi.editor.setActiveFile(insert_before - 1);
                } else {
                    std.mem.swap(pixi.Internal.File, &pixi.editor.open_files.values()[removed], &pixi.editor.open_files.values()[insert_before]);
                    std.mem.swap(u64, &pixi.editor.open_files.keys()[removed], &pixi.editor.open_files.keys()[insert_before]);
                    pixi.editor.setActiveFile(insert_before);
                }
            }

            self.tabs_removed_index = null;
            self.tabs_insert_before_index = null;
        } else { // Dragging from another workspace
            for (pixi.editor.workspaces.values()) |*workspace| {
                if (workspace.tabs_removed_index) |removed| {
                    if (removed > insert_before) {
                        std.mem.swap(pixi.Internal.File, &pixi.editor.open_files.values()[removed], &pixi.editor.open_files.values()[insert_before]);
                        std.mem.swap(u64, &pixi.editor.open_files.keys()[removed], &pixi.editor.open_files.keys()[insert_before]);

                        pixi.editor.open_files.values()[insert_before].editor.grouping = self.grouping;
                        pixi.editor.setActiveFile(insert_before);
                    } else {
                        if (insert_before > 0) {
                            std.mem.swap(pixi.Internal.File, &pixi.editor.open_files.values()[removed], &pixi.editor.open_files.values()[insert_before - 1]);
                            std.mem.swap(u64, &pixi.editor.open_files.keys()[removed], &pixi.editor.open_files.keys()[insert_before - 1]);
                            pixi.editor.open_files.values()[insert_before - 1].editor.grouping = self.grouping;
                            pixi.editor.setActiveFile(insert_before - 1);
                        } else {
                            std.mem.swap(pixi.Internal.File, &pixi.editor.open_files.values()[removed], &pixi.editor.open_files.values()[insert_before]);
                            std.mem.swap(u64, &pixi.editor.open_files.keys()[removed], &pixi.editor.open_files.keys()[insert_before]);
                            pixi.editor.open_files.values()[insert_before].editor.grouping = self.grouping;
                            pixi.editor.setActiveFile(insert_before);
                        }
                    }

                    self.tabs_removed_index = null;
                    self.tabs_insert_before_index = null;

                    workspace.tabs_removed_index = null;
                    workspace.tabs_insert_before_index = null;
                }
            }
        }
    }
}

/// Responsible for handling the cross-widget drag of tabs between multiple workspaces or between tabs and workspaces
pub fn processTabDrag(self: *Workspace, data: *dvui.WidgetData) void {
    if (dvui.dragName("tab_drag")) {
        for (dvui.events()) |*e| {
            if (!dvui.eventMatch(e, .{ .id = data.id, .r = data.rectScale().r, .drag_name = "tab_drag" })) continue;

            for (pixi.editor.workspaces.values()) |*workspace| {
                if (workspace.tabs_drag_index) |drag_index| {
                    var right_side = data.rectScale().r;
                    right_side.w /= 2;
                    right_side.x += right_side.w;

                    if (right_side.contains(e.evt.mouse.p) and pixi.editor.workspaces.keys()[pixi.editor.workspaces.keys().len - 1] == self.grouping) {
                        if (e.evt == .mouse and e.evt.mouse.action == .position) {
                            right_side.fill(dvui.Rect.Physical.all(right_side.w / 8), .{
                                .color = dvui.themeGet().color(.highlight, .fill).opacity(0.5),
                            });
                        }

                        if (e.evt == .mouse and e.evt.mouse.action == .release and e.evt.mouse.button.pointer()) {
                            defer workspace.tabs_drag_index = null;
                            // We dropped on the right side of the workspace, so we need to create a new workspace
                            e.handle(@src(), data);
                            dvui.dragEnd();
                            dvui.refresh(null, @src(), data.id);

                            var dragged_file = &pixi.editor.open_files.values()[drag_index];

                            if (workspace.open_file_index == pixi.editor.open_files.getIndex(dragged_file.id)) {
                                for (pixi.editor.open_files.values()) |f| {
                                    if (f.editor.grouping == workspace.grouping and f.id != dragged_file.id) {
                                        workspace.open_file_index = pixi.editor.open_files.getIndex(f.id) orelse 0;
                                        break;
                                    }
                                }
                            }
                            dragged_file.editor.grouping = pixi.editor.newGroupingID();
                            pixi.editor.open_workspace_grouping = dragged_file.editor.grouping;
                        }
                    } else if (data.rectScale().r.contains(e.evt.mouse.p)) {
                        if (e.evt == .mouse and e.evt.mouse.action == .position) {
                            data.rectScale().r.fill(dvui.Rect.Physical.all(data.rectScale().r.w / 8), .{
                                .color = dvui.themeGet().color(.highlight, .fill).opacity(0.5),
                            });
                        }

                        if (e.evt == .mouse and e.evt.mouse.action == .release and e.evt.mouse.button.pointer()) {
                            defer workspace.tabs_drag_index = null;
                            // We dropped on the full workspace, so we need to move the file to this workspace
                            e.handle(@src(), data);
                            dvui.dragEnd();
                            dvui.refresh(null, @src(), data.id);

                            var dragged_file = &pixi.editor.open_files.values()[drag_index];

                            if (workspace.open_file_index == pixi.editor.open_files.getIndex(dragged_file.id)) {
                                for (pixi.editor.open_files.values()) |f| {
                                    if (f.editor.grouping == workspace.grouping and f.id != dragged_file.id) {
                                        workspace.open_file_index = pixi.editor.open_files.getIndex(f.id) orelse 0;
                                        break;
                                    }
                                }
                            }
                            dragged_file.editor.grouping = self.grouping;
                            pixi.editor.open_workspace_grouping = dragged_file.editor.grouping;
                            self.open_file_index = pixi.editor.open_files.getIndex(dragged_file.id) orelse 0;
                        }
                    }
                }
            }
        }
    }
}

pub fn drawCanvas(self: *Workspace) !void {
    var canvas_vbox = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both });
    defer {
        dvui.toastsShow(canvas_vbox.data().id, canvas_vbox.data().contentRectScale().r.toNatural());
        canvas_vbox.deinit();
    }
    defer self.processTabDrag(canvas_vbox.data());

    if (pixi.editor.open_files.values().len > 0) {
        if (self.open_file_index >= pixi.editor.open_files.values().len) {
            self.open_file_index = pixi.editor.open_files.values().len - 1;
        }

        const file = &pixi.editor.open_files.values()[self.open_file_index];
        file.editor.canvas.id = canvas_vbox.data().id;

        if (pixi.editor.settings.show_rulers) {
            defer pixi.dvui.drawEdgeShadow(canvas_vbox.data().rectScale(), .top, .{});
            self.drawHorizontalRuler();
        }

        var canvas_hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .both });
        defer canvas_hbox.deinit();

        if (pixi.editor.settings.show_rulers) {
            defer pixi.dvui.drawEdgeShadow(canvas_vbox.data().rectScale(), .left, .{});
            self.drawVerticalRuler();
        }

        self.drawTransformDialog(canvas_vbox);

        if (self.grouping != file.editor.grouping) return;

        var file_widget = pixi.dvui.FileWidget.init(@src(), .{
            .file = file,
            .center = self.center,
        }, .{
            .expand = .both,
            .background = true,
            .color_fill = dvui.themeGet().color(.window, .fill),
        });

        defer file_widget.deinit();
        file_widget.processEvents();
    } else {
        try self.drawLogo(canvas_vbox);
    }
}

pub fn drawHorizontalRuler(self: *Workspace) void {
    const file = &pixi.editor.open_files.values()[self.open_file_index];
    const font = dvui.Font.theme(.mono).larger(-2.0);

    // Set ruler height to the font height plus some padding
    const ruler_height = font.textSize("M").h + pixi.editor.settings.ruler_padding;

    var canvas_hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
    });
    defer canvas_hbox.deinit();

    const largest_label = std.fmt.allocPrint(dvui.currentWindow().arena(), "{d}", .{file.rows - 1}) catch {
        dvui.log.err("Failed to allocate largest label", .{});
        return;
    };
    const largest_label_size = font.textSize(largest_label);
    const vert_ruler_width = largest_label_size.w + pixi.editor.settings.ruler_padding;

    var corner_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .none,
        .min_size_content = .{ .h = vert_ruler_width, .w = vert_ruler_width },
        .background = false,
        .color_fill = dvui.themeGet().color(.window, .fill).lighten(-2.0).opacity(0.75),
    });
    corner_box.deinit();

    var top_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .min_size_content = .{ .h = ruler_height, .w = ruler_height },
        .background = true,
        .color_fill = dvui.themeGet().color(.window, .fill),
    });
    defer top_box.deinit();

    self.horizontal_scroll_info.virtual_size.w = file.editor.canvas.scroll_info.virtual_size.w;
    self.horizontal_scroll_info.virtual_size.h = ruler_height;
    self.horizontal_scroll_info.viewport.w = file.editor.canvas.scroll_info.viewport.w;
    self.horizontal_scroll_info.viewport.x = file.editor.canvas.scroll_info.viewport.x;

    var horizontal_scroll_area = dvui.scrollArea(@src(), .{
        .scroll_info = &self.horizontal_scroll_info,
        .container = true,
        .process_events_after = true,
        .horizontal_bar = .hide,
        .vertical_bar = .hide,
    }, .{ .expand = .both });
    defer horizontal_scroll_area.deinit();

    var scaler = dvui.scale(@src(), .{ .scale = &file.editor.canvas.scale }, .{ .rect = .{ .x = -file.editor.canvas.origin.x, .y = 0 } });
    defer scaler.deinit();

    var outer_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .none,
        .rect = .{ .x = 0, .y = 0, .w = @as(f32, @floatFromInt(file.width())), .h = ruler_height / file.editor.canvas.scale },
    });
    defer outer_box.deinit();

    var columns = pixi.dvui.reorder(@src(), .{ .drag_name = "column_drag" }, .{
        .expand = .both,
        .margin = dvui.Rect.all(0),
        .padding = dvui.Rect.all(0),
        .background = false,
        .corner_radius = dvui.Rect.all(0),
    });
    defer columns.deinit();

    var columns_hbox = dvui.box(@src(), .{
        .dir = .horizontal,
    }, .{
        .expand = .both,
        .background = false,
        .corner_radius = dvui.Rect.all(0),
        .margin = dvui.Rect.all(0),
        .padding = dvui.Rect.all(0),
    });
    defer columns_hbox.deinit();

    const ruler_stroke_color = dvui.themeGet().color(.control, .fill_hover).lighten(2.0);

    defer dvui.Path.stroke(
        .{ .points = &.{
            columns_hbox.data().rectScale().r.topRight(),
            columns_hbox.data().rectScale().r.bottomRight(),
        } },
        .{
            .color = ruler_stroke_color,
            .thickness = 2.0,
        },
    );

    for (0..file.columns) |column_index| {
        var reorderable = columns.reorderable(@src(), .{
            .mode = .any_y,
        }, .{
            .expand = .vertical,
            .id_extra = column_index,
            .padding = dvui.Rect.all(0),
            .margin = dvui.Rect.all(0),
            .min_size_content = .{ .h = 1, .w = @as(f32, @floatFromInt(file.column_width)) },
        });
        defer reorderable.deinit();
        var button_color = if (columns.drag_point != null) dvui.themeGet().color(.control, .fill).opacity(0.75) else dvui.themeGet().color(.window, .fill);

        if (pixi.dvui.hovered(reorderable.data())) {
            button_color = dvui.themeGet().color(.control, .fill);
            dvui.cursorSet(.hand);
        }

        var cell_box: dvui.BoxWidget = undefined;
        cell_box.init(@src(), .{ .dir = .horizontal }, .{
            .expand = .both,
            .background = true,
            .color_fill = button_color,
            .id_extra = column_index,
        });

        if (reorderable.floating()) {
            self.rows_drag_index = column_index;
            columns.reorderable_size.h = @as(f32, @floatFromInt(file.height())) + ruler_height / file.editor.canvas.scale;
        }

        {
            defer cell_box.deinit();
            cell_box.drawBackground();

            const label = file.fmtColumn(dvui.currentWindow().arena(), @intCast(column_index)) catch {
                dvui.log.err("Failed to allocate label", .{});
                return;
            };

            const label_size = font.textSize(label).scale(dvui.currentWindow().natural_scale, dvui.Size.Physical);

            var label_rect = cell_box.data().rectScale().r;
            const padding = pixi.editor.settings.ruler_padding * dvui.currentWindow().natural_scale;

            if (label_size.w + padding <= label_rect.w) {
                label_rect.h = label_size.h + padding;
                label_rect.x += (label_rect.w - label_size.w) / 2.0;
                label_rect.y += (label_rect.h - label_size.h) / 2.0;

                dvui.renderText(.{
                    .text = label,
                    .font = font,
                    .color = dvui.themeGet().color(.control, .text),
                    .rs = .{
                        .r = label_rect,
                        .s = dvui.currentWindow().natural_scale,
                    },
                }) catch {
                    dvui.log.err("Failed to render text", .{});
                };
            }

            const top_right = cell_box.data().rectScale().r.topLeft();
            const bottom_right = cell_box.data().rectScale().r.bottomLeft();

            dvui.Path.stroke(.{ .points = &.{ top_right, bottom_right } }, .{ .color = ruler_stroke_color, .thickness = 2.0 });

            if (reorderable.floating()) {
                const top_left = cell_box.data().rectScale().r.topLeft();
                const bottom_left = cell_box.data().rectScale().r.bottomLeft();

                dvui.Path.stroke(.{ .points = &.{ top_left, bottom_left } }, .{ .color = ruler_stroke_color, .thickness = 2.0 });
            }

            loop: for (dvui.events()) |*e| {
                if (!cell_box.matchEvent(e)) {
                    continue;
                }

                switch (e.evt) {
                    .mouse => |me| {
                        if (me.action == .press and me.button.pointer()) {
                            e.handle(@src(), cell_box.data());
                            dvui.captureMouse(cell_box.data(), e.num);
                            dvui.dragPreStart(me.p, .{
                                .size = reorderable.data().rectScale().r.size(),
                                .offset = reorderable.data().rectScale().r.topLeft().diff(me.p),
                            });
                        } else if (me.action == .release and me.button.pointer()) {
                            dvui.captureMouse(null, e.num);
                            dvui.dragEnd();
                            self.columns_drag_index = null;
                        } else if (me.action == .motion) {
                            if (dvui.captured(cell_box.data().id)) {
                                e.handle(@src(), cell_box.data());
                                if (dvui.dragging(me.p, null)) |_| {
                                    reorderable.reorder.dragStart(reorderable.data().id.asUsize(), me.p, 0); // reorder grabs capture
                                    break :loop;
                                }
                            }
                        }
                    },

                    else => {},
                }
            }
        }

        if (reorderable.floating()) {
            const image_rect = dvui.Rect{
                .x = 0,
                .y = ruler_height / file.editor.canvas.scale,
                .w = @as(f32, @floatFromInt(file.column_width)),
                .h = @as(f32, @floatFromInt(file.height())),
            };

            const box = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .rect = image_rect,
                .background = false,
                .color_fill = dvui.themeGet().color(.err, .fill),
            });
            defer box.deinit();

            var i: usize = file.layers.len;

            while (i > 0) {
                i -= 1;
                const layer = file.layers.get(i);
                if (!layer.visible) {
                    continue;
                }

                // UVs cover just the needed portion
                const uv: dvui.Rect = .{
                    .x = @as(f32, @floatFromInt(column_index)) * @as(f32, @floatFromInt(file.column_width)) / @as(f32, @floatFromInt(file.width())),
                    .y = 0.0,
                    .w = @as(f32, @floatFromInt(file.column_width)) / @as(f32, @floatFromInt(file.width())),
                    .h = @as(f32, @floatFromInt(file.height())) / @as(f32, @floatFromInt(file.height())),
                };

                dvui.renderImage(layer.source, box.data().rectScale(), .{
                    .uv = uv,
                }) catch {
                    dvui.log.err("Failed to render checkerboard", .{});
                };
            }
        }
    }

    if (columns.finalSlot(.any_y)) {
        self.columns_insert_before_index = file.columns - 1;
    }
}

pub fn drawVerticalRuler(self: *Workspace) void {
    const file = &pixi.editor.open_files.values()[self.open_file_index];
    const font = dvui.Font.theme(.mono).larger(-2.0);

    const largest_label = std.fmt.allocPrint(dvui.currentWindow().arena(), "{d}", .{file.rows - 1}) catch {
        dvui.log.err("Failed to allocate largest label", .{});
        return;
    };
    const largest_label_size = font.textSize(largest_label);
    const ruler_width = largest_label_size.w + pixi.editor.settings.ruler_padding;

    var ruler_box = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .vertical,
        .min_size_content = .{ .w = ruler_width, .h = 1.0 },
        .background = true,
        .color_fill = dvui.themeGet().color(.window, .fill),
    });
    defer ruler_box.deinit();

    self.vertical_scroll_info.virtual_size.h = file.editor.canvas.scroll_info.virtual_size.h;
    self.vertical_scroll_info.virtual_size.w = ruler_width;
    self.vertical_scroll_info.viewport.h = file.editor.canvas.scroll_info.viewport.h;
    self.vertical_scroll_info.viewport.y = file.editor.canvas.scroll_info.viewport.y;

    var vertical_scroll_area = dvui.scrollArea(@src(), .{
        .scroll_info = &self.vertical_scroll_info,
        .container = true,
        .process_events_after = true,
        .horizontal_bar = .hide,
        .vertical_bar = .hide,
    }, .{ .expand = .both });
    defer vertical_scroll_area.deinit();

    var scaler = dvui.scale(@src(), .{ .scale = &file.editor.canvas.scale }, .{ .rect = .{ .x = 0, .y = -file.editor.canvas.origin.y } });
    defer scaler.deinit();

    var outer_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .none,
        .rect = .{ .x = 0, .y = 0, .h = @as(f32, @floatFromInt(file.height())), .w = ruler_width * (1.0 / file.editor.canvas.scale) },
    });
    defer outer_box.deinit();

    var rows = pixi.dvui.reorder(@src(), .{ .drag_name = "row_drag" }, .{
        .expand = .both,
        .margin = dvui.Rect.all(0),
        .padding = dvui.Rect.all(0),
        .background = false,
        .corner_radius = dvui.Rect.all(0),
    });
    defer rows.deinit();

    var rows_vbox = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .both,
        .background = false,
        .corner_radius = dvui.Rect.all(0),
        .margin = dvui.Rect.all(0),
        .padding = dvui.Rect.all(0),
    });
    defer rows_vbox.deinit();

    const ruler_stroke_color = dvui.themeGet().color(.control, .fill_hover);

    defer dvui.Path.stroke(
        .{ .points = &.{
            rows_vbox.data().rectScale().r.bottomRight(),
            rows_vbox.data().rectScale().r.bottomLeft(),
        } },
        .{
            .color = ruler_stroke_color,
            .thickness = 2.0,
        },
    );

    for (0..file.rows) |row_index| {
        var reorderable = rows.reorderable(@src(), .{
            .mode = .any_x,
        }, .{
            .expand = .horizontal,
            .id_extra = row_index,
            .padding = dvui.Rect.all(0),
            .margin = dvui.Rect.all(0),
            .min_size_content = .{ .h = @as(f32, @floatFromInt(file.row_height)), .w = 1 },
        });
        defer reorderable.deinit();

        var button_color = if (rows.drag_point != null) dvui.themeGet().color(.control, .fill).opacity(0.75) else dvui.themeGet().color(.window, .fill);

        if (pixi.dvui.hovered(reorderable.data())) {
            button_color = dvui.themeGet().color(.control, .fill);
            dvui.cursorSet(.hand);
        }

        if (reorderable.floating()) {
            self.rows_drag_index = row_index;
            rows.reorderable_size.w = @as(f32, @floatFromInt(file.width())) + ruler_width / file.editor.canvas.scale;
        }

        var cell_box: dvui.BoxWidget = undefined;

        cell_box.init(@src(), .{ .dir = .horizontal }, .{
            .expand = .both,
            .background = true,
            .color_fill = button_color,
            .id_extra = row_index,
        });

        {
            defer cell_box.deinit();
            cell_box.drawBackground();

            const top_right = cell_box.data().rectScale().r.topLeft();
            const top_left = cell_box.data().rectScale().r.topRight();

            const label = std.fmt.allocPrint(dvui.currentWindow().arena(), "{d}", .{row_index}) catch {
                dvui.log.err("Failed to allocate label", .{});
                return;
            };

            const label_size = font.textSize(label).scale(dvui.currentWindow().natural_scale, dvui.Size.Physical);
            const padding = pixi.editor.settings.ruler_padding * dvui.currentWindow().natural_scale;

            // always reserve space for the largest label width, and center within it
            const largest_label_size_scaled = largest_label_size.scale(dvui.currentWindow().natural_scale, dvui.Size.Physical);

            var label_rect = cell_box.data().rectScale().r;
            // Set the width to the largest possible label width + padding
            label_rect.w = largest_label_size_scaled.w + padding;

            // Center vertically
            label_rect.y += (label_rect.h - label_size.h) / 2.0;

            // Center horizontally: calculate start so that single- and multi-digit labels are centered in the same width
            label_rect.x += (label_rect.w - label_size.w) / 2.0;

            dvui.renderText(.{
                .text = label,
                .font = font,
                .color = dvui.themeGet().color(.control, .text),
                .rs = .{
                    .r = label_rect,
                    .s = dvui.currentWindow().natural_scale,
                },
            }) catch {
                dvui.log.err("Failed to render text", .{});
            };

            dvui.Path.stroke(.{ .points = &.{ top_right, top_left } }, .{
                .color = ruler_stroke_color,
                .thickness = 2.0,
            });

            loop: for (dvui.events()) |*e| {
                if (!cell_box.matchEvent(e)) {
                    continue;
                }

                switch (e.evt) {
                    .mouse => |me| {
                        if (me.action == .press and me.button.pointer()) {
                            e.handle(@src(), cell_box.data());
                            dvui.captureMouse(cell_box.data(), e.num);
                            dvui.dragPreStart(me.p, .{
                                .size = reorderable.data().rectScale().r.size(),
                                .offset = reorderable.data().rectScale().r.topLeft().diff(me.p),
                            });
                        } else if (me.action == .release and me.button.pointer()) {
                            dvui.captureMouse(null, e.num);
                            dvui.dragEnd();
                            self.rows_drag_index = null;
                        } else if (me.action == .motion) {
                            if (dvui.captured(cell_box.data().id)) {
                                e.handle(@src(), cell_box.data());
                                if (dvui.dragging(me.p, null)) |_| {
                                    reorderable.reorder.dragStart(reorderable.data().id.asUsize(), me.p, 0); // reorder grabs capture
                                    break :loop;
                                }
                            }
                        }
                    },

                    else => {},
                }
            }
        }

        if (reorderable.floating()) {
            const image_rect = dvui.Rect{
                .x = ruler_width / file.editor.canvas.scale,
                .y = 0.0,
                .w = @as(f32, @floatFromInt(file.width())),
                .h = @as(f32, @floatFromInt(file.row_height)),
            };

            const box = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .rect = image_rect,
                .background = false,
                .color_fill = dvui.themeGet().color(.err, .fill),
            });
            defer box.deinit();

            var i: usize = file.layers.len;

            while (i > 0) {
                i -= 1;
                const layer = file.layers.get(i);
                if (!layer.visible) {
                    continue;
                }

                // UVs cover just the needed portion
                const uv: dvui.Rect = .{
                    .x = 0.0,
                    .y = @as(f32, @floatFromInt(row_index)) * @as(f32, @floatFromInt(file.row_height)) / @as(f32, @floatFromInt(file.height())),
                    .w = 1.0,
                    .h = @as(f32, @floatFromInt(file.row_height)) / @as(f32, @floatFromInt(file.height())),
                };

                dvui.renderImage(layer.source, box.data().rectScale(), .{
                    .uv = uv,
                }) catch {
                    dvui.log.err("Failed to render checkerboard", .{});
                };
            }
        }
    }

    if (rows.finalSlot(.any_x)) {
        self.rows_insert_before_index = file.rows - 1;
    }
}

pub fn drawTransformDialog(self: *Workspace, canvas_vbox: *dvui.BoxWidget) void {
    const file = &pixi.editor.open_files.values()[self.open_file_index];
    if (file.editor.transform) |*transform| {
        var rect = canvas_vbox.data().rect;
        rect.w = 0;
        rect.h = 0;

        var fw: dvui.FloatingWidget = undefined;
        fw.init(@src(), .{}, .{
            .rect = .{ .x = canvas_vbox.data().rectScale().r.toNatural().x + 10, .y = canvas_vbox.data().rectScale().r.toNatural().y + 10, .w = 0, .h = 0 },
            .expand = .none,
            .background = true,
            .color_fill = dvui.themeGet().color(.control, .fill),
            .corner_radius = dvui.Rect.all(8),
            .box_shadow = .{
                .color = .black,
                .alpha = 0.2,
                .fade = 8,
                .corner_radius = dvui.Rect.all(8),
            },
        });
        defer fw.deinit();

        var anim = dvui.animate(@src(), .{ .kind = .vertical, .duration = 450_000, .easing = dvui.easing.outBack }, .{});
        defer anim.deinit();

        var anim_box = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .both,
            .background = false,
        });
        defer anim_box.deinit();

        dvui.labelNoFmt(@src(), "TRANSFORM", .{ .align_x = 0.5 }, .{
            .padding = dvui.Rect.all(4),
            .expand = .horizontal,
            .font = dvui.Font.theme(.title).larger(-4.0).withWeight(.bold),
        });
        _ = dvui.separator(@src(), .{ .expand = .horizontal });

        _ = dvui.spacer(@src(), .{ .expand = .horizontal });

        var degrees: f32 = std.math.radiansToDegrees(transform.rotation);

        var slider_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
            .background = false,
        });

        if (dvui.sliderEntry(@src(), "{d:0.0}°", .{
            .value = &degrees,
            .min = 0,
            .max = 360,
            .interval = 1,
        }, .{ .expand = .horizontal, .color_fill = dvui.themeGet().color(.window, .fill) })) {
            transform.rotation = std.math.degreesToRadians(degrees);
        }
        slider_box.deinit();

        if (transform.ortho) {
            var box = dvui.box(@src(), .{ .dir = .horizontal, .equal_space = true }, .{
                .expand = .horizontal,
                .background = false,
            });
            defer box.deinit();
            dvui.label(@src(), "Width: {d:0.0}", .{transform.point(.bottom_left).diff(transform.point(.bottom_right).*).length()}, .{ .expand = .horizontal, .font = dvui.Font.theme(.heading) });
            dvui.label(@src(), "Height: {d:0.0}", .{transform.point(.top_left).diff(transform.point(.bottom_left).*).length()}, .{ .expand = .horizontal, .font = dvui.Font.theme(.heading) });
        }

        {
            var box = dvui.box(@src(), .{ .dir = .horizontal, .equal_space = true }, .{
                .expand = .horizontal,
                .background = false,
            });
            defer box.deinit();
            if (dvui.buttonIcon(@src(), "transform_cancel", icons.tvg.lucide.@"trash-2", .{}, .{ .stroke_color = dvui.themeGet().color(.window, .fill) }, .{ .style = .err, .expand = .horizontal })) {
                pixi.editor.cancel() catch {
                    dvui.log.err("Failed to cancel transform", .{});
                };
            }
            if (dvui.buttonIcon(@src(), "transform_accept", icons.tvg.lucide.check, .{}, .{ .stroke_color = dvui.themeGet().color(.window, .fill) }, .{ .style = .highlight, .expand = .horizontal })) {
                pixi.editor.accept() catch {
                    dvui.log.err("Failed to accept transform", .{});
                };
            }
        }
    }
}

pub fn drawLogo(_: *Workspace, canvas_vbox: *dvui.BoxWidget) !void {
    if (true) {
        const logo_pixel_size = 32;
        const logo_width = 3;
        const logo_height = 5;

        const logo_vbox = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .none,
            .gravity_x = 0.5,
            .gravity_y = 0.5,
            .padding = dvui.Rect.all(10),
        });
        defer logo_vbox.deinit();

        { // Logo

            const vbox2 = dvui.box(@src(), .{ .dir = .vertical }, .{
                .expand = .none,
                .gravity_x = 0.5,
                .min_size_content = .{ .w = logo_pixel_size * logo_width, .h = logo_pixel_size * logo_height },
                .padding = dvui.Rect.all(20),
            });
            defer vbox2.deinit();

            for (0..5) |i| {
                const hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
                    .expand = .none,
                    .min_size_content = .{ .w = logo_pixel_size * logo_width, .h = logo_pixel_size },
                    .margin = dvui.Rect.all(0),
                    .padding = dvui.Rect.all(0),
                    .id_extra = i,
                });
                defer hbox.deinit();

                for (0..3) |j| {
                    const index = i * logo_width + j;
                    var pixi_color = logo_colors[index];

                    if (pixi_color.value[3] < 1.0 and pixi_color.value[3] > 0.0) {
                        const theme_bg = dvui.themeGet().color(.window, .fill);
                        pixi_color = pixi_color.lerp(pixi.math.Color.initBytes(theme_bg.r, theme_bg.g, theme_bg.b, 255), pixi_color.value[3]);
                        pixi_color.value[3] = 1.0;
                    }

                    const color = pixi_color.bytes();

                    const pixel = dvui.box(@src(), .{ .dir = .horizontal }, .{
                        .expand = .none,
                        .min_size_content = .{ .w = logo_pixel_size, .h = logo_pixel_size },
                        .id_extra = index,
                        .background = false,
                        .color_fill = .{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] },
                        .margin = dvui.Rect.all(0),
                        .padding = dvui.Rect.all(0),
                    });

                    const rect = pixel.data().rect.outset(.{ .x = 0, .y = 0 });
                    const rs = pixel.data().rectScale();
                    pixel.deinit();

                    if (pixi_color.value[3] <= 0.0) continue;

                    try drawBubble(rect, rs, color, index);
                }
            }
        }

        var vbox = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .none,
            .gravity_x = 0.5,
        });
        {
            var button: dvui.ButtonWidget = undefined;
            button.init(@src(), .{ .draw_focus = true }, .{
                .gravity_x = 0.5,
                .expand = .horizontal,
                .padding = dvui.Rect.all(2),
                .color_fill = dvui.themeGet().color(.window, .fill),
            });
            defer button.deinit();

            button.processEvents();
            button.drawBackground();

            pixi.dvui.labelWithKeybind("Open Folder", dvui.currentWindow().keybinds.get("open_folder") orelse .{}, true, .{ .padding = dvui.Rect.all(4), .expand = .horizontal, .gravity_x = 1.0 });

            if (button.clicked()) {
                pixi.backend.showOpenFolderDialog(setProjectFolderCallback, null);
            }
        }

        {
            var button: dvui.ButtonWidget = undefined;
            button.init(@src(), .{ .draw_focus = true }, .{
                .gravity_x = 0.5,
                .expand = .horizontal,
                .padding = dvui.Rect.all(2),
                .color_fill = dvui.themeGet().color(.window, .fill),
            });
            defer button.deinit();

            button.processEvents();
            button.drawBackground();

            pixi.dvui.labelWithKeybind("Open Files", dvui.currentWindow().keybinds.get("open_files") orelse .{}, true, .{ .padding = dvui.Rect.all(4), .expand = .horizontal, .gravity_x = 1.0 });

            if (button.clicked()) {
                // if (try dvui.dialogNativeFileOpenMultiple(dvui.currentWindow().arena(), .{
                //     .title = "Open Files...",
                //     .filter_description = ".pixi, .png",
                //     .filters = &.{ "*.pixi", "*.png" },
                // })) |files| {
                //     for (files) |file| {
                //         _ = pixi.editor.openFilePath(file, pixi.editor.open_workspace_grouping) catch {
                //             std.log.err("Failed to open file: {s}", .{file});
                //         };
                //     }
                // }

                pixi.backend.showOpenFileDialog(openFilesCallback, &.{
                    .{ .name = "Image Files", .pattern = "pixi;png;jpg" },
                }, "", null);
            }
        }
        vbox.deinit();

        const spacer = dvui.spacer(@src(), .{ .expand = .horizontal, .min_size_content = .{ .h = 30 } });

        {
            var recents_box = dvui.box(@src(), .{ .dir = .vertical }, .{
                .expand = .none,
                .gravity_x = 0.5,
                .max_size_content = .{ .h = (canvas_vbox.data().rect.h - spacer.rect.y) / 3.0, .w = canvas_vbox.data().rect.w / 2.0 },
            });
            defer recents_box.deinit();

            var scroll_area = dvui.scrollArea(@src(), .{}, .{
                .expand = .both,
                .color_border = dvui.themeGet().color(.control, .fill),
                .corner_radius = dvui.Rect.all(8),
            });
            defer scroll_area.deinit();

            var i: usize = pixi.editor.recents.folders.items.len;
            while (i > 0) : (i -= 1) {
                var anim = dvui.animate(@src(), .{
                    .kind = .horizontal,
                    .duration = 150_000 + 150_000 * @as(i32, @intCast(i)),
                    .easing = dvui.easing.outBack,
                }, .{
                    .id_extra = i,
                    .expand = .horizontal,
                });
                defer anim.deinit();

                const folder = pixi.editor.recents.folders.items[i - 1];
                if (dvui.button(@src(), folder, .{
                    .draw_focus = false,
                }, .{
                    .expand = .horizontal,
                    .font = dvui.Font.theme(.mono).larger(-2.0),
                    .id_extra = i,
                    .margin = dvui.Rect.all(1),
                    .padding = dvui.Rect.all(2),
                    .color_fill = dvui.themeGet().color(.window, .fill),
                    .color_text = dvui.themeGet().color(.control, .text).opacity(0.5),
                })) {
                    try pixi.editor.setProjectFolder(folder);
                }
            }
        }
    }
}

pub fn drawBubble(rect: dvui.Rect, rs: dvui.RectScale, color: [4]u8, id_extra: usize) !void {
    var new_rect = dvui.Rect{
        .x = rect.x - (1 / dvui.currentWindow().rectScale().s),
        .y = rect.y - rect.h,
        .w = rect.w + (1 / dvui.currentWindow().rectScale().s),
        .h = rect.h,
    };

    for (dvui.events()) |evt| {
        switch (evt.evt) {
            .mouse => |me| {
                const dx = @abs(me.p.x - (rs.r.x + rs.r.w * 0.5)) / rs.s;
                const dy = @abs(me.p.y - (rs.r.y - rs.r.h * 0.5)) / rs.s;
                const distance = @sqrt(dx * dx + dy * dy);

                const min_h: f32 = 0;
                const max_h: f32 = rect.h;

                const max_distance: f32 = rect.h * 2.0;

                var t = distance / max_distance;
                if (t > 1.0) t = 1.0;
                if (t < 0.0) t = 0.0;
                const scaled_h = max_h - (max_h - min_h) * t;

                new_rect.h = @ceil(scaled_h);
                new_rect.y = @ceil(rect.y - new_rect.h);
            },
            else => {},
        }
    }

    const corner_radius: dvui.Rect = .{ .x = rs.r.w / 2.0, .y = rs.r.h / 2.0 };

    var box = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .rect = new_rect,
        .id_extra = id_extra,
        .color_fill = .{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] },
    });

    var path = dvui.Path.Builder.init(dvui.currentWindow().lifo());
    defer path.deinit();

    const rad = corner_radius;
    const r = box.data().contentRectScale().r;
    box.deinit();
    const tl = dvui.Point.Physical{ .x = r.x + rad.x, .y = r.y + rad.x };
    const bl = dvui.Point.Physical{ .x = r.x + rad.h, .y = r.y + r.h - rad.h };
    const br = dvui.Point.Physical{ .x = r.x + r.w - rad.w, .y = r.y + r.h - rad.w };
    const tr = dvui.Point.Physical{ .x = r.x + r.w - rad.y, .y = r.y + rad.y };
    path.addRect(rs.r.outsetAll(1), dvui.Rect.Physical.all(0));

    if (new_rect.h > 0) {
        path.addArc(tl, rad.x, dvui.math.pi * 1.5, dvui.math.pi, true);
        path.addArc(bl, rad.h, dvui.math.pi, dvui.math.pi * 0.5, true);
        path.addArc(br, rad.w, dvui.math.pi * 0.5, 0, true);
        path.addArc(tr, rad.y, dvui.math.pi * 2.0, dvui.math.pi * 1.5, false);
    }

    path.build().fillConvex(.{ .color = .{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] }, .fade = 1.0 });
}

// This should never be able to return more than one folder
pub fn setProjectFolderCallback(folder: ?[][:0]const u8) void {
    if (folder) |f| {
        pixi.editor.setProjectFolder(f[0]) catch {
            dvui.log.err("Failed to set project folder: {s}", .{f[0]});
        };
    }
}

pub fn openFilesCallback(files: ?[][:0]const u8) void {
    if (files) |f| {
        for (f) |file| {
            _ = pixi.editor.openFilePath(file, pixi.editor.open_workspace_grouping) catch {
                dvui.log.err("Failed to open file: {s}", .{file});
            };
        }
    }
}
