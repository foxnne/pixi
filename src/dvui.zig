const std = @import("std");
const pixi = @import("pixi.zig");
const dvui = @import("dvui");
const builtin = @import("builtin");
const icons = @import("icons");
const Widgets = @import("editor/Widgets.zig");

pub const FileWidget = Widgets.FileWidget;
pub const TabsWidget = Widgets.TabsWidget;
pub const ImageWidget = Widgets.ImageWidget;
pub const CanvasWidget = Widgets.CanvasWidget;
pub const ReorderWidget = Widgets.ReorderWidget;
pub const EditorPanedWidget = Widgets.EditorPanedWidget;
pub const PanedWidget = Widgets.PanedWidget;

/// Currently this is specialized for the layers paned widget, just includes icon and dragging flag so we know when the pane is dragging
pub fn paned(src: std.builtin.SourceLocation, init_opts: PanedWidget.InitOptions, opts: dvui.Options) *PanedWidget {
    var ret = dvui.widgetAlloc(PanedWidget);
    ret.* = PanedWidget.init(src, init_opts, opts);
    ret.data().was_allocated_on_widget_stack = true;
    ret.install();
    ret.processEvents();
    return ret;
}

pub fn hovered(wd: *dvui.WidgetData) bool {
    for (dvui.events()) |*event| {
        if (!dvui.eventMatchSimple(event, wd)) {
            continue;
        }

        switch (event.evt) {
            .mouse => |mouse| {
                return wd.borderRectScale().r.contains(mouse.p);
            },
            else => {},
        }
    }

    return false;
}

pub fn reorder(src: std.builtin.SourceLocation, init_opts: ReorderWidget.InitOptions, opts: dvui.Options) *ReorderWidget {
    var ret = dvui.widgetAlloc(ReorderWidget);
    ret.init(src, init_opts, opts);
    ret.data().was_allocated_on_widget_stack = true;
    ret.processEvents();
    return ret;
}

pub fn toastDisplay(id: dvui.Id) !void {
    const message = dvui.dataGetSlice(null, id, "_message", []u8) orelse {
        dvui.log.err("toastDisplay lost data for toast {x}\n", .{id});
        return;
    };

    var animator = dvui.animate(@src(), .{ .kind = .alpha, .duration = 300_000 }, .{ .id_extra = id.asUsize() });
    defer animator.deinit();

    dvui.labelNoFmt(@src(), message, .{}, .{
        .background = true,
        .corner_radius = dvui.Rect.all(1000),
        .padding = .{ .x = 16, .y = 8, .w = 16, .h = 8 },
        .color_fill = dvui.themeGet().color(.control, .fill),
        .border = dvui.Rect.all(2),
    });

    if (dvui.timerDone(id)) {
        animator.startEnd();
    }

    if (animator.end()) {
        dvui.toastRemove(id);
    }
}

pub const SpriteInitOptions = struct {
    source: dvui.ImageSource,
    file: ?*pixi.Internal.File = null,
    alpha_source: ?dvui.ImageSource = null,
    sprite: pixi.Sprite,
    scale: f32 = 1.0,
    //vertex_offsets: [4]dvui.Point.Physical = .{ .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 0 } },
    depth: f32 = 0.0, // -1.0 is front, 1.0 is back
    reflection: bool = false,
    overlap: f32 = 0.0,
};

pub fn sprite(src: std.builtin.SourceLocation, init_opts: SpriteInitOptions, opts: dvui.Options) dvui.WidgetData {
    const source_size: dvui.Size = dvui.imageSize(init_opts.source) catch .{ .w = 0, .h = 0 };

    const overlap: f32 = 1.0 - init_opts.overlap;

    const uv = dvui.Rect{
        .x = @as(f32, @floatFromInt(init_opts.sprite.source[0])) / source_size.w,
        .y = @as(f32, @floatFromInt(init_opts.sprite.source[1])) / source_size.h,
        .w = @as(f32, @floatFromInt(init_opts.sprite.source[2])) / source_size.w,
        .h = @as(f32, @floatFromInt(init_opts.sprite.source[3])) / source_size.h,
    };

    const options = (dvui.Options{ .name = "sprite" }).override(opts);

    var size = dvui.Size{};
    if (options.min_size_content) |msc| {
        // user gave us a min size, use it
        size = msc;
    } else {
        // user didn't give us one, use natural size
        size = .{ .w = @as(f32, @floatFromInt(init_opts.sprite.source[2])) * init_opts.scale * overlap, .h = @as(f32, @floatFromInt(init_opts.sprite.source[3])) * init_opts.scale * overlap };
    }

    var wd = dvui.WidgetData.init(src, .{}, options.override(.{ .min_size_content = size }));
    wd.register();

    const cr = wd.contentRect();
    const ms = wd.options.min_size_contentGet();

    var too_big = false;
    if (ms.w > cr.w or ms.h > cr.h) {
        too_big = true;
    }

    var e = wd.options.expandGet();
    const g = wd.options.gravityGet();
    var rect = dvui.placeIn(cr, ms, e, g);

    if (too_big and e != .ratio) {
        if (ms.w > cr.w and !e.isHorizontal()) {
            rect.w = ms.w;
            rect.x -= g.x * (ms.w - cr.w);
        }

        if (ms.h > cr.h and !e.isVertical()) {
            rect.h = ms.h;
            rect.y -= g.y * (ms.h - cr.h);
        }
    }

    // rect is the content rect, so expand to the whole rect
    wd.rect = rect.outset(wd.options.paddingGet()).outset(wd.options.borderGet()).outset(wd.options.marginGet());

    var renderBackground: ?dvui.Color = if (wd.options.backgroundGet()) wd.options.color(.fill) else null;

    if (wd.options.rotationGet() == 0.0) {
        wd.borderAndBackground(.{});
        renderBackground = null;
    } else {
        if (wd.options.borderGet().nonZero()) {
            dvui.log.debug("image {x} can't render border while rotated\n", .{wd.id});
        }
    }

    var path: dvui.Path.Builder = .init(dvui.currentWindow().arena());
    defer path.deinit();

    var top_left = wd.contentRectScale().r.topLeft();
    var top_right = wd.contentRectScale().r.topRight();
    var bottom_right = wd.contentRectScale().r.bottomRight();
    var bottom_left = wd.contentRectScale().r.bottomLeft();

    if (init_opts.depth > 0) {
        top_left = top_left.plus(bottom_right.diff(top_left).normalize().scale(init_opts.depth * wd.contentRectScale().r.w * -1.0, dvui.Point.Physical));
        bottom_left = bottom_left.plus(top_right.diff(bottom_left).normalize().scale(init_opts.depth * wd.contentRectScale().r.w * -1.0, dvui.Point.Physical));
    } else {
        top_right = top_right.plus(bottom_right.diff(top_right).normalize().scale(init_opts.depth * wd.contentRectScale().r.w, dvui.Point.Physical));
        bottom_right = bottom_right.plus(top_right.diff(bottom_right).normalize().scale(init_opts.depth * wd.contentRectScale().r.w, dvui.Point.Physical));
    }

    path.addPoint(top_left);
    path.addPoint(top_right);
    path.addPoint(bottom_right);
    path.addPoint(bottom_left);

    if (init_opts.reflection) {
        var path2: dvui.Path.Builder = .init(dvui.currentWindow().arena());
        defer path2.deinit();

        path2.addPoint(bottom_left.plus(.{ .y = bottom_left.y - top_left.y }));
        path2.addPoint(bottom_right.plus(.{ .y = bottom_left.y - top_left.y }));
        path2.addPoint(bottom_right);
        path2.addPoint(bottom_left);

        const reflection_triangles = pathToSubdividedQuad(path2.build(), dvui.currentWindow().arena(), .{ .subdivisions = 4, .uv = uv, .vertical_fade = true }) catch unreachable;
        dvui.renderTriangles(reflection_triangles, init_opts.source.getTexture() catch null) catch {
            dvui.log.err("Failed to render triangles", .{});
        };
    }

    const triangles = pathToSubdividedQuad(path.build(), dvui.currentWindow().arena(), .{ .subdivisions = 8, .uv = uv }) catch unreachable;

    if (init_opts.alpha_source) |alpha_source| {
        const alpha_triangles = pathToSubdividedQuad(path.build(), dvui.currentWindow().arena(), .{ .subdivisions = 8, .color_mod = dvui.themeGet().color(.content, .fill).lighten(12.0) }) catch unreachable;
        dvui.renderTriangles(alpha_triangles, alpha_source.getTexture() catch null) catch {
            dvui.log.err("Failed to render triangles", .{});
        };
    }

    if (init_opts.file) |file| {
        var index: usize = file.layers.len;
        while (index > 0) {
            index -= 1;
            dvui.renderTriangles(triangles, file.layers.items(.source)[index].getTexture() catch null) catch {
                dvui.log.err("Failed to render triangles", .{});
            };
        }
    } else {
        dvui.renderTriangles(triangles, init_opts.source.getTexture() catch null) catch {
            dvui.log.err("Failed to render triangles", .{});
        };
    }

    path.build().stroke(.{ .color = opts.color_border orelse .transparent, .thickness = 1.0, .closed = true });

    wd.minSizeSetAndRefresh();
    wd.minSizeReportToParent();

    return wd;
}

pub const PathToSubdividedQuadOptions = struct {
    subdivisions: usize = 4,
    uv: ?dvui.Rect = null,
    vertical_fade: bool = false,
    color_mod: dvui.Color = .white,
};

pub fn pathToSubdividedQuad(path: dvui.Path, allocator: std.mem.Allocator, options: PathToSubdividedQuadOptions) std.mem.Allocator.Error!dvui.Triangles {
    if (path.points.len != 4) {
        return .empty;
    }

    const subdivs = options.subdivisions;
    const vtx_count = (subdivs + 1) * (subdivs + 1);
    const idx_count = 2 * subdivs * subdivs * 3;

    var builder = try dvui.Triangles.Builder.init(allocator, vtx_count, idx_count);
    errdefer comptime unreachable;

    // Four quad corners in order: tl, tr, br, bl
    const tl = path.points[0];
    const tr = path.points[1];
    const br = path.points[2];
    const bl = path.points[3];

    // Use given UV or default to (0,0,1,1)
    const base_uv = options.uv orelse dvui.Rect{ .x = 0, .y = 0, .w = 1, .h = 1 };

    var last_pos: dvui.Point.Physical = tl;

    // Write all vertices, including the last row and column at s=1, t=1
    for (0..(subdivs + 1)) |j| { // vertical
        const t = @as(f32, @floatFromInt(j)) / @as(f32, @floatFromInt(subdivs));
        // Interpolate between tl/bl for left and tr/br for right
        const left = dvui.Point.Physical{
            .x = tl.x + (bl.x - tl.x) * t,
            .y = tl.y + (bl.y - tl.y) * t,
        };
        const right = dvui.Point.Physical{
            .x = tr.x + (br.x - tr.x) * t,
            .y = tr.y + (br.y - tr.y) * t,
        };
        for (0..(subdivs + 1)) |i| { // horizontal
            const s = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(subdivs));
            // Interpolate across row
            const pos = dvui.Point.Physical{
                .x = left.x + (right.x - left.x) * s,
                .y = left.y + (right.y - left.y) * s,
            };
            last_pos = pos;
            // Calculate UV in sub-rect if given, otherwise fill [0..1] range
            const uv = .{
                base_uv.x + base_uv.w * s,
                base_uv.y + base_uv.h * t,
            };

            const col: dvui.Color = if (options.vertical_fade) dvui.Color.white.opacity(0.5 * (1.0 - (1.0 - t))) else .white;
            const opacity = col.a;

            builder.appendVertex(.{
                .pos = pos,
                .col = dvui.Color.PMA.fromColor(col.lerp(options.color_mod, 0.5).opacity(@as(f32, @floatFromInt(opacity)) / 255.0)),
                .uv = uv,
            });
        }
    }

    // Generate indices for quads in row-major order
    for (0..subdivs) |j| {
        for (0..subdivs) |i| {
            const row_stride = subdivs + 1;
            const idx0 = j * row_stride + i;
            const idx1 = idx0 + 1;
            const idx2 = idx0 + row_stride;
            const idx3 = idx2 + 1;
            // 0---1
            // | / |
            // 2---3
            // first triangle (idx0, idx2, idx1)
            builder.appendTriangles(&.{
                @intCast(idx0),
                @intCast(idx2),
                @intCast(idx1),
            });
            // second triangle (idx1, idx2, idx3)
            builder.appendTriangles(&.{
                @intCast(idx1),
                @intCast(idx2),
                @intCast(idx3),
            });
        }
    }

    return builder.build();
}

pub fn renderSprite(source: dvui.ImageSource, s: pixi.Sprite, data_point: dvui.Point, scale: f32, opts: dvui.RenderTextureOptions) !void {
    const atlas_size = dvui.imageSize(source) catch {
        std.log.err("Failed to get atlas size", .{});
        return;
    };

    var opt = opts;

    const uv = dvui.Rect{
        .x = (@as(f32, @floatFromInt(s.source[0])) / atlas_size.w),
        .y = (@as(f32, @floatFromInt(s.source[1])) / atlas_size.h),
        .w = (@as(f32, @floatFromInt(s.source[2])) / atlas_size.w),
        .h = (@as(f32, @floatFromInt(s.source[3])) / atlas_size.h),
    };

    opt.uv = uv;

    const origin = dvui.Point{
        .x = @as(f32, @floatFromInt(s.origin[0])) * 1 / scale,
        .y = @as(f32, @floatFromInt(s.origin[1])) * 1 / scale,
    };

    const position = data_point.diff(origin);

    const box = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .none,
        .rect = .{
            .x = position.x,
            .y = position.y,
            .w = @as(f32, @floatFromInt(s.source[2])) * scale,
            .h = @as(f32, @floatFromInt(s.source[3])) * scale,
        },
        .border = dvui.Rect.all(0),
        .corner_radius = .{ .x = 0, .y = 0 },
        .padding = .{ .x = 0, .y = 0 },
        .margin = .{ .x = 0, .y = 0 },
        .background = false,
        .color_fill = dvui.themeGet().color(.err, .fill),
    });
    defer box.deinit();

    const rs = box.data().rectScale();

    try dvui.renderImage(source, rs, opt);
}

pub fn labelWithKeybind(label_str: []const u8, hotkey: dvui.enums.Keybind, enabled: bool, opts: dvui.Options) void {
    const box = dvui.box(@src(), .{ .dir = .horizontal }, opts);
    defer box.deinit();

    var new_opts = opts.strip();
    if (!enabled) {
        if (new_opts.color_text) |c| {
            new_opts.color_text = c.opacity(0.5);
        } else {
            new_opts.color_text = dvui.themeGet().color(.window, .text).opacity(0.5);
        }
    }

    dvui.labelNoFmt(@src(), label_str, .{}, new_opts);
    _ = dvui.spacer(@src(), .{ .min_size_content = .width(12) });

    var second_opts = opts.strip();
    second_opts.color_text = dvui.themeGet().color(.control, .text);
    second_opts.gravity_y = 0.5;
    second_opts.gravity_x = 1.0;
    second_opts.font_style = .heading;

    keybindLabels(&hotkey, enabled, second_opts);
}

pub fn keybindLabels(self: *const dvui.enums.Keybind, enabled: bool, opts: dvui.Options) void {
    var box = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .none, .gravity_x = 1.0 });
    defer box.deinit();

    var color = if (opts.color_text) |c| c else dvui.themeGet().color(.control, .text);
    if (true or enabled) {
        color = color.opacity(0.5);
    }

    var second_opts = opts.strip();
    second_opts.color_text = color;

    var needs_space = false;
    if (self.control) |ctrl| {
        if (ctrl) {
            needs_space = true;
            if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts.strip());
            //if (needs_plus) dvui.labelNoFmt(@src(), "+", .{}, opts.strip()) else needs_plus = true;
            //if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts.strip()) else needs_space = true;

            dvui.labelNoFmt(@src(), "ctrl", .{}, second_opts);
        }
    }

    if (self.command) |cmd| {
        if (cmd) {
            needs_space = true;
            if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts.strip());
            //if (needs_plus) dvui.labelNoFmt(@src(), "+", .{}, opts.strip()) else needs_plus = true;
            //if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts.strip()) else needs_space = true;
            if (builtin.os.tag == .macos) {
                dvui.icon(@src(), "cmd", icons.tvg.lucide.command, .{ .stroke_color = color }, .{ .gravity_y = 0.5 });
            } else {
                dvui.labelNoFmt(@src(), "cmd", .{}, second_opts);
            }
        }
    }

    if (self.alt) |alt| {
        if (alt) {
            needs_space = true;
            if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts.strip());
            //if (needs_plus) dvui.labelNoFmt(@src(), "+", .{}, opts.strip()) else needs_plus = true;
            //if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts.strip()) else needs_space = true;
            if (builtin.os.tag == .macos) {
                dvui.icon(@src(), "option", icons.tvg.lucide.option, .{ .stroke_color = color }, .{ .gravity_y = 0.5 });
            } else {
                dvui.labelNoFmt(@src(), "alt", .{}, second_opts);
            }
        }
    }

    if (self.shift) |shift| {
        if (shift) {
            needs_space = true;
            if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts.strip());
            //if (needs_plus) dvui.labelNoFmt(@src(), "+", .{}, opts.strip()) else needs_plus = true;
            //if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts.strip()) else needs_space = true;
            dvui.labelNoFmt(@src(), "shift", .{}, second_opts);
        }
    }

    if (self.key) |key| {
        needs_space = true;
        if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts.strip());
        //if (needs_plus) dvui.labelNoFmt(@src(), "+", .{}, opts.strip()) else needs_plus = true;
        //if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts.strip()) else needs_space = true;
        dvui.labelNoFmt(@src(), @tagName(key), .{}, second_opts);
    }
}

const Shadow = enum {
    top,
    bottom,
    right,
    left,
};

const ShadowOptions = struct {
    color: dvui.Color = .black,
    opacity: f32 = 0.25,
    offset: dvui.Rect = .{},
    thickness: f32 = 20.0,
};

pub fn drawEdgeShadow(container: dvui.RectScale, shadow: Shadow, opts: ShadowOptions) void {
    switch (shadow) {
        .top => {
            var rs = container;
            rs.r.h = opts.thickness;

            rs.r = rs.r.plus(.cast(opts.offset));

            var path: dvui.Path.Builder = .init(dvui.currentWindow().arena());
            path.addRect(rs.r, dvui.Rect.Physical.all(5));

            var triangles = path.build().fillConvexTriangles(dvui.currentWindow().arena(), .{ .center = rs.r.center(), .color = .white }) catch return;

            const ca0 = opts.color.opacity(opts.opacity);
            const ca1 = opts.color.opacity(0);

            for (triangles.vertexes) |*v| {
                const t = std.math.clamp((v.pos.y - rs.r.y) / rs.r.h, 0.0, 1.0);
                v.col = v.col.multiply(.fromColor(dvui.Color.lerp(ca0, ca1, t)));
            }
            dvui.renderTriangles(triangles, null) catch {
                dvui.log.err("Failed to render triangles", .{});
            };

            triangles.deinit(dvui.currentWindow().arena());
            path.deinit();
        },

        .bottom => {
            var rs = container;
            rs.r.y += rs.r.h - opts.thickness;
            rs.r.h = opts.thickness;

            rs.r = rs.r.plus(.cast(opts.offset));

            var path: dvui.Path.Builder = .init(dvui.currentWindow().arena());
            path.addRect(rs.r, dvui.Rect.Physical.all(5));

            var triangles = path.build().fillConvexTriangles(dvui.currentWindow().arena(), .{ .center = rs.r.center(), .color = .white }) catch return;

            const ca0 = opts.color.opacity(0.0);
            const ca1 = opts.color.opacity(opts.opacity);

            for (triangles.vertexes) |*v| {
                const t = std.math.clamp((v.pos.y - rs.r.y) / rs.r.h, 0.0, 1.0);
                v.col = v.col.multiply(.fromColor(dvui.Color.lerp(ca0, ca1, t)));
            }
            dvui.renderTriangles(triangles, null) catch {
                dvui.log.err("Failed to render triangles", .{});
            };

            triangles.deinit(dvui.currentWindow().arena());
            path.deinit();
        },

        .right => {
            var rs = container;
            rs.r.x += rs.r.w - opts.thickness;
            rs.r.w = opts.thickness;

            rs.r = rs.r.plus(.cast(opts.offset));

            var path: dvui.Path.Builder = .init(dvui.currentWindow().arena());
            path.addRect(rs.r, dvui.Rect.Physical.all(5));

            var triangles = path.build().fillConvexTriangles(dvui.currentWindow().arena(), .{ .center = rs.r.center(), .color = .white }) catch return;

            const ca0 = opts.color.opacity(0.0);
            const ca1 = opts.color.opacity(opts.opacity);

            for (triangles.vertexes) |*v| {
                const t = std.math.clamp((v.pos.x - rs.r.x) / rs.r.w, 0.0, 1.0);
                v.col = v.col.multiply(.fromColor(dvui.Color.lerp(ca0, ca1, t)));
            }
            dvui.renderTriangles(triangles, null) catch {
                dvui.log.err("Failed to render triangles", .{});
            };

            triangles.deinit(dvui.currentWindow().arena());
            path.deinit();
        },
        .left => {
            var rs = container;
            rs.r.w = opts.thickness;

            rs.r = rs.r.plus(.cast(opts.offset));

            var path: dvui.Path.Builder = .init(dvui.currentWindow().arena());
            path.addRect(rs.r, dvui.Rect.Physical.all(5));

            var triangles = path.build().fillConvexTriangles(dvui.currentWindow().arena(), .{ .center = rs.r.center(), .color = .white }) catch return;

            const ca0 = opts.color.opacity(opts.opacity);
            const ca1 = opts.color.opacity(0.0);

            for (triangles.vertexes) |*v| {
                const t = std.math.clamp((v.pos.x - rs.r.x) / rs.r.w, 0.0, 1.0);
                v.col = v.col.multiply(.fromColor(dvui.Color.lerp(ca0, ca1, t)));
            }
            dvui.renderTriangles(triangles, null) catch {
                dvui.log.err("Failed to render triangles", .{});
            };

            triangles.deinit(dvui.currentWindow().arena());
            path.deinit();
        },
    }
}
