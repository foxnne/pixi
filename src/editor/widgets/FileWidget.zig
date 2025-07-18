pub const FileWidget = @This();

file: *pixi.Internal.File,
init_options: InitOptions,
options: Options,
scroll: *dvui.ScrollAreaWidget = undefined,
scaler: *ScaleWidget = undefined,
mbbox: ?dvui.Rect.Physical = null,
last_mouse_event: ?dvui.Event = null,

pub const InitOptions = struct {};

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

    fw.last_mouse_event = dvui.dataGet(null, file.canvas.scroll_container.data().id, "mouse_point", dvui.Event);

    return fw;
}

pub fn processSampleTool(self: *FileWidget) void {
    const file = self.file;

    for (dvui.events()) |*e| {
        if (!file.canvas.scroll_container.matchEvent(e))
            continue;

        switch (e.evt) {
            .mouse => |me| {
                self.last_mouse_event = e.*;
                const current_point = file.canvas.dataFromScreenPoint(me.p);

                if (me.action == .press and me.button == .right) {
                    e.handle(@src(), file.canvas.scroll_container.data());
                    dvui.captureMouse(file.canvas.scroll_container.data(), e.num);
                    dvui.dragPreStart(me.p, .{ .name = "sample_drag" });
                    file.canvas.prev_drag_point = current_point;

                    sample(file, current_point);
                } else if (me.action == .release and me.button == .right) {
                    if (dvui.captured(file.canvas.scroll_container.data().id)) {
                        e.handle(@src(), file.canvas.scroll_container.data());
                        dvui.captureMouse(null, e.num);
                        dvui.dragEnd();

                        file.canvas.prev_drag_point = null;
                        file.canvas.sample_data_point = null;
                    }
                } else if (me.action == .motion or me.action == .wheel_x or me.action == .wheel_y) {
                    if (dvui.captured(file.canvas.scroll_container.data().id)) {
                        if (dvui.dragging(me.p, "sample_drag")) |_| {
                            if (file.canvas.prev_drag_point) |previous_point| {
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

    file.canvas.sample_data_point = point;

    if (color[3] == 0) {
        if (pixi.editor.tools.current != .eraser) {
            pixi.editor.tools.set(.eraser);
        }
    } else {
        pixi.editor.tools.set(pixi.editor.tools.previous_drawing_tool);
    }
}

pub fn processStrokeTool(self: *FileWidget) void {
    defer if (self.last_mouse_event) |last_mouse_event| {
        dvui.dataSet(null, self.file.canvas.scroll_container.data().id, "mouse_point", last_mouse_event);
    };

    if (switch (pixi.editor.tools.current) {
        .pencil,
        .eraser,
        => false,
        else => true,
    }) return;

    const file = self.file;
    const color: [4]u8 = switch (pixi.editor.tools.current) {
        .pencil => pixi.editor.colors.primary,
        .eraser => [_]u8{ 0, 0, 0, 0 },
        //.heightmap => [_]u8{ pixi.editor.colors.height, 0, 0, 255 },
        else => unreachable,
    };

    // var active_layer = file.layers.get(file.selected_layer_index);

    for (dvui.events()) |*e| {
        if (!file.canvas.scroll_container.matchEvent(e)) {
            if (e.evt == .mouse) {
                if (file.temporary_layer.dirty) {
                    @memset(file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                    file.temporary_layer.invalidate();
                    file.temporary_layer.dirty = false;
                }
                self.last_mouse_event = null;
            }
            continue;
        }

        switch (e.evt) {
            .key => |ke| {
                if (ke.matchBind("increase_stroke_size") and ke.action == .down) {
                    if (pixi.editor.tools.stroke_size < std.math.maxInt(u8))
                        pixi.editor.tools.stroke_size += 1;
                }

                if (ke.matchBind("decrease_stroke_size") and ke.action == .down) {
                    if (pixi.editor.tools.stroke_size > 1)
                        pixi.editor.tools.stroke_size -= 1;
                }

                if (self.last_mouse_event) |last_mouse_event| {
                    switch (last_mouse_event.evt) {
                        .mouse => |me| {
                            @memset(file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                            const current_point = file.canvas.dataFromScreenPoint(me.p);
                            file.drawPoint(current_point, color, .temporary, true, false);
                        },
                        else => {},
                    }
                }
            },
            .mouse => |me| {
                const current_point = file.canvas.dataFromScreenPoint(me.p);
                self.last_mouse_event = e.*;

                if (file.canvas.rect.contains(me.p)) {
                    dvui.focusWidget(file.canvas.scroll_container.data().id, null, e.num);
                }

                // if (file.canvas.prev_drag_point == null) {
                //     if (file.canvas.rect.contains(me.p) and file.canvas.prev_drag_point == null) {
                //         @memset(file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                //         if (file.canvas.sample_data_point == null or color[3] == 0) {
                //             const temp_color = if (pixi.editor.tools.current != .eraser) color else [_]u8{ 255, 255, 255, 255 };
                //             file.temporary_layer.setPixel(current_point, temp_color);
                //         }
                //         file.temporary_layer.invalidate();
                //         file.temporary_layer.dirty = true;
                //     } else {
                //         @memset(file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                //         file.temporary_layer.invalidate();
                //         file.temporary_layer.dirty = true;
                //     }
                // }

                if (me.action == .press and me.button.pointer()) {
                    e.handle(@src(), file.canvas.scroll_container.data());
                    dvui.captureMouse(file.canvas.scroll_container.data(), e.num);
                    dvui.dragPreStart(me.p, .{ .name = "stroke_drag" });

                    if (!me.mod.matchBind("shift")) {
                        file.drawPoint(current_point, color, .selected, true, false);
                        // if (active_layer.getPixelIndex(current_point)) |current_index| {
                        //     var pixels = active_layer.pixels();

                        //     const current_value: [4]u8 = pixels[current_index];
                        //     if (!std.mem.containsAtLeast(usize, file.buffers.stroke.indices.items, 1, &.{current_index}))
                        //         file.buffers.stroke.append(current_index, current_value) catch {
                        //             std.log.err("Failed to append to stroke buffer", .{});
                        //         };

                        //     pixels[current_index] = color;
                        // }
                    }

                    file.canvas.prev_drag_point = current_point;
                    //active_layer.invalidate();
                } else if (me.action == .release and me.button.pointer()) {
                    if (dvui.captured(file.canvas.scroll_container.data().id)) {
                        e.handle(@src(), file.canvas.scroll_container.data());
                        dvui.captureMouse(null, e.num);
                        dvui.dragEnd();

                        if (me.mod.matchBind("shift")) {
                            if (file.canvas.prev_drag_point) |previous_point| {
                                file.drawLine(previous_point, current_point, color, .selected, true, true);
                            }
                        }

                        if (file.buffers.stroke.pixels.count() > 0) {
                            if (file.buffers.stroke.toChange(file.selected_layer_index) catch null) |change| {
                                file.history.append(change) catch {
                                    std.log.err("Failed to append to history", .{});
                                };
                            }
                        }

                        file.canvas.prev_drag_point = null;
                    }
                } else if (me.action == .motion or me.action == .wheel_x or me.action == .wheel_y) {
                    if (dvui.captured(file.canvas.scroll_container.data().id)) {
                        if (dvui.dragging(me.p, "stroke_drag")) |_| {
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
                                    @memset(file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                                    file.drawLine(previous_point, current_point, color, .temporary, true, false);
                                }
                            } else {
                                if (file.canvas.prev_drag_point) |previous_point| {
                                    file.drawLine(previous_point, current_point, color, .selected, true, false);
                                }
                                //active_layer.invalidate();
                                file.canvas.prev_drag_point = current_point;
                            }

                            e.handle(@src(), file.canvas.scroll_container.data());
                        }
                    }
                    {
                        if (!me.mod.matchBind("shift")) {
                            if (file.canvas.rect.contains(me.p) and file.canvas.sample_data_point == null) {
                                if (file.canvas.sample_data_point == null or color[3] == 0) {
                                    @memset(file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                                    const temp_color = if (pixi.editor.tools.current != .eraser) color else [_]u8{ 255, 255, 255, 255 };
                                    file.drawPoint(current_point, temp_color, .temporary, true, false);
                                }
                            } else {
                                @memset(file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                                file.temporary_layer.dirty = true;
                                file.temporary_layer.invalidate();
                            }
                        }
                    }
                }
            },
            else => {},
        }
    }
}

pub fn drawCursor(fw: *FileWidget) void {
    const file = fw.file;

    if (pixi.editor.tools.current == .pointer) return;

    var cursor_data_point: ?dvui.Point = null;

    for (dvui.events()) |*e| {
        if (!file.canvas.scroll_container.matchEvent(e)) {
            if (e.evt == .mouse) {
                _ = dvui.cursorShow(true);
            }
            continue;
        }
        switch (e.evt) {
            .mouse => |me| {
                cursor_data_point = file.canvas.dataFromScreenPoint(me.p);
                if (file.canvas.rect.contains(me.p)) {
                    _ = dvui.cursorShow(false);
                } else {
                    _ = dvui.cursorShow(true);
                }
            },
            else => {},
        }
    }

    if (cursor_data_point) |data_point| {
        const mouse_point = file.canvas.screenFromDataPoint(data_point);
        if (!file.canvas.rect.contains(mouse_point)) return;
        if (file.canvas.sample_data_point != null) return;

        if (switch (pixi.editor.tools.current) {
            .pencil => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.pencil_default],
            .eraser => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.eraser_default],
            else => null,
        }) |sprite| {
            const atlas_size = dvui.imageSize(pixi.editor.atlas.source) catch {
                std.log.err("Failed to get atlas size", .{});
                return;
            };

            const uv = dvui.Rect{
                .x = (@as(f32, @floatFromInt(sprite.source[0])) / atlas_size.w),
                .y = (@as(f32, @floatFromInt(sprite.source[1])) / atlas_size.h),
                .w = (@as(f32, @floatFromInt(sprite.source[2])) / atlas_size.w),
                .h = (@as(f32, @floatFromInt(sprite.source[3])) / atlas_size.h),
            };

            const origin = dvui.Point{
                .x = @as(f32, @floatFromInt(sprite.origin[0])) * 1 / file.canvas.scale,
                .y = @as(f32, @floatFromInt(sprite.origin[1])) * 1 / file.canvas.scale,
            };

            const position = data_point.diff(origin);

            const box = dvui.box(@src(), .horizontal, .{
                .expand = .none,
                .rect = .{
                    .x = position.x,
                    .y = position.y,
                    .w = @as(f32, @floatFromInt(sprite.source[2])) * 1 / file.canvas.scale,
                    .h = @as(f32, @floatFromInt(sprite.source[3])) * 1 / file.canvas.scale,
                },
                .border = dvui.Rect.all(0),
                .corner_radius = .{ .x = 0, .y = 0 },
                .padding = .{ .x = 0, .y = 0 },
                .margin = .{ .x = 0, .y = 0 },
                .background = false,
                .color_fill = .err,
            });
            defer box.deinit();

            const rs = box.data().rectScale();

            dvui.renderImage(pixi.editor.atlas.source, rs, .{
                .uv = uv,
            }) catch {
                std.log.err("Failed to render cursor image", .{});
            };
        }
    }
}

pub fn drawSample(fw: *FileWidget) void {
    const file = fw.file;
    const point = file.canvas.sample_data_point;

    if (point) |data_point| {
        const mouse_point = file.canvas.screenFromDataPoint(data_point);
        if (!file.canvas.rect.contains(mouse_point)) return;

        { // Draw a box around the hovered pixel at the correct scale
            const pixel_box_size = file.canvas.scale * 2;

            const pixel_point: dvui.Point = .{
                .x = @round(data_point.x - 0.5),
                .y = @round(data_point.y - 0.5),
            };

            var pixel_box = dvui.Rect.Physical.fromPoint(file.canvas.screenFromDataPoint(pixel_point));
            pixel_box.w = pixel_box_size;
            pixel_box.h = pixel_box_size;
            dvui.Path.stroke(.{ .points = &.{
                pixel_box.topLeft(),
                pixel_box.topRight(),
                pixel_box.bottomRight(),
                pixel_box.bottomLeft(),
            } }, .{ .thickness = 2, .color = .white, .closed = true });
        }

        // The scale of the enlarged view is always twice the scale of file.canvas
        const enlarged_scale: f32 = file.canvas.scale * 2.0;

        // The size of the sample box in screen space (constant size)
        const sample_box_size: f32 = 100.0 * 1 / file.canvas.scale; // e.g. 100x80 pixels on screen

        const corner_radius = dvui.Rect{
            .y = sample_box_size / 2,
            .w = sample_box_size / 2,
            .h = sample_box_size / 2,
        };

        // The size of the sample region in data (texture) space
        // This is how many data pixels are shown in the box, so that the box always shows the same number of data pixels at 2x the canvas scale
        const sample_region_size: f32 = sample_box_size / enlarged_scale;

        const border_width = 2 / file.canvas.scale;

        // Position the sample box so that the data_point is at its center
        const box = dvui.box(@src(), .horizontal, .{
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
                .fade = 10 * 1 / file.canvas.scale,
                .corner_radius = .{
                    .x = sample_box_size / 12,
                    .y = sample_box_size / 2,
                    .w = sample_box_size / 2,
                    .h = sample_box_size / 2,
                },
                .alpha = 0.5,
                .offset = .{
                    .x = 2 * 1 / file.canvas.scale,
                    .y = 2 * 1 / file.canvas.scale,
                },
            },
        });
        defer box.deinit();

        // Compute UVs for the region to sample, normalized to [0,1]
        const uv_rect = dvui.Rect{
            .x = (data_point.x - sample_region_size / 2) / @as(f32, @floatFromInt(file.width)),
            .y = (data_point.y - sample_region_size / 2) / @as(f32, @floatFromInt(file.height)),
            .w = sample_region_size / @as(f32, @floatFromInt(file.width)),
            .h = sample_region_size / @as(f32, @floatFromInt(file.height)),
        };

        var rs = box.data().borderRectScale();
        rs.r = rs.r.inset(dvui.Rect.Physical.all(border_width * file.canvas.scale * 2));

        var i: usize = file.layers.len;
        while (i > 0) {
            i -= 1;
            const source = file.layers.items(.source)[i];
            dvui.renderImage(source, rs, .{
                .uv = uv_rect,
                .corner_radius = .{
                    .x = corner_radius.x * rs.s,
                    .y = corner_radius.y * rs.s,
                    .w = corner_radius.w * rs.s,
                    .h = corner_radius.h * rs.s,
                },
            }) catch continue;
        }

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

pub fn drawLayers(fw: *FileWidget) void {
    var file = fw.file;
    var layer_index: usize = file.layers.len;
    const tiles_wide: usize = @intCast(@divExact(file.width, file.tile_width));
    const tiles_high: usize = @intCast(@divExact(file.height, file.tile_height));

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

    // Outline the image with a rectangle
    dvui.Path.stroke(.{ .points = &.{
        file.canvas.rect.topLeft(),
        file.canvas.rect.topRight(),
        file.canvas.rect.bottomRight(),
        file.canvas.rect.bottomLeft(),
    } }, .{ .thickness = 1, .color = dvui.Color.fromTheme(.fill_hover), .closed = true });
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
                        if (dvui.dragging(me.p, "scroll_drag")) |dps| {
                            const rs = file.canvas.scroll_rect_scale;
                            file.canvas.scroll_info.viewport.x -= dps.x / rs.s;
                            file.canvas.scroll_info.viewport.y -= dps.y / rs.s;
                            dvui.refresh(null, @src(), file.canvas.scroll_container.data().id);
                        }
                    }
                } else if (me.action == .wheel_y or me.action == .wheel_x) {
                    switch (pixi.editor.settings.input_scheme) {
                        .mouse => {
                            const base: f32 = if (me.mod.matchBind("shift")) 1.005 else 1.001;
                            e.handle(@src(), file.canvas.scroll_container.data());
                            if (me.action == .wheel_y) {
                                const zs = @exp(@log(base) * me.action.wheel_y);
                                if (zs != 1.0) {
                                    zoom *= zs;
                                    zoomP = me.p;
                                }
                            }
                        },
                        .trackpad => {
                            if (me.mod.matchBind("zoom")) {
                                e.handle(@src(), file.canvas.scroll_container.data());
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
const builtin = @import("builtin");

test {
    @import("std").testing.refAllDecls(@This());
}
