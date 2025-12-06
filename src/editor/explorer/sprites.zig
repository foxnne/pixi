const std = @import("std");
const dvui = @import("dvui");
const icons = @import("icons");

const pixi = @import("../../pixi.zig");
const Editor = pixi.Editor;

const Sprites = @This();

animation_removed_index: ?usize = null,
animation_insert_before_index: ?usize = null,
sprite_removed_index: ?usize = null,
sprite_insert_before_index: ?usize = null,
edit_anim_id: ?u64 = null,
edit_sprite_id: ?u64 = null,
prev_anim_count: usize = 0,
prev_anim_id: u64 = 0,
prev_sprite_count: usize = 0,
max_split_ratio: f32 = 0.4,

pub fn init() Sprites {
    return .{};
}

pub fn draw(self: *Sprites) !void {
    if (pixi.editor.activeFile()) |file| {

        // Collect layers length to trigger a refit of the panel
        // const anim_count: usize = file.animations.len;
        // defer self.prev_anim_count = anim_count;

        // var paned = pixi.dvui.paned(@src(), .{
        //     .direction = .vertical,
        //     .collapsed_size = 0,
        //     .handle_size = 10,
        //     .handle_dynamic = .{},
        // }, .{ .expand = .both, .background = false });
        // defer paned.deinit();

        // if (paned.dragging) {
        //     self.max_split_ratio = paned.split_ratio.*;
        //     pixi.editor.explorer.layers_ratio = paned.split_ratio.*;
        // }

        // if (paned.showFirst()) {
        const hbox = dvui.box(@src(), .{ .dir = .horizontal, .equal_space = true }, .{
            .expand = .horizontal,
            .background = false,
        });
        defer hbox.deinit();

        self.drawAnimations() catch {
            dvui.log.err("Failed to draw layers", .{});
        };

        if (file.selected_animation_index != null) {
            self.drawFrames() catch {
                dvui.log.err("Failed to draw sprites", .{});
            };
        }
        // }

        // const autofit = !paned.dragging and !paned.collapsed_state;

        // // Refit must be done between showFirst and showSecond
        // if (((dvui.firstFrame(paned.data().id) or self.prev_anim_count != anim_count) or autofit) and !pixi.editor.explorer.pinned_palettes) {
        //     if (dvui.firstFrame(paned.data().id) and anim_count == 0)
        //         paned.split_ratio.* = 0.0;

        //     const ratio = paned.getFirstFittedRatio(
        //         .{
        //             .min_split = 0,
        //             .max_split = @min(self.max_split_ratio, 0.75),
        //             .min_size = 0,
        //         },
        //     );

        //     const diff = @abs(ratio - paned.split_ratio.*);

        //     if (diff > 0.000001 and anim_count > 0) {
        //         paned.animateSplit(ratio);
        //     }
        // } else {
        //     if (dvui.firstFrame(paned.data().id)) {
        //         if (anim_count == 0)
        //             paned.split_ratio.* = 0.0
        //         else
        //             paned.split_ratio.* = pixi.editor.explorer.animations_ratio;

        //         pixi.editor.explorer.animations_ratio = paned.split_ratio.*;
        //     }
        // }

        // if (paned.showSecond()) {}
    }
}

pub fn drawAnimationControls(self: *Sprites) !void {
    var box = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .horizontal,
        // .background = true,
        // .color_fill = dvui.themeGet().color(.control, .fill),
        // .corner_radius = dvui.Rect.all(1000),
        // .margin = dvui.Rect.all(4),
        // .padding = dvui.Rect.all(0),
        // .border = dvui.Rect.all(1.0),
        // .color_border = dvui.themeGet().color(.control, .fill),
        // .box_shadow = .{
        //     .color = .black,
        //     .offset = .{ .x = -2.0, .y = 2.0 },
        //     .fade = 6.0,
        //     .alpha = 0.25,
        //     .corner_radius = dvui.Rect.all(1000),
        // },
    });
    defer box.deinit();

    if (pixi.editor.activeFile()) |file| {
        var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .none,
            .background = false,
            //.gravity_x = 1.0,
        });
        defer hbox.deinit();

        if (dvui.buttonIcon(@src(), "AddAnimation", icons.tvg.lucide.plus, .{}, .{}, .{
            .expand = .none,
            .gravity_y = 0.5,
            .corner_radius = dvui.Rect.all(1000),
            .box_shadow = .{
                .color = .black,
                .offset = .{ .x = -2.0, .y = 2.0 },
                .fade = 6.0,
                .alpha = 0.15,
                .corner_radius = dvui.Rect.all(1000),
            },
            .color_fill = dvui.themeGet().color(.control, .fill),
        })) {
            const anim_index = try file.createAnimation();
            file.selected_animation_index = anim_index;
            file.editor.animations_scroll_to_index = anim_index;
            self.edit_anim_id = file.animations.items(.id)[anim_index];
        }

        if (file.animations.len > 0) {
            if (file.selected_animation_index) |index| {
                if (dvui.buttonIcon(@src(), "DuplicateAnimation", icons.tvg.lucide.@"copy-plus", .{}, .{}, .{
                    .expand = .none,
                    .gravity_y = 0.5,
                    .corner_radius = dvui.Rect.all(1000),
                    .box_shadow = .{
                        .color = .black,
                        .offset = .{ .x = -2.0, .y = 2.0 },
                        .fade = 6.0,
                        .alpha = 0.15,
                        .corner_radius = dvui.Rect.all(1000),
                    },
                    .color_fill = dvui.themeGet().color(.control, .fill),
                })) {
                    const anim_index = try file.duplicateAnimation(index);
                    file.selected_animation_index = anim_index;
                    file.editor.animations_scroll_to_index = anim_index;
                    self.edit_anim_id = file.animations.items(.id)[anim_index];
                }

                if (dvui.buttonIcon(@src(), "DeleteAnimation", icons.tvg.lucide.trash, .{}, .{ .stroke_color = dvui.themeGet().color(.window, .fill) }, .{
                    .style = .err,
                    .expand = .none,
                    .gravity_y = 0.5,
                    .corner_radius = dvui.Rect.all(1000),
                    .box_shadow = .{
                        .color = .black,
                        .offset = .{ .x = -2.0, .y = 2.0 },
                        .fade = 6.0,
                        .alpha = 0.15,
                        .corner_radius = dvui.Rect.all(1000),
                    },
                })) {
                    file.deleteAnimation(index) catch {
                        dvui.log.err("Failed to delete animation", .{});
                    };

                    if (index > 0) {
                        file.selected_animation_index = index - 1;
                    } else {
                        file.selected_animation_index = null;
                    }
                }
            }
        }
    }
}

pub fn drawAnimations(self: *Sprites) !void {
    const controls_box = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .horizontal,
        .background = false,
    });
    defer controls_box.deinit();

    dvui.labelNoFmt(@src(), "ANIMATIONS", .{}, .{ .font_style = .title_4 });

    self.drawAnimationControls() catch {};

    const vbox = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .both,
        .background = false,
        .color_fill = dvui.themeGet().color(.content, .fill),
        .max_size_content = .{ .w = pixi.editor.explorer.rect.w / 2.0, .h = std.math.floatMax(f32) },
    });
    defer vbox.deinit();

    if (pixi.editor.activeFile()) |file| {
        // Make sure to update the prev anim count!
        defer self.prev_anim_count = file.animations.len;

        var scroll_area = dvui.scrollArea(@src(), .{ .scroll_info = &file.editor.animations_scroll_info }, .{
            .expand = .both,
            .background = false,
            .corner_radius = dvui.Rect.all(1000),
        });

        defer scroll_area.deinit();

        const vertical_scroll = file.editor.animations_scroll_info.offset(.vertical);

        var reorderable = pixi.dvui.reorder(@src(), .{ .drag_name = "anim_drag" }, .{
            .expand = .horizontal,
            .background = false,
        });
        defer reorderable.deinit();

        // Drag and drop is completing
        if (self.animation_insert_before_index) |insert_before| {
            if (self.animation_removed_index) |removed| {
                const prev_order = try dvui.currentWindow().arena().dupe(u64, file.animations.items(.id));

                const anim = file.animations.get(removed);
                file.animations.orderedRemove(removed);

                if (insert_before <= file.animations.len) {
                    file.animations.insert(pixi.app.allocator, if (removed < insert_before) insert_before - 1 else insert_before, anim) catch {
                        dvui.log.err("Failed to insert animation", .{});
                    };
                } else {
                    file.animations.insert(pixi.app.allocator, if (removed < insert_before) file.animations.len else 0, anim) catch {
                        dvui.log.err("Failed to insert animation", .{});
                    };
                }

                if (removed == file.selected_animation_index) {
                    if (insert_before < file.animations.len) {
                        file.selected_animation_index = if (removed < insert_before) insert_before - 1 else insert_before;
                    } else {
                        file.selected_animation_index = 0;
                    }
                }

                if (!std.mem.eql(u64, file.animations.items(.id)[0..file.animations.len], prev_order)) {
                    file.history.append(.{
                        .animation_order = .{
                            .order = prev_order,
                            .selected = file.animations.items(.id)[file.selected_animation_index orelse 0],
                        },
                    }) catch {
                        dvui.log.err("Failed to append history", .{});
                    };
                }

                self.animation_insert_before_index = null;
                self.animation_removed_index = null;
            }
        }

        const box = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .horizontal,
            .margin = dvui.Rect.all(4),
        });
        defer box.deinit();

        for (file.animations.items(.id), 0..) |anim_id, anim_index| {
            const selected = if (self.edit_anim_id) |id| id == anim_id else file.selected_animation_index == anim_index;

            var color = dvui.themeGet().color(.control, .fill_hover);
            if (pixi.editor.colors.file_tree_palette) |*palette| {
                color = palette.getDVUIColor(anim_id);
            }

            var r = reorderable.reorderable(@src(), .{}, .{
                .id_extra = anim_id,
                .expand = .horizontal,
                .corner_radius = dvui.Rect.all(1000),
                .min_size_content = .{ .w = 0.0, .h = reorderable.reorderable_size.h },
            });
            defer r.deinit();

            if (dvui.firstFrame(r.data().id) or self.prev_anim_count != file.animations.len) {
                dvui.animation(r.data().id, "anim_expand", .{
                    .start_val = 0.2,
                    .end_val = 1.0,
                    .end_time = 150_000 + (50_000 * @as(i32, @intCast(anim_index))),
                    .easing = dvui.easing.inOutQuad,
                });
            }

            if (dvui.animationGet(r.data().id, "anim_expand")) |a| {
                if (dvui.minSizeGet(r.data().id)) |ms| {
                    if (r.data().rect.w > ms.w + 0.001) {
                        // we are bigger than our min size (maybe expanded) - account for floating point
                        const w = r.data().rect.w;
                        r.data().rect.w *= @max(a.value(), 0);
                        r.data().rect.x += r.data().options.gravityGet().x * (w - r.data().rect.w);
                    }
                }
            }

            if (r.removed()) {
                self.animation_removed_index = anim_index;
            } else if (r.insertBefore()) {
                self.animation_insert_before_index = anim_index;
            }

            const hovered = pixi.dvui.hovered(r.data());

            var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .expand = .both,
                .background = true,
                .color_fill = if (selected or hovered) dvui.themeGet().color(.control, .fill_hover) else dvui.themeGet().color(.control, .fill),
                .corner_radius = dvui.Rect.all(1000),
                .margin = dvui.Rect.all(2),
                .padding = dvui.Rect.all(1),
                .border = dvui.Rect.all(1.0),
                .color_border = if (selected) color else dvui.themeGet().color(.control, .fill),
                .box_shadow = .{
                    .color = .black,
                    .offset = .{ .x = -2.0, .y = 2.0 },
                    .fade = 6.0,
                    .alpha = 0.25,
                    .corner_radius = dvui.Rect.all(1000),
                },
            });
            defer hbox.deinit();

            _ = pixi.dvui.ReorderWidget.draggable(@src(), .{
                .reorderable = r,
                .tvg_bytes = icons.tvg.lucide.@"grip-horizontal",
                .color = if (!selected) dvui.themeGet().color(.control, .text) else dvui.themeGet().color(.window, .text),
            }, .{
                .expand = .none,
                .gravity_y = 0.5,
                .margin = .{ .x = 4, .w = 4 },
            });

            if (self.edit_anim_id != anim_id) {
                if (file.selected_animation_index == anim_index) {
                    if (dvui.labelClick(@src(), "{s}", .{file.animations.items(.name)[anim_index]}, .{}, .{
                        .gravity_y = 0.5,
                        .font_style = .body,
                        .margin = dvui.Rect.all(2),
                        .padding = dvui.Rect.all(0),
                        .color_text = if (!selected) dvui.themeGet().color(.control, .text) else dvui.themeGet().color(.window, .text),
                    })) {
                        self.edit_anim_id = anim_id;
                    }
                } else {
                    dvui.labelNoFmt(@src(), file.animations.items(.name)[anim_index], .{}, .{
                        .gravity_y = 0.5,
                        .margin = dvui.Rect.all(2),
                        .font_style = .body,
                        .padding = dvui.Rect.all(0),
                        .color_text = if (!selected) dvui.themeGet().color(.control, .text) else dvui.themeGet().color(.window, .text),
                    });
                }
            } else {
                var te = dvui.textEntry(@src(), .{}, .{
                    .expand = .horizontal,
                    .background = false,
                    .padding = dvui.Rect.all(0),
                    .margin = dvui.Rect.all(0),
                    .font_style = .body,
                    .gravity_y = 0.5,
                });
                defer te.deinit();

                if (dvui.firstFrame(te.data().id)) {
                    te.textSet(file.animations.items(.name)[anim_index], true);
                    dvui.focusWidget(te.data().id, null, null);
                }

                if (te.enter_pressed or dvui.focusedWidgetId() != te.data().id) {
                    if (!std.mem.eql(u8, file.animations.items(.name)[anim_index], te.getText()) and te.getText().len > 0) {
                        file.history.append(.{
                            .animation_name = .{
                                .index = anim_index,
                                .name = try pixi.app.allocator.dupe(u8, file.animations.items(.name)[anim_index]),
                            },
                        }) catch {
                            dvui.log.err("Failed to append history", .{});
                        };
                        pixi.app.allocator.free(file.animations.items(.name)[anim_index]);
                        file.animations.items(.name)[anim_index] = try pixi.app.allocator.dupe(u8, te.getText());
                    }
                    self.edit_anim_id = null;
                }
            }

            // if (reorderable.drag_point == null) {
            //     var button_box = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .none, .background = false, .gravity_x = 1.0, .min_size_content = .{ .w = 20.0, .h = 20.0 } });
            //     defer button_box.deinit();
            // }

            // This consumes the click event, so we need to do this last
            if (dvui.clicked(hbox.data(), .{ .hover_cursor = .hand })) {
                file.selected_animation_index = anim_index;
            }

            if (file.editor.animations_scroll_to_index != null and dvui.timerGet(hbox.data().id) == null) {
                dvui.timer(hbox.data().id, 1);
            }

            if (dvui.timerDone(hbox.data().id)) {
                if (file.editor.animations_scroll_to_index) |index| {
                    if (index == anim_index) {
                        dvui.scrollTo(.{ .screen_rect = hbox.data().rectScale().r, .over_scroll = true });
                        file.editor.animations_scroll_to_index = null;
                    }
                }
            }
        }

        if (reorderable.finalSlot()) {
            self.animation_insert_before_index = file.animations.len;
        }

        // Only draw shadow if the scroll bar has been scrolled some
        if (vertical_scroll > 0.0)
            pixi.dvui.drawEdgeShadow(scroll_area.data().contentRectScale(), .top, .{});

        if (file.editor.animations_scroll_info.virtual_size.h > file.editor.animations_scroll_info.viewport.h and vertical_scroll < file.editor.animations_scroll_info.scrollMax(.vertical))
            pixi.dvui.drawEdgeShadow(scroll_area.data().contentRectScale(), .bottom, .{});
    }
}

pub fn drawFrameControls(_: *Sprites) !void {
    var box = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .horizontal,
        // .background = true,
        // .color_fill = dvui.themeGet().color(.control, .fill),
        // .corner_radius = dvui.Rect.all(1000),
        // .margin = dvui.Rect.all(4),
        // .padding = dvui.Rect.all(0),
        // .border = dvui.Rect.all(1.0),
        // .color_border = dvui.themeGet().color(.control, .fill),
        // .box_shadow = .{
        //     .color = .black,
        //     .offset = .{ .x = -2.0, .y = 2.0 },
        //     .fade = 6.0,
        //     .alpha = 0.25,
        //     .corner_radius = dvui.Rect.all(1000),
        // },
    });
    defer box.deinit();

    if (pixi.editor.activeFile()) |file| {
        if (file.selected_animation_index) |index| {
            var animation = file.animations.get(index);

            var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .expand = .none,
                .background = false,
                //.gravity_x = 1.0,
            });
            defer hbox.deinit();

            if (dvui.buttonIcon(@src(), "SortAnimationAsc", icons.tvg.lucide.@"arrow-up-from-line", .{}, .{}, .{
                .expand = .none,
                .gravity_y = 0.5,
                .corner_radius = dvui.Rect.all(1000),
                .box_shadow = .{
                    .color = .black,
                    .offset = .{ .x = -2.0, .y = 2.0 },
                    .fade = 6.0,
                    .alpha = 0.15,
                    .corner_radius = dvui.Rect.all(1000),
                },
                .color_fill = dvui.themeGet().color(.control, .fill),
            })) {
                std.mem.sort(usize, animation.frames, {}, comptime std.sort.asc(usize));
                file.animations.set(index, animation);
            }

            if (dvui.buttonIcon(@src(), "SortAnimationDec", icons.tvg.lucide.@"arrow-down-from-line", .{}, .{}, .{
                .expand = .none,
                .gravity_y = 0.5,
                .corner_radius = dvui.Rect.all(1000),
                .box_shadow = .{
                    .color = .black,
                    .offset = .{ .x = -2.0, .y = 2.0 },
                    .fade = 6.0,
                    .alpha = 0.15,
                    .corner_radius = dvui.Rect.all(1000),
                },
                .color_fill = dvui.themeGet().color(.control, .fill),
            })) {
                std.mem.sort(usize, animation.frames, {}, comptime std.sort.desc(usize));
                file.animations.set(index, animation);
            }

            if (file.editor.selected_sprites.count() > 0) {
                if (dvui.buttonIcon(@src(), "AddSprite", icons.tvg.lucide.plus, .{}, .{}, .{
                    .expand = .none,
                    .gravity_y = 0.5,
                    .corner_radius = dvui.Rect.all(1000),
                    .box_shadow = .{
                        .color = .black,
                        .offset = .{ .x = -2.0, .y = 2.0 },
                        .fade = 6.0,
                        .alpha = 0.15,
                        .corner_radius = dvui.Rect.all(1000),
                    },
                    .color_fill = dvui.themeGet().color(.control, .fill),
                })) {
                    var iter = file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
                    var frames = std.array_list.Managed(usize).init(dvui.currentWindow().arena());
                    while (iter.next()) |sprite_index| {
                        frames.append(sprite_index) catch {
                            dvui.log.err("Failed to append frame", .{});
                            return;
                        };
                    }

                    animation.appendFrames(pixi.app.allocator, frames.items) catch {
                        dvui.log.err("Failed to append frames", .{});
                    };

                    file.animations.set(index, animation);
                }

                var show_delete_button = false;

                var selection_iter = file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
                blk: while (selection_iter.next()) |sprite_index| {
                    for (animation.frames) |frame_sprite_index| {
                        if (frame_sprite_index == sprite_index) {
                            show_delete_button = true;
                            break :blk;
                        }
                    }
                }

                if (!show_delete_button) return;

                if (dvui.buttonIcon(@src(), "DeleteSprite", icons.tvg.lucide.trash, .{}, .{ .stroke_color = dvui.themeGet().color(.window, .fill) }, .{
                    .style = .err,
                    .expand = .none,
                    .gravity_y = 0.5,
                    .corner_radius = dvui.Rect.all(1000),
                    .box_shadow = .{
                        .color = .black,
                        .offset = .{ .x = -2.0, .y = 2.0 },
                        .fade = 6.0,
                        .alpha = 0.15,
                        .corner_radius = dvui.Rect.all(1000),
                    },
                })) {
                    var iter = file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
                    while (iter.next()) |sprite_index| {
                        for (animation.frames, 0..) |frame_sprite_index, i| {
                            if (frame_sprite_index == sprite_index) {
                                animation.removeFrame(pixi.app.allocator, i);
                                break;
                            }
                        }
                    }

                    file.animations.set(index, animation);
                }
            }
        }
    }
}

pub fn drawFrames(self: *Sprites) !void {
    if (pixi.editor.activeFile()) |file| {
        const controls_box = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .horizontal,
            .background = false,
        });
        defer controls_box.deinit();

        dvui.labelNoFmt(@src(), "FRAMES", .{}, .{ .font_style = .title_4 });

        self.drawFrameControls() catch {};

        const vbox = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .horizontal,
            .background = false,
            .color_fill = dvui.themeGet().color(.content, .fill),
            .max_size_content = .{ .w = pixi.editor.explorer.rect.w / 2.0, .h = std.math.floatMax(f32) },
        });
        defer vbox.deinit();

        var scroll_area = dvui.scrollArea(@src(), .{ .scroll_info = &file.editor.sprites_scroll_info }, .{
            .expand = .horizontal,
            .background = false,
            .corner_radius = dvui.Rect.all(1000),
        });

        defer scroll_area.deinit();

        const vertical_scroll = file.editor.sprites_scroll_info.offset(.vertical);

        if (file.selected_animation_index) |animation_index| {
            var animation = file.animations.get(animation_index);

            defer self.prev_sprite_count = animation.frames.len;
            defer self.prev_anim_id = animation.id;

            var reorder = pixi.dvui.reorder(@src(), .{ .drag_name = "sprite_drag" }, .{
                .expand = .horizontal,
                .background = false,
            });
            defer reorder.deinit();

            //var sprite = file.sprites.get(frame);

            // Drag and drop is completing
            if (self.sprite_insert_before_index) |_| {
                if (self.sprite_removed_index) |_| {
                    const prev_order = try dvui.currentWindow().arena().dupe(usize, animation.frames);

                    // file.animations.orderedRemove(removed);

                    // if (insert_before <= file.animations.len) {
                    //     file.animations.insert(pixi.app.allocator, if (removed < insert_before) insert_before - 1 else insert_before, anim) catch {
                    //         dvui.log.err("Failed to insert animation", .{});
                    //     };
                    // } else {
                    //     file.animations.insert(pixi.app.allocator, if (removed < insert_before) file.animations.len else 0, anim) catch {
                    //         dvui.log.err("Failed to insert animation", .{});
                    //     };
                    // }

                    // if (removed == file.selected_animation_index) {
                    //     if (insert_before < file.animations.len) {
                    //         file.selected_animation_index = if (removed < insert_before) insert_before - 1 else insert_before;
                    //     } else {
                    //         file.selected_animation_index = 0;
                    //     }
                    // }

                    if (!std.mem.eql(u64, animation.frames[0..animation.frames.len], prev_order)) {
                        file.history.append(.{
                            .animation_frames = .{
                                .index = animation_index,
                                .frames = animation.frames,
                            },
                        }) catch {
                            dvui.log.err("Failed to append history", .{});
                        };
                    }

                    self.sprite_insert_before_index = null;
                    self.sprite_removed_index = null;
                }
            }

            const box = dvui.box(@src(), .{ .dir = .vertical }, .{
                .expand = .horizontal,
                .margin = dvui.Rect.all(4),
            });
            defer box.deinit();

            for (animation.frames, 0..) |frame, frame_index| {
                var color = dvui.themeGet().color(.control, .fill_hover);
                if (pixi.editor.colors.file_tree_palette) |*palette| {
                    color = palette.getDVUIColor(animation.id);
                }

                var r = reorder.reorderable(@src(), .{}, .{
                    .id_extra = frame_index,
                    .expand = .horizontal,
                    .corner_radius = dvui.Rect.all(1000),
                    .min_size_content = .{ .w = 0.0, .h = reorder.reorderable_size.h },
                });
                defer r.deinit();

                if (dvui.firstFrame(r.data().id) or self.prev_sprite_count != animation.frames.len or self.prev_anim_id != animation.id) {
                    dvui.animation(r.data().id, "sprite_expand", .{
                        .start_val = 0.2,
                        .end_val = 1.0,
                        .end_time = 150_000 + (50_000 * @as(i32, @intCast(frame_index))),
                        .easing = dvui.easing.inOutQuad,
                    });
                }

                if (dvui.animationGet(r.data().id, "sprite_expand")) |a| {
                    if (dvui.minSizeGet(r.data().id)) |ms| {
                        if (r.data().rect.w > ms.w + 0.001) {
                            // we are bigger than our min size (maybe expanded) - account for floating point
                            const w = r.data().rect.w;
                            r.data().rect.w *= @max(a.value(), 0);
                            r.data().rect.x += r.data().options.gravityGet().x * (w - r.data().rect.w);
                        }
                    }
                }

                if (r.removed()) {
                    self.sprite_removed_index = frame_index;
                } else if (r.insertBefore()) {
                    self.sprite_insert_before_index = frame_index;
                }

                const selected = file.editor.selected_sprites.isSet(frame);
                const hovered = pixi.dvui.hovered(r.data());

                var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
                    .expand = .both,
                    .background = true,
                    .color_fill = if (hovered) dvui.themeGet().color(.control, .fill_hover) else dvui.themeGet().color(.control, .fill),
                    .corner_radius = dvui.Rect.all(1000),
                    .margin = dvui.Rect.all(2),
                    .padding = dvui.Rect.all(1),
                    .border = dvui.Rect.all(1.0),
                    .color_border = if (selected) dvui.themeGet().color(.highlight, .fill) else dvui.themeGet().color(.control, .fill),
                    .box_shadow = .{
                        .color = .black,
                        .offset = .{ .x = -2.0, .y = 2.0 },
                        .fade = 6.0,
                        .alpha = 0.25,
                        .corner_radius = dvui.Rect.all(1000),
                    },
                });
                defer hbox.deinit();

                _ = pixi.dvui.ReorderWidget.draggable(@src(), .{
                    .reorderable = r,
                    .tvg_bytes = icons.tvg.lucide.@"grip-horizontal",
                    .color = dvui.themeGet().color(.control, .text),
                }, .{
                    .expand = .none,
                    .gravity_y = 0.5,
                    .margin = .{ .x = 4, .w = 4 },
                });

                dvui.labelNoFmt(@src(), try file.spriteName(pixi.app.allocator, frame, false), .{}, .{
                    .gravity_y = 0.5,
                    .margin = dvui.Rect.all(2),
                    .font_style = .body,
                    .padding = dvui.Rect.all(0),
                    .color_text = if (selected) dvui.themeGet().color(.window, .text) else dvui.themeGet().color(.control, .text),
                });

                // if (self.edit_anim_id != animation.id) {
                //     if (file.selected_animation_index == anim_index) {
                //         if (dvui.labelClick(@src(), "{s}", .{file.animations.items(.name)[anim_index]}, .{}, .{
                //             .gravity_y = 0.5,
                //             .font_style = .body,
                //             .margin = dvui.Rect.all(2),
                //             .padding = dvui.Rect.all(0),
                //             .color_text = if (!selected) dvui.themeGet().color(.control, .text) else dvui.themeGet().color(.window, .text),
                //         })) {
                //             self.edit_anim_id = anim_id;
                //         }
                //     } else {
                //         dvui.labelNoFmt(@src(), file.animations.items(.name)[anim_index], .{}, .{
                //             .gravity_y = 0.5,
                //             .margin = dvui.Rect.all(2),
                //             .font_style = .body,
                //             .padding = dvui.Rect.all(0),
                //             .color_text = if (!selected) dvui.themeGet().color(.control, .text) else dvui.themeGet().color(.window, .text),
                //         });
                //     }
                // } else {
                //     var te = dvui.textEntry(@src(), .{}, .{
                //         .expand = .horizontal,
                //         .background = false,
                //         .padding = dvui.Rect.all(0),
                //         .margin = dvui.Rect.all(0),
                //         .font_style = .body,
                //         .gravity_y = 0.5,
                //     });
                //     defer te.deinit();

                //     if (dvui.firstFrame(te.data().id)) {
                //         te.textSet(file.animations.items(.name)[anim_index], true);
                //         dvui.focusWidget(te.data().id, null, null);
                //     }

                //     if (te.enter_pressed or dvui.focusedWidgetId() != te.data().id) {
                //         if (!std.mem.eql(u8, file.animations.items(.name)[anim_index], te.getText()) and te.getText().len > 0) {
                //             file.history.append(.{
                //                 .animation_name = .{
                //                     .index = anim_index,
                //                     .name = try pixi.app.allocator.dupe(u8, file.animations.items(.name)[anim_index]),
                //                 },
                //             }) catch {
                //                 dvui.log.err("Failed to append history", .{});
                //             };
                //             pixi.app.allocator.free(file.animations.items(.name)[anim_index]);
                //             file.animations.items(.name)[anim_index] = try pixi.app.allocator.dupe(u8, te.getText());
                //         }
                //         self.edit_anim_id = null;
                //     }
                // }

                if (reorder.drag_point == null and frame_index == file.selected_animation_frame_index) {
                    var button_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
                        .expand = .ratio,
                        .gravity_x = 1.0,
                        .min_size_content = .{ .w = 5.0, .h = 5.0 },
                        .corner_radius = dvui.Rect.all(1000),
                        .background = true,
                        .color_fill = color,
                        .box_shadow = .{
                            .color = .black,
                            .offset = .{ .x = -2.0, .y = 2.0 },
                            .fade = 6.0,
                            .alpha = 0.25,
                            .corner_radius = dvui.Rect.all(1000),
                        },
                    });
                    defer button_box.deinit();
                }

                // This consumes the click event, so we need to do this last
                if (dvui.clickedEx(hbox.data(), .{ .hover_cursor = .hand })) |e| {
                    if (e == .mouse) {
                        if (e.mouse.mod.matchBind("ctrl/cmd")) {
                            file.editor.selected_sprites.set(frame);
                        } else if (e.mouse.mod.matchBind("shift")) {
                            file.editor.selected_sprites.unset(frame);
                        } else {
                            file.editor.selected_sprites.setRangeValue(.{ .start = 0, .end = file.editor.selected_sprites.capacity() }, false);
                            file.editor.selected_sprites.set(frame);
                            file.selected_animation_frame_index = frame_index;
                        }
                    }
                }

                // if (file.editor.animations_scroll_to_index) |index| {
                //     if (index == anim_index) {
                //         dvui.scrollTo(.{ .screen_rect = hbox.data().rectScale().r });
                //         file.editor.animations_scroll_to_index = null;
                //     }
                // }
            }

            if (reorder.finalSlot()) {
                self.sprite_insert_before_index = animation.frames.len;
            }
        }

        // Only draw shadow if the scroll bar has been scrolled some
        if (vertical_scroll > 0.0)
            pixi.dvui.drawEdgeShadow(scroll_area.data().contentRectScale(), .top, .{});

        if (file.editor.sprites_scroll_info.virtual_size.h > file.editor.sprites_scroll_info.viewport.h and vertical_scroll < file.editor.animations_scroll_info.scrollMax(.vertical))
            pixi.dvui.drawEdgeShadow(scroll_area.data().contentRectScale(), .bottom, .{});
    }
}
