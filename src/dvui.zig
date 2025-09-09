const std = @import("std");
const dvui = @import("dvui");
const builtin = @import("builtin");
const icons = @import("icons");
const Widgets = @import("editor/Widgets.zig");

pub const FileWidget = Widgets.FileWidget;
pub const TabsWidget = Widgets.TabsWidget;
pub const ImageWidget = Widgets.ImageWidget;
pub const CanvasWidget = Widgets.CanvasWidget;
pub const ReorderWidget = Widgets.ReorderWidget;
pub const PanedWidget = Widgets.PanedWidget;
pub const LayerPanedWidget = Widgets.LayerPanedWidget;

/// Currently this is specialized for the layers paned widget, just includes icon and dragging flag so we know when the pane is dragging
pub fn layersPaned(src: std.builtin.SourceLocation, init_opts: LayerPanedWidget.InitOptions, opts: dvui.Options) *LayerPanedWidget {
    var ret = dvui.widgetAlloc(LayerPanedWidget);
    ret.* = LayerPanedWidget.init(src, init_opts, opts);
    ret.install();
    ret.processEvents();
    return ret;
}

/// Currently this is specialized, just includes icon in the handle
pub fn paned(src: std.builtin.SourceLocation, init_opts: PanedWidget.InitOptions, opts: dvui.Options) *PanedWidget {
    var ret = dvui.widgetAlloc(PanedWidget);
    ret.* = PanedWidget.init(src, init_opts, opts);
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

pub fn labelWithKeybind(label_str: []const u8, hotkey: dvui.enums.Keybind, opts: dvui.Options) void {
    const box = dvui.box(@src(), .{ .dir = .horizontal }, opts);
    defer box.deinit();

    dvui.labelNoFmt(@src(), label_str, .{}, opts.strip());
    _ = dvui.spacer(@src(), .{ .min_size_content = .width(6) });

    var second_opts = opts.strip();
    second_opts.color_text = dvui.themeGet().color(.control, .text);
    second_opts.gravity_y = 0.5;
    second_opts.gravity_x = 1.0;

    keybindLabels(&hotkey, second_opts);
}

pub fn keybindLabels(self: *const dvui.enums.Keybind, opts: dvui.Options) void {
    var box = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .none, .gravity_x = 1.0 });
    defer box.deinit();

    var needs_space = false;
    var needs_plus = false;
    if (self.control) |ctrl| {
        if (ctrl) {
            if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts.strip());
            if (needs_plus) dvui.labelNoFmt(@src(), "+", .{}, opts.strip()) else needs_plus = true;
            if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts.strip()) else needs_space = true;

            dvui.labelNoFmt(@src(), "ctrl", .{}, opts.strip());
        }
    }

    if (self.command) |cmd| {
        if (cmd) {
            if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts.strip());
            if (needs_plus) dvui.labelNoFmt(@src(), "+", .{}, opts.strip()) else needs_plus = true;
            if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts.strip()) else needs_space = true;
            if (builtin.os.tag == .macos) {
                dvui.icon(@src(), "cmd", icons.tvg.lucide.command, .{ .stroke_color = dvui.themeGet().color(.control, .text) }, .{ .gravity_y = 0.5 });
            } else {
                dvui.labelNoFmt(@src(), "cmd", .{}, opts.strip());
            }
        }
    }

    if (self.alt) |alt| {
        if (alt) {
            if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts.strip());
            if (needs_plus) dvui.labelNoFmt(@src(), "+", .{}, opts.strip()) else needs_plus = true;
            if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts.strip()) else needs_space = true;
            if (builtin.os.tag == .macos) {
                dvui.icon(@src(), "option", icons.tvg.lucide.option, .{ .stroke_color = dvui.themeGet().color(.control, .text) }, .{ .gravity_y = 0.5 });
            } else {
                dvui.labelNoFmt(@src(), "alt", .{}, opts.strip());
            }
        }
    }

    if (self.shift) |shift| {
        if (shift) {
            if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts.strip());
            if (needs_plus) dvui.labelNoFmt(@src(), "+", .{}, opts.strip()) else needs_plus = true;
            if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts.strip()) else needs_space = true;
            dvui.labelNoFmt(@src(), "shift", .{}, opts.strip());
        }
    }

    if (self.key) |key| {
        if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts.strip());
        if (needs_plus) dvui.labelNoFmt(@src(), "+", .{}, opts.strip()) else needs_plus = true;
        if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts.strip()) else needs_space = true;
        dvui.labelNoFmt(@src(), @tagName(key), .{}, opts.strip());
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
    opacity: f32 = 0.1,
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
