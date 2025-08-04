pub const ImageWidget = @This();
const CanvasWidget = @import("CanvasWidget.zig");

init_options: InitOptions,
options: Options,
last_mouse_event: ?dvui.Event = null,
drag_data_point: ?dvui.Point = null,
sample_data_point: ?dvui.Point = null,

pub const InitOptions = struct {
    canvas: *CanvasWidget,
    source: dvui.ImageSource,
};

pub fn init(src: std.builtin.SourceLocation, init_opts: InitOptions, opts: Options) ImageWidget {
    const iw: ImageWidget = .{
        .init_options = init_opts,
        .options = opts,
        .last_mouse_event = if (dvui.dataGet(null, init_opts.canvas.id, "mouse_point", dvui.Event)) |event| event else null,
        .drag_data_point = if (dvui.dataGet(null, init_opts.canvas.id, "drag_data_point", dvui.Point)) |point| point else null,
        .sample_data_point = if (dvui.dataGet(null, init_opts.canvas.id, "sample_data_point", dvui.Point)) |point| point else null,
    };

    const size: dvui.Size = dvui.imageSize(init_opts.source) catch .{ .w = 0, .h = 0 };

    init_opts.canvas.install(src, .{
        .id = init_opts.canvas.id,
        .data_size = .{
            .w = size.w,
            .h = size.h,
        },
    }, opts);

    return iw;
}

pub fn processSampleTool(self: *ImageWidget) void {
    for (dvui.events()) |*e| {
        if (!self.init_options.canvas.scroll_container.matchEvent(e))
            continue;

        switch (e.evt) {
            .mouse => |me| {
                self.last_mouse_event = e.*;
                const current_point = self.init_options.canvas.dataFromScreenPoint(me.p);

                if (me.action == .press and me.button == .right) {
                    e.handle(@src(), self.init_options.canvas.scroll_container.data());
                    dvui.captureMouse(self.init_options.canvas.scroll_container.data(), e.num);
                    dvui.dragPreStart(me.p, .{ .name = "sample_drag" });
                    self.drag_data_point = current_point;

                    self.sample(current_point);
                } else if (me.action == .release and me.button == .right) {
                    if (dvui.captured(self.init_options.canvas.scroll_container.data().id)) {
                        e.handle(@src(), self.init_options.canvas.scroll_container.data());
                        dvui.captureMouse(null, e.num);
                        dvui.dragEnd();

                        self.drag_data_point = null;
                        self.sample_data_point = null;
                    }
                } else if (me.action == .motion or me.action == .wheel_x or me.action == .wheel_y) {
                    if (dvui.captured(self.init_options.canvas.scroll_container.data().id)) {
                        if (dvui.dragging(me.p, "sample_drag")) |diff| {
                            const previous_point = current_point.plus(self.init_options.canvas.dataFromScreenPoint(diff));
                            // Construct a rect spanning between current_point and previous_point
                            const min_x = @min(previous_point.x, current_point.x);
                            const min_y = @min(previous_point.y, current_point.y);
                            const max_x = @max(previous_point.x, current_point.x);
                            const max_y = @max(previous_point.y, current_point.y);
                            const span_rect = dvui.Rect{
                                .x = min_x,
                                .y = min_y,
                                .w = max_x - min_x + 5,
                                .h = max_y - min_y + 5,
                            };

                            const screen_rect = self.init_options.canvas.screenFromDataRect(span_rect);

                            dvui.scrollDrag(.{
                                .mouse_pt = me.p,
                                .screen_rect = screen_rect,
                                .capture_id = self.init_options.canvas.scroll_container.data().id,
                            });

                            self.sample(current_point);
                            e.handle(@src(), self.init_options.canvas.scroll_container.data());
                        }
                    }
                }
            },
            else => {},
        }
    }
}

fn sample(self: *ImageWidget, point: dvui.Point) void {
    var color: [4]u8 = .{ 0, 0, 0, 0 };

    if (pixi.image.getPixelIndex(self.init_options.source, point)) |index| {
        const c = pixi.image.pixels(self.init_options.source)[index];
        if (c[3] > 0) {
            color = c;
        }
    }

    pixi.editor.colors.primary = color;

    self.sample_data_point = point;

    if (color[3] == 0) {
        if (pixi.editor.tools.current != .eraser) {
            pixi.editor.tools.set(.eraser);
        }
    } else {
        pixi.editor.tools.set(pixi.editor.tools.previous_drawing_tool);
    }
}

pub fn drawCursor(self: *ImageWidget) void {
    for (dvui.events()) |*e| {
        if (!self.init_options.canvas.scroll_container.matchEvent(e)) {
            if (e.evt == .mouse) {
                _ = dvui.cursorShow(true);
            }
            continue;
        }
        switch (e.evt) {
            .mouse => |me| {
                if (me.action == .press and me.button == .right) {
                    _ = dvui.cursorShow(false);
                } else if (me.action == .release and me.button == .right) {
                    _ = dvui.cursorShow(true);
                }
            },
            else => {},
        }
    }
}

pub fn drawSample(self: *ImageWidget) void {
    const point = self.sample_data_point;

    if (point) |data_point| {
        const mouse_point = self.init_options.canvas.screenFromDataPoint(data_point);
        if (!self.init_options.canvas.rect.contains(mouse_point)) return;

        { // Draw a box around the hovered pixel at the correct scale
            const pixel_box_size = self.init_options.canvas.scale * dvui.currentWindow().rectScale().s;

            const pixel_point: dvui.Point = .{
                .x = @round(data_point.x - 0.5),
                .y = @round(data_point.y - 0.5),
            };

            const pixel_box_point = self.init_options.canvas.screenFromDataPoint(pixel_point);
            var pixel_box = dvui.Rect.Physical.fromSize(.{ .w = pixel_box_size, .h = pixel_box_size });
            pixel_box.x = pixel_box_point.x;
            pixel_box.y = pixel_box_point.y;
            dvui.Path.stroke(.{ .points = &.{
                pixel_box.topLeft(),
                pixel_box.topRight(),
                pixel_box.bottomRight(),
                pixel_box.bottomLeft(),
            } }, .{ .thickness = 2, .color = .white, .closed = true });
        }

        // The scale of the enlarged view is always twice the scale of self.init_options.canvas
        const enlarged_scale: f32 = self.init_options.canvas.scale * 2.0;

        // The size of the sample box in screen space (constant size)
        const sample_box_size: f32 = 100.0 * 1 / self.init_options.canvas.scale; // e.g. 100x80 pixels on screen

        const corner_radius = dvui.Rect{
            .y = sample_box_size / 2,
            .w = sample_box_size / 2,
            .h = sample_box_size / 2,
        };

        // The size of the sample region in data (texture) space
        // This is how many data pixels are shown in the box, so that the box always shows the same number of data pixels at 2x the canvas scale
        const sample_region_size: f32 = sample_box_size / enlarged_scale;

        const border_width = 2 / self.init_options.canvas.scale;

        // Position the sample box so that the data_point is at its center
        const box = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .none,
            .rect = .{
                .x = data_point.x,
                .y = data_point.y,
                .w = sample_box_size,
                .h = sample_box_size,
            },
            .border = dvui.Rect.all(border_width),
            .color_border = .fill_hover,
            .corner_radius = corner_radius,
            .background = true,
            .color_fill = .fill_window,
            .box_shadow = .{
                .fade = 15 * 1 / self.init_options.canvas.scale,
                .corner_radius = .{
                    .x = sample_box_size / 12,
                    .y = sample_box_size / 2,
                    .w = sample_box_size / 2,
                    .h = sample_box_size / 2,
                },
                .alpha = 0.2,
                .offset = .{
                    .x = 2 * 1 / self.init_options.canvas.scale,
                    .y = 2 * 1 / self.init_options.canvas.scale,
                },
            },
        });
        defer box.deinit();

        const size = pixi.image.size(self.init_options.source);

        // Compute UVs for the region to sample, normalized to [0,1]
        const uv_rect = dvui.Rect{
            .x = (data_point.x - sample_region_size / 2) / size.w,
            .y = (data_point.y - sample_region_size / 2) / size.h,
            .w = sample_region_size / size.w,
            .h = sample_region_size / size.h,
        };

        var rs = box.data().borderRectScale();
        rs.r = rs.r.inset(dvui.Rect.Physical.all(border_width * self.init_options.canvas.scale * 2));

        dvui.renderImage(self.init_options.source, rs, .{
            .uv = uv_rect,
            .corner_radius = .{
                .x = corner_radius.x * rs.s,
                .y = corner_radius.y * rs.s,
                .w = corner_radius.w * rs.s,
                .h = corner_radius.h * rs.s,
            },
        }) catch {
            std.log.err("Failed to render image", .{});
        };

        // Draw a cross at the center of the rounded sample box
        const center_x = rs.r.x + rs.r.w / 2;
        const center_y = rs.r.y + rs.r.h / 2;
        const cross_size = @min(rs.r.w, rs.r.h) * 0.2;

        dvui.Path.stroke(.{ .points = &.{
            .{ .x = center_x - cross_size / 2, .y = center_y },
            .{ .x = center_x + cross_size / 2, .y = center_y },
        } }, .{ .thickness = 4, .color = .white });

        dvui.Path.stroke(.{ .points = &.{
            .{ .x = center_x, .y = center_y - cross_size / 2 },
            .{ .x = center_x, .y = center_y + cross_size / 2 },
        } }, .{ .thickness = 4, .color = .white });

        dvui.Path.stroke(.{ .points = &.{
            .{ .x = center_x - cross_size / 2 + 4, .y = center_y },
            .{ .x = center_x + cross_size / 2 - 4, .y = center_y },
        } }, .{ .thickness = 2, .color = .black });

        dvui.Path.stroke(.{ .points = &.{
            .{ .x = center_x, .y = center_y - cross_size / 2 + 4 },
            .{ .x = center_x, .y = center_y + cross_size / 2 - 4 },
        } }, .{ .thickness = 2, .color = .black });
    }
}

pub fn drawImage(self: *ImageWidget) void {
    const size: dvui.Size = dvui.imageSize(self.init_options.source) catch .{ .w = 0, .h = 0 };

    const shadow_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .none,
        .rect = .{ .x = 0, .y = 0, .w = size.w, .h = size.h },
        .border = dvui.Rect.all(0),
        .background = true,
        .box_shadow = .{
            .fade = 20 * 1 / self.init_options.canvas.scale,
            .corner_radius = dvui.Rect.all(2 * 1 / self.init_options.canvas.scale),
            .alpha = 0.2,
            .offset = .{
                .x = 2 * 1 / self.init_options.canvas.scale,
                .y = 2 * 1 / self.init_options.canvas.scale,
            },
        },
    });
    shadow_box.deinit();

    const image = dvui.image(@src(), .{ .source = self.init_options.source }, .{
        .rect = .{ .x = 0, .y = 0, .w = size.w, .h = size.h },
        .border = dvui.Rect.all(0),
        .background = false,
    });

    self.init_options.canvas.bounding_box = image.rectScale().r;

    // Outline the image with a rectangle
    dvui.Path.stroke(.{ .points = &.{
        self.init_options.canvas.rect.topLeft(),
        self.init_options.canvas.rect.topRight(),
        self.init_options.canvas.rect.bottomRight(),
        self.init_options.canvas.rect.bottomLeft(),
    } }, .{ .thickness = 1, .color = dvui.Color.fromTheme(.fill_hover), .closed = true });
}

pub fn processEvents(self: *ImageWidget) void {
    defer if (self.last_mouse_event) |last_mouse_event| {
        dvui.dataSet(null, self.init_options.canvas.id, "mouse_point", last_mouse_event);
    } else {
        dvui.dataRemove(null, self.init_options.canvas.id, "mouse_point");
    };
    defer if (self.drag_data_point) |drag_data_point| {
        dvui.dataSet(null, self.init_options.canvas.id, "drag_data_point", drag_data_point);
    } else {
        dvui.dataRemove(null, self.init_options.canvas.id, "drag_data_point");
    };
    defer if (self.sample_data_point) |sample_data_point| {
        dvui.dataSet(null, self.init_options.canvas.id, "sample_data_point", sample_data_point);
    } else {
        dvui.dataRemove(null, self.init_options.canvas.id, "sample_data_point");
    };

    self.processSampleTool();

    self.drawImage();
    self.drawCursor();
    self.drawSample();

    // Then process the scroll and zoom events last
    self.init_options.canvas.processEvents();
}

pub fn deinit(self: *ImageWidget) void {
    defer dvui.widgetFree(self);

    self.init_options.canvas.deinit();

    self.* = undefined;
}

pub fn hovered(self: *ImageWidget) ?dvui.Point {
    return self.init_options.canvas.hovered();
}

const Options = dvui.Options;
const Rect = dvui.Rect;
const Point = dvui.Point;

const BoxWidget = dvui.BoxWidget;
const ButtonWidget = dvui.ButtonWidget;
const ScrollAreaWidget = dvui.ScrollAreaWidget;
const ScrollContainerWidget = dvui.ScrollContainerWidget;
const ScaleWidget = dvui.ScaleWidget;

const std = @import("std");
const math = std.math;
const dvui = @import("dvui");
const pixi = @import("../../pixi.zig");
const builtin = @import("builtin");

test {
    @import("std").testing.refAllDecls(@This());
}
