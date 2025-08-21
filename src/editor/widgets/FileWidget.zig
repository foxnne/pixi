pub const FileWidget = @This();
const CanvasWidget = @import("CanvasWidget.zig");

init_options: InitOptions,
options: Options,
drag_data_point: ?dvui.Point = null,
sample_data_point: ?dvui.Point = null,
previous_mods: dvui.enums.Mod = .none,
right_mouse_down: bool = false,
sample_key_down: bool = false,

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
                    self.init_options.file.transform() catch {
                        std.log.err("Failed to transform", .{});
                    };
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

        @memset(file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
        const current_point = self.init_options.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt);
        file.drawPoint(
            current_point,
            if (pixi.editor.tools.current != .eraser) pixi.editor.colors.primary else [_]u8{ 255, 255, 255, 255 },
            .temporary,
            .{
                .invalidate = true,
                .to_change = false,
                .stroke_size = switch (pixi.editor.tools.current) {
                    .pencil, .eraser => pixi.editor.tools.stroke_size,
                    else => 1,
                },
            },
        );
        file.temporary_layer.dirty = true;
    } else if (current_mods.matchBind("sample") and !self.previous_mods.matchBind("sample")) {
        self.sample_key_down = true;
        const current_point = self.init_options.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt);
        self.sample(file, current_point, self.right_mouse_down);

        @memset(file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
        file.temporary_layer.invalidate();
        file.temporary_layer.dirty = false;
    }

    for (dvui.events()) |*e| {
        switch (e.evt) {
            .mouse => |me| {
                if (!self.init_options.canvas.scroll_container.matchEvent(e)) {
                    if (e.evt == .mouse) {
                        if (file.temporary_layer.dirty) {
                            @memset(file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                            file.temporary_layer.invalidate();
                            file.temporary_layer.dirty = false;
                        }
                    }
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

                    @memset(file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                    file.temporary_layer.invalidate();
                    file.temporary_layer.dirty = false;
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

                    @memset(file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                    file.drawPoint(
                        current_point,
                        if (pixi.editor.tools.current != .eraser) pixi.editor.colors.primary else [_]u8{ 255, 255, 255, 255 },
                        .temporary,
                        .{
                            .invalidate = true,
                            .to_change = false,
                            .stroke_size = switch (pixi.editor.tools.current) {
                                .pencil, .eraser => pixi.editor.tools.stroke_size,
                                else => 1,
                            },
                        },
                    );
                    file.temporary_layer.dirty = true;
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
                            file.selected_sprites.unset(sprite_index);
                        }
                    } else if (me.mod.matchBind("ctrl/cmd")) {
                        if (file.spriteIndex(self.init_options.canvas.dataFromScreenPoint(me.p))) |sprite_index| {
                            file.selected_sprites.set(sprite_index);
                        }
                    } else {
                        file.clearSelectedSprites();
                        if (file.spriteIndex(self.init_options.canvas.dataFromScreenPoint(me.p))) |sprite_index| {
                            file.selected_sprites.set(sprite_index);
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

                                var screen_selection_rect = self.init_options.canvas.screenFromDataRect(span_rect);

                                dvui.scrollDrag(.{
                                    .mouse_pt = me.p,
                                    .screen_rect = screen_selection_rect,
                                });

                                var selection_color = dvui.themeGet().color(.highlight, .fill).opacity(0.5);

                                if (me.mod.matchBind("shift")) {
                                    file.setSpriteSelection(span_rect, false);
                                    selection_color = dvui.themeGet().color(.err, .fill).opacity(0.5);
                                } else if (me.mod.matchBind("ctrl/cmd")) {
                                    file.setSpriteSelection(span_rect, true);
                                } else {
                                    file.clearSelectedSprites();
                                    file.setSpriteSelection(span_rect, true);
                                }

                                screen_selection_rect.fill(
                                    dvui.Rect.Physical.all(screen_selection_rect.w / 12),
                                    .{
                                        .color = selection_color,
                                    },
                                );
                            }
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
                    @memset(file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                    const current_point = self.init_options.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt);
                    file.drawPoint(
                        current_point,
                        if (pixi.editor.tools.current != .eraser) color else [_]u8{ 255, 255, 255, 255 },
                        .temporary,
                        .{
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
                            color,
                            .selected,
                            .{
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
                                    color,
                                    .selected,
                                    .{
                                        .invalidate = true,
                                        .to_change = true,
                                        .stroke_size = pixi.editor.tools.stroke_size,
                                    },
                                );
                            }
                        } else {
                            file.drawPoint(
                                current_point,
                                color,
                                .selected,
                                .{
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
                                    @memset(file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                                    file.drawLine(
                                        previous_point,
                                        current_point,
                                        color,
                                        .temporary,
                                        .{
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
                                        color,
                                        .selected,
                                        .{
                                            .invalidate = true,
                                            .to_change = false,
                                            .stroke_size = pixi.editor.tools.stroke_size,
                                        },
                                    );

                                self.drag_data_point = current_point;

                                if (self.init_options.canvas.rect.contains(me.p) and self.sample_data_point == null) {
                                    if (self.sample_data_point == null or color[3] == 0) {
                                        @memset(file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                                        const temp_color = if (pixi.editor.tools.current != .eraser) color else [_]u8{ 255, 255, 255, 255 };
                                        file.drawPoint(
                                            current_point,
                                            temp_color,
                                            .temporary,
                                            .{
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
                            @memset(file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                            const temp_color = if (pixi.editor.tools.current != .eraser) color else [_]u8{ 255, 255, 255, 255 };
                            file.drawPoint(
                                current_point,
                                temp_color,
                                .temporary,
                                .{ .invalidate = true, .to_change = false, .stroke_size = pixi.editor.tools.stroke_size },
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
                    file.fillPoint(current_point, color, .selected, .{
                        .invalidate = true,
                        .to_change = true,
                        .replace = me.mod.matchBind("ctrl/cmd"),
                    });
                }

                if (me.action == .motion or me.action == .wheel_x or me.action == .wheel_y) {
                    if (self.init_options.canvas.rect.contains(me.p) and self.sample_data_point == null) {
                        @memset(file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                        const temp_color = if (pixi.editor.tools.current != .eraser) color else [_]u8{ 255, 255, 255, 255 };
                        file.drawPoint(
                            current_point,
                            temp_color,
                            .temporary,
                            .{ .invalidate = true, .to_change = false, .stroke_size = 1 },
                        );
                    }
                }
            },
            else => {},
        }
    }
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

    var cursor_data_point: ?dvui.Point = null;

    for (dvui.events()) |*e| {
        if (!self.init_options.canvas.scroll_container.matchEvent(e)) {
            continue;
        }
        switch (e.evt) {
            .mouse => |me| {
                cursor_data_point = self.init_options.canvas.dataFromScreenPoint(me.p);

                if (self.init_options.canvas.rect.contains(me.p)) {
                    _ = dvui.cursorShow(false);
                }
            },
            .key => |_| {
                cursor_data_point = self.init_options.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt);

                if (self.init_options.canvas.rect.contains(dvui.currentWindow().mouse_pt)) {
                    _ = dvui.cursorShow(false);
                }
            },
            else => {},
        }
    }

    if (cursor_data_point) |data_point| {
        const mouse_point = self.init_options.canvas.screenFromDataPoint(data_point);
        if (!self.init_options.canvas.rect.contains(mouse_point)) return;
        if (self.sample_data_point != null) return;

        if (switch (pixi.editor.tools.current) {
            .pencil => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.pencil_default],
            .eraser => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.eraser_default],
            .bucket => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.bucket_default],
            .selection => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.selection_default],
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

        dvui.renderImage(file.checkerboard, image_rect_scale, .{
            .colormod = dvui.themeGet().color(.content, .fill).lighten(8.0),
        }) catch {
            std.log.err("Failed to render checkerboard", .{});
        };
    }

    while (layer_index > 0) {
        layer_index -= 1;

        if (!file.layers.items(.visible)[layer_index]) continue;

        const image = dvui.image(@src(), .{ .source = file.layers.items(.source)[layer_index] }, .{
            .rect = .{ .x = 0, .y = 0, .w = @floatFromInt(file.width), .h = @floatFromInt(file.height) },
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

    const image = dvui.image(@src(), .{
        .source = file.temporary_layer.source,
    }, .{
        .rect = .{ .x = 0, .y = 0, .w = @floatFromInt(file.width), .h = @floatFromInt(file.height) },
        .border = dvui.Rect.all(0),
        .id_extra = file.layers.len + 1,
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
    if (pixi.editor.tools.current == .pointer) {
        var iter = file.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
        while (iter.next()) |i| {
            const sprite_rect = file.spriteRect(i);
            const sprite_rect_physical = self.init_options.canvas.screenFromDataRect(sprite_rect);
            sprite_rect_physical.stroke(dvui.Rect.Physical.all(sprite_rect_physical.w / 8), .{
                .thickness = 6,
                .color = dvui.themeGet().color(.highlight, .fill),
                .closed = true,
            });
        }
    }

    if (file.editor.transform) |*transform| {
        //const top_left = transform.data_points[0];

        var path: dvui.Path.Builder = .init(dvui.currentWindow().arena());
        for (transform.data_points[0..5], 0..) |*point, point_index| {
            point.x = @round(point.x);
            point.y = @round(point.y);

            const screen_point = file.editor.canvas.screenFromDataPoint(point.*);

            var screen_rect = dvui.Rect.Physical.fromPoint(screen_point);
            screen_rect.w = 30;
            screen_rect.h = 30;
            screen_rect.x -= screen_rect.w / 2;
            screen_rect.y -= screen_rect.h / 2;

            {
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
                                if (screen_rect.contains(me.p)) {
                                    transform.active_data_point = point_index;
                                    e.handle(@src(), self.init_options.canvas.scroll_container.data());
                                    dvui.captureMouse(self.init_options.canvas.scroll_container.data(), e.num);
                                    dvui.dragPreStart(me.p, .{ .name = "transform_vertex_drag" });

                                    self.drag_data_point = current_point;
                                }
                            } else if (me.action == .release and me.button.pointer()) {
                                if (dvui.captured(self.init_options.canvas.scroll_container.data().id)) {
                                    e.handle(@src(), self.init_options.canvas.scroll_container.data());
                                    dvui.captureMouse(null, e.num);
                                    dvui.dragEnd();
                                }
                                self.drag_data_point = null;
                            } else if (me.action == .motion or me.action == .wheel_x or me.action == .wheel_y) {
                                if (dvui.captured(self.init_options.canvas.scroll_container.data().id)) {
                                    if (dvui.dragging(me.p, "transform_vertex_drag")) |_| {
                                        if (transform.active_data_point) |active_data_point| {
                                            if (active_data_point == point_index) {
                                                point.* = file.editor.canvas.dataFromScreenPoint(me.p);
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
            if (point_index < 4)
                path.addPoint(screen_point);
        }

        path.build().stroke(.{
            .thickness = 2,
            .color = dvui.themeGet().color(.err, .fill),
            .closed = true,
        });

        var centroid = transform.data_points[0];
        for (transform.data_points[1..4]) |*point| {
            centroid.x += point.x;
            centroid.y += point.y;
        }
        centroid.x /= 4;
        centroid.y /= 4;

        const triangle_opts: ?dvui.Triangles = path.build().fillConvexTriangles(dvui.currentWindow().arena(), .{
            .center = file.editor.canvas.screenFromDataPoint(centroid),
            .color = .white,
        }) catch null;

        if (triangle_opts) |triangles| {
            triangles.vertexes[0].uv = .{ 0.0, 0.0 }; // TL
            triangles.vertexes[1].uv = .{ 1.0, 0.0 }; // TR
            triangles.vertexes[2].uv = .{ 1.0, 1.0 }; // BR
            triangles.vertexes[3].uv = .{ 0.0, 1.0 }; // BL
            triangles.vertexes[4].uv = .{ 0.5, 0.5 }; // C

            dvui.renderTriangles(triangles, transform.source.getTexture() catch null) catch {
                std.log.err("Failed to render triangles", .{});
            };
        } else {
            std.log.err("Failed to fill triangles", .{});
        }

        for (transform.data_points[0..4]) |*point| {
            const screen_point = file.editor.canvas.screenFromDataPoint(point.*);

            var screen_rect = dvui.Rect.Physical.fromPoint(screen_point);
            screen_rect.w = 30;
            screen_rect.h = 30;
            screen_rect.x -= screen_rect.w / 2;
            screen_rect.y -= screen_rect.h / 2;

            screen_rect.fill(dvui.Rect.Physical.all(100000), .{
                .color = .green,
            });
        }

        const screen_point = file.editor.canvas.screenFromDataPoint(centroid);

        var screen_rect = dvui.Rect.Physical.fromPoint(screen_point);
        screen_rect.w = 30;
        screen_rect.h = 30;
        screen_rect.x -= screen_rect.w / 2;
        screen_rect.y -= screen_rect.h / 2;

        screen_rect.fill(dvui.Rect.Physical.all(100000), .{
            .color = .green,
        });

        // var triangles = dvui.Path.fillConvexTriangles(transform.data_points[0..4], pixi.app.allocator, .{}) catch {
        //     std.log.err("Failed to fill triangles", .{});
        //     return;
        // };

        // var transform_rect = dvui.Rect.fromPoint(top_left);
        // transform_rect.w = pixi.image.size(transform.source).w;
        // transform_rect.h = pixi.image.size(transform.source).h;

        // const transform_image = dvui.image(@src(), .{
        //     .source = transform.source,
        // }, .{
        //     .rect = transform_rect,
        //     .border = dvui.Rect.all(0),
        //     .id_extra = file.layers.len + 2,
        //     .background = false,
        // });

        // transform_image.rectScale().r.stroke(dvui.Rect.Physical.all(0), .{
        //     .thickness = 2,
        //     .color = dvui.themeGet().color(.err, .fill),
        //     .closed = true,
        // });
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
    @memset(self.init_options.file.temporary_layer.pixels(), .{ 0, 0, 0, 0 });

    if (self.hovered() != null) {
        self.processKeybinds();
        self.processFill();
        self.processStroke();
        self.processSample();
    }

    // Draw layers first, so that the scrolling bounding box is updated
    self.drawLayers();

    self.processSpriteSelection();

    // Draw shadows for the scroll container
    pixi.dvui.drawEdgeShadow(self.init_options.canvas.scroll_container.data().rectScale(), .top, .{});
    pixi.dvui.drawEdgeShadow(self.init_options.canvas.scroll_container.data().rectScale(), .bottom, .{ .opacity = 0.2 });
    pixi.dvui.drawEdgeShadow(self.init_options.canvas.scroll_container.data().rectScale(), .left, .{});
    pixi.dvui.drawEdgeShadow(self.init_options.canvas.scroll_container.data().rectScale(), .right, .{ .opacity = 0.2 });

    // Only process draw cursor on the hovered widget
    if (self.hovered() != null) {
        self.drawCursor();
        self.drawSample();
    }

    // Then process the scroll and zoom events last
    self.init_options.canvas.processEvents();
}

pub fn deinit(self: *FileWidget) void {
    defer dvui.widgetFree(self);

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
