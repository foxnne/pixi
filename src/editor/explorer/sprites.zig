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
prev_anim_count: usize = 0,
prev_anim_id: u64 = 0,
prev_sprite_count: usize = 0,

pub fn init() Sprites {
    return .{};
}

pub fn draw(self: *Sprites) !void {
    if (pixi.editor.activeFile()) |file| {
        const parent_height = dvui.parentGet().data().rect.h - 2.0 * dvui.currentWindow().natural_scale;
        const parent_data = dvui.parentGet().data();

        const vbox = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .both,
            .max_size_content = .{ .w = std.math.floatMax(f32), .h = parent_height },
        });
        defer vbox.deinit();

        const hbox = dvui.box(@src(), .{
            .dir = .horizontal,
            .equal_space = false,
        }, .{
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

        for (dvui.events()) |*e| {
            if (e.evt == .mouse and e.evt.mouse.action == .press) {
                if (dvui.eventMatchSimple(e, parent_data)) {
                    file.clearSelectedSprites();
                }
            }
        }
    }
}

pub fn drawOriginControls(_: *Sprites) !void {
    var preview_origin_x: ?f32 = null;
    var preview_origin_y: ?f32 = null;

    if (pixi.editor.activeFile()) |file| {
        if (file.editor.selected_sprites.findFirstSet()) |first_sprite_index| {
            const first_sprite = file.sprites.get(first_sprite_index);

            preview_origin_x = first_sprite.origin[0];
            preview_origin_y = first_sprite.origin[1];

            var iter = file.editor.selected_sprites.iterator(.{ .direction = .forward, .kind = .set });
            while (iter.next()) |selected_sprite_index| {
                const selected_sprite = file.sprites.get(selected_sprite_index);

                if (selected_sprite.origin[0] != preview_origin_x) {
                    preview_origin_x = null;
                }

                if (selected_sprite.origin[1] != preview_origin_y) {
                    preview_origin_y = null;
                }

                if (preview_origin_x == null and preview_origin_y == null) {
                    // We already know we have mixed origin sizes, so the origins are not unified
                    break;
                }
            }
        }
    }
}

pub fn drawAnimationControls(self: *Sprites) !void {
    var box = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .none,
    });
    defer box.deinit();

    const icon_color = dvui.themeGet().color(.control, .text);

    if (pixi.editor.activeFile()) |file| {
        {
            var add_animation_button: dvui.ButtonWidget = undefined;
            add_animation_button.init(@src(), .{}, .{
                .expand = .none,
                .gravity_y = 0.5,
                .padding = dvui.Rect.all(4),
                .corner_radius = dvui.Rect.all(1000),
                .box_shadow = .{
                    .color = .black,
                    .offset = .{ .x = -2.0, .y = 2.0 },
                    .fade = 6.0,
                    .alpha = 0.15,
                    .corner_radius = dvui.Rect.all(1000),
                },
                .color_fill = dvui.themeGet().color(.control, .fill),
            });
            defer add_animation_button.deinit();

            add_animation_button.processEvents();
            add_animation_button.drawBackground();

            dvui.icon(
                @src(),
                "AddAnimationIcon",
                icons.tvg.lucide.plus,
                .{
                    .fill_color = icon_color,
                    .stroke_color = icon_color,
                },
                .{
                    .gravity_x = 0.5,
                    .gravity_y = 0.5,
                    .expand = .ratio,
                    .color_text = add_animation_button.data().options.color_text,
                    .margin = dvui.Rect.all(0),
                    .padding = dvui.Rect.all(0),
                },
            );

            if (add_animation_button.clicked()) {
                const anim_index = try file.createAnimation();
                file.selected_animation_index = anim_index;
                file.editor.animations_scroll_to_index = anim_index;
                self.edit_anim_id = file.animations.items(.id)[anim_index];

                file.history.append(.{
                    .animation_restore_delete = .{
                        .action = .delete,
                        .index = anim_index,
                    },
                }) catch {
                    dvui.log.err("Failed to append history", .{});
                };
            }
        }

        {
            var duplicate_animation_button: dvui.ButtonWidget = undefined;
            duplicate_animation_button.init(@src(), .{}, .{
                .expand = .none,
                .gravity_y = 0.5,
                .padding = dvui.Rect.all(4),
                .corner_radius = dvui.Rect.all(1000),
                .box_shadow = .{
                    .color = .black,
                    .offset = .{ .x = -2.0, .y = 2.0 },
                    .fade = 6.0,
                    .alpha = 0.15,
                    .corner_radius = dvui.Rect.all(1000),
                },
                .color_fill = dvui.themeGet().color(.control, .fill),
            });

            defer duplicate_animation_button.deinit();
            duplicate_animation_button.processEvents();
            const alpha = dvui.alpha(if (file.selected_animation_index != null and file.animations.len > 0) 1.0 else 0.5);
            duplicate_animation_button.drawBackground();

            dvui.icon(
                @src(),
                "DuplicateAnimationIcon",
                icons.tvg.lucide.@"copy-plus",
                .{ .fill_color = icon_color, .stroke_color = icon_color },
                .{
                    .gravity_x = 0.5,
                    .gravity_y = 0.5,
                    .expand = .ratio,
                    .color_text = duplicate_animation_button.data().options.color_text,
                    .margin = dvui.Rect.all(0),
                    .padding = dvui.Rect.all(0),
                },
            );

            dvui.alphaSet(alpha);

            if (duplicate_animation_button.clicked()) {
                if (file.animations.len > 0) {
                    if (file.selected_animation_index) |index| {
                        const anim_index = try file.duplicateAnimation(index);
                        file.selected_animation_index = anim_index;
                        file.editor.animations_scroll_to_index = anim_index;
                        self.edit_anim_id = file.animations.items(.id)[anim_index];

                        file.history.append(.{
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
        }

        {
            var delete_animation_button: dvui.ButtonWidget = undefined;
            delete_animation_button.init(@src(), .{}, .{
                .expand = .none,
                .gravity_y = 0.5,
                .padding = dvui.Rect.all(4),
                .corner_radius = dvui.Rect.all(1000),
                .box_shadow = .{
                    .color = .black,
                    .offset = .{ .x = -2.0, .y = 2.0 },
                    .fade = 6.0,
                    .alpha = 0.15,
                    .corner_radius = dvui.Rect.all(1000),
                },
                .color_fill = dvui.themeGet().color(.err, .fill).opacity(0.75),
            });
            defer delete_animation_button.deinit();
            delete_animation_button.processEvents();

            const alpha = dvui.alpha(if (file.selected_animation_index != null and file.animations.len > 0) 1.0 else 0.5);
            delete_animation_button.drawBackground();

            dvui.icon(
                @src(),
                "DeleteAnimationIcon",
                icons.tvg.lucide.trash,
                .{ .fill_color = dvui.themeGet().color(.window, .fill), .stroke_color = dvui.themeGet().color(.window, .fill) },
                .{
                    .gravity_x = 0.5,
                    .gravity_y = 0.5,
                    .expand = .ratio,
                    .margin = dvui.Rect.all(0),
                    .padding = dvui.Rect.all(0),
                },
            );

            dvui.alphaSet(alpha);

            if (delete_animation_button.clicked()) {
                if (file.animations.len > 0) {
                    if (file.selected_animation_index) |index| {
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
}

pub fn drawAnimations(self: *Sprites) !void {
    const outer_box = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .horizontal,
        .background = false,
    });
    defer outer_box.deinit();

    const parent_width = dvui.parentGet().data().rect.w;
    const controls_box = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .horizontal,
        .background = false,
    });
    dvui.labelNoFmt(@src(), "ANIMATIONS", .{}, .{ .font = dvui.Font.theme(.title).larger(-3.0).withWeight(.bold) });

    self.drawAnimationControls() catch {};

    controls_box.deinit();

    if (pixi.editor.activeFile()) |file| {
        // Make sure to update the prev anim count!
        defer self.prev_anim_count = file.animations.len;

        var scroll_area = dvui.scrollArea(@src(), .{
            .scroll_info = &file.editor.animations_scroll_info,
            .horizontal_bar = .auto_overlay,
            .vertical_bar = .auto_overlay,
        }, .{
            .expand = .horizontal,
            .background = false,

            .max_size_content = .{ .h = std.math.floatMax(f32), .w = parent_width / 2.0 },
        });
        defer scroll_area.deinit();

        var inner_box = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .both,
            .background = false,
            .margin = .{ .h = 6, .w = 6 },
        });
        defer inner_box.deinit();

        defer {
            if (file.editor.animations_scroll_info.viewport.w < file.editor.animations_scroll_info.virtual_size.w) {
                if (file.editor.animations_scroll_info.offset(.horizontal) < file.editor.animations_scroll_info.scrollMax(.horizontal)) {
                    pixi.dvui.drawEdgeShadow(scroll_area.data().contentRectScale(), .right, .{});
                }
                if (file.editor.animations_scroll_info.offset(.horizontal) > 0.0) {
                    pixi.dvui.drawEdgeShadow(scroll_area.data().contentRectScale(), .left, .{});
                }
            }
        }

        const vertical_scroll = file.editor.animations_scroll_info.offset(.vertical);

        var reorderable = pixi.dvui.reorder(@src(), .{ .drag_name = "anim_drag" }, .{
            .expand = .horizontal,
            .background = false,
        });
        defer reorderable.deinit();

        // Drag and drop is completing
        if (self.animation_insert_before_index) |insert_before| {
            if (self.animation_removed_index) |removed| {
                //const prev_order = try pixi.app.allocator.dupe(pixi.Animation.Frame, file.animations.items(.id));

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

                // if (!std.mem.eql(u64, file.animations.items(.id)[0..file.animations.len], prev_order)) {
                //     file.history.append(.{
                //         .animation_order = .{
                //             .order = prev_order,
                //             .selected = file.animations.items(.id)[file.selected_animation_index orelse 0],
                //         },
                //     }) catch {
                //         dvui.log.err("Failed to append history", .{});
                //     };
                // }

                self.animation_insert_before_index = null;
                self.animation_removed_index = null;
            }
        }

        const box = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .horizontal,
            .margin = dvui.Rect.all(4),
        });
        defer box.deinit();

        const total_duration: i32 = 600_000;
        const max_step_duration: i32 = @divTrunc(total_duration, 3);

        var duration_step: i32 = max_step_duration;

        if (file.animations.len > 0) {
            duration_step = std.math.clamp(@divTrunc(total_duration, @as(i32, @intCast(file.animations.len))), 0, max_step_duration);
        }

        for (file.animations.items(.id), 0..) |anim_id, anim_index| {
            const duration = max_step_duration + (duration_step * @as(i32, @intCast(anim_index + 1)));

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
                    .end_time = duration,
                    .easing = dvui.easing.outBack,
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

            const font = dvui.Font.theme(.mono).larger(-2.0);
            const padding: dvui.Rect = .{ .w = 6 };

            if (self.edit_anim_id != anim_id) {
                if (file.selected_animation_index == anim_index) {
                    if (dvui.labelClick(@src(), "{s}", .{file.animations.items(.name)[anim_index]}, .{}, .{
                        .gravity_y = 0.5,
                        .font = font,
                        .margin = dvui.Rect.all(2),
                        .padding = padding,
                        .color_text = if (!selected) dvui.themeGet().color(.control, .text) else dvui.themeGet().color(.window, .text),
                    })) {
                        self.edit_anim_id = anim_id;
                    }
                } else {
                    dvui.labelNoFmt(@src(), file.animations.items(.name)[anim_index], .{ .ellipsize = true }, .{
                        .gravity_y = 0.5,
                        .margin = dvui.Rect.all(2),
                        .font = font,
                        .padding = padding,
                        .color_text = if (!selected) dvui.themeGet().color(.control, .text) else dvui.themeGet().color(.window, .text),
                    });
                }
            } else {
                var te = dvui.textEntry(@src(), .{}, .{
                    .expand = .horizontal,
                    .background = false,
                    .padding = padding,
                    .margin = dvui.Rect.all(0),
                    .font = font,
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
                const anim = file.animations.get(anim_index);
                if (anim.frames.len > 0) {
                    if (file.selected_animation_frame_index >= anim.frames.len) {
                        file.selected_animation_frame_index = anim.frames.len - 1;
                    }
                } else {
                    file.selected_animation_frame_index = 0;
                }
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

        if (reorderable.finalSlot(.default)) {
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
    var box = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .none,
    });
    defer box.deinit();

    if (pixi.editor.activeFile()) |file| {
        const index = if (file.selected_animation_index) |i| i else 0;
        var animation = file.animations.get(index);

        const icon_color = dvui.themeGet().color(.control, .text);

        {
            var sort_anim_asc_button: dvui.ButtonWidget = undefined;
            sort_anim_asc_button.init(@src(), .{}, .{
                .expand = .none,
                .gravity_y = 0.5,
                .padding = dvui.Rect.all(4),
                .corner_radius = dvui.Rect.all(1000),
                .box_shadow = .{
                    .color = .black,
                    .offset = .{ .x = -2.0, .y = 2.0 },
                    .fade = 6.0,
                    .alpha = 0.15,
                    .corner_radius = dvui.Rect.all(1000),
                },
                .color_fill = dvui.themeGet().color(.control, .fill),
            });

            defer sort_anim_asc_button.deinit();
            sort_anim_asc_button.processEvents();
            const alpha = dvui.alpha(if (file.selected_animation_index != null and file.animations.len > 0) 1.0 else 0.5);
            sort_anim_asc_button.drawBackground();

            dvui.icon(
                @src(),
                "SortAnimationAscIcon",
                icons.tvg.lucide.@"arrow-up-from-line",
                .{ .fill_color = icon_color, .stroke_color = icon_color },
                .{
                    .gravity_x = 0.5,
                    .gravity_y = 0.5,
                    .expand = .ratio,
                    .color_text = sort_anim_asc_button.data().options.color_text,
                    .margin = dvui.Rect.all(0),
                    .padding = dvui.Rect.all(0),
                },
            );

            dvui.alphaSet(alpha);

            if (sort_anim_asc_button.clicked()) {
                const prev_order = try pixi.app.allocator.dupe(pixi.Animation.Frame, animation.frames);
                std.mem.sort(pixi.Animation.Frame, animation.frames, {}, FrameSort.asc);

                if (!animation.eqlFrames(prev_order)) {
                    file.history.append(.{
                        .animation_frames = .{
                            .index = index,
                            .frames = prev_order,
                        },
                    }) catch {
                        dvui.log.err("Failed to append history", .{});
                    };

                    file.animations.set(index, animation);
                } else {
                    pixi.app.allocator.free(prev_order);
                }
            }
        }
        {
            {
                var sort_anim_desc_button: dvui.ButtonWidget = undefined;
                sort_anim_desc_button.init(@src(), .{}, .{
                    .expand = .none,
                    .gravity_y = 0.5,
                    .padding = dvui.Rect.all(4),
                    .corner_radius = dvui.Rect.all(1000),
                    .box_shadow = .{
                        .color = .black,
                        .offset = .{ .x = -2.0, .y = 2.0 },
                        .fade = 6.0,
                        .alpha = 0.15,
                        .corner_radius = dvui.Rect.all(1000),
                    },
                    .color_fill = dvui.themeGet().color(.control, .fill),
                });

                defer sort_anim_desc_button.deinit();
                sort_anim_desc_button.processEvents();
                const alpha = dvui.alpha(if (file.selected_animation_index != null and file.animations.len > 0) 1.0 else 0.5);
                sort_anim_desc_button.drawBackground();

                dvui.icon(
                    @src(),
                    "SortAnimationDescIcon",
                    icons.tvg.lucide.@"arrow-down-from-line",
                    .{ .fill_color = icon_color, .stroke_color = icon_color },
                    .{
                        .gravity_x = 0.5,
                        .gravity_y = 0.5,
                        .expand = .ratio,
                        .color_text = sort_anim_desc_button.data().options.color_text,
                        .margin = dvui.Rect.all(0),
                        .padding = dvui.Rect.all(0),
                    },
                );

                dvui.alphaSet(alpha);

                if (sort_anim_desc_button.clicked()) {
                    const prev_order = try pixi.app.allocator.dupe(pixi.Animation.Frame, animation.frames);
                    std.mem.sort(pixi.Animation.Frame, animation.frames, {}, FrameSort.desc);

                    if (!animation.eqlFrames(prev_order)) {
                        file.history.append(.{
                            .animation_frames = .{
                                .index = index,
                                .frames = prev_order,
                            },
                        }) catch {
                            dvui.log.err("Failed to append history", .{});
                        };

                        file.animations.set(index, animation);
                    } else {
                        pixi.app.allocator.free(prev_order);
                    }
                }
            }
        }

        {
            var add_sprite_button: dvui.ButtonWidget = undefined;
            add_sprite_button.init(@src(), .{}, .{
                .expand = .none,
                .gravity_y = 0.5,
                .padding = dvui.Rect.all(4),
                .corner_radius = dvui.Rect.all(1000),
                .box_shadow = .{
                    .color = .black,
                    .offset = .{ .x = -2.0, .y = 2.0 },
                    .fade = 6.0,
                    .alpha = 0.15,
                    .corner_radius = dvui.Rect.all(1000),
                },
                .color_fill = dvui.themeGet().color(.control, .fill),
            });

            defer add_sprite_button.deinit();
            add_sprite_button.processEvents();
            const alpha = dvui.alpha(if (file.selected_animation_index != null and file.animations.len > 0) 1.0 else 0.5);
            add_sprite_button.drawBackground();

            dvui.icon(
                @src(),
                "AddSpriteIcon",
                icons.tvg.lucide.plus,
                .{ .fill_color = icon_color, .stroke_color = icon_color },
                .{
                    .gravity_x = 0.5,
                    .gravity_y = 0.5,
                    .expand = .ratio,
                    .color_text = add_sprite_button.data().options.color_text,
                    .margin = dvui.Rect.all(0),
                    .padding = dvui.Rect.all(0),
                },
            );

            dvui.alphaSet(alpha);

            if (add_sprite_button.clicked()) {
                if (file.editor.selected_sprites.count() > 0) {
                    var iter = file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
                    var frames = std.array_list.Managed(pixi.Animation.Frame).init(dvui.currentWindow().arena());
                    while (iter.next()) |sprite_index| {
                        frames.append(.{
                            .sprite_index = sprite_index,
                            .ms = @intFromFloat(1000.0 / @as(f32, @floatFromInt(file.editor.selected_sprites.count()))),
                        }) catch {
                            dvui.log.err("Failed to append frame", .{});
                            return;
                        };
                    }

                    const prev_order = try pixi.app.allocator.dupe(pixi.Animation.Frame, animation.frames);

                    animation.appendFrames(pixi.app.allocator, frames.items) catch {
                        dvui.log.err("Failed to append frames", .{});
                    };

                    if (!animation.eqlFrames(prev_order)) {
                        file.history.append(.{
                            .animation_frames = .{
                                .index = index,
                                .frames = prev_order,
                            },
                        }) catch {
                            dvui.log.err("Failed to append history", .{});
                        };

                        file.animations.set(index, animation);
                    } else {
                        pixi.app.allocator.free(prev_order);
                    }
                }
            }
        }

        var selection_in_animation = false;

        var selection_iter = file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
        blk: while (selection_iter.next()) |sprite_index| {
            for (animation.frames) |frame| {
                if (frame.sprite_index == sprite_index) {
                    selection_in_animation = true;
                    break :blk;
                }
            }
        }

        {
            var duplicate_animation_button: dvui.ButtonWidget = undefined;
            duplicate_animation_button.init(@src(), .{}, .{
                .expand = .none,
                .gravity_y = 0.5,
                .padding = dvui.Rect.all(4),
                .corner_radius = dvui.Rect.all(1000),
                .box_shadow = .{
                    .color = .black,
                    .offset = .{ .x = -2.0, .y = 2.0 },
                    .fade = 6.0,
                    .alpha = 0.15,
                    .corner_radius = dvui.Rect.all(1000),
                },
                .color_fill = dvui.themeGet().color(.control, .fill),
            });

            defer duplicate_animation_button.deinit();
            duplicate_animation_button.processEvents();
            const alpha = dvui.alpha(if (selection_in_animation) 1.0 else 0.5);
            duplicate_animation_button.drawBackground();

            dvui.icon(
                @src(),
                "DuplicateAnimationIcon",
                icons.tvg.lucide.@"copy-plus",
                .{ .fill_color = icon_color, .stroke_color = icon_color },
                .{
                    .gravity_x = 0.5,
                    .gravity_y = 0.5,
                    .expand = .ratio,
                    .color_text = duplicate_animation_button.data().options.color_text,
                    .margin = dvui.Rect.all(0),
                    .padding = dvui.Rect.all(0),
                },
            );

            dvui.alphaSet(alpha);

            if (duplicate_animation_button.clicked()) {
                var iter = file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
                const prev_order = try pixi.app.allocator.dupe(pixi.Animation.Frame, animation.frames);

                while (iter.next()) |sprite_index| {
                    for (animation.frames) |frame| {
                        if (frame.sprite_index == sprite_index) {
                            try animation.appendFrame(pixi.app.allocator, .{
                                .sprite_index = frame.sprite_index,
                                .ms = frame.ms,
                            });
                            break;
                        }
                    }
                }

                if (!animation.eqlFrames(prev_order)) {
                    file.history.append(.{
                        .animation_frames = .{
                            .index = index,
                            .frames = prev_order,
                        },
                    }) catch {
                        dvui.log.err("Failed to append history", .{});
                    };
                    file.selected_animation_frame_index = 0;
                    file.animations.set(index, animation);
                } else {
                    pixi.app.allocator.free(prev_order);
                }
            }
        }

        {
            var delete_animation_button: dvui.ButtonWidget = undefined;
            delete_animation_button.init(@src(), .{}, .{
                .expand = .none,
                .gravity_y = 0.5,
                .padding = dvui.Rect.all(4),
                .corner_radius = dvui.Rect.all(1000),
                .box_shadow = .{
                    .color = .black,
                    .offset = .{ .x = -2.0, .y = 2.0 },
                    .fade = 6.0,
                    .alpha = 0.15,
                    .corner_radius = dvui.Rect.all(1000),
                },
                .color_fill = dvui.themeGet().color(.err, .fill).opacity(0.75),
            });

            defer delete_animation_button.deinit();
            delete_animation_button.processEvents();
            const alpha = dvui.alpha(if (selection_in_animation) 1.0 else 0.5);
            delete_animation_button.drawBackground();

            dvui.icon(
                @src(),
                "DeleteAnimationIcon",
                icons.tvg.lucide.minus,
                .{ .fill_color = dvui.themeGet().color(.err, .text), .stroke_color = dvui.themeGet().color(.err, .text) },
                .{
                    .gravity_x = 0.5,
                    .gravity_y = 0.5,
                    .color_text = dvui.themeGet().color(.err, .text),
                    .expand = .ratio,
                    .margin = dvui.Rect.all(0),
                    .padding = dvui.Rect.all(0),
                },
            );

            dvui.alphaSet(alpha);

            if (delete_animation_button.clicked()) {
                var iter = file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
                const prev_order = try pixi.app.allocator.dupe(pixi.Animation.Frame, animation.frames);

                while (iter.next()) |sprite_index| {
                    var i: usize = animation.frames.len;
                    while (i > 0) : (i -= 1) {
                        if (animation.frames[i - 1].sprite_index == sprite_index) {
                            animation.removeFrame(pixi.app.allocator, i - 1);
                            break;
                        }
                    }
                }

                if (!animation.eqlFrames(prev_order)) {
                    file.history.append(.{
                        .animation_frames = .{
                            .index = index,
                            .frames = prev_order,
                        },
                    }) catch {
                        dvui.log.err("Failed to append history", .{});
                    };
                    file.selected_animation_frame_index = 0;
                    file.animations.set(index, animation);
                } else {
                    pixi.app.allocator.free(prev_order);
                }
            }
        }
    }
}

pub fn drawFrames(self: *Sprites) !void {
    if (pixi.editor.activeFile()) |file| {
        var anim = dvui.animate(@src(), .{ .kind = .horizontal, .duration = 450_000, .easing = dvui.easing.outBack }, .{});
        defer anim.deinit();

        const outer_box = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .horizontal,
            .background = false,
        });
        defer outer_box.deinit();

        const controls_box = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .none,
            .background = false,
        });
        dvui.labelNoFmt(@src(), "FRAMES", .{}, .{ .font = dvui.Font.theme(.title).larger(-3.0).withWeight(.bold) });

        self.drawFrameControls() catch {};

        controls_box.deinit();

        var scroll_area = dvui.scrollArea(@src(), .{ .scroll_info = &file.editor.sprites_scroll_info, .horizontal_bar = .auto_overlay, .vertical_bar = .auto_overlay }, .{
            .expand = .horizontal,
            .background = false,
            .corner_radius = dvui.Rect.all(1000),
        });

        defer scroll_area.deinit();

        var inner_box = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .both,
            .background = false,
            .margin = .{ .h = 6, .w = 6 },
        });
        defer inner_box.deinit();

        const vertical_scroll = file.editor.sprites_scroll_info.offset(.vertical);

        if (file.selected_animation_index) |animation_index| {
            const animation = file.animations.get(animation_index);

            defer self.prev_sprite_count = animation.frames.len;
            defer self.prev_anim_id = animation.id;

            var reorder = pixi.dvui.reorder(@src(), .{ .drag_name = "sprite_drag" }, .{
                .expand = .horizontal,
                .background = false,
            });
            defer reorder.deinit();

            //var sprite = file.sprites.get(frame);

            // Drag and drop is completing
            if (self.sprite_insert_before_index) |insert_before| {
                if (self.sprite_removed_index) |removed| {
                    const prev_order = try pixi.app.allocator.dupe(pixi.Animation.Frame, animation.frames);
                    defer file.animations.set(animation_index, animation);

                    dvui.ReorderWidget.reorderSlice(pixi.Animation.Frame, animation.frames, removed, insert_before);

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

                    if (!animation.eqlFrames(prev_order)) {
                        file.history.append(.{
                            .animation_frames = .{
                                .index = animation_index,
                                .frames = prev_order,
                            },
                        }) catch {
                            dvui.log.err("Failed to append history", .{});
                        };
                    } else {
                        pixi.app.allocator.free(prev_order);
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

            const total_duration: i32 = 600_000;
            const max_step_duration: i32 = @divTrunc(total_duration, 3);

            var duration_step: i32 = max_step_duration;
            if (animation.frames.len > 0) {
                duration_step = std.math.clamp(@divTrunc(total_duration, @as(i32, @intCast(animation.frames.len))), 0, max_step_duration);
            }

            for (animation.frames, 0..) |*frame, frame_index| {
                const duration = max_step_duration + (duration_step * @as(i32, @intCast(frame_index + 1)));
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

                if (dvui.firstFrame(r.data().id) or self.prev_sprite_count != animation.frames.len) {
                    dvui.animation(r.data().id, "sprite_expand", .{
                        .start_val = 0.0,
                        .end_val = 1.0,
                        .end_time = duration,
                        .easing = dvui.easing.outBack,
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

                const selected = if (frame.sprite_index < file.editor.selected_sprites.capacity()) file.editor.selected_sprites.isSet(frame.sprite_index) else false;
                const hovered = pixi.dvui.hovered(r.data());

                var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
                    .expand = .horizontal,
                    .background = false,
                });
                defer hbox.deinit();

                var index_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
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
                _ = pixi.dvui.ReorderWidget.draggable(@src(), .{
                    .reorderable = r,
                    .tvg_bytes = icons.tvg.lucide.@"grip-horizontal",
                    .color = dvui.themeGet().color(.control, .text),
                }, .{
                    .expand = .none,
                    .gravity_y = 0.5,
                    .margin = .{ .x = 4, .w = 4 },
                });

                dvui.labelNoFmt(@src(), try file.fmtSprite(dvui.currentWindow().arena(), frame.sprite_index, .grid), .{}, .{
                    .gravity_y = 0.5,
                    .margin = dvui.Rect.all(0),
                    .font = dvui.Font.theme(.mono).larger(-2.0),
                    .padding = .{ .x = 6, .y = 2, .w = 6, .h = 2 },
                    .background = if (frame_index == file.selected_animation_frame_index) true else false,
                    .color_fill = if (frame_index == file.selected_animation_frame_index) dvui.themeGet().color(.window, .fill) else dvui.themeGet().color(.control, .fill),
                    .corner_radius = dvui.Rect.all(1000),
                    .color_text = if (selected) dvui.themeGet().color(.control, .text) else dvui.themeGet().color(.control, .text),
                });

                index_box.deinit();

                var ms_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
                    .expand = .horizontal,
                    .background = false,
                    .margin = dvui.Rect.all(2),
                    .padding = dvui.Rect.all(1),
                    .color_border = if (selected) dvui.themeGet().color(.highlight, .fill) else dvui.themeGet().color(.control, .fill),
                    .border = dvui.Rect.all(1.0),
                    .corner_radius = dvui.Rect.all(1000),
                    .gravity_y = 0.5,
                    .gravity_x = 1.0,
                    .box_shadow = .{
                        .color = .black,
                        .offset = .{ .x = -2.0, .y = 2.0 },
                        .fade = 6.0,
                        .alpha = 0.25,
                        .corner_radius = dvui.Rect.all(1000),
                    },
                });
                defer ms_box.deinit();

                const frame_ms_text = std.fmt.allocPrint(dvui.currentWindow().arena(), "{d}", .{frame.ms}) catch {
                    dvui.log.err("Failed to allocate frame ms text", .{});
                    return;
                };

                const result = dvui.textEntryNumber(@src(), u32, .{ .value = &frame.ms, .min = 0, .max = 9999999 }, .{
                    .expand = .horizontal,
                    .background = true,
                    .padding = dvui.Rect.all(2),
                    .margin = dvui.Rect.all(0),
                    .border = dvui.Rect.all(0),
                    .min_size_content = .{
                        .w = dvui.Font.theme(.mono).larger(-2.0).textSize(frame_ms_text).w,
                        .h = dvui.Font.theme(.mono).larger(-2.0).textSize(frame_ms_text).h,
                    },
                    .font = dvui.Font.theme(.mono).larger(-2.0),
                    .gravity_y = 0.5,
                });

                // Set all frames that are currently selected
                if (result.changed) {
                    if (result.value == .Valid) {
                        for (animation.frames) |*f| {
                            if (file.editor.selected_sprites.isSet(f.sprite_index) and file.editor.selected_sprites.isSet(frame.sprite_index)) {
                                f.ms = result.value.Valid;
                            }
                        }
                    }
                }

                dvui.labelNoFmt(@src(), "ms", .{}, .{
                    .gravity_y = 0.5,
                    .margin = dvui.Rect.all(0),
                    .font = dvui.Font.theme(.mono).larger(-5.0),
                    .padding = .{ .x = 2, .w = 6 },
                });

                if (dvui.clickedEx(hbox.data(), .{ .hover_cursor = .hand })) |e| {
                    if (e == .mouse) {
                        if (frame.sprite_index < file.editor.selected_sprites.capacity()) {
                            if (e.mouse.mod.matchBind("ctrl/cmd")) {
                                file.editor.selected_sprites.set(frame.sprite_index);
                            } else if (e.mouse.mod.matchBind("shift")) {
                                file.editor.selected_sprites.unset(frame.sprite_index);
                            } else {
                                file.clearSelectedSprites();
                                file.editor.selected_sprites.set(frame.sprite_index);
                                file.selected_animation_frame_index = frame_index;
                            }
                        }
                    }
                }
            }

            if (reorder.finalSlot(.default)) {
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

const FrameSort = struct {
    pub fn asc(_: void, a: pixi.Animation.Frame, b: pixi.Animation.Frame) bool {
        return a.sprite_index < b.sprite_index;
    }

    pub fn desc(_: void, a: pixi.Animation.Frame, b: pixi.Animation.Frame) bool {
        return a.sprite_index > b.sprite_index;
    }
};
