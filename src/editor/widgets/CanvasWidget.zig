const std = @import("std");
const dvui = @import("dvui");
const pixi = @import("../../pixi.zig");

pub const CanvasWidget = @This();

id: dvui.Id = undefined,
init_opts: InitOptions = undefined,
scroll: *dvui.ScrollAreaWidget = undefined,
scaler: *dvui.ScaleWidget = undefined,
rect: dvui.Rect.Physical = .{},
scroll_container: *dvui.ScrollContainerWidget = undefined,
scroll_rect_scale: dvui.RectScale = .{},
screen_rect_scale: dvui.RectScale = .{},
scroll_info: dvui.ScrollInfo = .{ .vertical = .given, .horizontal = .given },
origin: dvui.Point = .{},
scale: f32 = 1.0,
prev_size: dvui.Size = .{},
prev_scale: f32 = 0.0,
bounding_box: ?dvui.Rect.Physical = null,
hovered: bool = false,

pub const InitOptions = struct {
    id: dvui.Id,
    data_size: dvui.Size,
};

pub fn install(self: *CanvasWidget, src: std.builtin.SourceLocation, init_opts: InitOptions, opts: dvui.Options) void {
    self.id = init_opts.id;
    self.init_opts = init_opts;

    defer self.prev_size = self.init_opts.data_size;

    var parent_id = dvui.parentGet().data().id;
    const parent = dvui.parentGet().data().rect;

    parent_id = self.id;

    if (self.prev_size.h != self.init_opts.data_size.h or self.prev_size.w != self.init_opts.data_size.w) {
        const file_width: f32 = init_opts.data_size.w;
        const file_height: f32 = init_opts.data_size.h;
        const target_width = parent.w;
        const target_height = parent.h;
        var target_scale: f32 = 1.0;

        target_scale = @min(target_width / (file_width * 1.2), target_height / (file_height * 1.5));

        if (target_scale != self.prev_scale) {
            self.scale = target_scale;
            self.prev_scale = target_scale;
        }

        // Center the canvas within the viewport
        self.scroll_info.virtual_size.w = file_width * self.scale;
        self.scroll_info.virtual_size.h = file_height * self.scale;

        // Calculate the amount of blank space for centering
        const view_w = target_width;
        const view_h = target_height;
        const virt_w = self.scroll_info.virtual_size.w;
        const virt_h = self.scroll_info.virtual_size.h;

        // Center by default if content is smaller than viewport, else 0
        const offset_x = if (virt_w < view_w) (view_w - virt_w) * 0.5 else 0.0;
        const offset_y = if (virt_h < view_h) (view_h - virt_h) * 0.5 else 0.0;

        self.scroll_info.viewport.x = offset_x;
        self.scroll_info.viewport.y = offset_y;
        self.origin.x = -offset_x;
        self.origin.y = -offset_y;

        //self.scroll_info.scrollToFraction(.horizontal, 0.0);
        //self.scroll_info.scrollToFraction(.vertical, 0.0);
        dvui.refresh(null, @src(), parent_id);
    }

    self.scroll = dvui.scrollArea(src, .{ .scroll_info = &self.scroll_info }, opts);
    self.scroll_container = &self.scroll.scroll.?;

    self.scaler = dvui.scale(src, .{ .scale = &self.scale }, .{ .rect = .{ .x = -self.origin.x, .y = -self.origin.y } });

    // can use this to convert between viewport/virtual_size and screen coords
    self.scroll_rect_scale = self.scroll_container.screenRectScale(.{});
    // can use this to convert between data and screen coords
    self.screen_rect_scale = self.scaler.screenRectScale(.{});

    self.rect = self.screenFromDataRect(dvui.Rect.fromSize(.{ .w = init_opts.data_size.w, .h = init_opts.data_size.h }));
}

pub fn deinit(self: *CanvasWidget) void {
    self.scaler.deinit();
    self.scroll.deinit();
}

pub fn dataFromScreenPoint(self: *CanvasWidget, screen: dvui.Point.Physical) dvui.Point {
    return self.screen_rect_scale.pointFromPhysical(screen);
}

pub fn screenFromDataPoint(self: *CanvasWidget, data: dvui.Point) dvui.Point.Physical {
    return self.screen_rect_scale.pointToPhysical(data);
}

pub fn viewportFromScreenPoint(self: *CanvasWidget, screen: dvui.Point.Physical) dvui.Point {
    return self.scroll_rect_scale.pointFromPhysical(screen);
}

pub fn screenFromViewportPoint(self: *CanvasWidget, viewport: dvui.Point) dvui.Point.Physical {
    return self.scroll_rect_scale.pointToPhysical(viewport);
}

pub fn dataFromScreenRect(self: *CanvasWidget, screen: dvui.Rect.Physical) dvui.Rect {
    return self.screen_rect_scale.rectFromPhysical(screen);
}

pub fn screenFromDataRect(self: *CanvasWidget, data: dvui.Rect) dvui.Rect.Physical {
    return self.screen_rect_scale.rectToPhysical(data);
}

pub fn viewportFromScreenRect(self: *CanvasWidget, screen: dvui.Rect.Physical) dvui.Rect {
    return self.scroll_rect_scale.rectFromPhysical(screen);
}

pub fn screenFromViewportRect(self: *CanvasWidget, viewport: dvui.Rect) dvui.Rect.Physical {
    return self.scroll_rect_scale.rectToPhysical(viewport);
}

/// If the mouse position is currently contained within the canvas rect,
/// Returns the data/world point of the mouse, which corresponds to the pixel input of
/// Layer functions
// pub fn hovered(self: *CanvasWidget) ?dvui.Point {
//     for (dvui.events()) |*e| {
//         if (!self.scroll_container.matchEvent(e)) {
//             continue;
//         }

//         if (e.evt == .mouse and e.evt.mouse.action == .position) {
//             if (self.rect.contains(e.evt.mouse.p)) {
//                 return self.dataFromScreenPoint(e.evt.mouse.p);
//             }
//         }
//     }

//     return null;
// }

/// Returns the mouse event if one occured this frame
pub fn mouse(self: *CanvasWidget) ?dvui.Event.Mouse {
    for (dvui.events()) |*e| {
        if (!self.scroll_container.matchEvent(e))
            continue;

        switch (e.evt) {
            .mouse => |me| {
                return me;
            },
            else => {},
        }
    }

    return null;
}

pub fn processEvents(self: *CanvasWidget) void {
    //const file = self.file;

    var zoom: f32 = 1;
    var zoomP: dvui.Point.Physical = .{};

    // process scroll area events after boxes so the boxes get first pick (so
    // the button works)
    for (dvui.events()) |*e| {
        if (!self.scroll_container.matchEvent(e))
            continue;

        switch (e.evt) {
            .mouse => |me| {
                if (me.action == .position) {
                    if (self.rect.contains(me.p))
                        self.hovered = true;
                }

                if (me.action == .press and me.button == .middle) {
                    e.handle(@src(), self.scroll_container.data());
                    dvui.captureMouse(self.scroll_container.data(), e.num);
                    dvui.dragPreStart(me.p, .{ .name = "scroll_drag" });
                } else if (me.action == .release and me.button == .middle) {
                    if (dvui.captured(self.scroll_container.data().id)) {
                        e.handle(@src(), self.scroll_container.data());
                        dvui.captureMouse(null, e.num);
                        dvui.dragEnd();
                    }
                } else if (me.action == .motion) {
                    if (dvui.captured(self.scroll_container.data().id)) {
                        if (dvui.dragging(me.p, "scroll_drag")) |dps| {
                            const rs = self.scroll_rect_scale;
                            self.scroll_info.viewport.x -= dps.x / rs.s;
                            self.scroll_info.viewport.y -= dps.y / rs.s;
                            dvui.refresh(null, @src(), self.scroll_container.data().id);
                        }
                    }
                } else if (me.action == .wheel_y or me.action == .wheel_x) {
                    switch (pixi.editor.settings.input_scheme) {
                        .mouse => {
                            const base: f32 = if (me.mod.matchBind("shift")) 1.005 else 1.001;
                            if ((me.mod.matchBind("shift") and me.mod.matchBind("ctrl/cmd")) or !me.mod.matchBind("shift") and !me.mod.matchBind("ctrl/cmd")) {
                                e.handle(@src(), self.scroll_container.data());
                                if (me.action == .wheel_y) {
                                    const zs = @exp(@log(base) * me.action.wheel_y);
                                    if (zs != 1.0) {
                                        zoom *= zs;
                                        zoomP = me.p;
                                    }
                                }
                            }
                        },
                        .trackpad => {
                            if (me.mod.matchBind("zoom")) {
                                e.handle(@src(), self.scroll_container.data());
                                if (me.action == .wheel_y) {
                                    const base: f32 = if (me.mod.matchBind("shift")) 1.005 else 1.001;
                                    const zs = @exp(@log(base) * me.action.wheel_y);
                                    if (zs != 1.0) {
                                        zoom *= zs;
                                        zoomP = me.p;
                                    }
                                }
                            }
                        },
                    }
                }
            },
            else => {},
        }
    }

    // scale around mouse point
    // first get data point of mouse
    // data from screen
    const prevP = self.dataFromScreenPoint(zoomP);

    // scale
    var pp = prevP.scale(1 / self.scale, dvui.Point);
    self.scale *= zoom;
    pp = pp.scale(self.scale, dvui.Point);

    // get where the mouse would be now
    // data to screen
    const newP = self.screenFromDataPoint(pp);

    if (zoom != 1.0) {

        // convert both to viewport
        const diff = self.viewportFromScreenPoint(newP).diff(self.viewportFromScreenPoint(zoomP));
        self.scroll_info.viewport.x += diff.x;
        self.scroll_info.viewport.y += diff.y;

        dvui.refresh(null, @src(), self.scroll_container.data().id);
    }

    // // don't mess with scrolling if we aren't being shown (prevents weirdness
    // // when starting out)
    if (!self.scroll_info.viewport.empty()) {
        // add current viewport plus padding
        const pad = 10;
        var bbox = self.scroll_info.viewport.outsetAll(pad);
        if (self.bounding_box) |bb| {
            // convert bb from screen space to viewport space
            const scrollbbox = self.viewportFromScreenRect(bb);
            bbox = bbox.unionWith(scrollbbox);
        }

        // adjust top if needed
        if (bbox.y != 0) {
            const adj = -bbox.y;
            self.scroll_info.virtual_size.h += adj;
            self.scroll_info.viewport.y += adj;
            self.origin.y -= adj;
            dvui.refresh(null, @src(), self.scroll.data().id);
        }

        // adjust left if needed
        if (bbox.x != 0) {
            const adj = -bbox.x;
            self.scroll_info.virtual_size.w += adj;
            self.scroll_info.viewport.x += adj;
            self.origin.x -= adj;
            dvui.refresh(null, @src(), self.scroll.data().id);
        }

        // adjust bottom if needed
        if (bbox.h != self.scroll_info.virtual_size.h) {
            self.scroll_info.virtual_size.h = bbox.h;
            dvui.refresh(null, @src(), self.scroll.data().id);
        }

        // adjust right if needed
        if (bbox.w != self.scroll_info.virtual_size.w) {
            self.scroll_info.virtual_size.w = bbox.w;
            dvui.refresh(null, @src(), self.scroll.data().id);
        }
    }
}
