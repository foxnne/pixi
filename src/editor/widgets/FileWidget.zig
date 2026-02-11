const std = @import("std");
const math = std.math;
const dvui = @import("dvui");
const pixi = @import("../../pixi.zig");
const builtin = @import("builtin");

const Options = dvui.Options;
const Rect = dvui.Rect;
const Point = dvui.Point;

const BoxWidget = dvui.BoxWidget;
const ButtonWidget = dvui.ButtonWidget;
const ScrollAreaWidget = dvui.ScrollAreaWidget;
const ScrollContainerWidget = dvui.ScrollContainerWidget;
const ScaleWidget = dvui.ScaleWidget;

pub const FileWidget = @This();
const CanvasWidget = @import("CanvasWidget.zig");
const icons = @import("icons");

init_options: InitOptions,
options: Options,
drag_data_point: ?dvui.Point = null,
sample_data_point: ?dvui.Point = null,
resize_data_point: ?dvui.Point = null,
previous_mods: dvui.enums.Mod = .none,
left_mouse_down: bool = false,
right_mouse_down: bool = false,
sample_key_down: bool = false,
shift_key_down: bool = false,
hide_distance_bubble: bool = false,
hovered_bubble_sprite_index: ?usize = null,

pub const InitOptions = struct {
    file: *pixi.Internal.File,
    center: bool = false,
};

pub const temp_ms: u32 = 1000; // Default 1 second

pub fn init(src: std.builtin.SourceLocation, init_opts: InitOptions, opts: Options) FileWidget {
    const fw: FileWidget = .{
        .init_options = init_opts,
        .options = opts,
        .drag_data_point = if (dvui.dataGet(null, init_opts.file.editor.canvas.id, "drag_data_point", dvui.Point)) |point| point else null,
        .sample_data_point = if (dvui.dataGet(null, init_opts.file.editor.canvas.id, "sample_data_point", dvui.Point)) |point| point else null,
        .sample_key_down = if (dvui.dataGet(null, init_opts.file.editor.canvas.id, "sample_key_down", bool)) |key| key else false,
        .resize_data_point = if (dvui.dataGet(null, init_opts.file.editor.canvas.id, "resize_data_point", dvui.Point)) |point| point else null,
        .right_mouse_down = if (dvui.dataGet(null, init_opts.file.editor.canvas.id, "right_mouse_down", bool)) |key| key else false,
        .left_mouse_down = if (dvui.dataGet(null, init_opts.file.editor.canvas.id, "left_mouse_down", bool)) |key| key else false,
        .hide_distance_bubble = if (dvui.dataGet(null, init_opts.file.editor.canvas.id, "hide_distance_bubble", bool)) |key| key else false,
    };

    init_opts.file.editor.canvas.install(src, .{
        .id = init_opts.file.editor.canvas.id,
        .data_size = .{
            .w = @floatFromInt(init_opts.file.width()),
            .h = @floatFromInt(init_opts.file.height()),
        },
        .center = init_opts.center,
    }, opts);

    return fw;
}

pub fn processSample(self: *FileWidget) void {
    const file = self.init_options.file;

    const current_mods = dvui.currentWindow().modifiers;

    if (current_mods.matchBind("ctrl/cmd") and !self.previous_mods.matchBind("ctrl/cmd") and (self.right_mouse_down or self.sample_key_down)) {
        const current_point = self.init_options.file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt);
        self.sample(file, current_point, true, true);
    }

    if (current_mods.matchBind("sample") and !self.previous_mods.matchBind("sample")) {
        self.sample_key_down = true;
        const current_point = self.init_options.file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt);
        self.sample(file, current_point, self.right_mouse_down or self.left_mouse_down, false);
    } else if (!current_mods.matchBind("sample") and self.sample_key_down) {
        self.sample_key_down = false;
        if (!self.right_mouse_down) {
            self.sample_data_point = null;
        }
    }

    for (dvui.events()) |*e| {
        switch (e.evt) {
            .mouse => |me| {
                if (!self.init_options.file.editor.canvas.scroll_container.matchEvent(e)) {
                    continue;
                }
                const current_point = self.init_options.file.editor.canvas.dataFromScreenPoint(me.p);

                if (me.action == .press and me.button.pointer()) {
                    dvui.refresh(null, @src(), self.init_options.file.editor.canvas.scroll_container.data().id);
                    self.left_mouse_down = true;
                    if (dvui.dragging(me.p, "sample_drag")) |_| {
                        self.sample(file, current_point, true, false);
                    }
                } else if (me.action == .release and me.button.pointer()) {
                    dvui.refresh(null, @src(), self.init_options.file.editor.canvas.scroll_container.data().id);
                    self.left_mouse_down = false;
                }

                if (me.action == .press and me.button == .right) {
                    dvui.refresh(null, @src(), self.init_options.file.editor.canvas.scroll_container.data().id);
                    self.right_mouse_down = true;
                    e.handle(@src(), self.init_options.file.editor.canvas.scroll_container.data());
                    dvui.captureMouse(self.init_options.file.editor.canvas.scroll_container.data(), e.num);
                    dvui.dragPreStart(me.p, .{ .name = "sample_drag" });
                    self.drag_data_point = current_point;

                    self.sample(file, current_point, self.sample_key_down or self.left_mouse_down, false);

                    @memset(file.editor.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
                    file.editor.temporary_layer.invalidate();
                    file.editor.temporary_layer.dirty = false;
                } else if (me.action == .release and me.button == .right) {
                    dvui.refresh(null, @src(), self.init_options.file.editor.canvas.scroll_container.data().id);
                    self.right_mouse_down = false;
                    self.sample(file, current_point, self.sample_key_down or self.left_mouse_down, true);
                    if (dvui.captured(self.init_options.file.editor.canvas.scroll_container.data().id)) {
                        e.handle(@src(), self.init_options.file.editor.canvas.scroll_container.data());
                        dvui.captureMouse(null, e.num);
                        dvui.dragEnd();

                        if (!self.sample_key_down) {
                            self.drag_data_point = null;
                            self.sample_data_point = null;
                        }
                    }
                } else if (me.action == .motion or me.action == .wheel_x or me.action == .wheel_y) {
                    if (dvui.captured(self.init_options.file.editor.canvas.scroll_container.data().id)) {
                        if (dvui.dragging(me.p, "sample_drag")) |diff| {
                            const previous_point = current_point.plus(self.init_options.file.editor.canvas.dataFromScreenPoint(diff));
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

                            const screen_rect = self.init_options.file.editor.canvas.screenFromDataRect(span_rect);

                            dvui.scrollDrag(.{
                                .mouse_pt = me.p,
                                .screen_rect = screen_rect,
                            });

                            self.sample(file, current_point, self.sample_key_down or self.left_mouse_down or current_mods.matchBind("ctrl/cmd"), false);
                            e.handle(@src(), self.init_options.file.editor.canvas.scroll_container.data());
                        }
                    } else if (self.right_mouse_down or self.sample_key_down) {
                        self.sample(file, current_point, self.right_mouse_down and (self.sample_key_down or self.left_mouse_down or current_mods.matchBind("ctrl/cmd")), false);
                    }
                }
            },
            else => {},
        }
    }
}

fn sample(self: *FileWidget, file: *pixi.Internal.File, point: dvui.Point, change_layer: bool, change_tool: bool) void {
    self.sample_data_point = point;
    var color: [4]u8 = .{ 0, 0, 0, 0 };

    var min_layer_index: usize = 0;

    if (file.editor.isolate_layer) {
        if (file.peek_layer_index) |peek_layer_index| {
            min_layer_index = peek_layer_index;
        } else if (!pixi.editor.explorer.tools.layersHovered()) {
            min_layer_index = file.selected_layer_index;
        }
    }

    var layer_index: usize = file.layers.len;
    while (layer_index > min_layer_index) {
        layer_index -= 1;
        var layer = file.layers.get(layer_index);
        if (!layer.visible) continue;
        if (layer.pixelIndex(point)) |index| {
            const c = layer.pixels()[index];
            if (c[3] > 0) {
                color = c;
                if (change_layer and !file.editor.isolate_layer) {
                    file.selected_layer_index = layer_index;
                    file.peek_layer_index = layer_index;
                }
            }
        }
    }

    if (change_tool) {
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
}

/// Responsible for changing the currently selected animation index, the animation frame index, and the animations scroll to index
/// when the user clicks on a sprite that is part of an animation.
///
/// This is not restricted to any pane or tool, and will change on hover for any tool except the pointer tool.
pub fn processAnimationSelection(self: *FileWidget) void {
    const file = self.init_options.file;
    for (dvui.events()) |*e| {
        if (!self.init_options.file.editor.canvas.scroll_container.matchEvent(e)) {
            continue;
        }

        switch (e.evt) {
            .mouse => |me| {
                if ((me.button.pointer() and me.action == .press and !me.mod.matchBind("ctrl/cmd") and !me.mod.matchBind("shift")) or (pixi.editor.tools.current != .pointer and self.sample_data_point == null)) {
                    if (file.spriteIndex(self.init_options.file.editor.canvas.dataFromScreenPoint(me.p))) |sprite_index| {
                        var found: bool = false;
                        for (file.animations.items(.frames), 0..) |frames, anim_index| {
                            for (frames, 0..) |frame, frame_index| {
                                if (frame.sprite_index == sprite_index) {
                                    file.selected_animation_index = anim_index;
                                    file.editor.animations_scroll_to_index = anim_index;

                                    if (!file.editor.playing)
                                        file.selected_animation_frame_index = frame_index;

                                    found = true;
                                    break;
                                }
                                if (found) break;
                            }
                            if (found) break;
                        }
                    }
                }
            },
            else => {},
        }
    }
}

/// Responsible for handling rough/broad sprite selection (grid tiles)
/// Sprites can only be selected with the pointer tool.
///
/// Supports add/remove, drag selection, etc.
pub fn processSpriteSelection(self: *FileWidget) void {
    if (pixi.editor.tools.current != .pointer) return;
    if (self.init_options.file.editor.transform != null) return;
    if (self.sample_data_point != null) return;

    const file = self.init_options.file;

    for (dvui.events()) |*e| {
        if (!self.init_options.file.editor.canvas.scroll_container.matchEvent(e)) {
            continue;
        }

        switch (e.evt) {
            .key => |ke| {
                if (ke.mod.matchBind("shift")) {
                    switch (ke.action) {
                        .down, .repeat => {
                            self.shift_key_down = true;
                        },
                        .up => {
                            self.shift_key_down = false;
                        },
                    }
                }
            },
            .mouse => |me| {
                const current_point = self.init_options.file.editor.canvas.dataFromScreenPoint(me.p);

                if (me.action == .press and me.button.pointer()) {
                    if (me.mod.matchBind("shift")) {
                        self.shift_key_down = true;
                        if (file.spriteIndex(self.init_options.file.editor.canvas.dataFromScreenPoint(me.p))) |sprite_index| {
                            file.editor.selected_sprites.unset(sprite_index);
                        }
                    } else if (me.mod.matchBind("ctrl/cmd")) {
                        if (file.spriteIndex(self.init_options.file.editor.canvas.dataFromScreenPoint(me.p))) |sprite_index| {
                            file.editor.selected_sprites.set(sprite_index);
                        }
                    } else {
                        if (file.spriteIndex(self.init_options.file.editor.canvas.dataFromScreenPoint(me.p))) |sprite_index| {
                            const selected = file.editor.selected_sprites.isSet(sprite_index);
                            file.clearSelectedSprites();

                            if (!selected) {
                                file.editor.selected_sprites.set(sprite_index);
                            }
                        } else if (!file.editor.canvas.hovered) {
                            pixi.editor.cancel() catch {
                                dvui.log.err("Failed to cancel", .{});
                            };
                        }
                    }

                    e.handle(@src(), self.init_options.file.editor.canvas.scroll_container.data());
                    dvui.captureMouse(self.init_options.file.editor.canvas.scroll_container.data(), e.num);
                    dvui.dragPreStart(me.p, .{ .name = "sprite_selection_drag" });

                    self.drag_data_point = current_point;
                } else if (me.action == .release and me.button.pointer()) {
                    if (dvui.captured(self.init_options.file.editor.canvas.scroll_container.data().id)) {
                        e.handle(@src(), self.init_options.file.editor.canvas.scroll_container.data());
                        dvui.captureMouse(null, e.num);
                        dvui.dragEnd();
                        dvui.refresh(null, @src(), self.init_options.file.editor.canvas.scroll_container.data().id);
                    }
                    self.drag_data_point = null;
                } else if (me.action == .motion or me.action == .wheel_x or me.action == .wheel_y) {
                    if (dvui.captured(self.init_options.file.editor.canvas.scroll_container.data().id)) {
                        if (dvui.dragging(me.p, "sprite_selection_drag")) |_| {
                            if (self.drag_data_point) |previous_point| {
                                e.handle(@src(), self.init_options.file.editor.canvas.scroll_container.data());
                                const min_x = @min(previous_point.x, current_point.x);
                                const min_y = @min(previous_point.y, current_point.y);
                                const max_x = @max(previous_point.x, current_point.x);
                                const max_y = @max(previous_point.y, current_point.y);
                                const span_rect = dvui.Rect{
                                    .x = min_x,
                                    .y = min_y,
                                    .w = @max(max_x - min_x, 1),
                                    .h = @max(max_y - min_y, 1),
                                };

                                const screen_selection_rect = self.init_options.file.editor.canvas.screenFromDataRect(span_rect);

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
                                    self.shift_key_down = false;
                                } else {
                                    self.shift_key_down = false;
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

/// Responsible for drawing the indicators for animation frames as bubbles over each sprite.
///
/// Bubbles contain a button that acts as a toggle for adding/removing a sprite from an animation.
/// When using the pointer tool, bubbles will be drawn based on distance from the mouse location, as well as the currently selected animation frames.
/// When using other tools, bubbles will be drawn based on the currently selected animation frames.
///
/// Bubbles use a elastic animation, and also display the currently viewed animation frame in the panel.
pub fn drawSpriteBubbles(self: *FileWidget) void {
    if (self.init_options.file.editor.transform != null) return;
    if (self.resize_data_point != null) return;

    var sprite_index: usize = self.init_options.file.spriteCount();

    const animation_id = self.init_options.file.editor.canvas.scroll_container.data().id;

    { // Create animations for closing or opening bubbles

        if ((dvui.dragName("sprite_selection_drag") or
            (pixi.editor.tools.current != .pointer) or
            (dvui.currentWindow().modifiers.matchBind("shift") or dvui.currentWindow().modifiers.matchBind("ctrl/cmd"))) or
            pixi.editor.tools.radial_menu.visible or
            self.init_options.file.editor.transform != null or
            self.sample_data_point != null)
        {
            if (dvui.animationGet(animation_id, "bubble_close")) |anim| {
                if (anim.done()) {
                    self.hide_distance_bubble = true;
                }
            } else if (dvui.animationGet(animation_id, "bubble_open")) |_| {
                _ = dvui.currentWindow().animations.remove(animation_id.update("bubble_open"));
                dvui.animation(animation_id, "bubble_close", .{
                    .easing = dvui.easing.outQuint,
                    .end_time = 200_000,
                    .start_val = 1.0,
                    .end_val = 0.0,
                });
            } else if (!self.hide_distance_bubble) {
                dvui.animation(animation_id, "bubble_close", .{
                    .easing = dvui.easing.outQuint,
                    .end_time = 200_000,
                    .start_val = 1.0,
                    .end_val = 0.0,
                });
            }
        } else {
            if (dvui.animationGet(animation_id, "bubble_open")) |anim| {
                if (anim.done()) {
                    self.hide_distance_bubble = false;
                }
            } else if (dvui.animationGet(animation_id, "bubble_close")) |_| {
                _ = dvui.currentWindow().animations.remove(animation_id.update("bubble_close"));

                dvui.animation(animation_id, "bubble_open", .{
                    .easing = dvui.easing.outElastic,
                    .end_time = 900_000,
                    .start_val = 0.0,
                    .end_val = 1.0,
                });
            } else if (self.hide_distance_bubble) {
                dvui.animation(animation_id, "bubble_open", .{
                    .easing = dvui.easing.outElastic,
                    .end_time = 900_000,
                    .start_val = 0.0,
                    .end_val = 1.0,
                });
            }
        }
    }

    var shadow_drawn: bool = false;
    var bubble_drawn: bool = false;
    while (!shadow_drawn or !bubble_drawn) {
        defer {
            if (!shadow_drawn) {
                shadow_drawn = true;
            } else {
                bubble_drawn = true;
            }
            sprite_index = self.init_options.file.spriteCount();
        }

        while (sprite_index > 0) {
            sprite_index -= 1;

            //index -= 1;

            const sprite_rect = self.init_options.file.spriteRect(sprite_index);

            // Set the default bubble color, which will be the highlight color
            var color = dvui.themeGet().color(.control, .fill_hover);

            var automatic_animation: bool = false;
            var automatic_animation_frame_i: usize = 0;

            var animation_index: ?usize = null;

            // First, search through the frames of the selected animation to see if our current sprite is in it
            if (self.init_options.file.selected_animation_index) |selected_animation_index| {
                for (self.init_options.file.animations.items(.frames)[selected_animation_index], 0..) |frame, i| {
                    if (frame.sprite_index == sprite_index) {
                        automatic_animation_frame_i = i;
                        animation_index = selected_animation_index;
                        break;
                    }
                }
            }

            // If we didn't find the sprite in the selected animation, search through all animations
            if (animation_index == null) {
                anim_blk: for (self.init_options.file.animations.items(.frames), 0..) |frames, i| {
                    for (frames, 0..) |frame, j| {
                        if (frame.sprite_index == sprite_index) {
                            automatic_animation_frame_i = j;
                            animation_index = i;
                            break :anim_blk;
                        }
                    }
                }
            }

            if (animation_index) |ai| {
                const id = self.init_options.file.animations.get(ai).id;

                // If we have a sprite thats part of an animation, bubble color needs to come from the animation color
                if (pixi.editor.colors.file_tree_palette) |*palette| {
                    color = palette.getDVUIColor(id);
                }

                // If the current animation is the selected animation, set the automatic animation flag
                if (self.init_options.file.selected_animation_index == ai) {
                    automatic_animation = true;
                }
            }

            if (self.init_options.file.editor.selected_sprites.count() > 0) {
                if (self.init_options.file.editor.selected_sprites.isSet(sprite_index)) {
                    automatic_animation = true;

                    if (animation_index) |ai| {
                        if (ai != self.init_options.file.selected_animation_index) {
                            color = dvui.themeGet().color(.control, .fill_hover);
                        }
                    }
                }
            }

            const peek: bool = if (dvui.dragName("sprite_selection_drag") or
                (dvui.currentWindow().modifiers.matchBind("shift") or dvui.currentWindow().modifiers.matchBind("ctrl/cmd")) or
                pixi.editor.tools.current != .pointer or
                self.sample_data_point != null)
                true
            else
                false;

            if (automatic_animation) {
                const total_duration: i32 = 1_500_000;
                const max_step_duration: i32 = @divTrunc(total_duration, 3);

                var duration_step = max_step_duration;

                if (animation_index) |ai| {
                    duration_step = std.math.clamp(@divTrunc(total_duration, @as(i32, @intCast(self.init_options.file.animations.get(ai).frames.len))), 0, max_step_duration);
                }

                const duration = max_step_duration + (duration_step * @as(i32, @intCast(automatic_animation_frame_i + 1)));

                var open: bool = true;
                var id_extra: usize = sprite_index;

                if (animation_index) |ai| {
                    id_extra = dvui.Id.extendId(@enumFromInt(sprite_index), @src(), ai).asUsize();
                }

                {
                    const current_point = self.init_options.file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt);

                    const max_distance: f32 = if (peek) @max(sprite_rect.h, sprite_rect.w) * 1.5 else @max(sprite_rect.h, sprite_rect.w) * 1.5;

                    const dx = @abs(current_point.x - (sprite_rect.x + sprite_rect.w * 0.5));
                    const dy = @abs(current_point.y - (sprite_rect.y) + sprite_rect.h * 0.5);
                    const distance = @sqrt(dx * dx + dy * dy);

                    if (distance < max_distance and peek and current_point.y - sprite_rect.y < 0.0 and current_point.y - sprite_rect.y > -sprite_rect.h) {
                        open = false;
                        id_extra = dvui.Id.update(@enumFromInt(id_extra), "peek").asUsize();
                    } else {
                        id_extra = dvui.Id.update(@enumFromInt(id_extra), "unpeek").asUsize();
                    }
                }

                if (shadow_drawn) {
                    id_extra = dvui.Id.update(@enumFromInt(id_extra), "shadow").asUsize();
                } else {
                    id_extra = dvui.Id.update(@enumFromInt(id_extra), "bubble").asUsize();
                }

                var t: f32 = 0.0;

                const anim = dvui.animate(@src(), .{
                    .duration = if (open) duration else @divTrunc(duration, 4),
                    .kind = .vertical,
                    .easing = if (open) dvui.easing.outElastic else dvui.easing.outQuint,
                }, .{
                    .id_extra = id_extra,
                });
                defer anim.deinit();

                t = if (open) anim.val orelse 1.0 else std.math.clamp(1.0 - (anim.val orelse 1.0), 0.0, 2.0);

                if (drawSpriteBubble(self, sprite_index, t, color, animation_index, !shadow_drawn)) {
                    self.hovered_bubble_sprite_index = sprite_index;
                }
            } else {
                // Only draw bubbles over sprites that are part of the selected sprites if there is a selection
                if (self.init_options.file.editor.selected_sprites.count() > 0) {
                    if ((!self.init_options.file.editor.selected_sprites.isSet(sprite_index) or (animation_index != self.init_options.file.selected_animation_index and !self.init_options.file.editor.selected_sprites.isSet(sprite_index)))) {
                        continue;
                    }
                }

                const current_point = self.init_options.file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt);

                var max_distance: f32 = sprite_rect.h * 1.2;

                if (dvui.animationGet(animation_id, "bubble_open")) |anim| {
                    max_distance += (max_distance * 0.5) * (1.0 - anim.value());
                } else if (dvui.animationGet(animation_id, "bubble_close")) |anim| {
                    max_distance += (max_distance * 0.5) * (1.0 - anim.value());
                } else {
                    max_distance += (max_distance * 0.5) * if (!self.hide_distance_bubble) @as(f32, 0.0) else @as(f32, 1.0);
                }

                const dx = @abs(current_point.x - (sprite_rect.x + sprite_rect.w * 0.5));
                const dy = @abs(current_point.y - (sprite_rect.y - sprite_rect.h * 0.25));
                const distance = @sqrt((dx * dx) * 0.5 + (dy * dy) * 2.0);

                if (distance < (max_distance * 2.0)) {
                    var t: f32 = distance / max_distance;

                    if (dvui.animationGet(animation_id, "bubble_open")) |anim| {
                        t = (1.0 - t) * anim.value();
                    } else if (dvui.animationGet(animation_id, "bubble_close")) |anim| {
                        t = (1.0 - t) * anim.value();
                    } else {
                        t = (1.0 - t) * if (self.hide_distance_bubble) @as(f32, 0.0) else @as(f32, 1.0);
                    }

                    t = std.math.clamp(t, 0.0, 2.0);

                    if (drawSpriteBubble(
                        self,
                        sprite_index,
                        t,
                        dvui.themeGet().color(.window, .fill).lerp(color, 1.0 - (distance / (max_distance * 2.0))),
                        animation_index,
                        !shadow_drawn,
                    )) {
                        self.hovered_bubble_sprite_index = sprite_index;
                    }
                }
            }
        }
    }
}

/// Draw a single sprite bubble based on sprite index and progress. Animation index just lets us know if not null, its part of an animation,
/// and if its equal to the currently selected animation index, we need to draw a checkmark in the bubble because its part of the currently selected animation.
pub fn drawSpriteBubble(self: *FileWidget, sprite_index: usize, progress: f32, color: dvui.Color, animation_index: ?usize, shadow_only: bool) bool {

    // Would this sprite be removed if the user clicked the button?
    var remove: bool = false;
    if (self.init_options.file.selected_animation_index) |anim_index| {
        const anim = self.init_options.file.animations.get(anim_index);
        for (anim.frames) |frame| {
            if (frame.sprite_index == sprite_index) {
                remove = true;
            }
        }
    }

    //if (sprite_index != 0) return;
    const t = progress;
    const fill_color: dvui.Color = dvui.themeGet().color(.control, .fill);

    const sprite_rect = self.init_options.file.spriteRect(sprite_index);

    const target_button_height: f32 = 24.0;
    // Figure out artwork's baseline size (width or height, whichever is smaller)
    const baseline_sprite_size: f32 = 64.0;
    const min_sprite_size: f32 = @min(sprite_rect.w, sprite_rect.h);
    const baseline_scale: f32 = baseline_sprite_size / min_sprite_size;
    // Compensate the button size so that it stays visually consistent even if the tile is smaller/larger than 64x64
    var button_height = std.math.clamp((target_button_height * dvui.easing.outBack(t) / self.init_options.file.editor.canvas.scale), 0.0, min_sprite_size / 3.0);

    const sprite_rect_scale: dvui.RectScale = .{
        .r = self.init_options.file.editor.canvas.screenFromDataRect(sprite_rect),
        .s = self.init_options.file.editor.canvas.scale,
    };

    var bubble_max_height: f32 = @min(sprite_rect.h, sprite_rect.w) * 0.5;

    if (self.init_options.file.selected_animation_index) |ai| {
        if (self.init_options.file.selected_animation_frame_index < self.init_options.file.animations.get(ai).frames.len) {
            const animation = self.init_options.file.animations.get(ai);
            if (animation.frames.len > 0) {
                const frame = animation.frames[self.init_options.file.selected_animation_frame_index];
                if (frame.sprite_index != sprite_index and animation_index == ai) {
                    bubble_max_height = @min(sprite_rect.h, sprite_rect.w) * 0.3333;
                }
            }
        }
    }

    const bubble_height = std.math.clamp((bubble_max_height * t / self.init_options.file.editor.canvas.scale) * baseline_scale, 0.0, bubble_max_height * t);
    const bubble_rect = dvui.Rect{
        .x = sprite_rect.x,
        .y = sprite_rect.y - bubble_height,
        .w = sprite_rect.w,
        .h = bubble_height,
    };

    var bubble_rect_scale: dvui.RectScale = .{
        .r = self.init_options.file.editor.canvas.screenFromDataRect(bubble_rect),
        .s = self.init_options.file.editor.canvas.scale,
    };

    var path = dvui.Path.Builder.init(dvui.currentWindow().lifo());

    const center = bubble_rect.center();

    const animation_id = self.init_options.file.editor.canvas.scroll_container.data().id;

    // Choose a font size that fits scaled to button size.
    const font = dvui.Font.theme(.mono).larger(-3.0);

    const sprite_label = self.init_options.file.fmtSprite(dvui.currentWindow().arena(), sprite_index, .grid) catch {
        dvui.log.err("Failed to format sprite index", .{});
        return false;
    };

    const text_size = font.textSize(sprite_label);

    var button_width = @max(button_height, (text_size.w + 4.0) / self.init_options.file.editor.canvas.scale);

    if (dvui.animationGet(animation_id, "bubble_close")) |anim| {
        button_height *= anim.value();
        button_width *= anim.value();
    } else if (dvui.animationGet(animation_id, "bubble_open")) |anim| {
        button_height *= anim.value();
        button_width *= anim.value();
    } else if (pixi.editor.tools.current != .pointer or self.hide_distance_bubble) {
        button_height = 0.0;
        button_width = 0.0;
    }

    const button_rect = dvui.Rect{ .x = center.x - button_width / 2, .y = center.y - (button_height / 2), .w = button_width, .h = button_height };

    if (bubble_rect_scale.r.h <= dvui.currentWindow().natural_scale) {
        path.addPoint(bubble_rect_scale.r.topRight());
        path.addPoint(bubble_rect_scale.r.topLeft());

        path.build().stroke(.{ .thickness = dvui.currentWindow().natural_scale, .color = color });
    } else {
        const arc_height = std.math.clamp(
            bubble_rect_scale.r.h,
            dvui.currentWindow().natural_scale,
            @min(sprite_rect_scale.r.h, sprite_rect_scale.r.w) * 0.5 - dvui.currentWindow().natural_scale,
        );

        const d = bubble_rect_scale.r.w / 2;

        const radius: f32 = (d * d + arc_height * arc_height) / (2 * arc_height);

        const center_x: f32 = sprite_rect_scale.r.x + (sprite_rect_scale.r.w / 2);

        const arc_center: dvui.Point.Physical = .{ .x = center_x, .y = sprite_rect_scale.r.y + radius - arc_height };

        const end_angle: f32 = std.math.atan2(arc_center.y - sprite_rect_scale.r.topLeft().y, arc_center.x - sprite_rect_scale.r.topLeft().x);
        const start_angle: f32 = std.math.atan2(arc_center.y - sprite_rect_scale.r.topRight().y, arc_center.x - sprite_rect_scale.r.topRight().x);

        path.addArc(arc_center, radius, dvui.math.pi + start_angle, dvui.math.pi + end_angle, false);

        var built = path.build();
        defer path.deinit();

        var draw_transparency: bool = false;
        draw_transparency = sprite_rect_scale.r.contains(dvui.currentWindow().mouse_pt) and self.hovered();

        if (!draw_transparency) {
            if (self.init_options.file.editor.selected_sprites.findLastSet()) |last| {
                draw_transparency = last == sprite_index;
            } else if (self.init_options.file.selected_animation_index) |ai| {
                if (self.init_options.file.selected_animation_frame_index < self.init_options.file.animations.get(ai).frames.len) {
                    draw_transparency = self.init_options.file.animations.get(ai).frames[self.init_options.file.selected_animation_frame_index].sprite_index == sprite_index;
                }
            }
        }

        if (shadow_only) { // Draw drop shadow
            const shadow_fade = arc_height * 0.66 * dvui.easing.outExpo(t);
            const clip = dvui.clip(bubble_rect_scale.r.outset(.{
                .x = shadow_fade,
                .y = shadow_fade,
                .w = shadow_fade,
            }).offsetPoint(.{
                .x = 0.0,
                .y = -dvui.currentWindow().natural_scale,
            }));
            defer dvui.clipSet(clip);

            const shadow_color = dvui.Color.black.opacity(0.20);
            var shadow_path = dvui.Path.Builder.init(dvui.currentWindow().arena());
            shadow_path.addArc(arc_center.plus(.{ .x = 0.0, .y = 0.0 }), radius, dvui.math.pi + start_angle, dvui.math.pi + end_angle, false);
            shadow_path.build().fillConvex(.{ .color = shadow_color, .fade = shadow_fade });

            const mouse_data_pt = self.init_options.file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt);

            return button_rect.contains(mouse_data_pt);
        }

        if (draw_transparency) {
            if (self.init_options.file.editor.canvas.scale < 0.1) {
                built.fillConvex(.{ .color = fill_color, .fade = 3.0 });
            } else {
                built.fillConvex(.{ .color = fill_color, .fade = 0.0 });
                var triangles = built.fillConvexTriangles(dvui.currentWindow().arena(), .{ .color = fill_color.lighten(4.0).opacity(0.5), .fade = 0.0 }) catch {
                    dvui.log.err("Failed to fill convex triangles", .{});
                    return false;
                };

                const h = arc_height / sprite_rect_scale.r.h;

                const uv_rect = dvui.Rect{
                    .x = 0.0,
                    .w = 1.0,
                    .y = 1.0 - h,
                    .h = h, // adjust so text stays fixed on screen regardless of scale
                };
                triangles.uvFromRectuv(bubble_rect_scale.r, uv_rect);

                dvui.renderTriangles(triangles, self.init_options.file.editor.checkerboard_tile.getTexture() catch null) catch {
                    dvui.log.err("Failed to render triangles", .{});
                };
            }
        } else {
            dvui.Path.stroke(.{
                .points = &[_]dvui.Point.Physical{
                    bubble_rect_scale.r.bottomLeft(),
                    bubble_rect_scale.r.bottomRight(),
                },
            }, .{
                .color = dvui.themeGet().color(.window, .fill),
                .thickness = 1.0,
            });
            built.fillConvex(.{ .color = dvui.themeGet().color(.window, .fill), .fade = 3.0 });
        }
        // Draw bubble outline
        built.stroke(.{ .color = color, .thickness = dvui.currentWindow().natural_scale });

        // Dont draw any buttons if the button is too small or too large.
        if (button_rect.w > bubble_rect.w * 0.666 or button_rect.w < bubble_rect.w * 0.001) return false;

        var add_rem_message: ?[]const u8 = null;

        var border_color = dvui.themeGet().color(.control, .fill_hover);
        if (pixi.editor.colors.file_tree_palette) |*palette| {
            if (self.init_options.file.selected_animation_index) |index| {
                border_color = palette.getDVUIColor(self.init_options.file.animations.get(index).id);
                add_rem_message = std.fmt.allocPrint(dvui.currentWindow().arena(), "{s}", .{self.init_options.file.animations.get(index).name}) catch {
                    dvui.log.err("Failed to allocate add/remove message", .{});
                    return false;
                };
            } else {
                add_rem_message = std.fmt.allocPrint(dvui.currentWindow().arena(), "New Animation", .{}) catch {
                    dvui.log.err("Failed to allocate add/remove message", .{});
                    return false;
                };
            }
        }

        var show_hint: bool = false;
        if (self.hovered_bubble_sprite_index) |hovered_button_index| {
            var iter = self.init_options.file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
            while (iter.next()) |selected_index| {
                if (selected_index == sprite_index) {
                    show_hint = true;
                }
            }

            if (self.init_options.file.selected_animation_index) |selected_animation_index| {
                const selected_animation = self.init_options.file.animations.get(selected_animation_index);
                if (selected_animation.frames.len > 0) {
                    var hovered_in_animation: bool = false;
                    for (selected_animation.frames) |frame| {
                        if (frame.sprite_index == hovered_button_index) {
                            hovered_in_animation = true;
                            break;
                        }
                    }

                    var current_in_animation: bool = false;
                    for (selected_animation.frames) |frame| {
                        if (frame.sprite_index == sprite_index) {
                            current_in_animation = true;
                            break;
                        }
                    }

                    if (hovered_in_animation != current_in_animation) {
                        show_hint = false;
                    }
                }
            }

            var found_current_in_selection: bool = false;

            iter = self.init_options.file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
            while (iter.next()) |selected_index| {
                if (selected_index == hovered_button_index) {
                    found_current_in_selection = true;
                }
            }

            if (!found_current_in_selection)
                show_hint = false;
        }

        var button: dvui.ButtonWidget = undefined;
        button.init(@src(), .{
            .draw_focus = false,
        }, .{
            .rect = button_rect,
            .margin = .all(0),
            .padding = .all(0),
            .id_extra = sprite_index,
            .color_fill = dvui.themeGet().color(.control, .fill_hover),
            .color_border = dvui.themeGet().color(.control, .fill_hover),
            .border = dvui.Rect.all(1).scale(1.0 / self.init_options.file.editor.canvas.scale, dvui.Rect),
            .box_shadow = .{
                .color = .black,
                .offset = .{ .x = -0.05 * button_height, .y = 0.08 * button_height },
                .fade = (button_height / 10) * t,
                .alpha = 0.35 * t,
            },
            .corner_radius = dvui.Rect.all(1000000),
            .gravity_x = 0.5,
            .gravity_y = 0.5,
        });
        defer button.deinit();

        button.processEvents();

        if (button.hovered() or show_hint) {
            if (remove) {
                button.data().options.color_border = dvui.themeGet().color(.err, .fill).opacity(0.75);
            } else {
                button.data().options.color_border = dvui.themeGet().color(.highlight, .fill).opacity(0.75);
            }
        }

        button.drawBackground();

        if (button.clicked()) { // Toggle animation frame on or off for this selection/animation
            if (self.init_options.file.selected_animation_index) |anim_index| {
                // TODO: Efficiently resize the animation frames array instead of duplicating it

                var anim = self.init_options.file.animations.get(anim_index);

                var frames = std.array_list.Managed(pixi.Animation.Frame).init(pixi.app.allocator);
                frames.appendSlice(anim.frames) catch {
                    dvui.log.err("Failed to append frames", .{});
                    return false;
                };

                for (frames.items, 0..) |frame, i| {
                    if (frame.sprite_index == sprite_index) {

                        // First remove the currently clicked frame, regardless
                        _ = frames.orderedRemove(i);
                    }
                }

                if (self.init_options.file.editor.selected_sprites.count() > 0) {
                    var in_selection: bool = false;
                    var iter = self.init_options.file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
                    while (iter.next()) |selected_index| {
                        if (selected_index == sprite_index) {
                            in_selection = true;
                            break;
                        }
                    }

                    if (in_selection) {
                        // Remove all selected_sprite_index values from frames, regardless of their position.
                        // To avoid skipping items due to shifting, iterate backward through frames.
                        iter = self.init_options.file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
                        while (iter.next()) |selected_sprite_index| {
                            var j: usize = frames.items.len;
                            while (j > 0) : (j -= 1) {
                                if (frames.items[j - 1].sprite_index == selected_sprite_index) {
                                    _ = frames.orderedRemove(j - 1);
                                }
                            }
                        }
                    }
                }

                if (!remove) {
                    if (self.init_options.file.editor.selected_sprites.count() > 0) {
                        var in_selection: bool = false;

                        var iter = self.init_options.file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
                        while (iter.next()) |selected_index| {
                            if (selected_index == sprite_index) {
                                in_selection = true;
                                break;
                            }
                        }

                        if (in_selection) {
                            iter = self.init_options.file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
                            while (iter.next()) |selected_index| {
                                frames.append(.{ .sprite_index = selected_index, .ms = temp_ms }) catch {
                                    dvui.log.err("Failed to append frame", .{});
                                    return false;
                                };
                            }
                        } else {
                            frames.append(.{ .sprite_index = sprite_index, .ms = temp_ms }) catch {
                                dvui.log.err("Failed to append frame", .{});
                                return false;
                            };
                        }
                    } else {
                        frames.append(.{ .sprite_index = sprite_index, .ms = temp_ms }) catch {
                            dvui.log.err("Failed to append frame", .{});
                            return false;
                        };
                    }
                }

                if (!anim.eqlFrames(frames.items)) {
                    self.init_options.file.history.append(.{
                        .animation_frames = .{
                            .index = anim_index,
                            .frames = pixi.app.allocator.dupe(pixi.Animation.Frame, anim.frames) catch {
                                dvui.log.err("Failed to dupe frames", .{});
                                return false;
                            },
                        },
                    }) catch {
                        dvui.log.err("Failed to append history", .{});
                    };

                    pixi.app.allocator.free(anim.frames);
                    anim.frames = frames.toOwnedSlice() catch {
                        dvui.log.err("Failed to free frames", .{});
                        return false;
                    };

                    self.init_options.file.animations.set(anim_index, anim);
                }
            } else {
                if (self.init_options.file.createAnimation() catch null) |anim_index| {
                    self.init_options.file.selected_animation_index = anim_index;
                    self.init_options.file.editor.animations_scroll_to_index = anim_index;
                    pixi.editor.explorer.sprites.edit_anim_id = self.init_options.file.animations.items(.id)[anim_index];
                    pixi.editor.explorer.pane = .sprites;

                    var anim = self.init_options.file.animations.get(anim_index);
                    if (anim.frames.len == 0) {
                        anim.appendFrame(pixi.app.allocator, .{ .sprite_index = sprite_index, .ms = temp_ms }) catch {
                            dvui.log.err("Failed to append frame", .{});
                            return false;
                        };
                    }
                    self.init_options.file.animations.set(anim_index, anim);

                    self.init_options.file.history.append(.{
                        .animation_restore_delete = .{
                            .action = .delete,
                            .index = anim_index,
                        },
                    }) catch {
                        dvui.log.err("Failed to append history", .{});
                    };
                }
            }
        }

        if (button.data().contentRectScale().r.w > text_size.w) {
            // Determine the rect to draw in
            const btn_rect = button.data().contentRectScale().r;

            const scaled_text_size = text_size.scale(dvui.currentWindow().natural_scale, dvui.Size.Physical);

            const text_rect = dvui.Rect.Physical{
                .x = btn_rect.x + (btn_rect.w - scaled_text_size.w) / 2,
                .y = btn_rect.y + (btn_rect.h - scaled_text_size.h) / 2,
                .w = scaled_text_size.w,
                .h = scaled_text_size.h,
            };

            const color_main = if (button.hovered() or animation_index == self.init_options.file.selected_animation_index) dvui.themeGet().color(.window, .text) else dvui.themeGet().color(.control, .text);

            dvui.renderText(.{
                .text = sprite_label,
                .font = font,
                .color = color_main.opacity(progress),
                .rs = .{ .r = text_rect, .s = dvui.currentWindow().natural_scale },
            }) catch {
                dvui.log.err("Failed to render text", .{});
                return false;
            };

            var icon_rect = button.data().rectScale().r;
            icon_rect.x += icon_rect.w;
            icon_rect.w = icon_rect.w / 2.0;
            icon_rect.h = icon_rect.h / 2.0;
            icon_rect.x = icon_rect.x - icon_rect.w / 1.5;
            icon_rect.y = icon_rect.y - icon_rect.h / 3;

            var fill_rect = icon_rect;
            fill_rect.x += icon_rect.w + (2.0 * dvui.currentWindow().natural_scale);

            // Center fill_rect over the button rect if there is more than one selected sprite.
            if (self.init_options.file.editor.selected_sprites.count() > 1) {
                // Center fill_rect horizontally and vertically over button rect
                fill_rect.x = button.data().rectScale().r.x + (button.data().rectScale().r.w - fill_rect.w) / 2.0;

                fill_rect.y -= fill_rect.h + fill_rect.h / 3;
            }

            if (button.hovered() or show_hint) {
                var icon_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
                    .expand = .none,
                    .rect = button.data().rectScale().rectFromPhysical(icon_rect),
                    .border = dvui.Rect.all(0),
                    .background = true,
                    .corner_radius = dvui.Rect.all(1000000),
                    .box_shadow = .{
                        .color = .black,
                        .offset = .{ .x = -0.05 * button_height, .y = 0.08 * button_height },
                        .fade = (button_height / 10) * t,
                        .alpha = 0.35 * t,
                    },
                    .color_fill = if (remove) dvui.themeGet().color(.err, .fill).opacity(0.75) else dvui.themeGet().color(.highlight, .fill).opacity(0.75),
                });

                dvui.renderIcon("close", if (remove) icons.tvg.lucide.minus else icons.tvg.lucide.plus, .{ .r = icon_box.data().rectScale().r, .s = dvui.currentWindow().natural_scale }, .{}, .{}) catch {
                    dvui.log.err("Failed to render icon", .{});
                    return false;
                };
                icon_box.deinit();

                var message_size: dvui.Size = .{};

                if (add_rem_message) |message| {
                    message_size.w = font.textSize(message).w * dvui.currentWindow().natural_scale;
                    message_size.h = font.textSize(message).h * dvui.currentWindow().natural_scale + 2.0 * dvui.currentWindow().natural_scale;

                    fill_rect.w += message_size.w * 1.5;
                    fill_rect.h = @max(fill_rect.h, message_size.h);
                }
                if (button.hovered()) {
                    if (add_rem_message) |message| {
                        const fill_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
                            .expand = .none,
                            .rect = button.data().rectScale().rectFromPhysical(fill_rect),
                            .border = dvui.Rect.all(0),
                            .background = true,
                            .corner_radius = dvui.Rect.all(1000000),
                            .box_shadow = .{
                                .color = .black,
                                .offset = .{ .x = -0.05 * button_height, .y = 0.08 * button_height },
                                .fade = (button_height / 10) * t,
                                .alpha = 0.35 * t,
                            },
                            .color_fill = if (remove) dvui.themeGet().color(.err, .fill).opacity(0.75) else dvui.themeGet().color(.highlight, .fill).opacity(0.75),
                        });
                        defer fill_box.deinit();

                        var text_box = fill_box.data().contentRectScale().r;
                        text_box.x += (text_box.w - (message_size.w)) / 2.0;
                        text_box.y += (text_box.h - (message_size.h)) / 2.0;

                        dvui.renderText(.{
                            .text = message,
                            .font = font,
                            .color = .white,
                            .rs = .{ .r = text_box, .s = dvui.currentWindow().natural_scale },
                        }) catch {
                            dvui.log.err("Failed to render text", .{});
                        };
                    }
                }
            }
        }
    }

    return false;
}

/// Draw the highlight colored selection box for each selected sprite.
pub fn drawSpriteSelection(self: *FileWidget) void {
    if (pixi.editor.tools.current != .pointer) return;
    if (self.init_options.file.editor.transform != null) return;
    if (self.sample_data_point != null) return;

    if (self.drag_data_point) |previous_point| {
        const current_point = self.init_options.file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt);
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

        const screen_selection_rect = self.init_options.file.editor.canvas.screenFromDataRect(span_rect);
        const selection_color = if (dvui.currentWindow().modifiers.matchBind("shift")) dvui.themeGet().color(.err, .fill).opacity(0.5) else dvui.themeGet().color(.highlight, .fill).opacity(0.5);
        screen_selection_rect.fill(
            dvui.Rect.Physical.all(6 * dvui.currentWindow().natural_scale),
            .{
                .color = selection_color,
            },
        );
    }
}

/// Responsible for processing events to create/modify the current fine-grained selection.
/// This selection is pixel-based, and includes shift/ctrl/cmd modifiers to support add/remove.
/// The selection uses the same logic as the stroke tool to brush the selection over existing pixels.
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
        if (!self.init_options.file.editor.canvas.scroll_container.matchEvent(e)) {
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
                    const current_point = self.init_options.file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt);
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
                const current_point = self.init_options.file.editor.canvas.dataFromScreenPoint(me.p);

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

                if (me.action == .press and me.button.pointer()) {
                    e.handle(@src(), self.init_options.file.editor.canvas.scroll_container.data());
                    dvui.captureMouse(self.init_options.file.editor.canvas.scroll_container.data(), e.num);
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
                    if (dvui.captured(self.init_options.file.editor.canvas.scroll_container.data().id)) {
                        e.handle(@src(), self.init_options.file.editor.canvas.scroll_container.data());
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
                    if (dvui.captured(self.init_options.file.editor.canvas.scroll_container.data().id)) {
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

                                const screen_rect = self.init_options.file.editor.canvas.screenFromDataRect(span_rect);

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

/// Responsible for processing events to modify pixels on the current layer for strokes of various size
/// Supports using shift to draw a line between two points, and increasing/decreasing stroke size
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
        if (!self.init_options.file.editor.canvas.scroll_container.matchEvent(e)) {
            continue;
        }

        switch (e.evt) {
            .mouse => |me| {
                const current_point = self.init_options.file.editor.canvas.dataFromScreenPoint(me.p);

                if (me.action == .press and me.button.pointer()) {
                    e.handle(@src(), self.init_options.file.editor.canvas.scroll_container.data());
                    dvui.captureMouse(self.init_options.file.editor.canvas.scroll_container.data(), e.num);
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
                    if (dvui.captured(self.init_options.file.editor.canvas.scroll_container.data().id)) {
                        e.handle(@src(), self.init_options.file.editor.canvas.scroll_container.data());
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
                            dvui.refresh(null, @src(), self.init_options.file.editor.canvas.scroll_container.data().id);
                        }

                        self.drag_data_point = null;
                    }
                } else if (me.action == .position or me.action == .wheel_x or me.action == .wheel_y) {
                    if (dvui.captured(self.init_options.file.editor.canvas.scroll_container.data().id)) {
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

                                const screen_rect = self.init_options.file.editor.canvas.screenFromDataRect(span_rect);

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

                                if (self.init_options.file.editor.canvas.rect.contains(me.p) and self.sample_data_point == null) {
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

                            //e.handle(@src(), self.init_options.file.editor.canvas.scroll_container.data());
                        }
                    } else {
                        if (self.init_options.file.editor.canvas.rect.contains(me.p) and self.sample_data_point == null) {
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

/// Responsible for processing events to fill pixels on the current layer with a solid color.
/// Supports using ctrl/cmd to replace all existing pixels of the same color with the new color,
/// or without modifiers to flood fill the layer with the new color.
pub fn processFill(self: *FileWidget) void {
    if (pixi.editor.tools.current != .bucket) return;
    if (self.sample_key_down) return;
    const file = self.init_options.file;
    const color = pixi.editor.colors.primary;

    if (self.init_options.file.editor.canvas.rect.contains(dvui.currentWindow().mouse_pt) and self.sample_data_point == null) {
        @memset(file.editor.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
        const temp_color = if (pixi.editor.tools.current != .eraser) color else [_]u8{ 255, 255, 255, 255 };
        file.drawPoint(
            self.init_options.file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt),
            .temporary,
            .{
                .invalidate = true,
                .to_change = false,
                .stroke_size = 1,
                .color = .{ .r = temp_color[0], .g = temp_color[1], .b = temp_color[2], .a = temp_color[3] },
            },
        );
    }

    for (dvui.events()) |*e| {
        if (!self.init_options.file.editor.canvas.scroll_container.matchEvent(e)) {
            continue;
        }

        switch (e.evt) {
            .mouse => |me| {
                const current_point = self.init_options.file.editor.canvas.dataFromScreenPoint(me.p);

                if (me.action == .press and me.button.pointer()) {
                    file.fillPoint(current_point, .selected, .{
                        .color = .{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] },
                        .invalidate = true,
                        .to_change = true,
                        .replace = me.mod.matchBind("ctrl/cmd"),
                    });
                }
            },
            else => {},
        }
    }
}

/// Responsible for processing events to create/modify a transform. A transform is basically a quad with controls on each corner, and
/// allows moving, rotating, skewing and scaling the quad. The controls also include a pivot point for the rotation.
pub fn processTransform(self: *FileWidget) void {
    const file = self.init_options.file;
    const image_rect = dvui.Rect.fromSize(.{ .w = @floatFromInt(file.width()), .h = @floatFromInt(file.height()) });
    const image_rect_physical = dvui.Rect.Physical.fromSize(.{ .w = image_rect.w, .h = image_rect.h });

    if (file.editor.transform) |*transform| {

        // Data path is necessary to build and fill with convex triangles, which will be how we render to the target texture
        var data_path: dvui.Path.Builder = .init(dvui.currentWindow().arena());
        for (transform.data_points[0..4]) |*point| {
            data_path.addPoint(.{ .x = point.x, .y = point.y });
        }

        // Calculate the centroid of the four corner points
        const centroid = transform.centroid();

        var triangle_opts: ?dvui.Triangles = data_path.build().fillConvexTriangles(dvui.currentWindow().arena(), .{
            .center = .{ .x = centroid.x, .y = centroid.y },
            .color = .white,
        }) catch null;

        { // Update the rotate point to locate towards the mouse
            const diff = self.init_options.file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt).diff(transform.point(.pivot).*);
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
                    if (!self.init_options.file.editor.canvas.scroll_container.matchEvent(e)) {
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
                        .key => |ke| {
                            if ((ke.action == .down or ke.action == .repeat) and ke.matchBind("up")) {
                                transform.move(.{ .x = 0, .y = -1 });
                                e.handle(@src(), self.init_options.file.editor.canvas.scroll_container.data());
                                dvui.refresh(null, @src(), self.init_options.file.editor.canvas.scroll_container.data().id);
                            }
                            if ((ke.action == .down or ke.action == .repeat) and ke.matchBind("down")) {
                                transform.move(.{ .x = 0, .y = 1 });
                                e.handle(@src(), self.init_options.file.editor.canvas.scroll_container.data());
                                dvui.refresh(null, @src(), self.init_options.file.editor.canvas.scroll_container.data().id);
                            }
                            if ((ke.action == .down or ke.action == .repeat) and ke.matchBind("left")) {
                                transform.move(.{ .x = -1, .y = 0 });
                                e.handle(@src(), self.init_options.file.editor.canvas.scroll_container.data());
                                dvui.refresh(null, @src(), self.init_options.file.editor.canvas.scroll_container.data().id);
                            }
                            if ((ke.action == .down or ke.action == .repeat) and ke.matchBind("right")) {
                                transform.move(.{ .x = 1, .y = 0 });
                                e.handle(@src(), self.init_options.file.editor.canvas.scroll_container.data());
                                dvui.refresh(null, @src(), self.init_options.file.editor.canvas.scroll_container.data().id);
                            }
                        },
                        .mouse => |me| {
                            const current_point = self.init_options.file.editor.canvas.dataFromScreenPoint(me.p);

                            if (me.action == .press and me.button.pointer()) {
                                if (screen_rect.contains(me.p)) {
                                    transform.active_point = @enumFromInt(point_index);
                                    e.handle(@src(), self.init_options.file.editor.canvas.scroll_container.data());
                                    dvui.captureMouse(self.init_options.file.editor.canvas.scroll_container.data(), e.num);
                                    dvui.dragPreStart(me.p, .{ .name = "transform_vertex_drag" });
                                    self.drag_data_point = current_point;
                                    transform.start_rotation = transform.rotation;
                                }
                            } else if (me.action == .release and me.button.pointer()) {
                                if (dvui.captured(self.init_options.file.editor.canvas.scroll_container.data().id)) {
                                    if (transform.active_point) |active_point| {
                                        if (active_point == .pivot and transform.dragging == false) {
                                            transform.point(.pivot).* = transform.centroid();
                                            transform.updateRadius();
                                        }
                                    }

                                    e.handle(@src(), self.init_options.file.editor.canvas.scroll_container.data());
                                    dvui.captureMouse(null, e.num);
                                    dvui.dragEnd();
                                    transform.active_point = null;
                                    dvui.refresh(null, @src(), self.init_options.file.editor.canvas.scroll_container.data().id);
                                    self.drag_data_point = null;
                                    transform.dragging = false;
                                }
                            } else if (me.action == .motion or me.action == .wheel_x or me.action == .wheel_y) {
                                if (dvui.captured(self.init_options.file.editor.canvas.scroll_container.data().id)) {
                                    if (dvui.dragging(me.p, "transform_vertex_drag")) |_| {
                                        transform.dragging = true;
                                        if (transform.active_point) |active_point| {
                                            if (@intFromEnum(active_point) == point_index) {
                                                e.handle(@src(), self.init_options.file.editor.canvas.scroll_container.data());

                                                // Set this state in advance so we can use it for the radius calculation
                                                transform.track_pivot = active_point == .pivot;

                                                // This is the new data point of the dragged point
                                                var new_point = file.editor.canvas.dataFromScreenPoint(me.p);

                                                // Calculate the radius of the transform no matter what point is changing
                                                defer transform.updateRadius();

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
                    if (!self.init_options.file.editor.canvas.scroll_container.matchEvent(e)) {
                        continue;
                    }

                    var is_hovered: bool = false;

                    if (transform.hovered(file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt))) {
                        dvui.cursorSet(.hand);
                        is_hovered = true;
                    }

                    switch (e.evt) {
                        .mouse => |me| {
                            if (me.action == .press and me.button.pointer()) {
                                //if (is_hovered or me.mod.matchBind("ctrl/cmd")) {
                                e.handle(@src(), self.init_options.file.editor.canvas.scroll_container.data());
                                dvui.captureMouse(self.init_options.file.editor.canvas.scroll_container.data(), e.num);
                                dvui.dragPreStart(me.p, .{ .name = "transform_drag" });
                                //}
                            } else if (me.action == .motion or me.action == .wheel_x or me.action == .wheel_y) {
                                if (dvui.captured(self.init_options.file.editor.canvas.scroll_container.data().id)) {
                                    if (dvui.dragging(me.p, "transform_drag")) |_| {
                                        dvui.cursorSet(.hand);
                                        transform.dragging = true;
                                        e.handle(@src(), self.init_options.file.editor.canvas.scroll_container.data());

                                        var prev_point = file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt_prev);
                                        prev_point.x = @round(prev_point.x);
                                        prev_point.y = @round(prev_point.y);
                                        var new_point = file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt);
                                        new_point.x = @round(new_point.x);
                                        new_point.y = @round(new_point.y);

                                        transform.move(new_point.diff(prev_point));
                                        dvui.refresh(null, @src(), self.init_options.file.editor.canvas.scroll_container.data().id);
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
                dvui.log.err("Failed to create target texture", .{});
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
                dvui.log.err("Failed to render triangles", .{});
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
                dvui.log.err("Failed to read target", .{});
            }
        } else {
            dvui.log.err("Failed to fill triangles", .{});
        }
    }
}

/// Responsible for drawing the transform guides and controls for the current transform after processing.
/// Includes guides for the sprite size and angle in appropriately scaled text labels.
pub fn drawTransform(self: *FileWidget) void {
    const file = self.init_options.file;

    if (file.editor.transform) |*transform| {
        var path = dvui.Path.Builder.init(dvui.currentWindow().arena());
        for (transform.data_points[0..4]) |*point| {
            const screen_point = file.editor.canvas.screenFromDataPoint(point.*);
            path.addPoint(screen_point);
        }

        var centroid = transform.centroid();
        centroid = pixi.math.rotate(centroid, transform.point(.pivot).*, transform.rotation);

        // Draw guides if we are centered
        {
            if (file.spriteIndex(centroid)) |sprite_index| {
                const sprite_rect = file.spriteRect(sprite_index);
                const sprite_center = sprite_rect.center();

                const sprite_diff = sprite_center.diff(centroid);

                if (@floor(sprite_diff.x) == 0) {
                    const point_1: dvui.Point = .{ .x = sprite_center.x, .y = sprite_rect.topLeft().y };
                    const point_2: dvui.Point = .{ .x = sprite_center.x, .y = sprite_rect.bottomRight().y };

                    dvui.Path.stroke(.{ .points = &.{
                        file.editor.canvas.screenFromDataPoint(point_1),
                        file.editor.canvas.screenFromDataPoint(point_2),
                    } }, .{ .thickness = 1, .color = .magenta });
                }

                if (@floor(sprite_diff.y) == 0) {
                    const point_1: dvui.Point = .{ .x = sprite_rect.topLeft().x, .y = sprite_center.y };
                    const point_2: dvui.Point = .{ .x = sprite_rect.bottomRight().x, .y = sprite_center.y };

                    dvui.Path.stroke(.{ .points = &.{
                        file.editor.canvas.screenFromDataPoint(point_1),
                        file.editor.canvas.screenFromDataPoint(point_2),
                    } }, .{ .thickness = 1, .color = .magenta });
                }
            }
        }

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

                                const font = dvui.Font.theme(.mono);
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

                                const font = dvui.Font.theme(.mono);
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

                        const font = dvui.Font.theme(.mono);
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
    if (pixi.editor.tools.current == .pointer and self.sample_data_point == null) return;
    if (pixi.editor.tools.radial_menu.visible) return;
    if (self.init_options.file.editor.transform != null) return;

    var subtract = false;
    var add = false;

    if (self.init_options.file.editor.canvas.hovered) {
        _ = dvui.cursorSet(.hidden);
    }

    for (dvui.events()) |*e| {
        if (!self.init_options.file.editor.canvas.scroll_container.matchEvent(e)) {
            continue;
        }
        switch (e.evt) {
            .key => |ke| {
                if (ke.mod.matchBind("shift")) {
                    subtract = true;
                } else if (ke.mod.matchBind("ctrl/cmd")) {
                    add = true;
                }
            },
            .mouse => |me| {
                if (me.mod.matchBind("shift")) {
                    subtract = true;
                } else if (me.mod.matchBind("ctrl/cmd")) {
                    add = true;
                }
            },
            else => {},
        }
    }

    const data_point = self.init_options.file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt);
    const mouse_point = dvui.currentWindow().mouse_pt;
    if (!self.init_options.file.editor.canvas.rect.contains(mouse_point)) return;
    if (self.sample_data_point != null) return;

    if (switch (pixi.editor.tools.current) {
        .pencil => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.pencil_default],
        .eraser => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.eraser_default],
        .bucket => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.bucket_default],
        .selection => if (subtract) pixi.editor.atlas.data.sprites[pixi.atlas.sprites.selection_rem_default] else if (add) pixi.editor.atlas.data.sprites[pixi.atlas.sprites.selection_add_default] else pixi.editor.atlas.data.sprites[pixi.atlas.sprites.selection_default],
        else => null,
    }) |sprite| {
        const atlas_size = dvui.imageSize(pixi.editor.atlas.source) catch {
            dvui.log.err("Failed to get atlas size", .{});
            return;
        };

        const uv = dvui.Rect{
            .x = (@as(f32, @floatFromInt(sprite.source[0])) / atlas_size.w),
            .y = (@as(f32, @floatFromInt(sprite.source[1])) / atlas_size.h),
            .w = (@as(f32, @floatFromInt(sprite.source[2])) / atlas_size.w),
            .h = (@as(f32, @floatFromInt(sprite.source[3])) / atlas_size.h),
        };

        const origin = dvui.Point{
            .x = sprite.origin[0] * 1 / self.init_options.file.editor.canvas.scale,
            .y = sprite.origin[1] * 1 / self.init_options.file.editor.canvas.scale,
        };

        const position = data_point.diff(origin);

        const box = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .none,
            .rect = .{
                .x = position.x,
                .y = position.y,
                .w = @as(f32, @floatFromInt(sprite.source[2])) * 1 / self.init_options.file.editor.canvas.scale,
                .h = @as(f32, @floatFromInt(sprite.source[3])) * 1 / self.init_options.file.editor.canvas.scale,
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
            dvui.log.err("Failed to render cursor image", .{});
        };
    }
}

pub fn drawSample(self: *FileWidget) void {
    const file = self.init_options.file;
    const point = self.sample_data_point;

    if (point) |data_point| {
        const mouse_point = self.init_options.file.editor.canvas.screenFromDataPoint(data_point);
        if (!self.init_options.file.editor.canvas.rect.contains(mouse_point)) return;

        { // Draw a box around the hovered pixel at the correct scale
            const pixel_box_size = self.init_options.file.editor.canvas.scale * dvui.currentWindow().rectScale().s;

            const pixel_point: dvui.Point = .{
                .x = @round(data_point.x - 0.5),
                .y = @round(data_point.y - 0.5),
            };

            const pixel_box_point = self.init_options.file.editor.canvas.screenFromDataPoint(pixel_point);
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

        // The scale of the enlarged view varies based on the canvas scale
        // When canvas scale is small, we want more magnification
        // When canvas scale is large, we want less magnification
        const enlarged_scale: f32 = self.init_options.file.editor.canvas.scale * (8.0 / (1.0 + self.init_options.file.editor.canvas.scale));

        // The size of the sample box in screen space (constant size)
        const sample_box_size: f32 = 100.0 * 1 / self.init_options.file.editor.canvas.scale; // e.g. 100x80 pixels on screen

        const corner_radius = dvui.Rect{
            .y = 1000000,
            .w = 1000000,
            .h = 1000000,
        };

        // The size of the sample region in data (texture) space
        // This is how many data pixels are shown in the box, so that the box always shows the same number of data pixels at 2x the canvas scale
        const sample_region_size: f32 = sample_box_size / enlarged_scale;

        const border_width = 2 / self.init_options.file.editor.canvas.scale;

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
                .fade = 15 * 1 / self.init_options.file.editor.canvas.scale,
                .corner_radius = .{
                    .x = sample_box_size / 12,
                    .y = sample_box_size / 2,
                    .w = sample_box_size / 2,
                    .h = sample_box_size / 2,
                },
                .alpha = 0.2,
                .offset = .{
                    .x = 2 * 1 / self.init_options.file.editor.canvas.scale,
                    .y = 2 * 1 / self.init_options.file.editor.canvas.scale,
                },
            },
        });
        defer box.deinit();

        // Compute UVs for the region to sample, normalized to [0,1]
        const uv_rect = dvui.Rect{
            .x = (data_point.x - sample_region_size / 2) / @as(f32, @floatFromInt(file.width())),
            .y = (data_point.y - sample_region_size / 2) / @as(f32, @floatFromInt(file.height())),
            .w = sample_region_size / @as(f32, @floatFromInt(file.width())),
            .h = sample_region_size / @as(f32, @floatFromInt(file.height())),
        };

        var rs = box.data().borderRectScale();
        rs.r = rs.r.inset(dvui.Rect.Physical.all(border_width * self.init_options.file.editor.canvas.scale * 2));

        const nat_scale: u32 = @intFromFloat(1.0);

        dvui.renderImage(file.editor.checkerboard_tile, rs, .{
            .colormod = dvui.themeGet().color(.content, .fill).lighten(12.0),
            .uv = .{
                .x = @mod(data_point.x - sample_region_size / 2, @as(f32, @floatFromInt(file.column_width * nat_scale))) / @as(f32, @floatFromInt(file.column_width * nat_scale)),
                .y = @mod(data_point.y - sample_region_size / 2, @as(f32, @floatFromInt(file.row_height * nat_scale))) / @as(f32, @floatFromInt(file.row_height * nat_scale)),
                .w = sample_region_size / @as(f32, @floatFromInt(file.column_width * nat_scale)),
                .h = sample_region_size / @as(f32, @floatFromInt(file.row_height * nat_scale)),
            },
            .corner_radius = .{
                .x = corner_radius.x * rs.s,
                .y = corner_radius.y * rs.s,
                .w = corner_radius.w * rs.s,
                .h = corner_radius.h * rs.s,
            },
        }) catch {
            dvui.log.err("Failed to render checkerboard", .{});
        };

        pixi.render.renderLayers(.{
            .file = file,
            .rs = rs,
            .uv = uv_rect,
            .corner_radius = .{
                .x = corner_radius.x * rs.s,
                .y = corner_radius.y * rs.s,
                .w = corner_radius.w * rs.s,
                .h = corner_radius.h * rs.s,
            },
        }) catch {
            dvui.log.err("Failed to render layers", .{});
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

pub fn updateActiveLayerMask(self: *FileWidget) void {
    var file = self.init_options.file;
    if (file.selected_layer_index >= file.layers.len) return;
    var active_layer = file.layers.get(file.selected_layer_index);

    active_layer.clearMask();
    active_layer.setMaskFromTransparency(true);
}

pub fn drawLayers(self: *FileWidget) void {
    var file = self.init_options.file;
    var columns: usize = file.columns;
    var rows: usize = file.rows;

    const layer_rect = self.init_options.file.editor.canvas.dataFromScreenRect(self.init_options.file.editor.canvas.rect);
    var canvas_rect = layer_rect;

    if (self.resize_data_point) |resize_data_point| {
        canvas_rect.w = resize_data_point.x;
        canvas_rect.h = resize_data_point.y;

        if (resize_data_point.x < layer_rect.x + layer_rect.w or resize_data_point.y < layer_rect.y + layer_rect.h) {
            self.init_options.file.editor.canvas.screenFromDataRect(layer_rect).fill(.all(0), .{ .color = dvui.themeGet().color(.err, .fill).opacity(0.5), .fade = 1.5 });
            // Draw grid lines for the original layer_rect
            for (1..columns) |i| {
                dvui.Path.stroke(.{ .points = &.{
                    self.init_options.file.editor.canvas.screenFromDataPoint(.{ .x = @as(f32, @floatFromInt(i * file.column_width)), .y = 0 }),
                    self.init_options.file.editor.canvas.screenFromDataPoint(.{ .x = @as(f32, @floatFromInt(i * file.column_width)), .y = layer_rect.h }),
                } }, .{ .thickness = 1, .color = dvui.themeGet().color(.window, .fill) });
            }

            for (1..rows) |i| {
                dvui.Path.stroke(.{ .points = &.{
                    self.init_options.file.editor.canvas.screenFromDataPoint(.{ .x = 0, .y = @as(f32, @floatFromInt(i * file.row_height)) }),
                    self.init_options.file.editor.canvas.screenFromDataPoint(.{ .x = layer_rect.w, .y = @as(f32, @floatFromInt(i * file.row_height)) }),
                } }, .{ .thickness = 1, .color = dvui.themeGet().color(.window, .fill) });
            }
        }

        columns = @divTrunc(@as(u32, @intFromFloat(canvas_rect.w)), file.column_width);
        rows = @divTrunc(@as(u32, @intFromFloat(canvas_rect.h)), file.row_height);
    }

    const shadow_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .none,
        .rect = canvas_rect,
        .border = dvui.Rect.all(0),
        .background = false,
        .box_shadow = .{
            .fade = 20 * 1 / self.init_options.file.editor.canvas.scale,
            .corner_radius = dvui.Rect.all(2 * 1 / self.init_options.file.editor.canvas.scale),
            .alpha = 0.2,
            .offset = .{
                .x = 2 * 1 / self.init_options.file.editor.canvas.scale,
                .y = 2 * 1 / self.init_options.file.editor.canvas.scale,
            },
        },
        .color_fill = dvui.themeGet().color(.window, .fill),
    });
    shadow_box.deinit();

    const fill_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .none,
        .rect = .{ .x = layer_rect.x, .y = layer_rect.y, .w = @min(canvas_rect.w, layer_rect.w), .h = @min(canvas_rect.h, layer_rect.h) },
        .border = dvui.Rect.all(0),
        .background = true,
        .color_fill = dvui.themeGet().color(.window, .fill),
    });
    fill_box.deinit();

    const mouse_data_point = self.init_options.file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt);

    if (self.resize_data_point == null) {
        var image_rect_scale: dvui.RectScale = .{};
        if (file.spriteIndex(mouse_data_point)) |sprite_index| {
            const image_rect = file.spriteRect(sprite_index);

            image_rect_scale = .{
                .r = self.init_options.file.editor.canvas.screenFromDataRect(image_rect),
                .s = self.init_options.file.editor.canvas.scale,
            };

            if (self.init_options.file.editor.canvas.scale < 0.1) {
                image_rect_scale.r.fill(.all(0), .{ .color = dvui.themeGet().color(.control, .fill), .fade = 1.5 });
            } else {
                image_rect_scale.r.fill(.all(0), .{ .color = dvui.themeGet().color(.control, .fill), .fade = 1.5 });
                dvui.renderImage(file.editor.checkerboard_tile, image_rect_scale, .{
                    .colormod = dvui.themeGet().color(.control, .fill).lighten(4.0).opacity(0.5),
                }) catch {
                    dvui.log.err("Failed to render checkerboard", .{});
                };
            }
        }

        if (self.init_options.file.editor.selected_sprites.findLastSet()) |last| {
            const image_rect = file.spriteRect(last);

            image_rect_scale = .{
                .r = self.init_options.file.editor.canvas.screenFromDataRect(image_rect),
                .s = self.init_options.file.editor.canvas.scale,
            };
        } else if (self.init_options.file.selected_animation_index) |animation_index| {
            const animation = file.animations.get(animation_index);

            if (file.selected_animation_frame_index < animation.frames.len) {
                const image_rect = file.spriteRect(animation.frames[file.selected_animation_frame_index].sprite_index);

                image_rect_scale = .{
                    .r = self.init_options.file.editor.canvas.screenFromDataRect(image_rect),
                    .s = self.init_options.file.editor.canvas.scale,
                };
            }
        }

        if (self.init_options.file.editor.canvas.scale < 0.1) {
            image_rect_scale.r.fill(.all(0), .{ .color = dvui.themeGet().color(.control, .fill), .fade = 1.5 });
        } else {
            image_rect_scale.r.fill(.all(0), .{ .color = dvui.themeGet().color(.control, .fill), .fade = 1.5 });
            dvui.renderImage(file.editor.checkerboard_tile, image_rect_scale, .{
                .colormod = dvui.themeGet().color(.control, .fill).lighten(4.0).opacity(0.5),
            }) catch {
                dvui.log.err("Failed to render checkerboard", .{});
            };
        }
    }

    // Render all layers and update our bounding box;
    {
        if (file.editor.workspace.columns_drag_index == null and file.editor.workspace.rows_drag_index == null) {
            pixi.render.renderLayers(.{
                .file = file,
                .rs = .{
                    .r = self.init_options.file.editor.canvas.rect,
                    .s = self.init_options.file.editor.canvas.scale,
                },
            }) catch {
                dvui.log.err("Failed to render file image", .{});
                return;
            };
        } else {
            self.drawReorderPreviewLayers();
        }
    }

    // Draw the resize fill area if a resize is happening
    if (self.resize_data_point) |resize_data_point| {
        if (resize_data_point.x > layer_rect.x + layer_rect.w) {
            const new_tiles_rect = dvui.Rect{
                .x = layer_rect.topRight().x,
                .y = layer_rect.topRight().y,
                .w = resize_data_point.x - layer_rect.topRight().x,
                .h = @min(resize_data_point.y - layer_rect.topRight().y, layer_rect.h),
            };

            self.init_options.file.editor.canvas.screenFromDataRect(new_tiles_rect).fill(.all(0), .{ .color = dvui.themeGet().color(.highlight, .fill).opacity(0.5), .fade = 0.0 });
        }
        if (resize_data_point.y > layer_rect.y + layer_rect.h) {
            const new_tiles_rect = dvui.Rect{
                .x = layer_rect.topLeft().x,
                .y = layer_rect.bottomLeft().y,
                .w = resize_data_point.x,
                .h = resize_data_point.y - layer_rect.bottomLeft().y,
            };

            self.init_options.file.editor.canvas.screenFromDataRect(new_tiles_rect).fill(.all(0), .{ .color = dvui.themeGet().color(.highlight, .fill).opacity(0.5), .fade = 0.0 });
        }
    }

    // Draw the grid lines for the canvas
    {
        for (1..columns) |i| {
            dvui.Path.stroke(.{ .points = &.{
                self.init_options.file.editor.canvas.screenFromDataPoint(.{ .x = @as(f32, @floatFromInt(i * file.column_width)), .y = 0 }),
                self.init_options.file.editor.canvas.screenFromDataPoint(.{ .x = @as(f32, @floatFromInt(i * file.column_width)), .y = canvas_rect.h }),
            } }, .{ .thickness = 1, .color = dvui.themeGet().color(.control, .fill) });
        }

        for (1..rows) |i| {
            dvui.Path.stroke(.{ .points = &.{
                self.init_options.file.editor.canvas.screenFromDataPoint(.{ .x = 0, .y = @as(f32, @floatFromInt(i * file.row_height)) }),
                self.init_options.file.editor.canvas.screenFromDataPoint(.{ .x = canvas_rect.w, .y = @as(f32, @floatFromInt(i * file.row_height)) }),
            } }, .{ .thickness = 1, .color = dvui.themeGet().color(.control, .fill) });
        }

        if (self.resize_data_point) |resize_data_point| {
            dvui.Path.stroke(.{ .points = &.{
                self.init_options.file.editor.canvas.screenFromDataPoint(.{ .x = resize_data_point.x, .y = 0 }),
                self.init_options.file.editor.canvas.screenFromDataPoint(.{ .x = resize_data_point.x, .y = canvas_rect.h }),
            } }, .{ .thickness = 1, .color = dvui.themeGet().color(.control, .fill) });

            dvui.Path.stroke(.{ .points = &.{
                self.init_options.file.editor.canvas.screenFromDataPoint(.{ .x = 0, .y = resize_data_point.y }),
                self.init_options.file.editor.canvas.screenFromDataPoint(.{ .x = canvas_rect.w, .y = resize_data_point.y }),
            } }, .{ .thickness = 1, .color = dvui.themeGet().color(.control, .fill) });
        }
    }

    // Draw the selection box for the selected sprites
    if (pixi.editor.tools.current == .pointer and file.editor.transform == null and self.resize_data_point == null) {
        var iter = file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
        while (iter.next()) |i| {
            const sprite_rect = file.spriteRect(i);
            const sprite_rect_physical = self.init_options.file.editor.canvas.screenFromDataRect(sprite_rect);
            sprite_rect_physical.inset(.all(dvui.currentWindow().natural_scale * 1.5)).stroke(dvui.Rect.Physical.all(@min(sprite_rect_physical.w, sprite_rect_physical.h) / 8), .{
                .thickness = 1.5 * dvui.currentWindow().natural_scale,
                .color = dvui.themeGet().color(.highlight, .fill),
                .closed = true,
            });
        }
    }
}

// TODO: Maybe refactor this so its not so much duplicated code?
pub fn drawReorderPreviewLayers(self: *FileWidget) void {
    const file = self.init_options.file;
    if (file.editor.workspace.columns_drag_index == null and file.editor.workspace.rows_drag_index == null) {
        return;
    }

    const workspace = file.editor.workspace;

    const Mode = enum {
        columns,
        rows,
    };

    const mode = if (workspace.columns_drag_index != null) Mode.columns else Mode.rows;

    switch (mode) {
        .columns => {
            if (workspace.columns_target_index) |target_index| {
                const target_rect = file.columnRect(target_index);
                file.editor.canvas.screenFromDataRect(target_rect).fill(.all(0), .{ .color = dvui.themeGet().color(.highlight, .fill).opacity(0.5), .fade = 0.0 });

                if (workspace.columns_drag_index) |removed_index| {
                    const removed_rect = file.columnRect(removed_index);
                    if (target_index <= removed_index) {
                        {
                            const rect_left: dvui.Rect = .{
                                .x = 0.0,
                                .y = 0.0,
                                .w = @as(f32, @floatFromInt(file.column_width)) * @as(f32, @floatFromInt(target_index)),
                                .h = @as(f32, @floatFromInt(file.height())),
                            };

                            pixi.render.renderLayers(.{
                                .file = file,
                                .rs = .{
                                    .r = file.editor.canvas.screenFromDataRect(rect_left),
                                    .s = self.init_options.file.editor.canvas.scale,
                                },
                                .uv = .{
                                    .x = rect_left.x / @as(f32, @floatFromInt(file.width())),
                                    .y = rect_left.y / @as(f32, @floatFromInt(file.height())),
                                    .w = rect_left.w / @as(f32, @floatFromInt(file.width())),
                                    .h = rect_left.h / @as(f32, @floatFromInt(file.height())),
                                },
                            }) catch {
                                dvui.log.err("Failed to render file image", .{});
                                return;
                            };
                        }

                        // Draw the columns between the target and removed (exclusive),
                        // ensuring the column directly after the target is drawn.
                        if (removed_index - target_index >= 1) {
                            const rect_middle: dvui.Rect = .{
                                .x = target_rect.x,
                                .y = 0.0,
                                .w = @as(f32, @floatFromInt(file.column_width)) * @as(f32, @floatFromInt(removed_index - target_index)),
                                .h = @as(f32, @floatFromInt(file.height())),
                            };

                            if (rect_middle.w > 0.0) {
                                pixi.render.renderLayers(.{
                                    .file = file,
                                    .rs = .{
                                        .r = file.editor.canvas.screenFromDataRect(rect_middle.offsetPoint(.{ .x = @as(f32, @floatFromInt(file.column_width)) })),
                                        .s = self.init_options.file.editor.canvas.scale,
                                    },
                                    .uv = .{
                                        .x = rect_middle.x / @as(f32, @floatFromInt(file.width())),
                                        .y = rect_middle.y / @as(f32, @floatFromInt(file.height())),
                                        .w = rect_middle.w / @as(f32, @floatFromInt(file.width())),
                                        .h = rect_middle.h / @as(f32, @floatFromInt(file.height())),
                                    },
                                }) catch {
                                    dvui.log.err("Failed to render file image", .{});
                                    return;
                                };
                            }
                        }

                        {
                            const rect_right: dvui.Rect = .{
                                .x = removed_rect.x + removed_rect.w,
                                .y = 0.0,
                                .w = @as(f32, @floatFromInt(file.column_width)) * @as(f32, @floatFromInt(file.columns - removed_index - 1)),
                                .h = @as(f32, @floatFromInt(file.height())),
                            };

                            if (rect_right.w > 0.0) {
                                pixi.render.renderLayers(.{
                                    .file = file,
                                    .rs = .{
                                        .r = file.editor.canvas.screenFromDataRect(rect_right),
                                    },
                                    .uv = .{
                                        .x = rect_right.x / @as(f32, @floatFromInt(file.width())),
                                        .y = rect_right.y / @as(f32, @floatFromInt(file.height())),
                                        .w = rect_right.w / @as(f32, @floatFromInt(file.width())),
                                        .h = rect_right.h / @as(f32, @floatFromInt(file.height())),
                                    },
                                }) catch {
                                    dvui.log.err("Failed to render file image", .{});
                                    return;
                                };
                            }
                        }
                    } else {
                        {
                            const rect_left: dvui.Rect = .{
                                .x = 0.0,
                                .y = 0.0,
                                .w = @as(f32, @floatFromInt(file.column_width)) * @as(f32, @floatFromInt(removed_index)),
                                .h = @as(f32, @floatFromInt(file.height())),
                            };

                            pixi.render.renderLayers(.{
                                .file = file,
                                .rs = .{
                                    .r = file.editor.canvas.screenFromDataRect(rect_left),
                                    .s = self.init_options.file.editor.canvas.scale,
                                },
                                .uv = .{
                                    .x = rect_left.x / @as(f32, @floatFromInt(file.width())),
                                    .y = rect_left.y / @as(f32, @floatFromInt(file.height())),
                                    .w = rect_left.w / @as(f32, @floatFromInt(file.width())),
                                    .h = rect_left.h / @as(f32, @floatFromInt(file.height())),
                                },
                            }) catch {
                                dvui.log.err("Failed to render file image", .{});
                                return;
                            };
                        }

                        if (target_index - removed_index >= 1) {
                            const rect_middle: dvui.Rect = .{
                                .x = removed_rect.x,
                                .y = 0.0,
                                .w = @as(f32, @floatFromInt(file.column_width)) * @as(f32, @floatFromInt(target_index - removed_index + 1)),
                                .h = @as(f32, @floatFromInt(file.height())),
                            };

                            if (rect_middle.w > 0.0) {
                                pixi.render.renderLayers(.{
                                    .file = file,
                                    .rs = .{
                                        .r = file.editor.canvas.screenFromDataRect(rect_middle.offsetPoint(.{ .x = -@as(f32, @floatFromInt(file.column_width)) })),
                                        .s = self.init_options.file.editor.canvas.scale,
                                    },
                                    .uv = .{
                                        .x = rect_middle.x / @as(f32, @floatFromInt(file.width())),
                                        .y = rect_middle.y / @as(f32, @floatFromInt(file.height())),
                                        .w = rect_middle.w / @as(f32, @floatFromInt(file.width())),
                                        .h = rect_middle.h / @as(f32, @floatFromInt(file.height())),
                                    },
                                }) catch {
                                    dvui.log.err("Failed to render file image", .{});
                                    return;
                                };
                            }
                        }

                        {
                            const rect_right: dvui.Rect = .{
                                .x = target_rect.x + target_rect.w,
                                .y = 0.0,
                                .w = @as(f32, @floatFromInt(file.column_width)) * @as(f32, @floatFromInt(file.columns - target_index - 1)),
                                .h = @as(f32, @floatFromInt(file.height())),
                            };

                            if (rect_right.w > 0.0) {
                                pixi.render.renderLayers(.{
                                    .file = file,
                                    .rs = .{
                                        .r = file.editor.canvas.screenFromDataRect(rect_right),
                                    },
                                    .uv = .{
                                        .x = rect_right.x / @as(f32, @floatFromInt(file.width())),
                                        .y = rect_right.y / @as(f32, @floatFromInt(file.height())),
                                        .w = rect_right.w / @as(f32, @floatFromInt(file.width())),
                                        .h = rect_right.h / @as(f32, @floatFromInt(file.height())),
                                    },
                                }) catch {
                                    dvui.log.err("Failed to render file image", .{});
                                    return;
                                };
                            }
                        }
                    }
                }
            }
        },
        .rows => {
            if (workspace.rows_target_index) |target_index| {
                const target_rect = file.rowRect(target_index);
                file.editor.canvas.screenFromDataRect(target_rect).fill(.all(0), .{ .color = dvui.themeGet().color(.highlight, .fill).opacity(0.5), .fade = 0.0 });

                if (workspace.rows_drag_index) |removed_index| {
                    const removed_rect = file.rowRect(removed_index);

                    if (target_index <= removed_index) {
                        {
                            const rect_top: dvui.Rect = .{
                                .x = 0.0,
                                .y = 0.0,
                                .w = @as(f32, @floatFromInt(file.width())),
                                .h = @as(f32, @floatFromInt(file.row_height)) * @as(f32, @floatFromInt(target_index)),
                            };

                            pixi.render.renderLayers(.{
                                .file = file,
                                .rs = .{
                                    .r = file.editor.canvas.screenFromDataRect(rect_top),
                                    .s = self.init_options.file.editor.canvas.scale,
                                },
                                .uv = .{
                                    .x = rect_top.x / @as(f32, @floatFromInt(file.width())),
                                    .y = rect_top.y / @as(f32, @floatFromInt(file.height())),
                                    .w = rect_top.w / @as(f32, @floatFromInt(file.width())),
                                    .h = rect_top.h / @as(f32, @floatFromInt(file.height())),
                                },
                            }) catch {
                                dvui.log.err("Failed to render file image", .{});
                                return;
                            };
                        }

                        // Draw the rows between the target and removed (exclusive),
                        // ensuring the row directly after the target is drawn.
                        if (removed_index - target_index >= 1) {
                            const rect_middle: dvui.Rect = .{
                                .x = 0.0,
                                .y = target_rect.y,
                                .w = @as(f32, @floatFromInt(file.width())),
                                .h = @as(f32, @floatFromInt(file.row_height)) * @as(f32, @floatFromInt(removed_index - target_index)),
                            };

                            if (rect_middle.h > 0.0) {
                                pixi.render.renderLayers(.{
                                    .file = file,
                                    .rs = .{
                                        .r = file.editor.canvas.screenFromDataRect(rect_middle.offsetPoint(.{ .y = @as(f32, @floatFromInt(file.row_height)) })),
                                        .s = self.init_options.file.editor.canvas.scale,
                                    },
                                    .uv = .{
                                        .x = rect_middle.x / @as(f32, @floatFromInt(file.width())),
                                        .y = rect_middle.y / @as(f32, @floatFromInt(file.height())),
                                        .w = rect_middle.w / @as(f32, @floatFromInt(file.width())),
                                        .h = rect_middle.h / @as(f32, @floatFromInt(file.height())),
                                    },
                                }) catch {
                                    dvui.log.err("Failed to render file image", .{});
                                    return;
                                };
                            }
                        }

                        {
                            const rect_bottom: dvui.Rect = .{
                                .x = 0.0,
                                .y = removed_rect.y + removed_rect.h,
                                .w = @as(f32, @floatFromInt(file.width())),
                                .h = @as(f32, @floatFromInt(file.row_height)) * @as(f32, @floatFromInt(file.rows - removed_index - 1)),
                            };

                            if (rect_bottom.h > 0.0) {
                                pixi.render.renderLayers(.{
                                    .file = file,
                                    .rs = .{
                                        .r = file.editor.canvas.screenFromDataRect(rect_bottom),
                                    },
                                    .uv = .{
                                        .x = rect_bottom.x / @as(f32, @floatFromInt(file.width())),
                                        .y = rect_bottom.y / @as(f32, @floatFromInt(file.height())),
                                        .w = rect_bottom.w / @as(f32, @floatFromInt(file.width())),
                                        .h = rect_bottom.h / @as(f32, @floatFromInt(file.height())),
                                    },
                                }) catch {
                                    dvui.log.err("Failed to render file image", .{});
                                    return;
                                };
                            }
                        }
                    } else {
                        {
                            const rect_top: dvui.Rect = .{
                                .x = 0.0,
                                .y = 0.0,
                                .w = @as(f32, @floatFromInt(file.width())),
                                .h = @as(f32, @floatFromInt(file.row_height)) * @as(f32, @floatFromInt(removed_index)),
                            };

                            pixi.render.renderLayers(.{
                                .file = file,
                                .rs = .{
                                    .r = file.editor.canvas.screenFromDataRect(rect_top),
                                    .s = self.init_options.file.editor.canvas.scale,
                                },
                                .uv = .{
                                    .x = rect_top.x / @as(f32, @floatFromInt(file.width())),
                                    .y = rect_top.y / @as(f32, @floatFromInt(file.height())),
                                    .w = rect_top.w / @as(f32, @floatFromInt(file.width())),
                                    .h = rect_top.h / @as(f32, @floatFromInt(file.height())),
                                },
                            }) catch {
                                dvui.log.err("Failed to render file image", .{});
                                return;
                            };
                        }

                        if (target_index - removed_index >= 1) {
                            const rect_middle: dvui.Rect = .{
                                .x = 0.0,
                                .y = removed_rect.y,
                                .w = @as(f32, @floatFromInt(file.width())),
                                .h = @as(f32, @floatFromInt(file.row_height)) * @as(f32, @floatFromInt(target_index - removed_index + 1)),
                            };

                            if (rect_middle.h > 0.0) {
                                pixi.render.renderLayers(.{
                                    .file = file,
                                    .rs = .{
                                        .r = file.editor.canvas.screenFromDataRect(rect_middle.offsetPoint(.{ .y = -@as(f32, @floatFromInt(file.row_height)) })),
                                        .s = self.init_options.file.editor.canvas.scale,
                                    },
                                    .uv = .{
                                        .x = rect_middle.x / @as(f32, @floatFromInt(file.width())),
                                        .y = rect_middle.y / @as(f32, @floatFromInt(file.height())),
                                        .w = rect_middle.w / @as(f32, @floatFromInt(file.width())),
                                        .h = rect_middle.h / @as(f32, @floatFromInt(file.height())),
                                    },
                                }) catch {
                                    dvui.log.err("Failed to render file image", .{});
                                    return;
                                };
                            }
                        }

                        {
                            const rect_bottom: dvui.Rect = .{
                                .x = 0.0,
                                .y = target_rect.y + target_rect.h,
                                .w = @as(f32, @floatFromInt(file.width())),
                                .h = @as(f32, @floatFromInt(file.row_height)) * @as(f32, @floatFromInt(file.rows - target_index - 1)),
                            };

                            if (rect_bottom.h > 0.0) {
                                pixi.render.renderLayers(.{
                                    .file = file,
                                    .rs = .{
                                        .r = file.editor.canvas.screenFromDataRect(rect_bottom),
                                    },
                                    .uv = .{
                                        .x = rect_bottom.x / @as(f32, @floatFromInt(file.width())),
                                        .y = rect_bottom.y / @as(f32, @floatFromInt(file.height())),
                                        .w = rect_bottom.w / @as(f32, @floatFromInt(file.width())),
                                        .h = rect_bottom.h / @as(f32, @floatFromInt(file.height())),
                                    },
                                }) catch {
                                    dvui.log.err("Failed to render file image", .{});
                                    return;
                                };
                            }
                        }
                    }
                }
            }
        },
    }
}

pub fn processResize(self: *FileWidget) void {
    if (pixi.editor.tools.current != .pointer) return;
    if (self.init_options.file.editor.transform != null) return;
    if (self.sample_data_point != null) return;

    const file = self.init_options.file;
    const file_rect = dvui.Rect.fromSize(.{ .w = @floatFromInt(file.width()), .h = @floatFromInt(file.height()) });

    {
        const min_size: f32 = @as(f32, @floatFromInt(@min(file.column_width, file.row_height)));
        const baseline_size: f32 = 64.0;
        const baseline_scale: f32 = baseline_size / min_size;
        const target_button_height: f32 = min_size / 3.0;
        const button_size: f32 = std.math.clamp((target_button_height * 1.0 / self.init_options.file.editor.canvas.scale) * baseline_scale, 0.0, min_size);
        var resize_button_rect = dvui.Rect{
            .x = file_rect.x + file_rect.w - button_size / 2.0,
            .y = file_rect.y + file_rect.h - button_size / 2.0,
            .w = button_size,
            .h = button_size,
        };

        const offset_data_point = self.init_options.file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt).plus(.{
            .x = @as(f32, @floatFromInt(file.column_width)) / 2.0,
            .y = @as(f32, @floatFromInt(file.row_height)) / 2.0,
        });

        const dragging = dvui.dragging(dvui.currentWindow().mouse_pt, "resize_drag") != null and self.active();

        if (self.resize_data_point != null or dragging) {
            const current_point: dvui.Point = self.resize_data_point orelse .{ .x = 0.0, .y = 0.0 };
            var new_point = self.init_options.file.spritePoint(offset_data_point);

            if (current_point.x != new_point.x or current_point.y != new_point.y) {
                new_point.x = std.math.clamp(new_point.x, @as(f32, @floatFromInt(file.column_width)), std.math.floatMax(f32));
                new_point.y = std.math.clamp(new_point.y, @as(f32, @floatFromInt(file.row_height)), std.math.floatMax(f32));

                if (self.resize_data_point != null) {
                    if (dvui.animationGet(self.init_options.file.editor.canvas.id, "resize_button_rect_x")) |anim| {
                        _ = dvui.currentWindow().animations.remove(self.init_options.file.editor.canvas.id.update("resize_button_rect_x"));
                        dvui.animation(self.init_options.file.editor.canvas.id, "resize_button_rect_x", .{
                            .start_val = anim.value(),
                            .end_val = new_point.x,
                            .end_time = 250_000,
                            .easing = dvui.easing.outBack,
                        });
                    } else {

                        // If we are here, we need to trigger a new animation to move the resize button rect to the new point
                        dvui.animation(self.init_options.file.editor.canvas.id, "resize_button_rect_x", .{
                            .start_val = current_point.x,
                            .end_val = new_point.x,
                            .end_time = 250_000,
                            .easing = dvui.easing.outBack,
                        });
                    }

                    if (dvui.animationGet(self.init_options.file.editor.canvas.id, "resize_button_rect_y")) |anim| {
                        _ = dvui.currentWindow().animations.remove(self.init_options.file.editor.canvas.id.update("resize_button_rect_y"));
                        dvui.animation(self.init_options.file.editor.canvas.id, "resize_button_rect_y", .{
                            .start_val = anim.value(),
                            .end_val = new_point.y,
                            .end_time = 250_000,
                            .easing = dvui.easing.outBack,
                        });
                    } else {

                        // If we are here, we need to trigger a new animation to move the resize button rect to the new point
                        dvui.animation(self.init_options.file.editor.canvas.id, "resize_button_rect_y", .{
                            .start_val = current_point.y,
                            .end_val = new_point.y,
                            .end_time = 250_000,
                            .easing = dvui.easing.outBack,
                        });
                    }
                }

                self.resize_data_point = new_point;
            }

            if (dvui.animationGet(self.init_options.file.editor.canvas.id, "resize_button_rect_x")) |anim| {
                resize_button_rect.x = anim.value();
            } else {
                resize_button_rect.x = new_point.x;
            }

            if (dvui.animationGet(self.init_options.file.editor.canvas.id, "resize_button_rect_y")) |anim| {
                resize_button_rect.y = anim.value();
            } else {
                resize_button_rect.y = new_point.y;
            }
        }

        var icon_button: dvui.ButtonWidget = undefined;
        icon_button.init(@src(), .{ .draw_focus = false }, .{
            .rect = resize_button_rect,
            .border = dvui.Rect.all(0),
            .margin = .all(0),
            .padding = .all(0),
            .background = false,
        });
        defer icon_button.deinit();
        icon_button.processEvents();

        if (dragging) {
            var bounds_rect = dvui.Rect.Physical.fromSize(.{ .w = @as(f32, @floatFromInt(file.column_width)), .h = @as(f32, @floatFromInt(file.row_height)) });
            bounds_rect = bounds_rect.scale(self.init_options.file.editor.canvas.scale * dvui.currentWindow().natural_scale, dvui.Rect.Physical);
            bounds_rect.x = icon_button.data().contentRectScale().r.topLeft().x - bounds_rect.w / 2.0;
            bounds_rect.y = icon_button.data().contentRectScale().r.topLeft().y - bounds_rect.h / 2.0;

            var path = dvui.Path.Builder.init(dvui.currentWindow().arena());
            path.addRect(bounds_rect, .{ .x = bounds_rect.w / 2.0, .y = bounds_rect.h / 2.0, .w = bounds_rect.w / 2.0, .h = bounds_rect.h / 2.0 });
            const built = path.build();
            built.fillConvex(.{ .color = dvui.themeGet().color(.window, .fill).opacity(0.5), .fade = 1.5 });
            built.stroke(.{ .color = dvui.themeGet().color(.control, .text).opacity(0.5), .thickness = 1.0, .closed = true });

            path = dvui.Path.Builder.init(dvui.currentWindow().arena());
            path.addPoint(icon_button.data().contentRectScale().r.topLeft());
            path.addRect(.{
                .x = dvui.currentWindow().mouse_pt.x - icon_button.data().contentRectScale().r.w / 8.0,
                .y = dvui.currentWindow().mouse_pt.y - icon_button.data().contentRectScale().r.h / 8.0,
                .w = icon_button.data().contentRectScale().r.w / 4.0,
                .h = icon_button.data().contentRectScale().r.h / 4.0,
            }, .all(icon_button.data().contentRectScale().r.w / 8.0));
            path.build().fillConvex(.{ .color = dvui.themeGet().color(.control, .text).opacity(0.5), .fade = 1.5 });

            path = dvui.Path.Builder.init(dvui.currentWindow().arena());
            path.addRect(.{
                .x = dvui.currentWindow().mouse_pt.x - icon_button.data().contentRectScale().r.w / 8.0,
                .y = dvui.currentWindow().mouse_pt.y - icon_button.data().contentRectScale().r.h / 8.0,
                .w = icon_button.data().contentRectScale().r.w / 4.0,
                .h = icon_button.data().contentRectScale().r.h / 4.0,
            }, .all(icon_button.data().contentRectScale().r.w / 8.0));
            path.build().fillConvex(.{ .color = dvui.themeGet().color(.highlight, .fill).opacity(0.5), .fade = 1.5 });
        } else {
            dvui.icon(@src(), "resize", if (dragging) icons.tvg.lucide.move else icons.tvg.lucide.@"move-diagonal-2", .{
                .stroke_color = if (icon_button.hover) dvui.themeGet().color(.highlight, .fill) else dvui.themeGet().color(.control, .text),
            }, .{
                .expand = .ratio,
                .min_size_content = .{ .w = 1.0, .h = 1.0 },
                .gravity_x = 0.5,
                .gravity_y = 0.5,
                .border = dvui.Rect.all(0),
                .margin = .all(0),
                .padding = .all(0),
                .background = false,
                .rotation = dvui.math.degreesToRadians(0.0),
            });
        }

        if (icon_button.pressed()) {
            dvui.dragStart(
                dvui.currentWindow().mouse_pt,
                .{ .name = "resize_drag", .cursor = .hidden },
            );
            dvui.captureMouse(self.init_options.file.editor.canvas.scroll_container.data(), 0);
        }

        if (dragging == false) {
            if (self.resize_data_point) |resize_data_point| {
                self.init_options.file.resize(.{
                    .columns = @divTrunc(@as(u32, @intFromFloat(resize_data_point.x)), self.init_options.file.column_width),
                    .rows = @divTrunc(@as(u32, @intFromFloat(resize_data_point.y)), self.init_options.file.row_height),
                    .history = true,
                }) catch |err| {
                    dvui.log.err("Failed to resize file: {s}", .{@errorName(err)});
                };
                self.resize_data_point = null;
                dvui.dragEnd();
                dvui.captureMouse(null, 0);
                dvui.refresh(null, @src(), self.init_options.file.editor.canvas.id);
            }
        }
    }
}

pub fn processEvents(self: *FileWidget) void {
    const transform = self.init_options.file.editor.transform != null;
    const reorder = self.init_options.file.editor.workspace.columns_drag_index != null or self.init_options.file.editor.workspace.rows_drag_index != null;

    // Try to ensure that selected animation frame index is valid
    if (self.init_options.file.selected_animation_index) |ai| {
        if (self.init_options.file.animations.get(ai).frames.len > 0) {
            if (self.init_options.file.selected_animation_frame_index >= self.init_options.file.animations.get(ai).frames.len) {
                self.init_options.file.selected_animation_frame_index = self.init_options.file.animations.get(ai).frames.len - 1;
            }
        } else {
            self.init_options.file.selected_animation_frame_index = 0;
        }
    }

    defer self.previous_mods = dvui.currentWindow().modifiers;

    defer if (self.drag_data_point) |drag_data_point| {
        dvui.dataSet(null, self.init_options.file.editor.canvas.id, "drag_data_point", drag_data_point);
    } else {
        dvui.dataRemove(null, self.init_options.file.editor.canvas.id, "drag_data_point");
    };

    defer if (self.sample_data_point) |sample_data_point| {
        dvui.dataSet(null, self.init_options.file.editor.canvas.id, "sample_data_point", sample_data_point);
    } else {
        dvui.dataRemove(null, self.init_options.file.editor.canvas.id, "sample_data_point");
    };

    defer if (self.resize_data_point) |resize_data_point| {
        dvui.dataSet(null, self.init_options.file.editor.canvas.id, "resize_data_point", resize_data_point);
    } else {
        dvui.dataRemove(null, self.init_options.file.editor.canvas.id, "resize_data_point");
    };

    defer if (self.sample_key_down) {
        dvui.dataSet(null, self.init_options.file.editor.canvas.id, "sample_key_down", self.sample_key_down);
    } else {
        dvui.dataRemove(null, self.init_options.file.editor.canvas.id, "sample_key_down");
    };

    defer if (self.right_mouse_down) {
        dvui.dataSet(null, self.init_options.file.editor.canvas.id, "right_mouse_down", self.right_mouse_down);
    } else {
        dvui.dataRemove(null, self.init_options.file.editor.canvas.id, "right_mouse_down");
    };

    defer if (self.left_mouse_down) {
        dvui.dataSet(null, self.init_options.file.editor.canvas.id, "left_mouse_down", self.left_mouse_down);
    } else {
        dvui.dataRemove(null, self.init_options.file.editor.canvas.id, "left_mouse_down");
    };

    defer if (self.hide_distance_bubble) {
        dvui.dataSet(null, self.init_options.file.editor.canvas.id, "hide_distance_bubble", self.hide_distance_bubble);
    } else {
        dvui.dataRemove(null, self.init_options.file.editor.canvas.id, "hide_distance_bubble");
    };

    if ((self.active() and self.hovered()) or self.hovered()) {
        defer self.init_options.file.editor.temporary_layer.invalidate();
        // If we are processing, we need to always ensure the temporary layer is cleared
        @memset(self.init_options.file.editor.temporary_layer.pixels(), .{ 0, 0, 0, 0 });
        self.init_options.file.editor.temporary_layer.clearMask();

        if (self.active()) {
            // Ensure that the active layer mask is always up to date
            self.updateActiveLayerMask();
        }

        // Animate/Flip the checkerboard if we are in selection mode
        if (pixi.editor.tools.current == .selection) {
            if (dvui.timerDoneOrNone(self.init_options.file.editor.canvas.scroll_container.data().id)) {
                self.init_options.file.editor.checkerboard.toggleAll();

                dvui.timer(self.init_options.file.editor.canvas.scroll_container.data().id, 500_000);
            }
        }

        if (self.init_options.file.editor.transform == null) {
            self.processFill();
            self.processStroke();
            self.processSample();
            self.processSelection();
        }
        self.processTransform();
    }

    self.drawLayers();

    if ((self.active() or self.hovered()) and !transform and !reorder) {
        self.drawSpriteBubbles();
        self.processResize();

        self.processAnimationSelection();
        self.processSpriteSelection();
        self.drawSpriteSelection();
    }

    // Draw shadows for the scroll container
    pixi.dvui.drawEdgeShadow(self.init_options.file.editor.canvas.scroll_container.data().rectScale(), .top, .{ .opacity = 0.15 });
    pixi.dvui.drawEdgeShadow(self.init_options.file.editor.canvas.scroll_container.data().rectScale(), .bottom, .{});
    pixi.dvui.drawEdgeShadow(self.init_options.file.editor.canvas.scroll_container.data().rectScale(), .left, .{ .opacity = 0.15 });
    pixi.dvui.drawEdgeShadow(self.init_options.file.editor.canvas.scroll_container.data().rectScale(), .right, .{});

    self.drawSample();
    self.drawTransform();
    self.drawCursor();

    // Then process the scroll and zoom events last
    self.init_options.file.editor.canvas.processEvents();
}

pub fn deinit(self: *FileWidget) void {
    self.init_options.file.editor.canvas.deinit();

    self.* = undefined;
}

pub fn hovered(self: *FileWidget) bool {
    return self.init_options.file.editor.canvas.hovered;
}

test {
    @import("std").testing.refAllDecls(@This());
}
