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
    ret.* = ReorderWidget.init(src, init_opts, opts);
    ret.install();
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
    sprite: pixi.Sprite,
    scale: f32 = 1.0,
};

pub fn sprite(src: std.builtin.SourceLocation, init_opts: SpriteInitOptions, opts: dvui.Options) dvui.WidgetData {
    const source_size: dvui.Size = dvui.imageSize(init_opts.source) catch .{ .w = 0, .h = 0 };

    const uv = dvui.Rect{
        .x = (@as(f32, @floatFromInt(init_opts.sprite.source[0])) / source_size.w),
        .y = (@as(f32, @floatFromInt(init_opts.sprite.source[1])) / source_size.h),
        .w = (@as(f32, @floatFromInt(init_opts.sprite.source[2])) / source_size.w),
        .h = (@as(f32, @floatFromInt(init_opts.sprite.source[3])) / source_size.h),
    };

    const options = (dvui.Options{ .name = "sprite" }).override(opts);

    var size = dvui.Size{};
    if (options.min_size_content) |msc| {
        // user gave us a min size, use it
        size = msc;
    } else {
        // user didn't give us one, use natural size
        size = .{ .w = @as(f32, @floatFromInt(init_opts.sprite.source[2])) * init_opts.scale, .h = @as(f32, @floatFromInt(init_opts.sprite.source[3])) * init_opts.scale };
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
    const render_tex_opts = dvui.RenderTextureOptions{
        .rotation = wd.options.rotationGet(),
        .corner_radius = wd.options.corner_radiusGet(),
        .uv = uv,
        .background_color = renderBackground,
    };
    const content_rs = wd.contentRectScale();
    dvui.renderImage(init_opts.source, content_rs, render_tex_opts) catch |err| dvui.logError(@src(), err, "Could not render image {?s} at {}", .{ opts.name, content_rs });
    wd.minSizeSetAndRefresh();
    wd.minSizeReportToParent();

    return wd;

    // const box = dvui.box(@src(), .{ .dir = .horizontal }, .{
    //     .expand = .none,
    //     .rect = .{
    //         .x = position.x,
    //         .y = position.y,
    //         .w = @as(f32, @floatFromInt(sprite.source[2])) * scale,
    //         .h = @as(f32, @floatFromInt(sprite.source[3])) * scale,
    //     },
    //     .border = dvui.Rect.all(0),
    //     .corner_radius = .{ .x = 0, .y = 0 },
    //     .padding = .{ .x = 0, .y = 0 },
    //     .margin = .{ .x = 0, .y = 0 },
    //     .background = false,
    //     .color_fill = dvui.themeGet().color(.err, .fill),
    // });
    // defer box.deinit();

    // const rs = box.data().rectScale();

    // try dvui.renderImage(source, rs, .{
    //     .uv = uv,
    // });
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
