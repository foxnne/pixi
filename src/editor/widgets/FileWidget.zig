pub const FileWidget = @This();
const CanvasWidget = @import("CanvasWidget.zig");

init_options: InitOptions,
options: Options,
drag_data_point: ?dvui.Point = null,
sample_data_point: ?dvui.Point = null,
previous_mods: dvui.enums.Mod = .none,
right_mouse_down: bool = false,
sample_key_down: bool = false,
shift_key_down: bool = false,

pub const InitOptions = struct {
    canvas: *CanvasWidget,
    file: *pixi.Internal.File,
};

pub fn init(src: std.builtin.SourceLocation, init_opts: InitOptions, opts: Options) FileWidget {
    const fw: FileWidget = .{
        .init_options = init_opts,
        .options = opts,
        .drag_data_point = if (dvui.dataGet(null, init_opts.canvas.id, "drag_data_point", dvui.Point)) |point| point else null,
        .sample_data_point = if (dvui.dataGet(null, init_opts.canvas.id, "sample_data_point", dvui.Point)) |point| point else null,
        .sample_key_down = if (dvui.dataGet(null, init_opts.canvas.id, "sample_key_down", bool)) |key| key else false,
        .right_mouse_down = if (dvui.dataGet(null, init_opts.canvas.id, "right_mouse_down", bool)) |key| key else false,
    };

    init_opts.canvas.install(src, .{
        .id = init_opts.canvas.id,
        .data_size = .{
            .w = @floatFromInt(init_opts.file.width),
            .h = @floatFromInt(init_opts.file.height),
        },
    }, opts);

    return fw;
}

pub fn processKeybinds(self: *FileWidget) void {
    for (dvui.events()) |*e| {
        if (!self.init_options.canvas.scroll_container.matchEvent(e)) {
            continue;
        }

        switch (e.evt) {
            .key => |ke| {
                if (ke.matchBind("undo") and (ke.action == .down or ke.action == .repeat)) {
                    self.init_options.file.history.undoRedo(self.init_options.file, .undo) catch {
                        std.log.err("Failed to undo", .{});
                    };
                }

                if (ke.matchBind("redo") and (ke.action == .down or ke.action == .repeat)) {
                    self.init_options.file.history.undoRedo(self.init_options.file, .redo) catch {
                        std.log.err("Failed to undo", .{});
                    };
                }

                if (ke.matchBind("save") and ke.action == .down) {
                    pixi.editor.save() catch {
                        std.log.err("Failed to save", .{});
                    };
                }

                if (ke.matchBind("transform") and ke.action == .down) {
                    pixi.editor.transform() catch {
                        std.log.err("Failed to transform", .{});
                    };
                }

                if (ke.matchBind("activate") and (ke.action == .down or ke.action == .repeat)) {
                    if (self.init_options.file.editor.transform) |*transform| {
                        transform.accept();
                        e.handle(@src(), self.init_options.canvas.scroll_container.data());
                    }
                }

                if (ke.matchBind("cancel") and ke.action == .down) {
                    if (self.init_options.file.editor.transform) |*transform| {
                        transform.cancel();
                        e.handle(@src(), self.init_options.canvas.scroll_container.data());
                    } else if (pixi.editor.tools.current == .pointer) {
                        self.init_options.file.clearSelectedSprites();
                    }
                }

                if (ke.matchBind("copy") and ke.action == .down) {
                    pixi.editor.copy() catch {
                        std.log.err("Failed to copy", .{});
                    };
                    e.handle(@src(), self.init_options.canvas.scroll_container.data());
                }

                if (ke.matchBind("paste") and ke.action == .down) {
                    pixi.editor.paste() catch {
                        std.log.err("Failed to paste", .{});
                    };
                    e.handle(@src(), self.init_options.canvas.scroll_container.data());
                }
            },
            else => {},
        }
    }
}

pub fn processSample(self: *FileWidget) void {
    const file = self.init_options.file;

    const current_mods = dvui.currentWindow().modifiers;

    if (!current_mods.matchBind("sample") and self.sample_key_down) {
        self.sample_key_down = false;
        if (!self.right_mouse_down) {
            self.sample_data_point = null;
        }
    } else if (current_mods.matchBind("sample") and !self.previous_mods.matchBind("sample")) {
        self.sample_key_down = true;
        const current_point = self.init_options.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt);
        self.sample(file, current_point, self.right_mouse_down);

        @memset(file.editor.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
        file.editor.temporary_layer.invalidate();
        file.editor.temporary_layer.dirty = false;
    }

    for (dvui.events()) |*e| {
        switch (e.evt) {
            .mouse => |me| {
                if (!self.init_options.canvas.scroll_container.matchEvent(e)) {
                    continue;
                }

                const current_point = self.init_options.canvas.dataFromScreenPoint(me.p);

                if (me.action == .press and me.button == .right) {
                    self.right_mouse_down = true;
                    e.handle(@src(), self.init_options.canvas.scroll_container.data());
                    dvui.captureMouse(self.init_options.canvas.scroll_container.data(), e.num);
                    dvui.dragPreStart(me.p, .{ .name = "sample_drag" });
                    self.drag_data_point = current_point;

                    self.sample(file, current_point, self.sample_key_down);

                    @memset(file.editor.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                    file.editor.temporary_layer.invalidate();
                    file.editor.temporary_layer.dirty = false;
                } else if (me.action == .release and me.button == .right) {
                    self.right_mouse_down = false;
                    if (dvui.captured(self.init_options.canvas.scroll_container.data().id)) {
                        e.handle(@src(), self.init_options.canvas.scroll_container.data());
                        dvui.captureMouse(null, e.num);
                        dvui.dragEnd();

                        if (!self.sample_key_down) {
                            self.drag_data_point = null;
                            self.sample_data_point = null;
                        }
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
                            });

                            self.sample(file, current_point, self.sample_key_down);
                            e.handle(@src(), self.init_options.canvas.scroll_container.data());
                        }
                    } else if (self.right_mouse_down or self.sample_key_down) {
                        self.sample(file, current_point, self.right_mouse_down and self.sample_key_down);
                    }
                }
            },
            else => {},
        }
    }
}

fn sample(self: *FileWidget, file: *pixi.Internal.File, point: dvui.Point, change_layer: bool) void {
    self.sample_data_point = point;
    var color: [4]u8 = .{ 0, 0, 0, 0 };

    var layer_index: usize = file.layers.len;
    while (layer_index > 0) {
        layer_index -= 1;
        var layer = file.layers.get(layer_index);
        if (!layer.visible) continue;
        if (layer.pixelIndex(point)) |index| {
            const c = layer.pixels()[index];
            if (c[3] > 0) {
                color = c;
                if (change_layer) {
                    file.selected_layer_index = layer_index;
                }
            }
        }
    }

    if (color[3] == 0) {
        if (pixi.editor.tools.current != .eraser) {
            pixi.editor.tools.set(.eraser);
        }
    } else {
        pixi.editor.colors.primary = color;
        if (switch (pixi.editor.tools.current) {
            .pencil, .bucket => false,
            else => true,
        })
            pixi.editor.tools.set(pixi.editor.tools.previous_drawing_tool);
    }
}

pub fn processSpriteSelection(self: *FileWidget) void {
    if (pixi.editor.tools.current != .pointer) return;
    if (self.init_options.file.editor.transform != null) return;

    self.shift_key_down = false;

    const file = self.init_options.file;

    for (dvui.events()) |*e| {
        if (!self.init_options.canvas.scroll_container.matchEvent(e)) {
            continue;
        }

        switch (e.evt) {
            .mouse => |me| {
                const current_point = self.init_options.canvas.dataFromScreenPoint(me.p);

                if (self.init_options.canvas.rect.contains(me.p))
                    dvui.focusWidget(self.init_options.canvas.scroll_container.data().id, null, e.num);

                if (me.action == .press and me.button.pointer()) {
                    if (me.mod.matchBind("shift")) {
                        if (file.spriteIndex(self.init_options.canvas.dataFromScreenPoint(me.p))) |sprite_index| {
                            file.editor.selected_sprites.unset(sprite_index);
                        }
                    } else if (me.mod.matchBind("ctrl/cmd")) {
                        if (file.spriteIndex(self.init_options.canvas.dataFromScreenPoint(me.p))) |sprite_index| {
                            file.editor.selected_sprites.set(sprite_index);
                        }
                    } else {
                        file.clearSelectedSprites();
                        if (file.spriteIndex(self.init_options.canvas.dataFromScreenPoint(me.p))) |sprite_index| {
                            file.editor.selected_sprites.set(sprite_index);
                        }
                    }

                    e.handle(@src(), self.init_options.canvas.scroll_container.data());
                    dvui.captureMouse(self.init_options.canvas.scroll_container.data(), e.num);
                    dvui.dragPreStart(me.p, .{ .name = "sprite_selection_drag" });

                    self.drag_data_point = current_point;
                } else if (me.action == .release and me.button.pointer()) {
                    if (dvui.captured(self.init_options.canvas.scroll_container.data().id)) {
                        e.handle(@src(), self.init_options.canvas.scroll_container.data());
                        dvui.captureMouse(null, e.num);
                        dvui.dragEnd();
                    }
                    self.drag_data_point = null;
                } else if (me.action == .motion or me.action == .wheel_x or me.action == .wheel_y) {
                    if (dvui.captured(self.init_options.canvas.scroll_container.data().id)) {
                        if (dvui.dragging(me.p, "sprite_selection_drag")) |_| {
                            if (self.drag_data_point) |previous_point| {
                                e.handle(@src(), self.init_options.canvas.scroll_container.data());
                                const min_x = @min(previous_point.x, current_point.x);
                                const min_y = @min(previous_point.y, current_point.y);
                                const max_x = @max(previous_point.x, current_point.x);
                                const max_y = @max(previous_point.y, current_point.y);
                                const span_rect = dvui.Rect{
                                    .x = min_x,
                                    .y = min_y,
                                    .w = max_x - min_x,
                                    .h = max_y - min_y,
                                };

                                const screen_selection_rect = self.init_options.canvas.screenFromDataRect(span_rect);

                                dvui.scrollDrag(.{
                                    .mouse_pt = me.p,
                                    .screen_rect = screen_selection_rect,
                                });

                                if (me.mod.matchBind("shift")) {
                                    file.setSpriteSelection(span_rect, false);
                                    self.shift_key_down = true;
                                    //selection_color = dvui.themeGet().color(.err, .fill).opacity(0.5);
                                } else if (me.mod.matchBind("ctrl/cmd")) {
                                    file.setSpriteSelection(span_rect, true);
                                } else {
                                    file.clearSelectedSprites();
                                    file.setSpriteSelection(span_rect, true);
                                }
                            }
                        }
                    }
                }
            },
            else => {},
        }
    }
}

pub fn drawSpriteSelection(self: *FileWidget) void {
    if (pixi.editor.tools.current != .pointer) return;
    if (self.init_options.file.editor.transform != null) return;

    if (self.drag_data_point) |previous_point| {
        const current_point = self.init_options.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt);
        const min_x = @min(previous_point.x, current_point.x);
        const min_y = @min(previous_point.y, current_point.y);
        const max_x = @max(previous_point.x, current_point.x);
        const max_y = @max(previous_point.y, current_point.y);
        const span_rect = dvui.Rect{
            .x = min_x,
            .y = min_y,
            .w = max_x - min_x,
            .h = max_y - min_y,
        };

        const screen_selection_rect = self.init_options.canvas.screenFromDataRect(span_rect);
        const selection_color = if (self.shift_key_down) dvui.themeGet().color(.err, .fill).opacity(0.5) else dvui.themeGet().color(.highlight, .fill).opacity(0.5);
        screen_selection_rect.fill(
            dvui.Rect.Physical.all(6 * dvui.currentWindow().natural_scale),
            .{
                .color = selection_color,
            },
        );
    }
}

pub fn processSelection(self: *FileWidget) void {
    if (switch (pixi.editor.tools.current) {
        .selection,
        => false,
        else => true,
    }) return;

    if (self.sample_key_down or self.right_mouse_down) return;

    const file = self.init_options.file;
    const active_layer = &file.layers.get(file.selected_layer_index);

    const selection_alpha: u8 = 185;
    const selection_color_primary: dvui.Color = .{ .r = 200, .g = 200, .b = 200, .a = selection_alpha };
    const selection_color_secondary: dvui.Color = .{ .r = 50, .g = 50, .b = 50, .a = selection_alpha };

    const selection_alpha_stroke: u8 = 225;
    var selection_color_primary_stroke: dvui.Color = .{ .r = 255, .g = 255, .b = 255, .a = selection_alpha_stroke };
    var selection_color_secondary_stroke: dvui.Color = .{ .r = 200, .g = 200, .b = 200, .a = selection_alpha_stroke };

    { // Always draw the selection to the temporary layer so we dont only show it when the mouse moves/hovers
        defer file.editor.temporary_layer.invalidate();

        // Clear temporary layer pixels and mask
        @memset(file.editor.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
        file.editor.temporary_layer.clearMask();

        // Set the temporary layer mask to the selection layer mask
        file.editor.temporary_layer.mask.setUnion(file.editor.selection_layer.mask);
        file.editor.temporary_layer.mask.setIntersection(active_layer.mask);

        // Now temp mask contains the active selection trimmed by the active layer mask
        // go ahead and draw out the selection in the normal colors
        file.editor.temporary_layer.setColorFromMask(selection_color_primary);
        file.editor.temporary_layer.mask.setIntersection(file.editor.checkerboard);
        file.editor.temporary_layer.setColorFromMask(selection_color_secondary);
    }

    for (dvui.events()) |*e| {
        if (!self.init_options.canvas.scroll_container.matchEvent(e)) {
            continue;
        }

        switch (e.evt) {
            .key => |ke| {
                var update: bool = false;
                if (ke.matchBind("increase_stroke_size") and (ke.action == .down or ke.action == .repeat)) {
                    if (pixi.editor.tools.stroke_size < pixi.Editor.Tools.max_brush_size - 1)
                        pixi.editor.tools.stroke_size += 1;

                    pixi.editor.tools.setStrokeSize(pixi.editor.tools.stroke_size);
                    update = true;
                }

                if (ke.matchBind("decrease_stroke_size") and (ke.action == .down or ke.action == .repeat)) {
                    if (pixi.editor.tools.stroke_size > 1)
                        pixi.editor.tools.stroke_size -= 1;

                    pixi.editor.tools.setStrokeSize(pixi.editor.tools.stroke_size);
                    update = true;
                }

                if (update) {
                    defer file.editor.temporary_layer.invalidate();
                    const current_point = self.init_options.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt);
                    {
                        defer file.editor.temporary_layer.invalidate();

                        // Clear temporary layer pixels and mask
                        @memset(file.editor.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                        file.editor.temporary_layer.clearMask();

                        // Set the temporary layer mask to the selection layer mask
                        file.editor.temporary_layer.mask.setUnion(file.editor.selection_layer.mask);

                        // Draw the point at the stroke size to the temporary layer mask only
                        file.drawPoint(
                            current_point,
                            .temporary,
                            .{
                                .mask_only = true,
                                .stroke_size = pixi.editor.tools.stroke_size,
                            },
                        );

                        // Intersect with the active layer mask so the stroke is confined to only non-transparent pixels
                        file.editor.temporary_layer.mask.setIntersection(active_layer.mask);
                        file.editor.temporary_layer.setColorFromMask(selection_color_primary);

                        // Intersect with the checkerboard mask so we can show the pattern
                        file.editor.temporary_layer.mask.setIntersection(file.editor.checkerboard);
                        file.editor.temporary_layer.setColorFromMask(selection_color_secondary);
                    }
                }
            },
            .mouse => |me| {
                const current_point = self.init_options.canvas.dataFromScreenPoint(me.p);

                if (me.action == .position) {
                    // Clear the mask, we now need to only draw the point at the stroke size to the mask
                    file.editor.temporary_layer.clearMask();

                    var default: bool = true;

                    if (me.mod.matchBind("shift")) {
                        default = false;
                        selection_color_primary_stroke = selection_color_primary_stroke.lerp(dvui.themeGet().color(.err, .fill), 0.7);
                        selection_color_primary_stroke.a = selection_alpha_stroke;
                        selection_color_secondary_stroke = selection_color_secondary_stroke.lerp(dvui.themeGet().color(.err, .fill), 0.7);
                        selection_color_secondary_stroke.a = selection_alpha_stroke;
                    } else if (me.mod.matchBind("ctrl/cmd")) {
                        default = false;
                        selection_color_primary_stroke = selection_color_primary_stroke.lerp(dvui.themeGet().color(.highlight, .fill), 0.7);
                        selection_color_primary_stroke.a = selection_alpha_stroke;
                        selection_color_secondary_stroke = selection_color_secondary_stroke.lerp(dvui.themeGet().color(.highlight, .fill), 0.7);
                        selection_color_secondary_stroke.a = selection_alpha_stroke;
                    }

                    // Draw the point at the stroke size to the temporary layer mask only
                    file.drawPoint(
                        current_point,
                        .temporary,
                        .{
                            .mask_only = true,
                            .stroke_size = pixi.editor.tools.stroke_size,
                        },
                    );

                    // Only show stroke over relevant pixels to make selection clearer
                    if (me.mod.matchBind("shift")) {
                        file.editor.temporary_layer.mask.setIntersection(file.editor.selection_layer.mask);
                    } else if (me.mod.matchBind("ctrl/cmd")) {
                        var copy_mask = file.editor.selection_layer.mask.clone(dvui.currentWindow().arena()) catch {
                            dvui.log.err("Failed to clone selection layer mask", .{});
                            return;
                        };
                        copy_mask.toggleAll();
                        file.editor.temporary_layer.mask.setIntersection(copy_mask);
                    }

                    // Intersect with the active layer mask so the stroke is confined to only non-transparent pixels
                    file.editor.temporary_layer.mask.setIntersection(active_layer.mask);
                    file.editor.temporary_layer.setColorFromMask(selection_color_primary_stroke);

                    // Intersect with the checkerboard mask so we can show the pattern
                    file.editor.temporary_layer.mask.setIntersection(file.editor.checkerboard);
                    file.editor.temporary_layer.setColorFromMask(if (default) selection_color_secondary_stroke else selection_color_primary_stroke);
                }

                if (self.init_options.canvas.rect.contains(me.p))
                    dvui.focusWidget(self.init_options.canvas.scroll_container.data().id, null, e.num);

                if (me.action == .press and me.button.pointer()) {
                    e.handle(@src(), self.init_options.canvas.scroll_container.data());
                    dvui.captureMouse(self.init_options.canvas.scroll_container.data(), e.num);
                    dvui.dragPreStart(me.p, .{ .name = "stroke_drag" });

                    // Only clear the mask if we don't have ctrl/cmd pressed
                    if (!me.mod.matchBind("ctrl/cmd") and !me.mod.matchBind("shift"))
                        file.editor.selection_layer.clearMask();

                    file.selectPoint(
                        current_point,
                        .{
                            .value = !me.mod.matchBind("shift"),
                            .stroke_size = pixi.editor.tools.stroke_size,
                        },
                    );

                    self.drag_data_point = current_point;
                } else if (me.action == .release and me.button.pointer()) {
                    if (dvui.captured(self.init_options.canvas.scroll_container.data().id)) {
                        e.handle(@src(), self.init_options.canvas.scroll_container.data());
                        dvui.captureMouse(null, e.num);
                        dvui.dragEnd();

                        file.selectPoint(
                            current_point,
                            .{
                                .value = !me.mod.matchBind("shift"),
                                .stroke_size = pixi.editor.tools.stroke_size,
                            },
                        );

                        self.drag_data_point = null;
                    }
                } else if (me.action == .position or me.action == .wheel_x or me.action == .wheel_y) {
                    if (dvui.captured(self.init_options.canvas.scroll_container.data().id)) {
                        if (dvui.dragging(me.p, "stroke_drag")) |_| {
                            if (self.drag_data_point) |previous_point| {
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

                                const screen_rect = self.init_options.canvas.screenFromDataRect(span_rect);

                                dvui.scrollDrag(.{
                                    .mouse_pt = me.p,
                                    .screen_rect = screen_rect,
                                });
                            }

                            if (self.drag_data_point) |previous_point| {
                                file.selectLine(
                                    previous_point,
                                    current_point,
                                    .{
                                        .value = !me.mod.matchBind("shift"),
                                        .stroke_size = pixi.editor.tools.stroke_size,
                                    },
                                );
                            }

                            self.drag_data_point = current_point;
                        }
                    }
                }
            },
            else => {},
        }
    }
}

pub fn processStroke(self: *FileWidget) void {
    const file = self.init_options.file;

    if (switch (pixi.editor.tools.current) {
        .pencil,
        .eraser,
        => false,
        else => true,
    }) return;

    if (self.sample_key_down or self.right_mouse_down) return;

    const color: [4]u8 = switch (pixi.editor.tools.current) {
        .pencil => pixi.editor.colors.primary,
        .eraser => [_]u8{ 0, 0, 0, 0 },
        else => unreachable,
    };

    for (dvui.events()) |*e| {
        if (!self.init_options.canvas.scroll_container.matchEvent(e)) {
            continue;
        }

        switch (e.evt) {
            .key => |ke| {
                var update: bool = false;
                if (ke.matchBind("increase_stroke_size") and (ke.action == .down or ke.action == .repeat)) {
                    if (pixi.editor.tools.stroke_size < pixi.Editor.Tools.max_brush_size - 1)
                        pixi.editor.tools.stroke_size += 1;

                    pixi.editor.tools.setStrokeSize(pixi.editor.tools.stroke_size);
                    update = true;
                }

                if (ke.matchBind("decrease_stroke_size") and (ke.action == .down or ke.action == .repeat)) {
                    if (pixi.editor.tools.stroke_size > 1)
                        pixi.editor.tools.stroke_size -= 1;

                    pixi.editor.tools.setStrokeSize(pixi.editor.tools.stroke_size);
                    update = true;
                }

                if (update) {
                    @memset(file.editor.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                    const current_point = self.init_options.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt);
                    file.drawPoint(
                        current_point,
                        .temporary,
                        .{
                            .color = if (pixi.editor.tools.current != .eraser) .{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] } else .white,
                            .invalidate = true,
                            .to_change = false,
                            .stroke_size = pixi.editor.tools.stroke_size,
                        },
                    );
                }
            },
            .mouse => |me| {
                const current_point = self.init_options.canvas.dataFromScreenPoint(me.p);

                if (self.init_options.canvas.rect.contains(me.p))
                    dvui.focusWidget(self.init_options.canvas.scroll_container.data().id, null, e.num);

                if (me.action == .press and me.button.pointer()) {
                    e.handle(@src(), self.init_options.canvas.scroll_container.data());
                    dvui.captureMouse(self.init_options.canvas.scroll_container.data(), e.num);
                    dvui.dragPreStart(me.p, .{ .name = "stroke_drag" });

                    if (!me.mod.matchBind("shift")) {
                        file.drawPoint(
                            current_point,
                            .selected,
                            .{
                                .color = .{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] },
                                .invalidate = true,
                                .to_change = false,
                                .stroke_size = pixi.editor.tools.stroke_size,
                            },
                        );
                    }

                    self.drag_data_point = current_point;
                } else if (me.action == .release and me.button.pointer()) {
                    if (dvui.captured(self.init_options.canvas.scroll_container.data().id)) {
                        e.handle(@src(), self.init_options.canvas.scroll_container.data());
                        dvui.captureMouse(null, e.num);
                        dvui.dragEnd();

                        if (me.mod.matchBind("shift")) {
                            if (self.drag_data_point) |previous_point| {
                                file.drawLine(
                                    previous_point,
                                    current_point,
                                    .selected,
                                    .{
                                        .color = .{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] },
                                        .invalidate = true,
                                        .to_change = true,
                                        .stroke_size = pixi.editor.tools.stroke_size,
                                    },
                                );
                            }
                        } else {
                            file.drawPoint(
                                current_point,
                                .selected,
                                .{
                                    .color = .{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] },
                                    .invalidate = true,
                                    .to_change = true,
                                    .stroke_size = pixi.editor.tools.stroke_size,
                                },
                            );

                            // We need one extra frame to go ahead and set the dirty flag and update the ui to show
                            // the dirty flag, since the mouse hasn't moved and we will stop processing events the moment the
                            // mouse is released.
                            dvui.refresh(null, @src(), self.init_options.canvas.scroll_container.data().id);
                        }

                        self.drag_data_point = null;
                    }
                } else if (me.action == .position or me.action == .wheel_x or me.action == .wheel_y) {
                    if (dvui.captured(self.init_options.canvas.scroll_container.data().id)) {
                        if (dvui.dragging(me.p, "stroke_drag")) |_| {
                            if (self.drag_data_point) |previous_point| {
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

                                const screen_rect = self.init_options.canvas.screenFromDataRect(span_rect);

                                dvui.scrollDrag(.{
                                    .mouse_pt = me.p,
                                    .screen_rect = screen_rect,
                                });
                            }

                            if (me.mod.matchBind("shift")) {
                                if (self.drag_data_point) |previous_point| {
                                    @memset(file.editor.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                                    file.drawLine(
                                        previous_point,
                                        current_point,
                                        .temporary,
                                        .{
                                            .color = .{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] },
                                            .invalidate = true,
                                            .to_change = false,
                                            .stroke_size = pixi.editor.tools.stroke_size,
                                        },
                                    );
                                }
                            } else {
                                if (self.drag_data_point) |previous_point|
                                    file.drawLine(
                                        previous_point,
                                        current_point,
                                        .selected,
                                        .{
                                            .color = .{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] },
                                            .invalidate = true,
                                            .to_change = false,
                                            .stroke_size = pixi.editor.tools.stroke_size,
                                        },
                                    );

                                self.drag_data_point = current_point;

                                if (self.init_options.canvas.rect.contains(me.p) and self.sample_data_point == null) {
                                    if (self.sample_data_point == null or color[3] == 0) {
                                        @memset(file.editor.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                                        const temp_color = if (pixi.editor.tools.current != .eraser) color else [_]u8{ 255, 255, 255, 255 };
                                        file.drawPoint(
                                            current_point,
                                            .temporary,
                                            .{
                                                .color = .{ .r = temp_color[0], .g = temp_color[1], .b = temp_color[2], .a = temp_color[3] },
                                                .invalidate = true,
                                                .to_change = false,
                                                .stroke_size = pixi.editor.tools.stroke_size,
                                            },
                                        );
                                    }
                                }
                            }

                            e.handle(@src(), self.init_options.canvas.scroll_container.data());
                        }
                    } else {
                        if (self.init_options.canvas.rect.contains(me.p) and self.sample_data_point == null) {
                            @memset(file.editor.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                            const temp_color = if (pixi.editor.tools.current != .eraser) color else [_]u8{ 255, 255, 255, 255 };
                            file.drawPoint(
                                current_point,
                                .temporary,
                                .{
                                    .invalidate = true,
                                    .to_change = false,
                                    .stroke_size = pixi.editor.tools.stroke_size,
                                    .color = .{ .r = temp_color[0], .g = temp_color[1], .b = temp_color[2], .a = temp_color[3] },
                                },
                            );
                        }
                    }
                }
            },
            else => {},
        }
    }
}

pub fn processFill(self: *FileWidget) void {
    if (pixi.editor.tools.current != .bucket) return;
    const file = self.init_options.file;
    const color = pixi.editor.colors.primary;

    for (dvui.events()) |*e| {
        if (!self.init_options.canvas.scroll_container.matchEvent(e)) {
            continue;
        }

        switch (e.evt) {
            .mouse => |me| {
                const current_point = self.init_options.canvas.dataFromScreenPoint(me.p);

                if (self.init_options.canvas.rect.contains(me.p))
                    dvui.focusWidget(self.init_options.canvas.scroll_container.data().id, null, e.num);

                if (me.action == .press and me.button.pointer()) {
                    file.fillPoint(current_point, .selected, .{
                        .color = .{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] },
                        .invalidate = true,
                        .to_change = true,
                        .replace = me.mod.matchBind("ctrl/cmd"),
                    });
                }

                if (me.action == .motion or me.action == .wheel_x or me.action == .wheel_y) {
                    if (self.init_options.canvas.rect.contains(me.p) and self.sample_data_point == null) {
                        @memset(file.editor.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                        const temp_color = if (pixi.editor.tools.current != .eraser) color else [_]u8{ 255, 255, 255, 255 };
                        file.drawPoint(
                            current_point,
                            .temporary,
                            .{
                                .invalidate = true,
                                .to_change = false,
                                .stroke_size = 1,
                                .color = .{ .r = temp_color[0], .g = temp_color[1], .b = temp_color[2], .a = temp_color[3] },
                            },
                        );
                    }
                }
            },
            else => {},
        }
    }
}

pub fn processTransform(self: *FileWidget) void {
    var valid: bool = true;

    if (switch (pixi.editor.tools.current) {
        .pointer,
        => false,
        else => true,
    }) valid = false;

    const file = self.init_options.file;
    const image_rect = dvui.Rect.fromSize(.{ .w = @floatFromInt(file.width), .h = @floatFromInt(file.height) });
    const image_rect_physical = dvui.Rect.Physical.fromSize(.{ .w = image_rect.w, .h = image_rect.h });

    if (file.editor.transform) |*transform| {
        // If the scenario is not valid, cancel the transform
        if (!valid) {
            transform.cancel();
            return;
        }

        // Data path is necessary to build and fill with convex triangles, which will be how we render to the target texture
        var data_path: dvui.Path.Builder = .init(dvui.currentWindow().arena());
        for (transform.data_points[0..4]) |*point| {
            data_path.addPoint(.{ .x = point.x, .y = point.y });
        }

        // Calculate the centroid of the four corner points
        var centroid = transform.data_points[0];
        for (transform.data_points[1..4]) |*point| {
            centroid.x += point.x;
            centroid.y += point.y;
        }
        centroid.x /= 4;
        centroid.y /= 4;

        var triangle_opts: ?dvui.Triangles = data_path.build().fillConvexTriangles(dvui.currentWindow().arena(), .{
            .center = .{ .x = centroid.x, .y = centroid.y },
            .color = .white,
        }) catch null;

        { // Update the rotate point to locate towards the mouse
            const diff = self.init_options.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt).diff(transform.point(.pivot).*);
            transform.point(.rotate).* = transform.point(.pivot).plus(diff.normalize().scale(transform.radius, dvui.Point));
        }

        if (triangle_opts) |*triangles| {
            // First, we rotate the triangles to match the angle
            triangles.rotate(.{ .x = transform.point(.pivot).x, .y = transform.point(.pivot).y }, transform.rotation);

            for (transform.data_points[0..6], 0..) |*data_point, point_index| {
                const transform_point = @as(pixi.Editor.Transform.TransformPoint, @enumFromInt(point_index));
                const screen_point = if (point_index < 4) file.editor.canvas.screenFromDataPoint(.{ .x = triangles.vertexes[point_index].pos.x, .y = triangles.vertexes[point_index].pos.y }) else file.editor.canvas.screenFromDataPoint(data_point.*);

                var screen_rect = dvui.Rect.Physical.fromPoint(screen_point);
                screen_rect.w = 16 * dvui.currentWindow().natural_scale;
                screen_rect.h = 16 * dvui.currentWindow().natural_scale;
                screen_rect.x -= screen_rect.w / 2;
                screen_rect.y -= screen_rect.h / 2;

                for (dvui.events()) |*e| {
                    if (!self.init_options.canvas.scroll_container.matchEvent(e)) {
                        continue;
                    }

                    if (screen_rect.contains(dvui.currentWindow().mouse_pt)) {
                        dvui.cursorSet(.hand);
                    } else if (transform.active_point) |active_point| {
                        if (active_point == @as(pixi.Editor.Transform.TransformPoint, @enumFromInt(point_index))) {
                            dvui.cursorSet(.hand);
                        }
                    }

                    switch (e.evt) {
                        .mouse => |me| {
                            const current_point = self.init_options.canvas.dataFromScreenPoint(me.p);

                            if (self.init_options.canvas.rect.contains(me.p))
                                dvui.focusWidget(self.init_options.canvas.scroll_container.data().id, null, e.num);

                            if (me.action == .press and me.button.pointer()) {
                                if (screen_rect.contains(me.p)) {
                                    transform.active_point = @enumFromInt(point_index);
                                    e.handle(@src(), self.init_options.canvas.scroll_container.data());
                                    dvui.captureMouse(self.init_options.canvas.scroll_container.data(), e.num);
                                    dvui.dragPreStart(me.p, .{ .name = "transform_vertex_drag" });
                                    self.drag_data_point = current_point;
                                    transform.start_rotation = transform.rotation;
                                }
                            } else if (me.action == .release and me.button.pointer()) {
                                if (dvui.captured(self.init_options.canvas.scroll_container.data().id)) {
                                    e.handle(@src(), self.init_options.canvas.scroll_container.data());
                                    dvui.captureMouse(null, e.num);
                                    dvui.dragEnd();
                                    transform.active_point = null;
                                    dvui.refresh(null, @src(), self.init_options.canvas.scroll_container.data().id);
                                    self.drag_data_point = null;
                                    transform.dragging = false;
                                }
                            } else if (me.action == .motion or me.action == .wheel_x or me.action == .wheel_y) {
                                if (dvui.captured(self.init_options.canvas.scroll_container.data().id)) {
                                    if (dvui.dragging(me.p, "transform_vertex_drag")) |_| {
                                        if (transform.active_point) |active_point| {
                                            if (@intFromEnum(active_point) == point_index) {
                                                e.handle(@src(), self.init_options.canvas.scroll_container.data());

                                                // Set this state in advance so we can use it for the radius calculation
                                                transform.track_pivot = active_point == .pivot;

                                                // This is the new data point of the dragged point
                                                var new_point = file.editor.canvas.dataFromScreenPoint(me.p);

                                                // Calculate the radius of the transform no matter what point is changing
                                                defer {
                                                    var radius: f32 = 0.0;

                                                    for (transform.data_points[0..4]) |*point| {
                                                        const diff = point.diff(transform.point(.pivot).*);
                                                        if (diff.length() + 4 > radius) {
                                                            radius = diff.length() + 4;
                                                        }
                                                    }

                                                    transform.radius = radius;
                                                }

                                                if (point_index < 4) {
                                                    // Only round the corner points
                                                    new_point.x = @round(new_point.x);
                                                    new_point.y = @round(new_point.y);

                                                    // Now we have to un-rotate the vertex and set the original location
                                                    new_point = pixi.math.rotate(new_point, transform.point(.pivot).*, -transform.rotation);
                                                    data_point.* = new_point;

                                                    transform.ortho = false;

                                                    // data_point is the currently dragged point, but we also need to update adjacent points if we are keeping the transform square
                                                    blk_vert: {
                                                        if (!me.mod.matchBind("ctrl/cmd")) {
                                                            transform.ortho = true;

                                                            // Find adjacent verts
                                                            const adjacent_index_cw = if (point_index < 3) point_index + 1 else 0;
                                                            const adjacent_index_ccw = if (point_index > 0) point_index - 1 else 3;

                                                            // Get the adjacent points
                                                            const adjacent_point_cw = &transform.data_points[adjacent_index_cw];
                                                            const adjacent_point_ccw = &transform.data_points[adjacent_index_ccw];

                                                            const opposite_index: usize = switch (point_index) {
                                                                0 => 2,
                                                                1 => 3,
                                                                2 => 0,
                                                                3 => 1,
                                                                else => unreachable,
                                                            };

                                                            const opposite_point = &transform.data_points[opposite_index];

                                                            var rotation_direction: dvui.Point = pixi.math.rotate(dvui.Point{ .x = 1, .y = 0 }, transform.point(.pivot).*, 0);
                                                            var rotation_perp: dvui.Point = pixi.math.rotate(dvui.Point{ .x = 0, .y = 1 }, transform.point(.pivot).*, 0);

                                                            // Calculate the difference between the adjacent points and the new point

                                                            { // Calculate intersection point to set adjacent vert
                                                                const as = data_point.*;
                                                                const bs = opposite_point.*;
                                                                const ad = rotation_direction.scale(-1.0, dvui.Point);
                                                                const bd = rotation_perp;
                                                                const dx = bs.x - as.x;
                                                                const dy = bs.y - as.y;
                                                                const det = bd.x * ad.y - bd.y * ad.x;
                                                                if (det == 0.0) break :blk_vert;
                                                                const u = (dy * bd.x - dx * bd.y) / det;
                                                                switch (point_index) {
                                                                    0, 2 => adjacent_point_cw.* = as.plus(ad.scale(u, dvui.Point)),
                                                                    1, 3 => adjacent_point_ccw.* = as.plus(ad.scale(u, dvui.Point)),
                                                                    else => unreachable,
                                                                }
                                                            }

                                                            { // Calculate intersection point to set adjacent vert
                                                                const as = data_point.*;
                                                                const bs = opposite_point.*;
                                                                const ad = rotation_perp.scale(-1.0, dvui.Point);
                                                                const bd = rotation_direction;
                                                                const dx = bs.x - as.x;
                                                                const dy = bs.y - as.y;
                                                                const det = bd.x * ad.y - bd.y * ad.x;
                                                                if (det == 0.0) break :blk_vert;
                                                                const u = (dy * bd.x - dx * bd.y) / det;
                                                                switch (point_index) {
                                                                    0, 2 => adjacent_point_ccw.* = as.plus(ad.scale(u, dvui.Point)),
                                                                    1, 3 => adjacent_point_cw.* = as.plus(ad.scale(u, dvui.Point)),
                                                                    else => unreachable,
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                                if (active_point == .pivot) {
                                                    data_point.* = new_point;
                                                }
                                                if (transform_point == .rotate) {
                                                    if (self.drag_data_point) |drag_data_point| {
                                                        const drag_diff = drag_data_point.diff(transform.point(.pivot).*);
                                                        const drag_angle = std.math.atan2(drag_diff.y, drag_diff.x);

                                                        const diff = new_point.diff(transform.point(.pivot).*);
                                                        const angle = std.math.atan2(diff.y, diff.x);

                                                        transform.rotation = std.math.degreesToRadians(@round(std.math.radiansToDegrees(transform.start_rotation + (angle - drag_angle))));

                                                        if (me.mod.matchBind("ctrl/cmd")) { // Lock rotation to cardinal directions
                                                            const direction = pixi.math.Direction.fromRadians(transform.rotation);
                                                            transform.rotation = switch (direction) {
                                                                .n => std.math.pi / 2.0,
                                                                .ne => std.math.pi / 4.0,
                                                                .e => 0,
                                                                .s => (3.0 * std.math.pi) / 2.0,
                                                                .nw => (3.0 * std.math.pi) / 4.0,
                                                                .w => std.math.pi,
                                                                .sw => (5.0 * std.math.pi) / 4.0,
                                                                .se => (7.0 * std.math.pi) / 4.0,
                                                                else => unreachable,
                                                            };
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        },
                        else => {},
                    }
                }
            }

            // Now if we havent selected any of the points, we need to handle dragging the interior of the polygon
            // to move the entire transform
            if (transform.active_point == null) {
                for (dvui.events()) |*e| {
                    if (!self.init_options.canvas.scroll_container.matchEvent(e)) {
                        continue;
                    }

                    var is_hovered: bool = false;

                    if (transform.hovered(file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt))) {
                        dvui.cursorSet(.hand);
                        is_hovered = true;
                    }

                    switch (e.evt) {
                        .mouse => |me| {
                            //const current_point = self.init_options.canvas.dataFromScreenPoint(me.p);

                            if (self.init_options.canvas.rect.contains(me.p))
                                dvui.focusWidget(self.init_options.canvas.scroll_container.data().id, null, e.num);

                            if (me.action == .press and me.button.pointer()) {
                                if (is_hovered) {
                                    e.handle(@src(), self.init_options.canvas.scroll_container.data());
                                    dvui.captureMouse(self.init_options.canvas.scroll_container.data(), e.num);
                                    dvui.dragPreStart(me.p, .{ .name = "transform_drag" });
                                }
                            } else if (me.action == .motion or me.action == .wheel_x or me.action == .wheel_y) {
                                if (dvui.captured(self.init_options.canvas.scroll_container.data().id)) {
                                    if (dvui.dragging(me.p, "transform_drag")) |_| {
                                        transform.dragging = true;
                                        e.handle(@src(), self.init_options.canvas.scroll_container.data());

                                        var prev_point = file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt_prev);
                                        prev_point.x = @round(prev_point.x);
                                        prev_point.y = @round(prev_point.y);
                                        var new_point = file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt);
                                        new_point.x = @round(new_point.x);
                                        new_point.y = @round(new_point.y);

                                        const diff = new_point.diff(prev_point);
                                        for (transform.data_points[0..5]) |*point| {
                                            point.* = point.plus(diff);
                                        }
                                    }
                                }
                            }
                        },
                        else => {},
                    }
                }
            }

            // Here pass in the data rect, since we will be rendering directly to the low-res texture
            const target_texture = dvui.textureCreateTarget(@intFromFloat(image_rect.w), @intFromFloat(image_rect.h), .nearest) catch {
                std.log.err("Failed to create target texture", .{});
                return;
            };

            defer {
                const texture: ?dvui.Texture = dvui.textureFromTarget(target_texture) catch null;
                if (texture) |t| {
                    dvui.textureDestroyLater(t);
                }
            }

            // This is the previous target, we will be setting this back
            const previous_target = dvui.renderTarget(.{ .texture = target_texture, .offset = image_rect_physical.topLeft() });

            // Make sure we clip to the image rect, if we don't  and the texture overlaps the canvas,
            // the rendering will be clipped incorrectly
            // Use clipSet instead of clip, clip unions with current clip
            const clip_rect = image_rect_physical;
            const prev_clip = dvui.clipGet();
            dvui.clipSet(clip_rect);

            // Set UVs, there are 5 vertexes, or 1 more than the number of triangles, and is at the center

            triangles.vertexes[0].uv = .{ 0.0, 0.0 }; // TL
            triangles.vertexes[1].uv = .{ 1.0, 0.0 }; // TR
            triangles.vertexes[2].uv = .{ 1.0, 1.0 }; // BR
            triangles.vertexes[3].uv = .{ 0.0, 1.0 }; // BL
            triangles.vertexes[4].uv = .{ 0.5, 0.5 }; // C

            // Render the triangles to the target texture
            dvui.renderTriangles(triangles.*, transform.source.getTexture() catch null) catch {
                std.log.err("Failed to render triangles", .{});
            };

            // Restore the previous clip
            dvui.clipSet(prev_clip);
            // Set the target back
            _ = dvui.renderTarget(previous_target);

            // Read the target texture and copy it to the selection layer
            if (dvui.textureReadTarget(dvui.currentWindow().arena(), target_texture) catch null) |image_data| {
                @memcpy(file.editor.temporary_layer.bytes(), @as([*]u8, @ptrCast(image_data.ptr)));
                file.editor.temporary_layer.invalidate();
            } else {
                std.log.err("Failed to read target", .{});
            }
        } else {
            std.log.err("Failed to fill triangles", .{});
        }
    }
}

pub fn drawTransform(self: *FileWidget) void {
    const file = self.init_options.file;
    if (pixi.editor.tools.current != .pointer) return;

    if (file.editor.transform) |*transform| {
        var path = dvui.Path.Builder.init(dvui.currentWindow().arena());
        for (transform.data_points[0..4]) |*point| {
            const screen_point = file.editor.canvas.screenFromDataPoint(point.*);
            path.addPoint(screen_point);
        }

        var centroid = transform.data_points[0];
        for (transform.data_points[1..4]) |*point| {
            centroid.x += point.x;
            centroid.y += point.y;
        }
        centroid.x /= 4;
        centroid.y /= 4;

        centroid = pixi.math.rotate(centroid, transform.point(.pivot).*, transform.rotation);

        {
            const centroid_rect = dvui.Rect.fromPoint(centroid);
            var centroid_screen_rect = file.editor.canvas.screenFromDataRect(centroid_rect);
            centroid_screen_rect.w = 8 * dvui.currentWindow().natural_scale;
            centroid_screen_rect.h = 8 * dvui.currentWindow().natural_scale;
            centroid_screen_rect.x -= centroid_screen_rect.w / 2;
            centroid_screen_rect.y -= centroid_screen_rect.h / 2;

            centroid_screen_rect.fill(dvui.Rect.Physical.all(100000), .{
                .color = dvui.themeGet().color(.control, .fill),
            });

            centroid_screen_rect = centroid_screen_rect.insetAll(2 * dvui.currentWindow().natural_scale);
            centroid_screen_rect.fill(dvui.Rect.Physical.all(100000), .{
                .color = dvui.themeGet().color(.window, .text),
            });
        }

        {
            { // Draw circular outline for the rotation path
                var rotate_path = dvui.Path.Builder.init(dvui.currentWindow().arena());
                var outline_rect = dvui.Rect.fromSize(.{ .w = transform.radius * 2, .h = transform.radius * 2 });

                outline_rect.x = transform.point(.pivot).x - transform.radius;
                outline_rect.y = transform.point(.pivot).y - transform.radius;
                const outline_screen_rect = file.editor.canvas.screenFromDataRect(outline_rect);

                rotate_path.addRect(outline_screen_rect, dvui.Rect.Physical.all(100000));
                rotate_path.build().stroke(.{
                    .thickness = 4 * dvui.currentWindow().natural_scale,
                    .color = dvui.themeGet().color(.control, .fill),
                    .closed = true,
                    .endcap_style = .square,
                });
                rotate_path.build().stroke(.{
                    .thickness = 2,
                    .color = dvui.themeGet().color(.window, .text),
                    .closed = true,
                    .endcap_style = .square,
                });
            }

            if (transform.active_point) |active_point| {
                if (active_point == .rotate) {
                    // Draw the arms of the rotation
                    if (self.drag_data_point) |drag_data_point| {
                        const diff = drag_data_point.diff(transform.point(.pivot).*);

                        // Start angle
                        doubleStroke(&.{
                            file.editor.canvas.screenFromDataPoint(transform.point(.pivot).*),
                            file.editor.canvas.screenFromDataPoint(transform.point(.pivot).plus(diff.normalize().scale(transform.radius, dvui.Point))),
                        }, dvui.themeGet().color(.control, .text), 2);

                        // New angle
                        doubleStroke(&.{
                            file.editor.canvas.screenFromDataPoint(transform.point(.pivot).*),
                            file.editor.canvas.screenFromDataPoint(transform.point(.rotate).*),
                        }, dvui.themeGet().color(.control, .text), 2);
                    }
                }
            }
        }

        var triangles_opt = path.build().fillConvexTriangles(dvui.currentWindow().arena(), .{
            .center = .{ .x = centroid.x, .y = centroid.y },
            .color = .white,
        }) catch null;

        if (triangles_opt) |*triangles| {
            triangles.rotate(file.editor.canvas.screenFromDataPoint(transform.point(.pivot).*), transform.rotation);

            { // Draw the outline of the triangles
                const is_hovered = transform.hovered(file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt));
                var outline_path = dvui.Path.Builder.init(dvui.currentWindow().arena());
                for (triangles.vertexes[0..4]) |*vertex| {
                    outline_path.addPoint(.{ .x = vertex.pos.x, .y = vertex.pos.y });
                }

                outline_path.build().stroke(.{
                    .thickness = 4 * dvui.currentWindow().natural_scale,
                    .color = dvui.themeGet().color(.control, .fill),
                    .closed = true,
                    .endcap_style = .square,
                });
                outline_path.build().stroke(.{
                    .thickness = 2,
                    .color = if ((is_hovered and transform.active_point == null) or transform.dragging) dvui.themeGet().color(.highlight, .fill) else dvui.themeGet().color(.window, .text),
                    .closed = true,
                    .endcap_style = .square,
                });
            }

            // Dimensions and angle labels
            {
                // Draw dimensions if the transform is square and there is an active point
                if (transform.active_point) |active_point| {
                    if (@intFromEnum(active_point) < 4) {
                        if (transform.ortho) {
                            { // Vertical dimension
                                const top_left: dvui.Point = .{ .x = triangles.vertexes[0].pos.x, .y = triangles.vertexes[0].pos.y };
                                const bottom_left: dvui.Point = .{ .x = triangles.vertexes[3].pos.x, .y = triangles.vertexes[3].pos.y };

                                var offset: dvui.Point = .{ .x = -3 * dvui.currentWindow().natural_scale * file.editor.canvas.scale, .y = 0 };
                                offset = pixi.math.rotate(offset, .{ .x = 0, .y = 0 }, transform.rotation);

                                const dim_top_left: dvui.Point = top_left.plus(offset);
                                const dim_bottom_left: dvui.Point = bottom_left.plus(offset);

                                const dim_arm_top_left = dim_top_left.plus(pixi.math.rotate(.{ .x = -(0.75 * dvui.currentWindow().natural_scale) * file.editor.canvas.scale, .y = 0 }, .{ .x = 0, .y = 0 }, transform.rotation));
                                const dim_arm_top_right = dim_top_left.plus(pixi.math.rotate(.{ .x = (0.75 * dvui.currentWindow().natural_scale) * file.editor.canvas.scale, .y = 0 }, .{ .x = 0, .y = 0 }, transform.rotation));
                                const dim_arm_bottom_left = dim_bottom_left.plus(pixi.math.rotate(.{ .x = -(0.75 * dvui.currentWindow().natural_scale) * file.editor.canvas.scale, .y = 0 }, .{ .x = 0, .y = 0 }, transform.rotation));
                                const dim_arm_bottom_right = dim_bottom_left.plus(pixi.math.rotate(.{ .x = (0.75 * dvui.currentWindow().natural_scale) * file.editor.canvas.scale, .y = 0 }, .{ .x = 0, .y = 0 }, transform.rotation));

                                doubleStroke(&.{
                                    .{ .x = dim_top_left.x, .y = dim_top_left.y },
                                    .{ .x = dim_bottom_left.x, .y = dim_bottom_left.y },
                                }, dvui.themeGet().color(.control, .text), 1);

                                doubleStroke(&.{
                                    .{ .x = dim_arm_top_left.x, .y = dim_arm_top_left.y },
                                    .{ .x = dim_arm_top_right.x, .y = dim_arm_top_right.y },
                                }, dvui.themeGet().color(.control, .text), 1);

                                doubleStroke(&.{
                                    .{ .x = dim_arm_bottom_left.x, .y = dim_arm_bottom_left.y },
                                    .{ .x = dim_arm_bottom_right.x, .y = dim_arm_bottom_right.y },
                                }, dvui.themeGet().color(.control, .text), 1);

                                const center = top_left.plus(bottom_left).scale(0.5, dvui.Point);

                                const dimension_text = std.fmt.allocPrint(dvui.currentWindow().arena(), "{d:0.0}", .{transform.data_points[0].diff(transform.data_points[3]).length()}) catch "Failed to allocate dimension text";

                                const font = dvui.themeGet().font_caption;
                                const text_size = font.textSize(dimension_text);

                                var text_rect = dvui.currentWindow().rectScale().rectToPhysical(.fromSize(.{ .w = text_size.w, .h = text_size.h }));
                                text_rect.x = center.x + offset.x - text_rect.w / 2;
                                text_rect.y = center.y + offset.y - text_rect.h / 2;

                                var outline_rect = text_rect.outsetAll(2 * dvui.currentWindow().natural_scale);

                                outline_rect.fill(dvui.Rect.Physical.all(100000), .{
                                    .color = dvui.themeGet().color(.control, .fill),
                                });

                                dvui.renderText(.{
                                    .text = dimension_text,
                                    .font = font,
                                    .color = dvui.themeGet().color(.window, .text),
                                    .rs = .{ .r = text_rect, .s = dvui.currentWindow().natural_scale },
                                }) catch {
                                    dvui.log.err("Failed to render dimension text", .{});
                                };
                            }

                            { // Horizontal dimension
                                const bottom_right: dvui.Point = .{ .x = triangles.vertexes[2].pos.x, .y = triangles.vertexes[2].pos.y };
                                const bottom_left: dvui.Point = .{ .x = triangles.vertexes[3].pos.x, .y = triangles.vertexes[3].pos.y };

                                var offset: dvui.Point = .{ .x = 0, .y = 3 * dvui.currentWindow().natural_scale * file.editor.canvas.scale };
                                offset = pixi.math.rotate(offset, .{ .x = 0, .y = 0 }, transform.rotation);

                                const dim_bottom_right: dvui.Point = bottom_right.plus(offset);
                                const dim_bottom_left: dvui.Point = bottom_left.plus(offset);

                                const dim_arm_right_bottom = dim_bottom_right.plus(pixi.math.rotate(.{ .x = 0, .y = -(0.75 * dvui.currentWindow().natural_scale) * file.editor.canvas.scale }, .{ .x = 0, .y = 0 }, transform.rotation));
                                const dim_arm_right_top = dim_bottom_right.plus(pixi.math.rotate(.{ .x = 0, .y = (0.75 * dvui.currentWindow().natural_scale) * file.editor.canvas.scale }, .{ .x = 0, .y = 0 }, transform.rotation));
                                const dim_arm_left_bottom = dim_bottom_left.plus(pixi.math.rotate(.{ .x = 0, .y = -(0.75 * dvui.currentWindow().natural_scale) * file.editor.canvas.scale }, .{ .x = 0, .y = 0 }, transform.rotation));
                                const dim_arm_left_top = dim_bottom_left.plus(pixi.math.rotate(.{ .x = 0, .y = (0.75 * dvui.currentWindow().natural_scale) * file.editor.canvas.scale }, .{ .x = 0, .y = 0 }, transform.rotation));

                                doubleStroke(&.{
                                    .{ .x = dim_bottom_right.x, .y = dim_bottom_right.y },
                                    .{ .x = dim_bottom_left.x, .y = dim_bottom_left.y },
                                }, dvui.themeGet().color(.control, .text), 1);

                                doubleStroke(&.{
                                    .{ .x = dim_arm_right_bottom.x, .y = dim_arm_right_bottom.y },
                                    .{ .x = dim_arm_right_top.x, .y = dim_arm_right_top.y },
                                }, dvui.themeGet().color(.control, .text), 1);

                                doubleStroke(&.{
                                    .{ .x = dim_arm_left_bottom.x, .y = dim_arm_left_bottom.y },
                                    .{ .x = dim_arm_left_top.x, .y = dim_arm_left_top.y },
                                }, dvui.themeGet().color(.control, .text), 1);

                                const center = bottom_right.plus(bottom_left).scale(0.5, dvui.Point);

                                const dimension_text = std.fmt.allocPrint(dvui.currentWindow().arena(), "{d:0.0}", .{transform.data_points[3].diff(transform.data_points[2]).length()}) catch "Failed to allocate dimension text";

                                const font = dvui.themeGet().font_caption;
                                const text_size = font.textSize(dimension_text);

                                var text_rect = dvui.currentWindow().rectScale().rectToPhysical(.fromSize(.{ .w = text_size.w, .h = text_size.h }));
                                text_rect.x = center.x + offset.x - text_rect.w / 2;
                                text_rect.y = center.y + offset.y - text_rect.h / 2;

                                var outline_rect = text_rect.outsetAll(2 * dvui.currentWindow().natural_scale);

                                outline_rect.fill(dvui.Rect.Physical.all(100000), .{
                                    .color = dvui.themeGet().color(.control, .fill),
                                });

                                dvui.renderText(.{
                                    .text = dimension_text,
                                    .font = font,
                                    .color = dvui.themeGet().color(.window, .text),
                                    .rs = .{ .r = text_rect, .s = dvui.currentWindow().natural_scale },
                                }) catch {
                                    dvui.log.err("Failed to render dimension text", .{});
                                };
                            }
                        }
                    }

                    if (transform.active_point == .rotate) {
                        // Draw a stroke from transform.point(.rotate).* to the point on the circle at the midpoint of the rotation arc,
                        // but if the arc is > 180 degrees, the midpoint angle needs to be flipped 180 degrees.
                        const pivot = transform.point(.pivot).*;
                        const radius = transform.radius;

                        // Find the angle of the start (drag) and end (current) rotation arms
                        const start_angle = blk: {
                            if (self.drag_data_point) |drag_data_point| {
                                const drag_diff = drag_data_point.diff(pivot);
                                break :blk std.math.atan2(drag_diff.y, drag_diff.x);
                            } else {
                                // Fallback: use current rotation
                                break :blk std.math.atan2(transform.point(.rotate).y - pivot.y, transform.point(.rotate).x - pivot.x);
                            }
                        };

                        // Compute the shortest arc between start and end
                        var delta_angle = transform.rotation - transform.start_rotation;
                        // Normalize to [-pi, pi]
                        if (delta_angle > std.math.pi) {
                            delta_angle -= 2.0 * std.math.pi;
                        } else if (delta_angle < -std.math.pi) {
                            delta_angle += 2.0 * std.math.pi;
                        }

                        // The midpoint angle along the arc
                        var mid_angle = start_angle + delta_angle / 2.0;

                        // If the arc is more than 180 degrees, flip the midpoint angle by 180 degrees
                        if (delta_angle < 0) {
                            mid_angle += std.math.pi;
                        }

                        // Calculate the point on the circle at the midpoint angle
                        const center = file.editor.canvas.screenFromDataPoint(pivot.plus(.{
                            .x = radius * (1.0 + 0.075 * dvui.currentWindow().natural_scale) * std.math.cos(mid_angle),
                            .y = radius * (1.0 + 0.075 * dvui.currentWindow().natural_scale) * std.math.sin(mid_angle),
                        }));

                        var degrees = std.math.radiansToDegrees(delta_angle);
                        if (degrees < 0) degrees += 360.0;

                        const dimension_text = std.fmt.allocPrint(dvui.currentWindow().arena(), "{d:0.0}°", .{degrees}) catch "Failed to allocate dimension text";

                        const font = dvui.themeGet().font_caption;
                        const text_size = font.textSize(dimension_text);

                        var text_rect = dvui.currentWindow().rectScale().rectToPhysical(.fromSize(.{ .w = text_size.w, .h = text_size.h }));
                        text_rect.x = center.x - text_rect.w / 2;
                        text_rect.y = center.y - text_rect.h / 2;

                        var outline_rect = text_rect.outsetAll(2 * dvui.currentWindow().natural_scale);

                        outline_rect.fill(dvui.Rect.Physical.all(100000), .{
                            .color = dvui.themeGet().color(.control, .fill),
                        });

                        dvui.renderText(.{
                            .text = dimension_text,
                            .font = font,
                            .color = dvui.themeGet().color(.window, .text),
                            .rs = .{ .r = text_rect, .s = dvui.currentWindow().natural_scale },
                        }) catch {
                            dvui.log.err("Failed to render dimension text", .{});
                        };
                    }
                }
            }

            for (transform.data_points[0..6], 0..) |*point, point_index| {
                if (transform.active_point) |active_point| {
                    if (active_point == .pivot) {
                        if (point_index == 5) continue; // skip drawing the rotate point if we are dragging the pivot
                    }
                }

                var screen_point = file.editor.canvas.screenFromDataPoint(point.*);

                // Use the triangle points for the corners
                if (point_index < 4)
                    screen_point = triangles.vertexes[point_index].pos;

                var screen_rect = dvui.Rect.Physical.fromPoint(screen_point);
                screen_rect.w = 16 * dvui.currentWindow().natural_scale;
                screen_rect.h = 16 * dvui.currentWindow().natural_scale;
                screen_rect.x -= screen_rect.w / 2;
                screen_rect.y -= screen_rect.h / 2;

                screen_rect.fill(dvui.Rect.Physical.all(100000), .{
                    .color = dvui.themeGet().color(.control, .fill),
                });

                screen_rect = screen_rect.inset(dvui.Rect.Physical.all(1 * dvui.currentWindow().natural_scale));

                var color = dvui.themeGet().color(.window, .text);

                if (transform.active_point) |active_point| {
                    if (active_point == @as(pixi.Editor.Transform.TransformPoint, @enumFromInt(point_index))) {
                        color = dvui.themeGet().color(.highlight, .fill);
                    }
                } else if (screen_rect.contains(dvui.currentWindow().mouse_pt)) {
                    color = dvui.themeGet().color(.highlight, .fill);
                }

                screen_rect.fill(dvui.Rect.Physical.all(100000), .{
                    .color = color,
                });

                screen_rect = screen_rect.inset(dvui.Rect.Physical.all(2 * dvui.currentWindow().natural_scale));
                screen_rect.fill(dvui.Rect.Physical.all(100000), .{
                    .color = dvui.themeGet().color(.control, .fill),
                });
            }
        }
    }
}

fn doubleStroke(points: []const dvui.Point.Physical, color: dvui.Color, thickness: f32) void {
    dvui.Path.stroke(.{
        .points = points,
    }, .{
        .thickness = thickness * 2 * dvui.currentWindow().natural_scale,
        .color = dvui.themeGet().color(.control, .fill),
    });
    dvui.Path.stroke(.{
        .points = points,
    }, .{
        .thickness = thickness,
        .color = color,
    });
}

pub fn active(self: *FileWidget) bool {
    if (pixi.editor.activeFile()) |file| {
        if (file.id == self.init_options.file.id) {
            return true;
        }
    }
    return false;
}

pub fn drawCursor(self: *FileWidget) void {
    if (pixi.editor.tools.current == .pointer) return;
    if (pixi.editor.tools.radial_menu.visible) return;

    var subtract = false;
    var add = false;

    for (dvui.events()) |*e| {
        if (!self.init_options.canvas.scroll_container.matchEvent(e)) {
            continue;
        }
        switch (e.evt) {
            .key => |ke| {
                if (ke.mod.matchBind("shift")) {
                    subtract = true;
                } else if (ke.mod.matchBind("ctrl/cmd")) {
                    add = true;
                }
                if (self.init_options.canvas.rect.contains(dvui.currentWindow().mouse_pt)) {
                    _ = dvui.cursorSet(.hidden);
                }
            },
            .mouse => |me| {
                if (me.mod.matchBind("shift")) {
                    subtract = true;
                } else if (me.mod.matchBind("ctrl/cmd")) {
                    add = true;
                }
                if (self.init_options.canvas.rect.contains(me.p)) {
                    _ = dvui.cursorSet(.hidden);
                }
            },
            else => {},
        }
    }

    const data_point = self.init_options.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt);
    const mouse_point = dvui.currentWindow().mouse_pt;
    if (!self.init_options.canvas.rect.contains(mouse_point)) return;
    if (self.sample_data_point != null) return;

    if (switch (pixi.editor.tools.current) {
        .pencil => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.pencil_default],
        .eraser => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.eraser_default],
        .bucket => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.bucket_default],
        .selection => if (subtract) pixi.editor.atlas.data.sprites[pixi.atlas.sprites.selection_rem_default] else if (add) pixi.editor.atlas.data.sprites[pixi.atlas.sprites.selection_add_default] else pixi.editor.atlas.data.sprites[pixi.atlas.sprites.selection_default],
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
            .x = @as(f32, @floatFromInt(sprite.origin[0])) * 1 / self.init_options.canvas.scale,
            .y = @as(f32, @floatFromInt(sprite.origin[1])) * 1 / self.init_options.canvas.scale,
        };

        const position = data_point.diff(origin);

        const box = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .none,
            .rect = .{
                .x = position.x,
                .y = position.y,
                .w = @as(f32, @floatFromInt(sprite.source[2])) * 1 / self.init_options.canvas.scale,
                .h = @as(f32, @floatFromInt(sprite.source[3])) * 1 / self.init_options.canvas.scale,
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

        dvui.renderImage(pixi.editor.atlas.source, rs, .{
            .uv = uv,
        }) catch {
            std.log.err("Failed to render cursor image", .{});
        };
    }
}

pub fn drawSample(self: *FileWidget) void {
    const file = self.init_options.file;
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
            .color_border = dvui.themeGet().color(.control, .text),
            .corner_radius = corner_radius,
            .background = true,
            .color_fill = dvui.themeGet().color(.window, .fill),
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

        // Compute UVs for the region to sample, normalized to [0,1]
        const uv_rect = dvui.Rect{
            .x = (data_point.x - sample_region_size / 2) / @as(f32, @floatFromInt(file.width)),
            .y = (data_point.y - sample_region_size / 2) / @as(f32, @floatFromInt(file.height)),
            .w = sample_region_size / @as(f32, @floatFromInt(file.width)),
            .h = sample_region_size / @as(f32, @floatFromInt(file.height)),
        };

        var rs = box.data().borderRectScale();
        rs.r = rs.r.inset(dvui.Rect.Physical.all(border_width * self.init_options.canvas.scale * 2));

        var i: usize = file.layers.len;
        while (i > 0) {
            i -= 1;
            if (!file.layers.items(.visible)[i]) continue;
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

pub fn updateActiveLayerMask(self: *FileWidget) void {
    var file = self.init_options.file;
    var active_layer = file.layers.get(file.selected_layer_index);

    active_layer.clearMask();
    active_layer.setMaskFromTransparency(true);
}

pub fn drawLayers(self: *FileWidget) void {
    var file = self.init_options.file;
    var layer_index: usize = file.layers.len;
    const tiles_wide: usize = @intCast(@divExact(file.width, file.tile_width));
    const tiles_high: usize = @intCast(@divExact(file.height, file.tile_height));

    const shadow_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .none,
        .rect = .{ .x = 0, .y = 0, .w = @floatFromInt(file.width), .h = @floatFromInt(file.height) },
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

    const mouse_data_point = self.init_options.file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt);
    // Draw the checkerboard texture at the hovered sprite position
    if (file.spriteIndex(mouse_data_point)) |sprite_index| {
        const image_rect = file.spriteRect(sprite_index);

        const image_rect_scale: dvui.RectScale = .{
            .r = self.init_options.canvas.screenFromDataRect(image_rect),
            .s = self.init_options.canvas.scale,
        };

        dvui.renderImage(file.editor.checkerboard_tile, image_rect_scale, .{
            .colormod = dvui.themeGet().color(.content, .fill).lighten(8.0),
        }) catch {
            std.log.err("Failed to render checkerboard", .{});
        };
    }

    const image_rect = dvui.Rect.fromSize(.{ .w = @floatFromInt(file.width), .h = @floatFromInt(file.height) });

    while (layer_index > 0) {
        layer_index -= 1;

        if (!file.layers.items(.visible)[layer_index]) continue;

        const image = dvui.image(@src(), .{ .source = file.layers.items(.source)[layer_index] }, .{
            .rect = image_rect,
            .border = dvui.Rect.all(0),
            .id_extra = file.layers.items(.id)[layer_index],
            .background = false,
        });

        const boxRect = image.rectScale().r;
        if (self.init_options.canvas.bounding_box) |b| {
            self.init_options.canvas.bounding_box = b.unionWith(boxRect);
        } else {
            self.init_options.canvas.bounding_box = boxRect;
        }
    }

    // Draw the selection layer
    _ = dvui.image(@src(), .{
        .source = file.editor.selection_layer.source,
    }, .{
        .rect = image_rect,
        .border = dvui.Rect.all(0),
        .id_extra = file.layers.len + 1,
        .background = false,
    });

    // Draw the temporary layer
    const image = dvui.image(@src(), .{
        .source = file.editor.temporary_layer.source,
    }, .{
        .rect = image_rect,
        .border = dvui.Rect.all(0),
        .id_extra = file.layers.len + 2,
        .background = false,
    });

    for (0..tiles_wide) |x| {
        dvui.Path.stroke(.{ .points = &.{
            self.init_options.canvas.screenFromDataPoint(.{ .x = @as(f32, @floatFromInt(x * file.tile_width)), .y = 0 }),
            self.init_options.canvas.screenFromDataPoint(.{ .x = @as(f32, @floatFromInt(x * file.tile_width)), .y = @as(f32, @floatFromInt(file.height)) }),
        } }, .{ .thickness = 1, .color = dvui.themeGet().color(.control, .text) });
    }

    for (0..tiles_high) |y| {
        dvui.Path.stroke(.{ .points = &.{
            self.init_options.canvas.screenFromDataPoint(.{ .x = 0, .y = @as(f32, @floatFromInt(y * file.tile_height)) }),
            self.init_options.canvas.screenFromDataPoint(.{ .x = @as(f32, @floatFromInt(file.width)), .y = @as(f32, @floatFromInt(y * file.tile_height)) }),
        } }, .{ .thickness = 1, .color = dvui.themeGet().color(.control, .text) });
    }

    self.init_options.canvas.bounding_box = image.rectScale().r;

    // Outline the image with a rectangle
    dvui.Path.stroke(.{ .points = &.{
        self.init_options.canvas.rect.topLeft(),
        self.init_options.canvas.rect.topRight(),
        self.init_options.canvas.rect.bottomRight(),
        self.init_options.canvas.rect.bottomLeft(),
    } }, .{ .thickness = 1, .color = dvui.themeGet().color(.control, .text), .closed = true });

    // Draw the selection box for the selected sprites
    if (pixi.editor.tools.current == .pointer and file.editor.transform == null) {
        var iter = file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
        while (iter.next()) |i| {
            const sprite_rect = file.spriteRect(i);
            const sprite_rect_physical = self.init_options.canvas.screenFromDataRect(sprite_rect);
            sprite_rect_physical.stroke(dvui.Rect.Physical.all(@min(sprite_rect_physical.w, sprite_rect_physical.h) / 8), .{
                .thickness = 3 * dvui.currentWindow().content_scale,
                .color = dvui.themeGet().color(.highlight, .fill),
                .closed = true,
            });
        }
    }
}

pub fn processEvents(self: *FileWidget) void {
    defer self.previous_mods = dvui.currentWindow().modifiers;

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

    defer if (self.sample_key_down) {
        dvui.dataSet(null, self.init_options.canvas.id, "sample_key_down", self.sample_key_down);
    } else {
        dvui.dataRemove(null, self.init_options.canvas.id, "sample_key_down");
    };

    defer if (self.right_mouse_down) {
        dvui.dataSet(null, self.init_options.canvas.id, "right_mouse_down", self.right_mouse_down);
    } else {
        dvui.dataRemove(null, self.init_options.canvas.id, "right_mouse_down");
    };

    // If we are processing, we need to always ensure the temporary layer is cleared
    @memset(self.init_options.file.editor.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
    self.init_options.file.editor.temporary_layer.clearMask();

    // Animate/Flip the checkerboard if we are in selection mode
    if (pixi.editor.tools.current == .selection) {
        const millis_per_frame = 250;
        if (dvui.timerDoneOrNone(self.init_options.file.editor.canvas.scroll_container.data().id)) {
            self.init_options.file.editor.checkerboard.toggleAll();

            const millis = @divFloor(dvui.frameTimeNS(), 1_000_000);
            const left = @as(i32, @intCast(@rem(millis, millis_per_frame)));
            const wait = 1000 * (millis_per_frame - left);
            dvui.timer(self.init_options.file.editor.canvas.scroll_container.data().id, wait);
        }
    }

    // Ensure that the active layer mask is always up to date
    self.updateActiveLayerMask();

    if (self.hovered() != null) {
        self.processFill();
        self.processStroke();
        self.processSample();
    }
    self.processSpriteSelection();
    self.processSelection();
    self.processTransform();

    // Draw layers first, so that the scrolling bounding box is updated

    self.drawLayers();
    self.drawSpriteSelection();

    // Draw shadows for the scroll container
    pixi.dvui.drawEdgeShadow(self.init_options.canvas.scroll_container.data().rectScale(), .top, .{});
    pixi.dvui.drawEdgeShadow(self.init_options.canvas.scroll_container.data().rectScale(), .bottom, .{ .opacity = 0.2 });
    pixi.dvui.drawEdgeShadow(self.init_options.canvas.scroll_container.data().rectScale(), .left, .{});
    pixi.dvui.drawEdgeShadow(self.init_options.canvas.scroll_container.data().rectScale(), .right, .{ .opacity = 0.2 });

    // Only process draw cursor on the hovered widget
    if (self.hovered() != null) {
        self.drawCursor();
        self.drawSample();
        self.processKeybinds();
    }
    self.drawTransform();

    // Then process the scroll and zoom events last
    self.init_options.canvas.processEvents();
}

pub fn deinit(self: *FileWidget) void {
    self.init_options.canvas.deinit();

    self.* = undefined;
}

pub fn hovered(self: *FileWidget) ?dvui.Point {
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
