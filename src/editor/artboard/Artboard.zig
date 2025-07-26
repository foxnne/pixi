const std = @import("std");

const dvui = @import("dvui");
const pixi = @import("../../pixi.zig");
const icons = @import("icons");

//const Core = @import("mach").Core;
const App = pixi.App;
const Editor = pixi.Editor;
//const Packer = pixi.Packer;
//const Assets = pixi.Assets;

// const nfd = @import("nfd");
// const imgui = @import("zig-imgui");

pub const Artboard = @This();

// pub const mach_module = .artboard;
// pub const mach_systems = .{ .init, .deinit, .draw };

//pub const menu = @import("menu.zig");
//pub const rulers = @import("rulers.zig");
//pub const canvas = @import("canvas.zig");
//pub const canvas_pack = @import("canvas_pack.zig");

//pub const flipbook = @import("flipbook/flipbook.zig");
//pub const infobar = @import("infobar.zig");

grouping: u8 = 0,

split: bool = false,

pub fn init(grouping: u8) Artboard {
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
    color_0,
    color_1,
    color_1,
    color_2,
    color_3,
    color_2,
    color_4,
    color_4,
    color_4,
    color_5,
    color_3,
    color_3,
    color_3,
    color_0,
    color_0,
};

pub fn draw(self: *Artboard) !dvui.App.Result {

    // Canvas Area
    var vbox = dvui.box(@src(), .vertical, .{ .expand = .both, .background = true, .gravity_y = 0.0 });
    defer vbox.deinit();

    self.drawTabs();
    try self.drawCanvas();

    return .ok;
}

fn drawTabs(_: *Artboard) void {
    if (pixi.editor.open_files.values().len == 0) return;

    var tabs = pixi.dvui.TabsWidget.init(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
    });
    {
        tabs.install();
        defer tabs.deinit();

        for (pixi.editor.open_files.values(), 0..) |file, i| {
            const selected = pixi.editor.open_file_index == i;
            var tab_box = tabs.addTab(selected, .{
                .id_extra = i,
                .corner_radius = dvui.Rect.all(0),
                .color_fill_hover = .fill,
                .color_fill = .fill_window,
                .padding = dvui.Rect.all(0),
                .margin = dvui.Rect.all(0),
                .background = true,
            });
            defer tab_box.deinit();

            var tab_button = dvui.ButtonWidget.init(@src(), .{}, .{
                .margin = dvui.Rect.all(0),
                .id_extra = i,
                .padding = .{ .x = 2, .y = 6, .h = 6, .w = 2 },
            });
            var hovered = false;
            {
                defer tab_button.deinit();
                tab_button.install();
                tab_button.processEvents();
                hovered = tab_button.hovered();

                if (tab_button.clicked()) {
                    pixi.editor.open_file_index = i;
                }

                const hbox = dvui.box(@src(), .horizontal, .{
                    .background = true,
                    .color_fill = if (hovered) .fill else .fill_window,
                });
                defer hbox.deinit();

                dvui.icon(@src(), "file_icon", icons.tvg.lucide.file, .{}, .{
                    .gravity_y = 0.5,
                    .padding = dvui.Rect.all(2),
                });
                dvui.label(@src(), "{s}", .{std.fs.path.basename(file.path)}, .{
                    .color_text = if (selected) .text else .text_press,
                    .padding = dvui.Rect.all(2),
                    .gravity_y = 0.5,
                });
            }

            var close_button = dvui.ButtonWidget.init(@src(), .{}, .{
                .color_fill_hover = .err,
                .color_fill = .fill_window,
                .gravity_y = 0.5,
                .padding = dvui.Rect.all(1),
                .margin = .{ .w = 4 },
            });
            {
                defer close_button.deinit();
                close_button.install();
                close_button.processEvents();
                var color = dvui.Color.fromTheme(.text);

                if (hovered or close_button.hovered()) {
                    close_button.drawBackground();
                } else color = if (file.dirty()) .fromTheme(.text) else color.opacity(0.0);

                dvui.icon(@src(), "close", if (file.dirty() and !(hovered or close_button.hovered())) icons.tvg.lucide.@"circle-small" else icons.tvg.lucide.x, .{
                    .fill_color = color,
                }, .{
                    .gravity_y = 0.5,
                });

                if (close_button.clicked()) {
                    pixi.editor.closeFileID(file.id) catch |err| {
                        std.log.err("closeFile: {d} failed: {s}", .{ i, @errorName(err) });
                    };
                    break;
                }
            }
        }
    }
}

pub fn drawCanvas(self: *Artboard) !void {
    var canvas_vbox = dvui.box(@src(), .vertical, .{ .expand = .both });
    defer {
        dvui.toastsShow(canvas_vbox.data().id, canvas_vbox.data().contentRectScale().r.toNatural());
        canvas_vbox.deinit();
    }

    if (pixi.editor.open_files.values().len > 0) {
        const file = &pixi.editor.open_files.values()[pixi.editor.open_file_index];
        file.canvas_id = canvas_vbox.data().id;

        var file_widget = pixi.dvui.FileWidget.init(@src(), file, .{}, .{
            .expand = .both,
            .background = true,
        });
        {
            defer file_widget.deinit();

            file_widget.processStrokeTool();
            file_widget.processSampleTool();

            // Draw layers first, so that the scrolling bounding box is updated
            file_widget.drawLayers();
            file_widget.drawCursor();
            file_widget.drawSample();

            // Then process the scroll and zoom events last
            file_widget.scrollAndZoom();
        }
    } else {
        try self.drawLogo();
    }

    {
        var rs = canvas_vbox.data().contentRectScale();
        rs.r.w = 20.0;

        var path: dvui.Path.Builder = .init(dvui.currentWindow().arena());
        path.addRect(rs.r, dvui.Rect.Physical.all(5));

        var triangles = try path.build().fillConvexTriangles(dvui.currentWindow().arena(), .{ .center = rs.r.center() });

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

    {
        var rs = canvas_vbox.data().contentRectScale();
        rs.r.h = 20.0;

        var path: dvui.Path.Builder = .init(dvui.currentWindow().arena());
        path.addRect(rs.r, dvui.Rect.Physical.all(5));

        var triangles = try path.build().fillConvexTriangles(dvui.currentWindow().arena(), .{ .center = rs.r.center() });

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

pub fn drawLogo(_: *Artboard) !void {
    if (true) {
        const logo_pixel_size = 32;
        const logo_width = 3;
        const logo_height = 5;

        const logo_vbox = dvui.box(@src(), .vertical, .{
            .expand = .none,
            .gravity_x = 0.5,
            .gravity_y = 0.5,
            .padding = dvui.Rect.all(10),
        });
        defer logo_vbox.deinit();

        { // Logo

            const vbox2 = dvui.box(@src(), .vertical, .{
                .expand = .none,
                .gravity_x = 0.5,
                .min_size_content = .{ .w = logo_pixel_size * logo_width, .h = logo_pixel_size * logo_height },
                .padding = dvui.Rect.all(20),
            });
            defer vbox2.deinit();

            for (0..5) |i| {
                const hbox = dvui.box(@src(), .horizontal, .{
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
                        const theme_bg = dvui.themeGet().color_fill;
                        pixi_color = pixi_color.lerp(pixi.math.Color.initBytes(theme_bg.r, theme_bg.g, theme_bg.b, 255), pixi_color.value[3]);
                        pixi_color.value[3] = 1.0;
                    }

                    const color = pixi_color.bytes();

                    // if (i == 0) {
                    //     if (j == 0) {
                    //         const pixel = dvui.box(@src(), .horizontal, .{
                    //             .expand = .none,
                    //             .min_size_content = .{ .w = logo_pixel_size, .h = logo_pixel_size },
                    //             .id_extra = j,
                    //             .background = true,
                    //             .color_fill = .{ .color = .{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] } },
                    //             .margin = dvui.Rect.all(0),
                    //             .padding = dvui.Rect.all(0),
                    //         });
                    //         defer pixel.deinit();
                    //     } else if (j == 1) {
                    //         const pixel = dvui.box(@src(), .horizontal, .{
                    //             .expand = .none,
                    //             .min_size_content = .{ .w = logo_pixel_size * 2, .h = logo_pixel_size },
                    //             .id_extra = j,
                    //             .background = true,
                    //             .color_fill = .{ .color = .{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] } },
                    //             .margin = dvui.Rect.all(0),
                    //             .padding = dvui.Rect.all(0),
                    //         });
                    //         defer pixel.deinit();
                    //     }
                    // } else if (i == 2) {
                    //     if (j == 0) {
                    //         const pixel = dvui.box(@src(), .horizontal, .{
                    //             .expand = .none,
                    //             .min_size_content = .{ .w = logo_pixel_size * 3, .h = logo_pixel_size },
                    //             .id_extra = j,
                    //             .background = true,
                    //             .color_fill = .{ .color = .{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] } },
                    //             .margin = dvui.Rect.all(0),
                    //             .padding = dvui.Rect.all(0),
                    //         });
                    //         defer pixel.deinit();
                    //     }
                    // } else if (i > 0) {
                    const pixel = dvui.box(@src(), .horizontal, .{
                        .expand = .none,
                        .min_size_content = .{ .w = logo_pixel_size, .h = logo_pixel_size },
                        .id_extra = index,
                        .background = false,
                        .color_fill = .{ .color = .{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] } },
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

                    try drawBubble(rect, rs, color, index);

                    //}
                }
            }
        }

        {
            var button = dvui.ButtonWidget.init(@src(), .{ .draw_focus = true }, .{
                .gravity_x = 0.5,
                .padding = dvui.Rect.all(2),
                .color_fill = .fill_window,
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

var mouse_dist: f32 = 1000;

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

    var box = dvui.box(@src(), .horizontal, .{
        .rect = new_rect,
        .id_extra = id_extra,
        .color_fill = .{ .color = .{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] } },
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
    path.addArc(tl, rad.x, dvui.math.pi * 1.5, dvui.math.pi, @abs(tl.y - bl.y) < 0.5);
    path.addArc(bl, rad.h, dvui.math.pi, dvui.math.pi * 0.5, @abs(bl.x - br.x) < 0.5);
    path.addArc(br, rad.w, dvui.math.pi * 0.5, 0, @abs(br.y - tr.y) < 0.5);
    path.addArc(tr, rad.y, dvui.math.pi * 2.0, dvui.math.pi * 1.5, @abs(tr.x - tl.x) < 0.5);

    path.build().fillConvex(.{ .color = .{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] } });
}
