pub const TabsWidget = @This();

init_options: InitOptions,
options: Options,
scroll: ScrollAreaWidget,
/// SAFETY: Set in `install`
box: BoxWidget = undefined,
tab_index: usize = 0,
/// SAFETY: Set in `addTab`
tab_box: dvui.BoxWidget = undefined,

pub var defaults: Options = .{
    .background = false,
    .corner_radius = Rect{},
    .name = "Tabs",
};

pub const InitOptions = struct {
    dir: dvui.enums.Direction = .horizontal,
};

pub fn init(src: std.builtin.SourceLocation, init_opts: InitOptions, opts: Options) TabsWidget {
    const scroll_opts: ScrollAreaWidget.InitOpts = switch (init_opts.dir) {
        .horizontal => .{ .vertical = .none, .horizontal = .auto, .horizontal_bar = .hide },
        .vertical => .{ .vertical = .auto, .vertical_bar = .hide },
    };
    return .{
        .init_options = init_opts,
        .options = opts,
        .scroll = ScrollAreaWidget.init(src, scroll_opts, defaults.override(opts)),
    };
}

pub fn install(self: *TabsWidget) void {
    self.scroll.install();

    self.box = BoxWidget.init(@src(), .{ .dir = self.init_options.dir }, self.options);
    self.box.install();

    // var r = self.scroll.data().contentRectScale().r;
    // switch (self.init_options.dir) {
    //     .horizontal => {
    //         if (dvui.currentWindow().snap_to_pixels) {
    //             r.x += 0.5;
    //             r.w -= 1.0;
    //             r.y = @floor(r.y) - 0.5;
    //         }
    //         dvui.Path.stroke(.{ .points = &.{ r.bottomLeft(), r.bottomRight() } }, .{ .thickness = 1, .color = dvui.themeGet().color_border });
    //     },
    //     .vertical => {
    //         if (dvui.currentWindow().snap_to_pixels) {
    //             r.y += 0.5;
    //             r.h -= 1.0;
    //             r.x = @floor(r.x) - 0.5;
    //         }
    //         dvui.Path.stroke(.{ .points = &.{ r.topRight(), r.bottomRight() } }, .{ .thickness = 1, .color = dvui.themeGet().color_border });
    //     },
    // }
}

pub fn addTabLabel(self: *TabsWidget, selected: bool, text: []const u8) bool {
    var tab = self.addTab(selected, .{});
    defer tab.deinit();

    var label_opts = tab.data().options.strip();
    if (dvui.captured(tab.data().id)) {
        label_opts.color_text = .{ .name = .text_press };
    }

    dvui.labelNoFmt(@src(), text, .{}, label_opts);

    return tab.clicked();
}

pub fn addTab(self: *TabsWidget, selected: bool, opts: Options) *dvui.BoxWidget {
    self.tab_box = dvui.BoxWidget.init(@src(), .{ .dir = .horizontal }, opts);
    self.tab_box.install();

    self.tab_box.drawBackground();

    if (selected) {
        const rs = self.tab_box.data().borderRectScale();
        const r = rs.r;

        switch (self.init_options.dir) {
            .horizontal => {
                var path: dvui.Path.Builder = .init(dvui.currentWindow().lifo());
                defer path.deinit();

                path.addPoint(r.topRight());
                path.addPoint(r.topLeft());
                path.build().stroke(.{ .thickness = 2 * rs.s, .color = dvui.themeGet().color(.window, .text), .after = true });
            },
            .vertical => {
                var path: dvui.Path.Builder = .init(dvui.currentWindow().lifo());
                defer path.deinit();

                path.addPoint(r.topRight());
                path.addPoint(r.bottomRight());
                path.build().stroke(.{ .thickness = 2 * rs.s, .color = dvui.themeGet().color(.window, .text), .after = true });
            },
        }
    }

    return &self.tab_box;
}

pub fn deinit(self: *TabsWidget) void {
    defer dvui.widgetFree(self);
    self.box.deinit();
    self.scroll.deinit();
    self.* = undefined;
}

const Options = dvui.Options;
const Rect = dvui.Rect;
const Point = dvui.Point;

const BoxWidget = dvui.BoxWidget;
const ButtonWidget = dvui.ButtonWidget;
const ScrollAreaWidget = dvui.ScrollAreaWidget;

const std = @import("std");
const math = std.math;
const dvui = @import("dvui");

test {
    @import("std").testing.refAllDecls(@This());
}
