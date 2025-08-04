const std = @import("std");
const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");
const icons = @import("icons");

var scroll_info: dvui.ScrollInfo = .{};
var removed_index: ?usize = null;
var insert_before_index: ?usize = null;
var edit_layer_id: ?u64 = null;

pub fn draw() !void {
    drawTools() catch {};

    dvui.labelNoFmt(@src(), "LAYERS", .{}, .{ .font_style = .title });

    var paned = dvui.paned(@src(), .{
        .direction = .vertical,
        .collapsed_size = 300,
        .handle_size = 10,
        .handle_dynamic = .{},
    }, .{ .expand = .both, .background = false });
    defer paned.deinit();

    if (dvui.firstFrame(paned.data().id)) {
        paned.split_ratio.* = 0.2;
    }

    if (paned.showFirst()) {
        drawLayers() catch {};
    }

    if (paned.showSecond()) {
        drawColors() catch {};
    }
}

pub fn drawTools() !void {
    const toolbox = dvui.flexbox(@src(), .{}, .{
        .expand = .horizontal,
        .max_size_content = .{ .w = pixi.editor.explorer.scroll_info.viewport.w - 10, .h = std.math.floatMax(f32) },
        .gravity_x = 0.5,
    });
    defer toolbox.deinit();
    for (0..std.meta.fields(pixi.Editor.Tools.Tool).len) |i| {
        const tool: pixi.Editor.Tools.Tool = @enumFromInt(i);
        const id_extra = i;

        var color = dvui.themeGet().color_fill_hover;
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
            .color_fill = if (pixi.editor.tools.current == tool) .fill_hover else .fill_window,
            .box_shadow = .{
                .color = .black,
                .offset = .{ .x = -4.0, .y = 4.0 },
                .fade = 8.0,
                .alpha = 0.25,
            },
            .border = dvui.Rect.all(1.0),
            .color_border = .{ .color = color },
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

        rs.r.x += (rs.r.w - width) / 2.0;
        rs.r.y += (rs.r.h - height) / 2.0;
        rs.r.w = width;
        rs.r.h = height;

        dvui.renderImage(pixi.editor.atlas.source, rs, .{
            .uv = uv,
            .fade = 0.0,
        }) catch {
            std.log.err("Failed to render image", .{});
        };

        if (button.clicked()) {
            pixi.editor.tools.set(tool);
        }
    }
}

pub fn drawLayers() !void {
    const vbox = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .both,
        .background = false,
    });
    defer vbox.deinit();

    if (pixi.editor.getFile(pixi.editor.open_file_index)) |file| {
        var scroll_area = dvui.scrollArea(@src(), .{ .scroll_info = &scroll_info }, .{
            .expand = .both,
            .background = false,
            .corner_radius = dvui.Rect.all(1000),
        });
        defer scroll_area.deinit();

        const vertical_scroll = scroll_info.offset(.vertical);

        var reorderable = pixi.dvui.reorder(@src(), .{
            .expand = .horizontal,
            .background = false,
        });
        defer reorderable.deinit();

        // Drag and drop is completing
        if (insert_before_index) |insert_before| {
            if (removed_index) |removed| {
                const order = try pixi.app.allocator.alloc(u64, file.layers.len);

                for (file.layers.items(.id), 0..) |id, i| {
                    order[i] = id;
                }
                file.history.append(.{
                    .layers_order = .{
                        .order = order,
                        .selected = file.layers.items(.id)[file.selected_layer_index],
                    },
                }) catch {
                    std.log.err("Failed to append history", .{});
                };

                const layer = file.layers.get(removed);
                file.layers.orderedRemove(removed);

                if (insert_before <= file.layers.len) {
                    file.layers.insert(pixi.app.allocator, if (removed > insert_before) insert_before + 1 else insert_before, layer) catch {
                        std.log.err("Failed to insert layer", .{});
                    };
                } else {
                    file.layers.insert(pixi.app.allocator, if (removed > insert_before) file.layers.len else 0, layer) catch {
                        std.log.err("Failed to insert layer", .{});
                    };
                }

                if (removed == file.selected_layer_index) {
                    if (insert_before < file.layers.len) {
                        file.selected_layer_index = insert_before;
                    } else {
                        file.selected_layer_index = 0;
                    }
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

        var layer_index: usize = file.layers.len;

        while (layer_index > 0) {
            layer_index -= 1;

            var color = dvui.themeGet().color_fill_hover;
            if (pixi.editor.colors.file_tree_palette) |*palette| {
                color = palette.getDVUIColor(file.layers.items(.id)[layer_index]);
            }

            var r = reorderable.reorderable(@src(), .{}, .{
                .id_extra = layer_index,
                .expand = .horizontal,
                .corner_radius = dvui.Rect.all(1000),
                .min_size_content = .{ .w = 0.0, .h = reorderable.reorderable_size.h },
            });
            defer r.deinit();

            if (r.removed()) {
                removed_index = layer_index;
            } else if (r.insertBefore()) {
                insert_before_index = layer_index;
            }

            var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .expand = .both,
                .background = true,
                .color_fill = if (file.selected_layer_index == layer_index) .fill else .fill_window,
                .corner_radius = dvui.Rect.all(1000),
                .margin = dvui.Rect.all(2),
                .padding = dvui.Rect.all(1),
                .border = dvui.Rect.all(1.0),
                .color_border = .{ .color = color },
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
                .color = if (file.selected_layer_index != layer_index) .fromTheme(.text_press) else .fromTheme(.text),
            }, .{
                .expand = .none,
                .gravity_y = 0.5,
                .margin = .{ .x = 4, .w = 4 },
            });

            if (edit_layer_id != file.layers.items(.id)[layer_index]) {
                if (file.selected_layer_index == layer_index) {
                    if (dvui.labelClick(@src(), "{s}", .{file.layers.items(.name)[layer_index]}, .{}, .{
                        .gravity_y = 0.5,
                        .margin = dvui.Rect.all(0),
                        .padding = dvui.Rect.all(0),
                        .color_text = if (file.selected_layer_index != layer_index) .text_press else .text,
                    })) {
                        edit_layer_id = file.layers.items(.id)[layer_index];
                    }
                } else {
                    dvui.labelNoFmt(@src(), file.layers.items(.name)[layer_index], .{}, .{
                        .gravity_y = 0.5,
                        .margin = dvui.Rect.all(0),
                        .padding = dvui.Rect.all(0),
                        .color_text = if (file.selected_layer_index != layer_index) .text_press else .text,
                    });
                }
            } else {
                var te = dvui.textEntry(@src(), .{}, .{
                    .expand = .horizontal,
                    .background = false,
                    .padding = dvui.Rect.all(0),
                    .margin = dvui.Rect.all(0),
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
                            std.log.err("Failed to append history", .{});
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
                    if (file.layers.items(.collapse)[layer_index]) icons.tvg.lucide.@"arrow-up-from-line" else icons.tvg.lucide.@"arrow-down-to-line",
                    .{ .draw_focus = false },
                    .{ .fill_color = if (file.selected_layer_index == layer_index) .fromTheme(.text) else .fromTheme(.text_press) },
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
                    .{ .fill_color = if (file.selected_layer_index == layer_index) .fromTheme(.text) else .fromTheme(.text_press) },
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

                if (dvui.buttonIcon(
                    @src(),
                    "delete_button",
                    icons.tvg.lucide.trash,
                    .{ .draw_focus = false },
                    .{ .fill_color = .fromTheme(.err) },
                    .{
                        .expand = .none,
                        .id_extra = layer_index,
                        .gravity_y = 0.5,
                        .corner_radius = dvui.Rect.all(1000),
                        .margin = dvui.Rect.all(1),
                    },
                )) {
                    std.log.info("delete layer {d}", .{layer_index});
                }

                if (dvui.clicked(hbox.data(), .{ .hover_cursor = .hand })) {
                    file.selected_layer_index = layer_index;
                }
            }
        }

        if (reorderable.finalSlot()) {
            insert_before_index = file.layers.len;
        }

        // Only draw shadow if the scroll bar has been scrolled some
        if (vertical_scroll > 0.0) {
            var rs = scroll_area.data().contentRectScale();
            rs.r.h = 20.0;

            var path: dvui.Path.Builder = .init(dvui.currentWindow().arena());
            path.addRect(rs.r, dvui.Rect.Physical.all(5));

            var triangles = try path.build().fillConvexTriangles(dvui.currentWindow().arena(), .{ .center = rs.r.center() });

            const black: dvui.Color = .black;
            const ca0 = black.opacity(0.2);
            const ca1 = black.opacity(0);

            for (triangles.vertexes) |*v| {
                const t = std.math.clamp((v.pos.y - rs.r.y) / rs.r.h, 0.0, 1.0);
                v.col = v.col.multiply(.fromColor(dvui.Color.lerp(ca0, ca1, t)));
            }
            try dvui.renderTriangles(triangles, null);

            triangles.deinit(dvui.currentWindow().arena());
            path.deinit();
        }

        if (scroll_info.virtual_size.h > scroll_info.viewport.h and vertical_scroll < scroll_info.scrollMax(.vertical)) {
            var rs = scroll_area.data().contentRectScale();
            rs.r.y += rs.r.h - 20;
            rs.r.h = 20;

            var path: dvui.Path.Builder = .init(dvui.currentWindow().arena());
            path.addRect(rs.r, dvui.Rect.Physical.all(5));

            var triangles = try path.build().fillConvexTriangles(dvui.currentWindow().arena(), .{ .center = rs.r.center() });

            const black: dvui.Color = .black;
            const ca0 = black.opacity(0.0);
            const ca1 = black.opacity(0.2);

            for (triangles.vertexes) |*v| {
                const t = std.math.clamp((v.pos.y - rs.r.y) / rs.r.h, 0.0, 1.0);
                v.col = v.col.multiply(.fromColor(dvui.Color.lerp(ca0, ca1, t)));
            }
            try dvui.renderTriangles(triangles, null);

            triangles.deinit(dvui.currentWindow().arena());
            path.deinit();
        }
    }
}

pub fn drawColors() !void {
    const vbox = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .both,
        .background = false,
    });
    defer vbox.deinit();

    dvui.labelNoFmt(@src(), "COLORS", .{}, .{ .font_style = .title });

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
        .color_fill = .fromColor(primary),
        .color_fill_hover = .fromColor(primary),
        .color_fill_press = .fromColor(primary),
        .margin = dvui.Rect.all(1),
        .padding = dvui.Rect.all(0),
        .border = dvui.Rect.all(1.0),
        .color_border = .fill,
        .box_shadow = .{
            .color = .black,
            .offset = .{ .x = -2.0, .y = 2.0 },
            .fade = 6.0,
            .alpha = 0.15,
            .corner_radius = dvui.Rect.all(8.0),
        },
    };

    const secondary_overrider: dvui.Options = .{
        .color_fill = .fromColor(secondary),
        .color_fill_hover = .fromColor(secondary),
        .color_fill_press = .fromColor(secondary),
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
            .color = .{ .color = .black },
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
