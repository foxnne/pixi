const std = @import("std");
const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");
const icons = @import("icons");

var removed_index: ?usize = null;
var insert_before_index: ?usize = null;
var edit_layer_id: ?u64 = null;
var prev_layer_count: usize = 0;
var max_split_ratio: f32 = 0.4;

pub fn draw() !void {
    drawTools() catch {};
    drawColors() catch {};
    drawLayerControls() catch {};

    // Collect layers length to trigger a refit of the panel
    const layer_count: usize = if (pixi.editor.activeFile()) |file| file.layers.len else 0;
    defer prev_layer_count = layer_count;

    var paned = pixi.dvui.layersPaned(@src(), .{
        .direction = .vertical,
        .collapsed_size = 0,
        .handle_size = 10,
        .handle_dynamic = .{},
    }, .{ .expand = .both, .background = false });
    defer paned.deinit();

    if (paned.showFirst()) {
        drawLayers() catch {
            dvui.log.err("Failed to draw layers", .{});
        };
    }

    if (paned.dragging) {
        max_split_ratio = paned.split_ratio.*;
    }

    const autofit = !paned.dragging and !paned.collapsed_state;

    // Refit must be done between showFirst and showSecond
    if (dvui.firstFrame(paned.data().id) or prev_layer_count != layer_count or autofit) {
        if (dvui.firstFrame(paned.data().id))
            paned.split_ratio.* = 0.0;

        const ratio = paned.getFirstFittedRatio(
            .{
                .min_split = 0,
                .max_split = @min(max_split_ratio, 0.75),
                .min_size = 0,
            },
        );

        const diff = @abs(ratio - paned.split_ratio.*);

        if (diff > 0.000001 and layer_count > 0) {
            paned.animateSplit(ratio);
        }
    }

    if (paned.showSecond()) {
        drawPalettes() catch {};
    }
}

pub fn drawTools() !void {
    const toolbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .none,
        .gravity_x = 0.5,
    });
    defer toolbox.deinit();
    for (0..std.meta.fields(pixi.Editor.Tools.Tool).len) |i| {
        const tool: pixi.Editor.Tools.Tool = @enumFromInt(i);
        const id_extra = i;

        var color = dvui.themeGet().color(.control, .fill_hover);
        if (pixi.editor.colors.file_tree_palette) |*palette| {
            color = palette.getDVUIColor(i);
        }

        const sprite = switch (tool) {
            .pointer => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.dropper_default],
            .pencil => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.pencil_default],
            .eraser => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.eraser_default],
            .bucket => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.bucket_default],
            .selection => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.selection_default],
        };
        var button = dvui.ButtonWidget.init(@src(), .{}, .{
            .expand = .none,
            .min_size_content = .{ .w = 24, .h = 24 },
            .id_extra = id_extra,
            .background = true,
            .corner_radius = dvui.Rect.all(1000),
            .color_fill = if (pixi.editor.tools.current == tool) dvui.themeGet().color(.control, .fill_hover) else dvui.themeGet().color(.control, .fill),
            .box_shadow = .{
                .color = .black,
                .offset = .{ .x = -4.0, .y = 4.0 },
                .fade = 8.0,
                .alpha = 0.25,
            },
            .border = dvui.Rect.all(1.0),
            .color_border = color,
            .margin = .{ .h = 10.0, .w = 4, .x = 4, .y = 4 },
        });
        defer button.deinit();

        const size: dvui.Size = dvui.imageSize(pixi.editor.atlas.source) catch .{ .w = 0, .h = 0 };

        const uv = dvui.Rect{
            .x = @as(f32, @floatFromInt(sprite.source[0])) / size.w,
            .y = @as(f32, @floatFromInt(sprite.source[1])) / size.h,
            .w = @as(f32, @floatFromInt(sprite.source[2])) / size.w,
            .h = @as(f32, @floatFromInt(sprite.source[3])) / size.h,
        };

        button.install();
        button.processEvents();
        button.drawBackground();

        var rs = button.data().contentRectScale();

        const width = @as(f32, @floatFromInt(sprite.source[2])) * rs.s;
        const height = @as(f32, @floatFromInt(sprite.source[3])) * rs.s;

        rs.r.x = @round(rs.r.x + (rs.r.w - width) / 2.0);
        rs.r.y = @round(rs.r.y + (rs.r.h - height) / 2.0);
        rs.r.w = width;
        rs.r.h = height;

        dvui.renderImage(pixi.editor.atlas.source, rs, .{
            .uv = uv,
            .fade = 0.0,
        }) catch {
            dvui.log.err("Failed to render image", .{});
        };

        if (button.clicked()) {
            pixi.editor.tools.set(tool);
        }
    }
}

pub fn drawLayerControls() !void {
    var box = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .horizontal,
        .background = false,
    });
    defer box.deinit();
    dvui.labelNoFmt(@src(), "LAYERS", .{}, .{ .font_style = .title_4, .gravity_y = 0.5 });

    if (pixi.editor.activeFile()) |file| {
        var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .none,
            .background = false,
            .gravity_x = 1.0,
        });
        defer hbox.deinit();

        if (dvui.buttonIcon(@src(), "AddLayer", icons.tvg.lucide.plus, .{}, .{}, .{
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
            if (file.createLayer() catch null) |id| {
                edit_layer_id = id;
            }
        }

        if (dvui.buttonIcon(@src(), "DuplicateLayer", icons.tvg.lucide.@"copy-plus", .{}, .{}, .{
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
            if (file.duplicateLayer(file.selected_layer_index) catch null) |id| {
                edit_layer_id = id;
            }
        }

        if (file.layers.len > 1) {
            if (dvui.buttonIcon(@src(), "DeleteLayer", icons.tvg.lucide.trash, .{}, .{ .stroke_color = dvui.themeGet().color(.window, .fill) }, .{
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
                file.deleteLayer(file.selected_layer_index) catch {
                    dvui.log.err("Failed to delete layer", .{});
                };
            }
        }
    }
}

pub fn drawLayers() !void {
    const vbox = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .both,
        .background = false,
    });
    defer vbox.deinit();

    if (pixi.editor.activeFile()) |file| {
        var scroll_area = dvui.scrollArea(@src(), .{ .scroll_info = &file.editor.layers_scroll_info }, .{
            .expand = .both,
            .background = false,
            .corner_radius = dvui.Rect.all(1000),
        });

        defer scroll_area.deinit();

        const vertical_scroll = file.editor.layers_scroll_info.offset(.vertical);

        var reorderable = pixi.dvui.reorder(@src(), .{ .drag_name = "layer_drag" }, .{
            .expand = .horizontal,
            .background = false,
        });
        defer reorderable.deinit();

        // Drag and drop is completing
        if (insert_before_index) |insert_before| {
            if (removed_index) |removed| {
                const prev_order = try pixi.app.allocator.alloc(u64, file.layers.len);
                for (file.layers.items(.id), 0..) |id, i| {
                    prev_order[i] = id;
                }

                const layer = file.layers.get(removed);
                file.layers.orderedRemove(removed);

                if (insert_before <= file.layers.len) {
                    file.layers.insert(pixi.app.allocator, if (removed < insert_before) insert_before - 1 else insert_before, layer) catch {
                        dvui.log.err("Failed to insert layer", .{});
                    };
                } else {
                    file.layers.insert(pixi.app.allocator, if (removed < insert_before) file.layers.len else 0, layer) catch {
                        dvui.log.err("Failed to insert layer", .{});
                    };
                }

                if (removed == file.selected_layer_index) {
                    if (insert_before < file.layers.len) {
                        file.selected_layer_index = if (removed < insert_before) insert_before - 1 else insert_before;
                    } else {
                        file.selected_layer_index = 0;
                    }
                }

                if (!std.mem.eql(u64, file.layers.items(.id)[0..file.layers.len], prev_order)) {
                    file.history.append(.{
                        .layers_order = .{
                            .order = prev_order,
                            .selected = file.layers.items(.id)[file.selected_layer_index],
                        },
                    }) catch {
                        dvui.log.err("Failed to append history", .{});
                    };
                } else {
                    pixi.app.allocator.free(prev_order);
                }

                insert_before_index = null;
                removed_index = null;
            }
        }

        const box = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .horizontal,
            .background = false,
            .corner_radius = dvui.Rect.all(1000),
            .margin = dvui.Rect.all(4),
        });
        defer box.deinit();

        for (file.layers.items(.id), 0..) |layer_id, layer_index| {
            const selected = if (edit_layer_id) |id| id == layer_id else file.selected_layer_index == layer_index;

            var color = dvui.themeGet().color(.control, .fill_hover);
            if (pixi.editor.colors.file_tree_palette) |*palette| {
                color = palette.getDVUIColor(layer_id);
            }

            var r = reorderable.reorderable(@src(), .{}, .{
                .id_extra = layer_index,
                .expand = .horizontal,
                .corner_radius = dvui.Rect.all(1000),
                .min_size_content = .{ .w = 0.0, .h = reorderable.reorderable_size.h },
            });
            defer r.deinit();

            if (dvui.firstFrame(r.data().id) or prev_layer_count != file.layers.len) {
                dvui.animation(r.data().id, "expand", .{
                    .start_val = 0.2,
                    .end_val = 1.0,
                    .end_time = 150_000 + (50_000 * @as(i32, @intCast(layer_index))),
                    .easing = dvui.easing.inOutQuad,
                });
            }

            if (dvui.animationGet(r.data().id, "expand")) |a| {
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
                removed_index = layer_index;
            } else if (r.insertBefore()) {
                insert_before_index = layer_index;
            }

            var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .expand = .both,
                .background = true,
                .color_fill = if (selected) dvui.themeGet().color(.content, .fill_press) else dvui.themeGet().color(.control, .fill),
                .corner_radius = dvui.Rect.all(1000),
                .margin = dvui.Rect.all(2),
                .padding = dvui.Rect.all(1),
                .border = dvui.Rect.all(1.0),
                .color_border = color,
                .box_shadow = .{
                    .color = .black,
                    .offset = .{ .x = -2.0, .y = 2.0 },
                    .fade = 6.0,
                    .alpha = 0.15,
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

            if (edit_layer_id != layer_id) {
                if (file.selected_layer_index == layer_index) {
                    if (dvui.labelClick(@src(), "{s}", .{file.layers.items(.name)[layer_index]}, .{}, .{
                        .gravity_y = 0.5,
                        .font_style = .body,
                        .margin = dvui.Rect.all(2),
                        .padding = dvui.Rect.all(0),
                        .color_text = if (!selected) dvui.themeGet().color(.control, .text) else dvui.themeGet().color(.window, .text),
                    })) {
                        edit_layer_id = layer_id;
                    }
                } else {
                    dvui.labelNoFmt(@src(), file.layers.items(.name)[layer_index], .{}, .{
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
                    te.textSet(file.layers.items(.name)[layer_index], true);
                    dvui.focusWidget(te.data().id, null, null);
                }

                if (te.enter_pressed or dvui.focusedWidgetId() != te.data().id) {
                    if (!std.mem.eql(u8, file.layers.items(.name)[layer_index], te.getText()) and te.getText().len > 0) {
                        file.history.append(.{
                            .layer_name = .{
                                .index = layer_index,
                                .name = try pixi.app.allocator.dupe(u8, file.layers.items(.name)[layer_index]),
                            },
                        }) catch {
                            dvui.log.err("Failed to append history", .{});
                        };
                        pixi.app.allocator.free(file.layers.items(.name)[layer_index]);
                        file.layers.items(.name)[layer_index] = try pixi.app.allocator.dupe(u8, te.getText());
                    }
                    edit_layer_id = null;
                }
            }

            if (reorderable.drag_point == null) {
                var button_box = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .none, .background = false, .gravity_x = 1.0, .min_size_content = .{ .w = 20.0, .h = 20.0 } });
                defer button_box.deinit();

                if (dvui.buttonIcon(
                    @src(),
                    "collapse_button",
                    if (file.layers.items(.collapse)[layer_index]) icons.tvg.lucide.@"arrow-down-to-line" else icons.tvg.lucide.package,
                    .{ .draw_focus = false },
                    .{},
                    //.{ .fill_color = if (file.selected_layer_index == layer_index) dvui.themeGet().color(.window, .text) else dvui.themeGet().color(.control, .text) },
                    .{
                        .expand = .none,
                        .id_extra = layer_index,
                        .gravity_y = 0.5,
                        .corner_radius = dvui.Rect.all(1000),
                        .margin = dvui.Rect.all(1),
                    },
                )) {
                    file.layers.items(.collapse)[layer_index] = !file.layers.items(.collapse)[layer_index];
                }

                if (dvui.buttonIcon(
                    @src(),
                    "hide_button",
                    if (file.layers.items(.visible)[layer_index]) icons.tvg.lucide.eye else icons.tvg.lucide.@"eye-closed",
                    .{ .draw_focus = false },
                    .{},
                    //.{ .fill_color = if (file.selected_layer_index == layer_index) dvui.themeGet().color(.window, .text) else dvui.themeGet().color(.control, .text) },
                    .{
                        .expand = .none,
                        .id_extra = layer_index,
                        .gravity_y = 0.5,
                        .corner_radius = dvui.Rect.all(1000),
                        .margin = dvui.Rect.all(1),
                    },
                )) {
                    file.layers.items(.visible)[layer_index] = !file.layers.items(.visible)[layer_index];
                }

                // This consumes the click event, so we need to do this last
                if (dvui.clicked(hbox.data(), .{ .hover_cursor = .hand })) {
                    file.selected_layer_index = layer_index;
                }
            }
        }

        if (reorderable.finalSlot()) {
            insert_before_index = file.layers.len;
        }

        // Only draw shadow if the scroll bar has been scrolled some
        if (vertical_scroll > 0.0)
            pixi.dvui.drawEdgeShadow(scroll_area.data().contentRectScale(), .top, .{});

        if (file.editor.layers_scroll_info.virtual_size.h > file.editor.layers_scroll_info.viewport.h and vertical_scroll < file.editor.layers_scroll_info.scrollMax(.vertical))
            pixi.dvui.drawEdgeShadow(scroll_area.data().contentRectScale(), .bottom, .{});
    }
}

pub fn drawColors() !void {
    dvui.labelNoFmt(@src(), "COLORS", .{}, .{ .font_style = .title_4 });

    var hbox = dvui.box(@src(), .{ .dir = .horizontal, .equal_space = true }, .{
        .expand = .horizontal,
        .background = false,
        .min_size_content = .{ .w = 64.0, .h = 64.0 },
    });
    defer hbox.deinit();

    const primary: dvui.Color = .{ .r = pixi.editor.colors.primary[0], .g = pixi.editor.colors.primary[1], .b = pixi.editor.colors.primary[2], .a = pixi.editor.colors.primary[3] };
    const secondary: dvui.Color = .{ .r = pixi.editor.colors.secondary[0], .g = pixi.editor.colors.secondary[1], .b = pixi.editor.colors.secondary[2], .a = pixi.editor.colors.secondary[3] };

    const button_opts: dvui.Options = .{
        .expand = .both,
        .background = true,
        .corner_radius = dvui.Rect.all(8.0),
        .color_fill = primary,
        //.color_fill_hover = primary,
        //.color_fill_press = primary,
        .margin = dvui.Rect.all(1),
        .padding = dvui.Rect.all(0),
        .border = dvui.Rect.all(1.0),
        .color_border = dvui.themeGet().color(.control, .fill),
        .box_shadow = .{
            .color = .black,
            .offset = .{ .x = -2.0, .y = 2.0 },
            .fade = 6.0,
            .alpha = 0.15,
            .corner_radius = dvui.Rect.all(8.0),
        },
    };

    const secondary_overrider: dvui.Options = .{
        .color_fill = secondary,
        //.color_fill_hover = secondary,
        //.color_fill_press = secondary,
    };

    var clicked: bool = false;
    {
        var primary_button = dvui.ButtonWidget.init(@src(), .{}, button_opts);
        defer primary_button.deinit();

        primary_button.install();
        primary_button.processEvents();
        primary_button.drawBackground();

        drawColorPicker(primary_button.data().rectScale().r, &pixi.editor.colors.primary) catch {};

        if (primary_button.clicked()) clicked = true;
    }

    {
        var secondary_button = dvui.ButtonWidget.init(@src(), .{}, button_opts.override(secondary_overrider));
        defer secondary_button.deinit();

        secondary_button.install();
        secondary_button.processEvents();
        secondary_button.drawBackground();

        drawColorPicker(secondary_button.data().rectScale().r, &pixi.editor.colors.secondary) catch {};

        if (secondary_button.clicked()) clicked = true;
    }

    if (clicked) {
        std.mem.swap([4]u8, &pixi.editor.colors.primary, &pixi.editor.colors.secondary);
    }
}

fn drawColorPicker(rect: dvui.Rect.Physical, backing_color: *[4]u8) !void {
    var context = dvui.context(@src(), .{ .rect = rect }, .{});
    defer context.deinit();

    if (context.activePoint()) |point| {
        var fw2 = dvui.floatingMenu(@src(), .{ .from = dvui.Rect.Natural.fromPoint(point) }, .{ .box_shadow = .{
            .color = .black,
            .offset = .{ .x = 0, .y = 0 },
            .shrink = 0,
            .fade = 10,
            .alpha = 0.15,
        } });
        defer fw2.deinit();

        var color: dvui.Color.HSV = .fromColor(.{
            .r = backing_color.*[0],
            .g = backing_color.*[1],
            .b = backing_color.*[2],
            .a = backing_color.*[3],
        });

        if (dvui.colorPicker(@src(), .{ .alpha = true, .hsv = &color }, .{
            .expand = .horizontal,
            .background = false,
            .corner_radius = dvui.Rect.all(1000),
        })) {
            const c = color.toColor();
            backing_color.* = .{
                c.r,
                c.g,
                c.b,
                c.a,
            };
        }
    }
}

pub fn drawPalettes() !void {
    dvui.labelNoFmt(@src(), "PALETTES", .{}, .{ .font_style = .title_4 });

    // Palette search dropdown
    {
        const oldt = dvui.themeGet();
        var t = oldt;
        t.control.fill = t.window.fill;
        dvui.themeSet(t);
        defer dvui.themeSet(oldt);

        var dropdown = dvui.DropdownWidget.init(@src(), .{ .label = "Palette" }, .{
            .expand = .horizontal,
            .corner_radius = dvui.Rect.all(1000),
        });
        dropdown.install();
        defer dropdown.deinit();

        var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .vertical,
            .gravity_x = 1.0,
        });

        if (pixi.editor.colors.palette) |*palette| {
            dvui.label(@src(), "{s}", .{palette.name}, .{ .margin = .all(0), .padding = .all(0) });
        } else {
            dvui.label(@src(), "Palette Search", .{}, .{ .margin = .all(0), .padding = .all(0) });
        }

        dvui.icon(
            @src(),
            "dropdown_triangle",
            dvui.entypo.triangle_down,
            .{},
            .{ .gravity_y = 0.5 },
        );

        hbox.deinit();

        if (dropdown.dropped()) {
            searchPalettes(&dropdown) catch {
                dvui.log.err("Failed to search palettes", .{});
            };
        }

        _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 10, .h = 10 } });
    }

    {
        if (pixi.editor.colors.palette) |*palette| {
            var flex_box = dvui.flexbox(@src(), .{ .justify_content = .center }, .{ .expand = .horizontal, .max_size_content = .{ .w = pixi.editor.explorer.rect.w, .h = std.math.floatMax(f32) } });
            defer flex_box.deinit();

            for (palette.colors, 0..) |color, i| {
                var button_widget = dvui.ButtonWidget.init(@src(), .{}, .{
                    .expand = .none,
                    .min_size_content = .{ .w = 24, .h = 24 },
                    .id_extra = i,
                    .background = true,
                    .corner_radius = dvui.Rect.all(1000),
                    .color_fill = .{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] },
                    .margin = .all(1),
                    .padding = .all(0),
                });

                button_widget.install();
                button_widget.processEvents();

                const button_center = button_widget.data().rectScale().r.center();
                const dist = dvui.currentWindow().mouse_pt.diff(button_center).length();

                // Calculate scale based on mouse distance (closer = larger)
                const max_distance = 50.0; // Maximum distance for scaling effect
                const scale_factor = if (dist < max_distance)
                    1.0 + (1.0 - (dist / max_distance)) * 0.5 // Scale up to 1.5x when very close
                else
                    1.0;

                const rect = button_widget.data().contentRectScale().r.outsetAll((scale_factor - 1) * button_widget.data().rectScale().r.w / 2);

                rect.fill(.all(1000), .{
                    .color = .{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] },
                });

                if (button_widget.clicked()) {
                    @memcpy(&pixi.editor.colors.primary, &color);
                }
                button_widget.deinit();
            }
        }
    }
}

fn searchPalettes(dropdown: *dvui.DropdownWidget) !void {
    var dir_opt = std.fs.cwd().openDir(pixi.paths.palettes, .{ .access_sub_paths = false, .iterate = true }) catch null;
    if (dir_opt) |*dir| {
        defer dir.close();
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file) {
                const ext = std.fs.path.extension(entry.name);
                if (std.mem.eql(u8, ext, ".hex")) {
                    const label = try std.fmt.allocPrint(dvui.currentWindow().arena(), "{s}", .{entry.name});
                    if (dropdown.addChoiceLabel(label)) {
                        const abs_path = try std.fs.path.join(dvui.currentWindow().arena(), &.{ pixi.paths.palettes, entry.name });

                        if (pixi.editor.colors.palette) |*palette|
                            palette.deinit();

                        pixi.editor.colors.palette = pixi.Internal.Palette.loadFromFile(abs_path) catch |err| {
                            dvui.log.err("Failed to load palette: {s}", .{@errorName(err)});
                            return error.FailedToLoadPalette;
                        };
                    }
                }
            }
        }
    }
}
