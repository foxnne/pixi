pub const FileWidget = @This();

file: *pixi.Internal.File,
init_options: InitOptions,
options: Options,
scroll: *dvui.ScrollAreaWidget = undefined,
scaler: *ScaleWidget = undefined,
mbbox: ?dvui.Rect.Physical = null,

pub const InitOptions = struct {
    dir: dvui.enums.Direction = .horizontal,
};

pub fn init(src: std.builtin.SourceLocation, file: *pixi.Internal.File, init_opts: InitOptions, opts: Options) FileWidget {
    var fw: FileWidget = .{
        .init_options = init_opts,
        .options = opts,
        .file = file,
    };
    fw.scroll = dvui.scrollArea(src, .{ .scroll_info = &file.canvas.scroll_info }, opts);

    fw.scaler = dvui.scale(src, .{ .scale = &file.canvas.scale }, .{ .rect = .{ .x = -file.canvas.origin.x, .y = -file.canvas.origin.y } });

    file.canvas.scroll_container = &fw.scroll.scroll.?;
    // can use this to convert between viewport/virtual_size and screen coords
    file.canvas.scroll_rect_scale = file.canvas.scroll_container.screenRectScale(.{});
    // can use this to convert between data and screen coords
    file.canvas.screen_rect_scale = fw.scaler.screenRectScale(.{});
    file.canvas.rect = file.canvas.screenFromDataRect(dvui.Rect.fromSize(.{ .w = @floatFromInt(file.width), .h = @floatFromInt(file.height) }));

    return fw;
}

pub fn processSampleTool(self: *FileWidget) void {
    const file = self.file;

    for (dvui.events()) |*e| {
        if (!file.canvas.scroll_container.matchEvent(e))
            continue;

        switch (e.evt) {
            .mouse => |me| {
                const current_point = file.canvas.dataFromScreenPoint(me.p);

                if (me.action == .press and me.button == .right) {
                    e.handle(@src(), file.canvas.scroll_container.data());
                    dvui.captureMouse(file.canvas.scroll_container.data(), e.num);
                    dvui.dragPreStart(me.p, .{ .name = "sample_drag" });
                    file.canvas.prev_drag_point = current_point;

                    @memset(file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                    file.temporary_layer.invalidateCache();

                    sample(file, current_point);
                } else if (me.action == .release and me.button == .right) {
                    if (dvui.captured(file.canvas.scroll_container.data().id)) {
                        e.handle(@src(), file.canvas.scroll_container.data());
                        dvui.captureMouse(null, e.num);
                        dvui.dragEnd();

                        file.canvas.prev_drag_point = null;
                    }
                } else if (me.action == .motion or me.action == .wheel_x or me.action == .wheel_y) {
                    if (dvui.captured(file.canvas.scroll_container.data().id)) {
                        if (dvui.draggingName("sample_drag")) {
                            if (file.canvas.prev_drag_point) |previous_point| {
                                // Construct a rect spanning between current_point and previous_point
                                const min_x = @min(previous_point.x, current_point.x);
                                const min_y = @min(previous_point.y, current_point.y);
                                const max_x = @max(previous_point.x, current_point.x);
                                const max_y = @max(previous_point.y, current_point.y);
                                const span_rect = dvui.Rect{
                                    .x = min_x,
                                    .y = min_y,
                                    .w = max_x - min_x + 1,
                                    .h = max_y - min_y + 1,
                                };

                                const screen_rect = file.canvas.screenFromDataRect(span_rect);

                                dvui.scrollDrag(.{
                                    .mouse_pt = me.p,
                                    .screen_rect = screen_rect,
                                    .capture_id = file.canvas.scroll_container.data().id,
                                });
                            }

                            sample(file, current_point);
                            e.handle(@src(), file.canvas.scroll_container.data());
                        }
                    }
                }
            },
            else => {},
        }
    }
}

fn sample(file: *pixi.Internal.File, point: dvui.Point) void {
    var color: [4]u8 = .{ 0, 0, 0, 0 };

    var layer_index: usize = file.layers.len;
    while (layer_index > 0) {
        layer_index -= 1;
        var layer = file.layers.get(layer_index);
        if (layer.getPixelIndex(point)) |index| {
            const c = layer.pixels()[index];
            if (c[3] > 0) {
                color = c;
            }
        }
    }

    pixi.editor.colors.secondary = pixi.editor.colors.primary;
    pixi.editor.colors.primary = color;

    if (color[3] == 0 and pixi.editor.tools.current != .eraser) {
        pixi.editor.tools.set(.eraser);
    } else {
        pixi.editor.tools.set(pixi.editor.tools.previous_drawing_tool);
    }
}

pub fn processStrokeTool(self: *FileWidget) void {
    if (switch (pixi.editor.tools.current) {
        .pointer,
        .pencil,
        .eraser,
        => false,
        else => true,
    }) return;

    const file = self.file;
    const color = switch (pixi.editor.tools.current) {
        .pointer, .pencil => pixi.editor.colors.primary,
        .eraser => [_]u8{ 0, 0, 0, 0 },
        //.heightmap => [_]u8{ pixi.editor.colors.height, 0, 0, 255 },
        else => unreachable,
    };

    var active_layer = file.layers.get(file.selected_layer_index);

    for (dvui.events()) |*e| {
        if (!file.canvas.scroll_container.matchEvent(e)) {
            if (file.temporary_layer.dirty) {
                @memset(file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                file.temporary_layer.invalidateCache();
            }
            continue;
        }

        switch (e.evt) {
            .mouse => |me| {
                const current_point = file.canvas.dataFromScreenPoint(me.p);

                if (me.action == .press and me.button.pointer()) {
                    e.handle(@src(), file.canvas.scroll_container.data());
                    dvui.captureMouse(file.canvas.scroll_container.data(), e.num);
                    dvui.dragPreStart(me.p, .{ .name = "stroke_drag" });

                    if (!me.mod.matchBind("shift")) {
                        if (active_layer.getPixelIndex(current_point)) |current_index| {
                            var pixels = active_layer.pixels();
                            const current_value: [4]u8 = pixels[current_index];
                            if (!std.mem.containsAtLeast(usize, file.buffers.stroke.indices.items, 1, &.{current_index}))
                                file.buffers.stroke.append(current_index, current_value) catch {
                                    std.log.err("Failed to append to stroke buffer", .{});
                                };

                            pixels[current_index] = color;
                        }
                    }

                    file.canvas.prev_drag_point = current_point;
                    active_layer.invalidateCache();
                } else if (me.action == .release and me.button.pointer()) {
                    if (dvui.captured(file.canvas.scroll_container.data().id)) {
                        e.handle(@src(), file.canvas.scroll_container.data());
                        dvui.captureMouse(null, e.num);
                        dvui.dragEnd();

                        if (me.mod.matchBind("shift")) {
                            if (file.canvas.prev_drag_point) |previous_point| {
                                if (pixi.algorithms.brezenham.process(previous_point, current_point) catch null) |points| {
                                    @memset(file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                                    for (points) |pixel| {
                                        if (active_layer.getPixelIndex(pixel)) |current_index| {
                                            var pixels = active_layer.pixels();
                                            const current_value: [4]u8 = pixels[current_index];
                                            if (!std.mem.containsAtLeast(usize, file.buffers.stroke.indices.items, 1, &.{current_index}))
                                                file.buffers.stroke.append(current_index, current_value) catch {
                                                    std.log.err("Failed to append to stroke buffer", .{});
                                                };

                                            pixels[current_index] = color;
                                        }
                                    }
                                    active_layer.invalidateCache();
                                }
                            }
                        }
                        file.canvas.prev_drag_point = null;

                        const change_opt = file.buffers.stroke.toChange(active_layer.id) catch null;
                        if (change_opt) |change| {
                            file.history.append(change) catch {
                                std.log.err("Failed to append to history", .{});
                            };
                        }
                    }
                } else if (me.action == .motion or me.action == .wheel_x or me.action == .wheel_y) {
                    if (dvui.captured(file.canvas.scroll_container.data().id)) {
                        if (dvui.dragging(me.p)) |_| {
                            if (dvui.draggingName("stroke_drag")) {
                                if (file.canvas.prev_drag_point) |previous_point| {
                                    // Construct a rect spanning between current_point and previous_point
                                    const min_x = @min(previous_point.x, current_point.x);
                                    const min_y = @min(previous_point.y, current_point.y);
                                    const max_x = @max(previous_point.x, current_point.x);
                                    const max_y = @max(previous_point.y, current_point.y);
                                    const span_rect = dvui.Rect{
                                        .x = min_x,
                                        .y = min_y,
                                        .w = max_x - min_x + 1,
                                        .h = max_y - min_y + 1,
                                    };

                                    const screen_rect = file.canvas.screenFromDataRect(span_rect);

                                    dvui.scrollDrag(.{
                                        .mouse_pt = me.p,
                                        .screen_rect = screen_rect,
                                        .capture_id = file.canvas.scroll_container.data().id,
                                    });
                                }

                                if (me.mod.matchBind("shift")) {
                                    if (file.canvas.prev_drag_point) |previous_point| {
                                        if (pixi.algorithms.brezenham.process(previous_point, current_point) catch null) |points| {
                                            @memset(file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                                            for (points) |pixel| {
                                                file.temporary_layer.setPixel(pixel, color);
                                                file.temporary_layer.dirty = true;
                                            }
                                            file.temporary_layer.invalidateCache();
                                        }
                                    }
                                } else {
                                    if (file.canvas.prev_drag_point) |previous_point| {
                                        if (pixi.algorithms.brezenham.process(previous_point, current_point) catch null) |points| {
                                            for (points) |pixel| {
                                                if (active_layer.getPixelIndex(pixel)) |current_index| {
                                                    var pixels = active_layer.pixels();
                                                    const current_value: [4]u8 = pixels[current_index];
                                                    if (!std.mem.containsAtLeast(usize, file.buffers.stroke.indices.items, 1, &.{current_index}))
                                                        file.buffers.stroke.append(current_index, current_value) catch {
                                                            std.log.err("Failed to append to stroke buffer", .{});
                                                        };

                                                    pixels[current_index] = color;
                                                }
                                            }
                                        }
                                    }
                                    active_layer.invalidateCache();
                                    file.canvas.prev_drag_point = current_point;
                                }

                                e.handle(@src(), file.canvas.scroll_container.data());
                            }
                        }
                    } else {
                        if (file.canvas.rect.contains(me.p)) {
                            @memset(file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                            file.temporary_layer.setPixel(current_point, color);
                            file.temporary_layer.invalidateCache();
                            file.temporary_layer.dirty = true;
                        } else {
                            @memset(file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                            file.temporary_layer.dirty = true;
                            file.temporary_layer.invalidateCache();
                        }
                    }
                }

                // if (me.action == .motion or me.action == .wheel_x or me.action == .wheel_y) {
                //     if (file.canvas.rect.contains(me.p)) {
                //         file.temporary_layer.setPixel(current_point, color);
                //         file.temporary_layer.invalidateCache();
                //     }
                // }
            },
            else => {},
        }
    }
}

pub fn drawLayers(fw: *FileWidget) void {
    var file = fw.file;
    var layer_index: usize = file.layers.len;
    while (layer_index > 0) {
        layer_index -= 1;
        const image = dvui.image(@src(), .{ .source = file.layers.items(.source)[layer_index] }, .{
            .rect = .{ .x = 0, .y = 0, .w = @floatFromInt(file.width), .h = @floatFromInt(file.height) },
            .border = dvui.Rect.all(0),
            .id_extra = file.layers.items(.id)[layer_index],
            .background = false,
        });

        const boxRect = image.rectScale().r;
        if (fw.mbbox) |b| {
            fw.mbbox = b.unionWith(boxRect);
        } else {
            fw.mbbox = boxRect;
        }
    }

    _ = dvui.image(@src(), .{
        .source = file.temporary_layer.source,
    }, .{
        .rect = .{ .x = 0, .y = 0, .w = @floatFromInt(file.width), .h = @floatFromInt(file.height) },
        .border = dvui.Rect.all(0),
        .id_extra = file.layers.len + 1,
        .background = false,
    });

    const tiles_wide: usize = @intCast(@divExact(file.width, file.tile_width));
    const tiles_high: usize = @intCast(@divExact(file.height, file.tile_height));

    // Outline the image with a rectangle
    dvui.Path.stroke(.{ .points = &.{
        file.canvas.rect.topLeft(),
        file.canvas.rect.topRight(),
        file.canvas.rect.bottomRight(),
        file.canvas.rect.bottomLeft(),
    } }, .{ .thickness = 1, .color = dvui.Color.fromTheme(.fill_hover), .closed = true });

    for (0..tiles_wide) |x| {
        dvui.Path.stroke(.{ .points = &.{
            file.canvas.screenFromDataPoint(.{ .x = @as(f32, @floatFromInt(x * file.tile_width)), .y = 0 }),
            file.canvas.screenFromDataPoint(.{ .x = @as(f32, @floatFromInt(x * file.tile_width)), .y = @as(f32, @floatFromInt(file.height)) }),
        } }, .{ .thickness = 1, .color = dvui.Color.fromTheme(.fill_hover) });
    }

    for (0..tiles_high) |y| {
        dvui.Path.stroke(.{ .points = &.{
            file.canvas.screenFromDataPoint(.{ .x = 0, .y = @as(f32, @floatFromInt(y * file.tile_height)) }),
            file.canvas.screenFromDataPoint(.{ .x = @as(f32, @floatFromInt(file.width)), .y = @as(f32, @floatFromInt(y * file.tile_height)) }),
        } }, .{ .thickness = 1, .color = dvui.Color.fromTheme(.fill_hover) });
    }
}

pub fn scrollAndZoom(self: *FileWidget) void {
    const file = self.file;

    var zoom: f32 = 1;
    var zoomP: dvui.Point.Physical = .{};

    // process scroll area events after boxes so the boxes get first pick (so
    // the button works)
    for (dvui.events()) |*e| {
        if (!file.canvas.scroll_container.matchEvent(e))
            continue;

        switch (e.evt) {
            .mouse => |me| {
                if (me.action == .press and me.button == .middle) {
                    e.handle(@src(), file.canvas.scroll_container.data());
                    dvui.captureMouse(file.canvas.scroll_container.data(), e.num);
                    dvui.dragPreStart(me.p, .{ .name = "scroll_drag" });
                } else if (me.action == .release and me.button == .middle) {
                    if (dvui.captured(file.canvas.scroll_container.data().id)) {
                        e.handle(@src(), file.canvas.scroll_container.data());
                        dvui.captureMouse(null, e.num);
                        dvui.dragEnd();
                    }
                } else if (me.action == .motion) {
                    if (dvui.captured(file.canvas.scroll_container.data().id)) {
                        if (dvui.dragging(me.p)) |dps| {
                            if (dvui.draggingName("scroll_drag")) {
                                const rs = file.canvas.scroll_rect_scale;
                                file.canvas.scroll_info.viewport.x -= dps.x / rs.s;
                                file.canvas.scroll_info.viewport.y -= dps.y / rs.s;
                                dvui.refresh(null, @src(), file.canvas.scroll_container.data().id);
                            }
                        }
                    }
                } else if ((me.action == .wheel_y or me.action == .wheel_x) and me.mod.matchBind("ctrl/cmd")) {
                    e.handle(@src(), file.canvas.scroll_container.data());
                    if (me.action == .wheel_y) {
                        const base: f32 = 1.001;
                        const zs = @exp(@log(base) * me.action.wheel_y);
                        if (zs != 1.0) {
                            zoom *= zs;
                            zoomP = me.p;
                        }
                    }
                }
            },
            else => {},
        }
    }

    // scale around mouse point
    // first get data point of mouse
    // data from screen
    const prevP = file.canvas.dataFromScreenPoint(zoomP);

    // scale
    var pp = prevP.scale(1 / file.canvas.scale, dvui.Point);
    file.canvas.scale *= zoom;
    pp = pp.scale(file.canvas.scale, dvui.Point);

    // get where the mouse would be now
    // data to screen
    const newP = file.canvas.screenFromDataPoint(pp);

    if (zoom != 1.0) {

        // convert both to viewport
        const diff = file.canvas.viewportFromScreenPoint(newP).diff(file.canvas.viewportFromScreenPoint(zoomP));
        file.canvas.scroll_info.viewport.x += diff.x;
        file.canvas.scroll_info.viewport.y += diff.y;

        dvui.refresh(null, @src(), file.canvas.scroll_container.data().id);
    }

    // // don't mess with scrolling if we aren't being shown (prevents weirdness
    // // when starting out)
    if (!file.canvas.scroll_info.viewport.empty()) {
        // add current viewport plus padding
        const pad = 10;
        var bbox = file.canvas.scroll_info.viewport.outsetAll(pad);
        if (self.mbbox) |bb| {
            // convert bb from screen space to viewport space
            const scrollbbox = file.canvas.viewportFromScreenRect(bb);
            bbox = bbox.unionWith(scrollbbox);
        }

        // adjust top if needed
        if (bbox.y != 0) {
            const adj = -bbox.y;
            file.canvas.scroll_info.virtual_size.h += adj;
            file.canvas.scroll_info.viewport.y += adj;
            file.canvas.origin.y -= adj;
            dvui.refresh(null, @src(), self.scroll.data().id);
        }

        // adjust left if needed
        if (bbox.x != 0) {
            const adj = -bbox.x;
            file.canvas.scroll_info.virtual_size.w += adj;
            file.canvas.scroll_info.viewport.x += adj;
            file.canvas.origin.x -= adj;
            dvui.refresh(null, @src(), self.scroll.data().id);
        }

        // adjust bottom if needed
        if (bbox.h != file.canvas.scroll_info.virtual_size.h) {
            file.canvas.scroll_info.virtual_size.h = bbox.h;
            dvui.refresh(null, @src(), self.scroll.data().id);
        }

        // adjust right if needed
        if (bbox.w != file.canvas.scroll_info.virtual_size.w) {
            file.canvas.scroll_info.virtual_size.w = bbox.w;
            dvui.refresh(null, @src(), self.scroll.data().id);
        }
    }
}

pub fn deinit(self: *FileWidget) void {
    defer dvui.widgetFree(self);

    self.scaler.deinit();
    //const scroll_container_id = self.scroll.data().id;
    self.scroll.deinit();

    self.* = undefined;
}

pub fn hovered(self: *FileWidget) ?dvui.Point {
    return self.file.canvas.hovered();
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

test {
    @import("std").testing.refAllDecls(@This());
}
