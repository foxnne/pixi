const std = @import("std");

const dvui = @import("dvui");
const pixi = @import("../pixi.zig");
const icons = @import("icons");

const App = pixi.App;
const Editor = pixi.Editor;

pub const Artboard = @This();

open_file_index: usize = 0,
grouping: u64 = 0,

drag_index: ?usize = null,
removed_index: ?usize = null,
insert_before_index: ?usize = null,

pub fn init(grouping: u64) Artboard {
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

pub fn draw(self: *Artboard) !dvui.App.Result {
    // Canvas Area
    var vbox = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both, .background = true, .gravity_y = 0.0, .id_extra = self.grouping });
    defer vbox.deinit();

    // Set the active artboard grouping when the user clicks on the artboard rect
    for (dvui.events()) |*e| {
        if (!vbox.matchEvent(e)) {
            continue;
        }

        if (e.evt == .mouse) {
            if (e.evt.mouse.action == .press) {
                pixi.editor.open_artboard_grouping = self.grouping;
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

fn drawProject(self: *Artboard) void {
    var canvas_vbox = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both, .id_extra = self.grouping });
    defer {
        self.drawShadows(canvas_vbox.data().rectScale());
        canvas_vbox.deinit();
    }

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

fn drawTabs(self: *Artboard) void {
    if (pixi.editor.open_files.values().len == 0) return;

    // Handle dragging of tabs between artboard reorderables (tab bars)
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
        if (file.grouping != self.grouping) continue;

        var reorderable = tabs.reorderable(@src(), .{}, .{
            .expand = .vertical,
            .id_extra = i,
            .padding = dvui.Rect.all(0),
            .margin = dvui.Rect.all(0),
        });
        defer reorderable.deinit();

        const selected = self.open_file_index == i and pixi.editor.open_artboard_grouping == self.grouping;

        var hbox = dvui.BoxWidget.init(@src(), .{ .dir = .horizontal }, .{
            .expand = .none,
            .border = .{ .y = 1 },
            .color_border = if (selected) dvui.themeGet().color(.window, .text) else dvui.themeGet().color(.control, .fill),
            .color_fill = if (selected) dvui.themeGet().color(.window, .fill) else dvui.themeGet().color(.control, .fill),
            .background = true,
            .id_extra = i,
            .padding = dvui.Rect.all(2),
            .margin = dvui.Rect.all(0),
        });
        defer hbox.deinit();
        hbox.install();

        var hovered = false;
        if (pixi.dvui.hovered(hbox.data())) {
            hovered = true;
            hbox.data().options.color_fill = dvui.themeGet().color(.window, .fill);
            hbox.data().options.color_border = dvui.themeGet().color(.window, .fill);
        }
        hbox.drawBackground();

        if (reorderable.floating()) {
            self.drag_index = i;
        }

        if (reorderable.removed()) {
            self.removed_index = i;
        } else if (reorderable.insertBefore()) {
            self.insert_before_index = i;
        }

        dvui.icon(@src(), "file_icon", icons.tvg.lucide.file, .{}, .{
            .gravity_y = 0.5,
            .padding = dvui.Rect.all(4),
        });
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
                .fill_color = dvui.themeGet().color(.window, .text),
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
        self.insert_before_index = pixi.editor.open_files.values().len;
    }
}

pub fn processTabsDrag(self: *Artboard) void {
    if (self.insert_before_index) |insert_before| {
        if (self.removed_index) |removed| { // Dragging from this artboard

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

            self.removed_index = null;
            self.insert_before_index = null;
        } else { // Dragging from another artboard
            for (pixi.editor.artboards.values()) |*artboard| {
                if (artboard.removed_index) |removed| {
                    if (removed > insert_before) {
                        std.mem.swap(pixi.Internal.File, &pixi.editor.open_files.values()[removed], &pixi.editor.open_files.values()[insert_before]);
                        std.mem.swap(u64, &pixi.editor.open_files.keys()[removed], &pixi.editor.open_files.keys()[insert_before]);

                        pixi.editor.open_files.values()[insert_before].grouping = self.grouping;
                        pixi.editor.setActiveFile(insert_before);
                    } else {
                        if (insert_before > 0) {
                            std.mem.swap(pixi.Internal.File, &pixi.editor.open_files.values()[removed], &pixi.editor.open_files.values()[insert_before - 1]);
                            std.mem.swap(u64, &pixi.editor.open_files.keys()[removed], &pixi.editor.open_files.keys()[insert_before - 1]);
                            pixi.editor.open_files.values()[insert_before - 1].grouping = self.grouping;
                            pixi.editor.setActiveFile(insert_before - 1);
                        } else {
                            std.mem.swap(pixi.Internal.File, &pixi.editor.open_files.values()[removed], &pixi.editor.open_files.values()[insert_before]);
                            std.mem.swap(u64, &pixi.editor.open_files.keys()[removed], &pixi.editor.open_files.keys()[insert_before]);
                            pixi.editor.open_files.values()[insert_before].grouping = self.grouping;
                            pixi.editor.setActiveFile(insert_before);
                        }
                    }

                    self.removed_index = null;
                    self.insert_before_index = null;

                    artboard.removed_index = null;
                    artboard.insert_before_index = null;
                }
            }
        }
    }
}

/// Responsible for handling the cross-widget drag of tabs between multiple artboards or between tabs and artboards
pub fn processCanvasDrag(self: *Artboard, data: *dvui.WidgetData) void {
    if (dvui.dragName("tab_drag")) {
        for (dvui.events()) |*e| {
            if (!dvui.eventMatch(e, .{ .id = data.id, .r = data.rectScale().r, .drag_name = "tab_drag" })) continue;

            for (pixi.editor.artboards.values()) |*artboard| {
                if (artboard.drag_index) |drag_index| {
                    defer artboard.drag_index = null;

                    var right_side = data.rectScale().r;
                    right_side.w /= 2;
                    right_side.x += right_side.w;

                    if (right_side.contains(e.evt.mouse.p) and pixi.editor.artboards.keys()[pixi.editor.artboards.keys().len - 1] == self.grouping) {
                        right_side.fill(dvui.Rect.Physical.all(right_side.w / 8), .{
                            .color = dvui.themeGet().color(.highlight, .fill).opacity(0.5),
                            //.thickness = 5,
                        });

                        if (e.evt == .mouse and e.evt.mouse.action == .release and e.evt.mouse.button.pointer()) {
                            // We dropped on the right side of the artboard, so we need to create a new artboard
                            e.handle(@src(), data);
                            dvui.dragEnd();
                            dvui.refresh(null, @src(), data.id);

                            var dragged_file = &pixi.editor.open_files.values()[drag_index];

                            if (artboard.open_file_index == pixi.editor.open_files.getIndex(dragged_file.id)) {
                                for (pixi.editor.open_files.values()) |f| {
                                    if (f.grouping == artboard.grouping and f.id != dragged_file.id) {
                                        artboard.open_file_index = pixi.editor.open_files.getIndex(f.id) orelse 0;
                                        break;
                                    }
                                }
                            }
                            dragged_file.grouping = pixi.editor.newGroupingID();
                            pixi.editor.open_artboard_grouping = dragged_file.grouping;
                        }
                    } else if (data.rectScale().r.contains(e.evt.mouse.p)) {
                        data.rectScale().r.fill(dvui.Rect.Physical.all(data.rectScale().r.w / 8), .{
                            .color = dvui.themeGet().color(.highlight, .fill).opacity(0.5),
                            //.thickness = 5,
                        });

                        if (e.evt == .mouse and e.evt.mouse.action == .release and e.evt.mouse.button.pointer()) {
                            // We dropped on the left side of the artboard, so we need to move the file to this artboard
                            e.handle(@src(), data);
                            dvui.dragEnd();
                            dvui.refresh(null, @src(), data.id);

                            var dragged_file = &pixi.editor.open_files.values()[drag_index];

                            if (artboard.open_file_index == pixi.editor.open_files.getIndex(dragged_file.id)) {
                                for (pixi.editor.open_files.values()) |f| {
                                    if (f.grouping == artboard.grouping and f.id != dragged_file.id) {
                                        artboard.open_file_index = pixi.editor.open_files.getIndex(f.id) orelse 0;
                                        break;
                                    }
                                }
                            }
                            dragged_file.grouping = self.grouping;
                            pixi.editor.open_artboard_grouping = dragged_file.grouping;
                            self.open_file_index = pixi.editor.open_files.getIndex(dragged_file.id) orelse 0;
                        }
                    }
                    break;
                }
            }
        }
    }
}

pub fn drawCanvas(self: *Artboard) !void {
    var canvas_vbox = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both });
    defer {
        dvui.toastsShow(canvas_vbox.data().id, canvas_vbox.data().contentRectScale().r.toNatural());
        self.drawShadows(canvas_vbox.data().rectScale());
        canvas_vbox.deinit();
    }
    defer self.processCanvasDrag(canvas_vbox.data());

    if (pixi.editor.open_files.values().len > 0) {
        if (self.open_file_index >= pixi.editor.open_files.values().len) {
            self.open_file_index = pixi.editor.open_files.values().len - 1;
        }

        const file = &pixi.editor.open_files.values()[self.open_file_index];
        file.gui.canvas.id = canvas_vbox.data().id;

        var file_widget = pixi.dvui.FileWidget.init(@src(), .{
            .canvas = &file.gui.canvas,
            .file = file,
        }, .{
            .expand = .both,
            .background = true,
            .color_fill = dvui.themeGet().color(.window, .fill),
        });

        defer file_widget.deinit();
        file_widget.processEvents();
    } else {
        try self.drawLogo();
    }
}

pub fn drawShadows(_: *Artboard, container: dvui.RectScale) void {
    {
        var rs = container;
        rs.r.w = 20.0;

        var path: dvui.Path.Builder = .init(dvui.currentWindow().arena());
        path.addRect(rs.r, dvui.Rect.Physical.all(5));

        var triangles = path.build().fillConvexTriangles(dvui.currentWindow().arena(), .{ .center = rs.r.center(), .color = .white }) catch return;

        const black: dvui.Color = .black;
        const ca0 = black.opacity(0.1);
        const ca1 = black.opacity(0);

        for (triangles.vertexes) |*v| {
            const t = std.math.clamp((v.pos.x - rs.r.x) / rs.r.w, 0.0, 1.0);
            v.col = v.col.multiply(.fromColor(dvui.Color.lerp(ca0, ca1, t)));
        }
        dvui.renderTriangles(triangles, null) catch {
            dvui.log.err("Failed to render triangles", .{});
        };

        triangles.deinit(dvui.currentWindow().arena());
        path.deinit();
    }

    {
        var rs = container;
        rs.r.h = 20.0;

        var path: dvui.Path.Builder = .init(dvui.currentWindow().arena());
        path.addRect(rs.r, dvui.Rect.Physical.all(5));

        var triangles = path.build().fillConvexTriangles(dvui.currentWindow().arena(), .{ .center = rs.r.center(), .color = .white }) catch return;

        const black: dvui.Color = .black;
        const ca0 = black.opacity(0.1);
        const ca1 = black.opacity(0);

        for (triangles.vertexes) |*v| {
            const t = std.math.clamp((v.pos.y - rs.r.y) / rs.r.h, 0.0, 1.0);
            v.col = v.col.multiply(.fromColor(dvui.Color.lerp(ca0, ca1, t)));
        }
        dvui.renderTriangles(triangles, null) catch {
            dvui.log.err("Failed to render triangles", .{});
        };

        triangles.deinit(dvui.currentWindow().arena());
        path.deinit();
    }
}

pub fn drawLogo(_: *Artboard) !void {
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

                    const outset_rect = pixel.data().rectScale().r.outset(.{ .x = 1, .y = 1 });
                    outset_rect.fill(dvui.Rect.Physical.all(0), .{ .color = .{
                        .r = color[0],
                        .g = color[1],
                        .b = color[2],
                        .a = color[3],
                    } });

                    const rect = pixel.data().rect.outset(.{ .x = 0, .y = 0 });
                    const rs = pixel.data().rectScale();
                    pixel.deinit();

                    if (pixi_color.value[3] <= 0.0) continue;

                    try drawBubble(rect, rs, color, index);
                }
            }
        }

        {
            var button = dvui.ButtonWidget.init(@src(), .{ .draw_focus = true }, .{
                .gravity_x = 0.5,
                .padding = dvui.Rect.all(2),
                .color_fill = dvui.themeGet().color(.control, .fill),
            });
            defer button.deinit();

            button.install();
            button.processEvents();
            button.drawBackground();

            pixi.dvui.labelWithKeybind("Open Folder", dvui.currentWindow().keybinds.get("open_folder") orelse .{}, .{ .padding = dvui.Rect.all(4) });

            if (button.clicked()) {
                if (try dvui.dialogNativeFolderSelect(dvui.currentWindow().arena(), .{ .title = "Open Project Folder" })) |folder| {
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
    if (new_rect.h <= 0) return;

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
    path.addArc(tl, rad.x, dvui.math.pi * 1.5, dvui.math.pi, true);
    path.addArc(bl, rad.h, dvui.math.pi, dvui.math.pi * 0.5, true);
    path.addArc(br, rad.w, dvui.math.pi * 0.5, 0, true);
    path.addArc(tr, rad.y, dvui.math.pi * 2.0, dvui.math.pi * 1.5, false);

    { // Bubble shadows
        // const triangles = path.build().fillConvexTriangles(dvui.currentWindow().arena(), .{ .center = r.center(), .fade = 10 }) catch return;

        // const black: dvui.Color = .black;
        // const ca0 = black.opacity(0.1);
        // const ca1 = black.opacity(0);

        // for (triangles.vertexes) |*v| {
        //     const t = std.math.clamp((v.pos.y - r.y) / r.h, 0.0, 1.0);
        //     v.col = v.col.multiply(.fromColor(dvui.Color.lerp(ca0, ca1, t)));
        //     v.pos.y -= 3;
        // }

        // dvui.renderTriangles(triangles, null) catch {
        //     dvui.log.err("Failed to render triangles", .{});
        // };
    }

    path.build().fillConvex(.{ .color = .{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] }, .fade = 1.0 });
}
