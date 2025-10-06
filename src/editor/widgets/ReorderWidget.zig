const std = @import("std");
const dvui = @import("dvui");

const Options = dvui.Options;
const Rect = dvui.Rect;
const RectScale = dvui.RectScale;
const Size = dvui.Size;
const Widget = dvui.Widget;
const WidgetData = dvui.WidgetData;

const ReorderWidget = @This();

pub const InitOptions = struct {
    /// If not null, drags give up mouse capture and set this drag name
    drag_name: ?[]const u8 = null,
};

wd: WidgetData,
init_opts: InitOptions,
id_reorderable: ?usize = null, // matches Reorderable.reorder_id
drag_point: ?dvui.Point.Physical = null, // non null if we started the drag
drag_ending: bool = false,
reorderable_size: Size = .{},
found_slot: bool = false,

pub fn init(src: std.builtin.SourceLocation, init_opts: InitOptions, opts: Options) ReorderWidget {
    const defaults = Options{ .name = "Reorder" };
    const wd = WidgetData.init(src, .{}, defaults.override(opts));
    var self: ReorderWidget = .{
        .wd = wd,
        .init_opts = init_opts,
        .id_reorderable = dvui.dataGet(null, wd.id, "_id_reorderable", usize),
        .drag_point = dvui.dataGet(null, wd.id, "_drag_point", dvui.Point.Physical),
        .reorderable_size = dvui.dataGet(null, wd.id, "_reorderable_size", dvui.Size) orelse .{},
    };
    if (init_opts.drag_name) |dn| {
        if (self.drag_point != null and !dvui.dragName(dn)) {
            self.drag_ending = true;
        }
    }
    return self;
}

pub fn install(self: *ReorderWidget) void {
    self.data().register();
    self.data().borderAndBackground(.{});

    dvui.parentSet(self.widget());
}

pub fn needFinalSlot(self: *ReorderWidget) bool {
    if (self.drag_ending or dvui.captured(self.wd.id) or (self.init_opts.drag_name != null and dvui.dragName(self.init_opts.drag_name.?))) {
        return !self.found_slot and self.data().borderRectScale().r.contains(dvui.currentWindow().mouse_pt);
    }

    return false;
}

pub fn finalSlot(self: *ReorderWidget) bool {
    if (self.needFinalSlot()) {
        var r = self.reorderable(@src(), .{ .last_slot = true }, .{});
        defer r.deinit();

        if (r.insertBefore()) {
            return true;
        }
    }

    return false;
}

pub fn widget(self: *ReorderWidget) Widget {
    return Widget.init(self, data, rectFor, screenRectScale, minSizeForChild);
}

pub fn data(self: *ReorderWidget) *WidgetData {
    return self.wd.validate();
}

pub fn rectFor(self: *ReorderWidget, id: dvui.Id, min_size: Size, e: Options.Expand, g: Options.Gravity) Rect {
    _ = id;
    return dvui.placeIn(self.data().contentRect().justSize(), min_size, e, g);
}

pub fn screenRectScale(self: *ReorderWidget, rect: Rect) RectScale {
    return self.data().contentRectScale().rectToRectScale(rect);
}

pub fn minSizeForChild(self: *ReorderWidget, s: Size) void {
    self.data().minSizeMax(self.data().options.padSize(s));
}

pub fn matchEvent(self: *ReorderWidget, event: *dvui.Event) bool {
    if (dvui.captured(self.wd.id) or (self.init_opts.drag_name != null and dvui.dragName(self.init_opts.drag_name.?))) {
        // passively listen to mouse motion
        for (dvui.events()) |*e| {
            if (e.evt == .mouse and e.evt.mouse.action == .motion) {
                if (self.drag_point != null) {
                    self.drag_point = e.evt.mouse.p;

                    dvui.scrollDrag(.{
                        .mouse_pt = e.evt.mouse.p,
                        .screen_rect = self.wd.rectScale().r,
                    });
                }
            }
        }
    }

    if (self.init_opts.drag_name) |dn| {
        if (dvui.dragName(dn)) {
            return dvui.eventMatch(event, .{ .id = self.wd.id, .r = self.data().borderRectScale().r, .drag_name = dn });
        }
    }

    return dvui.eventMatchSimple(event, self.data());
}

pub fn processEvents(self: *ReorderWidget) void {
    const evts = dvui.events();
    for (evts) |*e| {
        if (!self.matchEvent(e))
            continue;

        self.processEvent(e);
    }
}

pub fn processEvent(self: *ReorderWidget, e: *dvui.Event) void {
    switch (e.evt) {
        .mouse => |me| {
            if (me.action == .release and me.button.pointer() and self.drag_point != null) {
                e.handle(@src(), self.data());
                self.drag_ending = true;
                dvui.captureMouse(null, e.num);
                dvui.dragEnd();
            }
        },
        else => {},
    }
}

pub fn deinit(self: *ReorderWidget) void {
    defer dvui.widgetFree(self);
    if (self.drag_ending) {
        self.id_reorderable = null;
        self.drag_point = null;
        dvui.refresh(null, @src(), self.data().id);
    }

    if (self.id_reorderable) |idr| {
        dvui.dataSet(null, self.data().id, "_id_reorderable", idr);
    } else {
        dvui.dataRemove(null, self.data().id, "_id_reorderable");
    }

    if (self.drag_point) |dp| {
        dvui.dataSet(null, self.data().id, "_drag_point", dp);
    } else {
        dvui.dataRemove(null, self.data().id, "_drag_point");
    }

    dvui.dataSet(null, self.data().id, "_reorderable_size", self.reorderable_size);

    self.data().minSizeSetAndRefresh();
    self.data().minSizeReportToParent();
    dvui.parentReset(self.data().id, self.data().parent);
    self.* = undefined;
}

pub fn dragStart(self: *ReorderWidget, reorder_id: usize, p: dvui.Point.Physical, event_num: u16, offset: dvui.Point.Physical) void {
    self.id_reorderable = reorder_id;
    self.drag_point = p;
    dvui.captureMouse(self.data(), event_num);
    if (self.init_opts.drag_name) |dn| {
        // have to call dragStart to set the drag name
        dvui.dragStart(p, .{ .name = dn, .offset = offset });
        dvui.captureMouse(null, 0);
    }
}

pub const draggableInitOptions = struct {
    tvg_bytes: ?[]const u8 = null,
    top_left: ?dvui.Point.Physical = null,
    reorderable: ?*Reorderable = null,
    color: ?dvui.Color = null,
};

pub fn draggable(src: std.builtin.SourceLocation, init_opts: draggableInitOptions, opts: dvui.Options) ?dvui.Point.Physical {
    var iw = dvui.IconWidget.init(src, "reorder_drag_icon", init_opts.tvg_bytes orelse dvui.entypo.menu, .{ .fill_color = init_opts.color, .stroke_color = init_opts.color }, opts);
    iw.install();
    var ret: ?dvui.Point.Physical = null;
    loop: for (dvui.events()) |*e| {
        if (!iw.matchEvent(e))
            continue;

        switch (e.evt) {
            .mouse => |me| {
                if (me.action == .press and me.button.pointer()) {
                    e.handle(@src(), iw.data());
                    dvui.captureMouse(iw.data(), e.num);
                    //const reo_top_left: ?dvui.Point.Physical = if (init_opts.reorderable) |reo| reo.data().rectScale().r.topLeft() else null;
                    //const top_left: ?dvui.Point.Physical = init_opts.top_left orelse reo_top_left;
                    dvui.dragPreStart(me.p, .{ .offset = (iw.data().rectScale().r.topLeft()).diff(me.p) });
                } else if (me.action == .release and me.button.pointer()) {
                    dvui.captureMouse(null, e.num);
                    dvui.dragEnd();
                } else if (me.action == .motion) {
                    if (dvui.captured(iw.data().id)) {
                        e.handle(@src(), iw.data());
                        if (dvui.dragging(me.p, null)) |_| {
                            ret = me.p;
                            if (init_opts.reorderable) |reo| {
                                reo.reorder.dragStart(reo.data().id.asUsize(), me.p, e.num, (iw.data().rectScale().r.topLeft()).diff(me.p)); // reorder grabs capture
                            }
                            break :loop;
                        }
                    }
                }
            },
            else => {},
        }
    }
    iw.draw();
    iw.deinit();
    return ret;
}

pub fn reorderable(self: *ReorderWidget, src: std.builtin.SourceLocation, init_opts: Reorderable.InitOptions, opts: Options) *Reorderable {
    const ret = dvui.widgetAlloc(Reorderable);
    ret.* = Reorderable.init(src, self, init_opts, opts);
    ret.install();
    return ret;
}

pub const Reorderable = struct {
    pub const InitOptions = struct {

        // set to true for a reorderable that represents a final empty slot in
        // the list shown during dragging
        last_slot: bool = false,

        // if null, uses widget id
        // if non-null, must be unique among reorderables in a single reorder
        reorder_id: ?usize = null,

        // if false, caller responsible for drawing something when targetRectScale() returns true
        draw_target: bool = true,

        // if false, caller responsible for calling reinstall() when targetRectScale() returns true
        reinstall: bool = true,
    };

    wd: WidgetData,
    reorder: *ReorderWidget,
    init_options: Reorderable.InitOptions,
    options: Options,
    installed: bool = false,
    floating_widget: ?dvui.FloatingWidget = null,
    target_rs: ?dvui.RectScale = null,

    pub fn init(src: std.builtin.SourceLocation, reorder: *ReorderWidget, init_opts: Reorderable.InitOptions, opts: Options) Reorderable {
        const defaults = Options{ .name = "Reorderable" };
        const options = defaults.override(opts);
        return .{
            .reorder = reorder,
            .init_options = init_opts,
            .options = options,
            .wd = WidgetData.init(src, .{}, options.override(.{ .rect = .{} })),
        };
    }

    // can call this after init before install
    pub fn floating(self: *Reorderable) bool {
        // if drag_point is non-null, id_reorderable is non-null
        if (self.reorder.drag_point != null and self.reorder.id_reorderable.? == (self.init_options.reorder_id orelse self.data().id.asUsize())) {
            return true;
        }

        return false;
    }

    pub fn install(self: *Reorderable) void {
        self.installed = true;
        if (self.reorder.drag_ending or dvui.captured(self.reorder.data().id) or (self.reorder.init_opts.drag_name != null and dvui.dragName(self.reorder.init_opts.drag_name.?))) {
            const topleft = dvui.currentWindow().mouse_pt.plus(dvui.dragOffset());
            if (self.reorder.drag_point != null and self.reorder.id_reorderable.? == (self.init_options.reorder_id orelse self.data().id.asUsize())) {
                // we are being dragged - put in floating widget
                self.data().register();
                dvui.parentSet(self.widget());

                self.floating_widget = dvui.FloatingWidget.init(@src(), .{ .mouse_events = false }, .{ .rect = Rect.fromPoint(.cast(topleft.toNatural())), .min_size_content = self.reorder.reorderable_size });
                self.floating_widget.?.install();
            } else {
                if (self.init_options.last_slot) {
                    self.wd = WidgetData.init(self.data().src, .{}, self.options.override(.{ .min_size_content = self.reorder.reorderable_size }));
                } else {
                    self.wd = WidgetData.init(self.data().src, .{}, self.options);
                }
                const rs = self.data().rectScale();
                const dragRect = Rect.Physical.fromPoint(topleft).toSize(self.reorder.reorderable_size.scale(rs.s, Size.Physical));

                if (!self.reorder.found_slot and !rs.r.intersect(dragRect).empty()) {
                    // user is dragging a reorderable over this rect
                    self.target_rs = rs;
                    self.reorder.found_slot = true;

                    if (self.init_options.draw_target) {
                        rs.r.fill(
                            .all(10000),
                            .{ .color = dvui.themeGet().color(.window, .fill), .fade = if (rs.s > 1.0) 0.0 else 1.0 },
                        );
                    }

                    if (self.init_options.reinstall and !self.init_options.last_slot) {
                        self.reinstall();
                    }

                    if (self.init_options.last_slot) {
                        dvui.scrollTo(.{ .screen_rect = rs.r });
                    }
                }

                if (self.target_rs == null or self.init_options.last_slot) {
                    self.data().register();
                    dvui.parentSet(self.widget());
                }
            }
        } else {
            self.wd = WidgetData.init(self.data().src, .{}, self.options);
            self.reorder.reorderable_size = self.wd.rect.size();

            self.wd.register();
            dvui.parentSet(self.widget());
        }
    }

    pub fn targetRectScale(self: *Reorderable) ?dvui.RectScale {
        return self.target_rs;
    }

    pub fn removed(self: *Reorderable) bool {
        if (self.reorder.drag_ending and self.reorder.drag_point != null and self.reorder.id_reorderable.? == (self.init_options.reorder_id orelse self.data().id.asUsize())) {
            return true;
        }

        return false;
    }

    // must be called after install()
    pub fn insertBefore(self: *Reorderable) bool {
        if (!self.installed) {
            dvui.log.err("Reorderable.insertBefore() must be called after install()", .{});
            std.debug.assert(false);
        }

        if (self.reorder.drag_ending and self.target_rs != null) {
            return true;
        }

        return false;
    }

    pub fn reinstall(self: *Reorderable) void {
        self.reinstall1();
        self.reinstall2();
    }

    pub fn reinstall1(self: *Reorderable) void {
        // send our target rect to the parent for sizing
        self.data().minSizeMax(self.data().rect.size());
        self.data().minSizeReportToParent();
    }

    pub fn reinstall2(self: *Reorderable) void {
        // reinstall ourselves getting the next rect from parent
        self.wd = WidgetData.init(self.wd.src, .{}, self.options);
        self.wd.register();
        dvui.parentSet(self.widget());
    }

    pub fn widget(self: *Reorderable) Widget {
        return Widget.init(self, Reorderable.data, Reorderable.rectFor, Reorderable.screenRectScale, Reorderable.minSizeForChild);
    }

    pub fn data(self: *Reorderable) *WidgetData {
        return self.wd.validate();
    }

    pub fn rectFor(self: *Reorderable, id: dvui.Id, min_size: Size, e: Options.Expand, g: Options.Gravity) Rect {
        _ = id;
        return dvui.placeIn(self.data().contentRect().justSize(), min_size, e, g);
    }

    pub fn screenRectScale(self: *Reorderable, rect: Rect) RectScale {
        return self.data().contentRectScale().rectToRectScale(rect);
    }

    pub fn minSizeForChild(self: *Reorderable, s: Size) void {
        self.data().minSizeMax(self.data().options.padSize(s));
    }

    pub fn deinit(self: *Reorderable) void {
        defer dvui.widgetFree(self);
        if (self.floating_widget) |*fw| {
            self.data().minSizeMax(fw.data().min_size);
            fw.deinit();
        }

        self.data().minSizeSetAndRefresh();
        self.data().minSizeReportToParent();

        dvui.parentReset(self.data().id, self.data().parent);
        self.* = undefined;
    }
};

pub fn reorderSlice(comptime T: type, slice: []T, removed_idx: usize, insert_before_idx: usize) void {
    const ri = removed_idx;
    const ibi = insert_before_idx;

    const removed = slice[ri];
    if (ri < ibi) {
        // moving down, shift others up
        for (ri..ibi - 1) |i| {
            slice[i] = slice[i + 1];
        }
        slice[ibi - 1] = removed;
    } else {
        // moving up, shift others down
        for (ibi..ri, 0..) |_, i| {
            slice[ri - i] = slice[ri - i - 1];
        }
        slice[ibi] = removed;
    }
}

test {
    @import("std").testing.refAllDecls(@This());
}
