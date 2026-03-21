const std = @import("std");
const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");
const icons = @import("icons");
const assets = @import("assets");

const Tools = @This();

var removed_index: ?usize = null;
var insert_before_index: ?usize = null;
var edit_layer_id: ?u64 = null;
var prev_layer_count: usize = 0;
var max_split_ratio: f32 = 0.4;

/// In-flight primary-button gesture for the active file's layer list (reorder / click / rename).
/// Not stored in `dvui.data`: a single path at end of `drawLayers` processes events after rename `textEntry`.
const LayerRowGesture = struct {
    file_id: u64,
    press_idx: usize,
    press_p: dvui.Point.Physical,
    drag_branch: ?usize,
    moved: bool,
    reorder_drag: bool,
};
var layer_row_gesture: ?LayerRowGesture = null;

/// Filled while the layer rename text entry exists so `processLayerTreePointerEvents` can skip those hits.
var layer_rename_hit_te_id: ?dvui.Id = null;
var layer_rename_hit_rect: ?dvui.Rect.Physical = null;

layers_rect: ?dvui.Rect.Physical = null,

pub fn init() Tools {
    return .{};
}

pub fn draw(self: *Tools) !void {
    drawTools() catch {};
    drawColors() catch {};
    drawLayerControls() catch {};

    // Collect layers length to trigger a refit of the panel
    const layer_count: usize = if (pixi.editor.activeFile()) |file| file.layers.len else 0;
    defer prev_layer_count = layer_count;

    var paned = pixi.dvui.paned(@src(), .{
        .direction = .vertical,
        .collapsed_size = 0,
        .handle_size = 10,
        .handle_dynamic = .{},
    }, .{ .expand = .both, .background = false });
    defer paned.deinit();

    if (paned.dragging) {
        max_split_ratio = paned.split_ratio.*;
        pixi.editor.explorer.layers_ratio = paned.split_ratio.*;
    }

    if (paned.showFirst()) {
        self.layers_rect = self.drawLayers() catch {
            dvui.log.err("Failed to draw layers", .{});
            return;
        };
    }

    const autofit = !paned.dragging and !paned.collapsed_state and !paned.animating;

    // Refit must be done between showFirst and showSecond
    if (((dvui.firstFrame(paned.data().id) or prev_layer_count != layer_count) or autofit) and !pixi.editor.explorer.pinned_palettes) {
        if (dvui.firstFrame(paned.data().id) and layer_count == 0)
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
            paned.animateSplit(ratio, dvui.easing.outBack);
        }
    } else {
        if (dvui.firstFrame(paned.data().id)) {
            if (layer_count == 0)
                paned.split_ratio.* = 0.0
            else
                paned.split_ratio.* = pixi.editor.explorer.layers_ratio;

            pixi.editor.explorer.layers_ratio = paned.split_ratio.*;
        }
    }

    if (paned.showSecond()) {
        drawPaletteControls() catch {};
        drawPalettes() catch {};
    }
}

pub fn layersHovered(self: *Tools) bool {
    if (self.layers_rect) |rect| {
        return rect.contains(dvui.currentWindow().mouse_pt);
    }

    return false;
}

pub fn drawTools() !void {
    const toolbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .none,
        .gravity_x = 0.5,
        .padding = .{ .h = 10.0, .w = 4.0, .x = 4.0, .y = 4.0 },
    });
    defer toolbox.deinit();
    for (0..std.meta.fields(pixi.Editor.Tools.Tool).len) |i| {
        const tool: pixi.Editor.Tools.Tool = @enumFromInt(i);
        const id_extra = i;

        const selected = pixi.editor.tools.current == tool;

        var color = dvui.themeGet().color(.control, .fill_hover);
        if (pixi.editor.colors.file_tree_palette) |*palette| {
            color = palette.getDVUIColor(i);
        }

        const sprite = switch (tool) {
            .pointer => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.cursor_default],
            .pencil => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.pencil_default],
            .eraser => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.eraser_default],
            .bucket => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.bucket_default],
            .selection => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.selection_default],
        };
        var button: dvui.ButtonWidget = undefined;
        button.init(@src(), .{}, .{
            .expand = .none,
            .min_size_content = .{ .w = 40, .h = 40 },
            .id_extra = id_extra,
            .background = true,
            .corner_radius = dvui.Rect.all(1000),
            .color_fill = if (selected) dvui.themeGet().color(.content, .fill) else .transparent,
            .color_fill_hover = if (!selected) dvui.themeGet().color(.content, .fill_hover) else null,
            .box_shadow = if (selected) .{
                .color = .black,
                .offset = .{ .x = -2.5, .y = 2.5 },
                .fade = 4.0,
                .alpha = 0.25,
            } else null,
            .padding = .all(0),
            //.border = dvui.Rect.all(1.0),
            //.color_border = if (selected) color else dvui.themeGet().color(.control, .fill),
        });
        defer button.deinit();

        pixi.editor.tools.drawTooltip(tool, button.data().rectScale().r, id_extra) catch {};

        if (button.hovered()) {
            button.data().options.color_border = color;
        }

        const size: dvui.Size = dvui.imageSize(pixi.editor.atlas.source) catch .{ .w = 0, .h = 0 };

        const uv = dvui.Rect{
            .x = @as(f32, @floatFromInt(sprite.source[0])) / size.w,
            .y = @as(f32, @floatFromInt(sprite.source[1])) / size.h,
            .w = @as(f32, @floatFromInt(sprite.source[2])) / size.w,
            .h = @as(f32, @floatFromInt(sprite.source[3])) / size.h,
        };

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
    dvui.labelNoFmt(@src(), "LAYERS", .{}, .{ .font = dvui.Font.theme(.title).larger(-3.0).withWeight(.bold), .gravity_y = 0.5 });

    if (pixi.editor.activeFile()) |file| {
        var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .none,
            .background = false,
            .gravity_x = 1.0,
        });
        defer hbox.deinit();

        if (dvui.buttonIcon(
            @src(),
            "TogglePeek",
            if (file.editor.isolate_layer) icons.tvg.lucide.@"layers-2" else icons.tvg.lucide.layers,
            .{},
            .{},
            .{
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
                .style = if (file.editor.isolate_layer) .highlight else .control,
            },
        )) {
            file.editor.isolate_layer = !file.editor.isolate_layer;
        }

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

pub fn drawLayers(tools: *Tools) !?dvui.Rect.Physical {
    const vbox = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .both,
        .background = false,
    });
    defer vbox.deinit();

    if (pixi.editor.activeFile()) |file| {
        layer_rename_hit_te_id = null;
        layer_rename_hit_rect = null;

        var scroll_area = dvui.scrollArea(@src(), .{ .scroll_info = &file.editor.layers_scroll_info }, .{
            .expand = .both,
            .background = false,
            .corner_radius = dvui.Rect.all(1000),
        });

        defer scroll_area.deinit();

        const vertical_scroll = file.editor.layers_scroll_info.offset(.vertical);

        var tree = pixi.dvui.TreeWidget.tree(@src(), .{ .enable_reordering = true }, .{
            .expand = .horizontal,
            .background = false,
        });
        defer tree.deinit();

        var layer_hits_buf: [256]LayerRowHit = undefined;
        var layer_hits_len: usize = 0;

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
            .margin = dvui.Rect.rect(4, 0, 4, 4),
        });
        defer box.deinit();

        for (file.layers.items(.id), 0..) |layer_id, layer_index| {
            var row_label_r: ?dvui.Rect.Physical = null;
            const selected = if (edit_layer_id) |id| id == layer_id else file.selected_layer_index == layer_index;
            const visible = file.layers.items(.visible)[layer_index];
            const font = if (visible) dvui.Font.theme(.body) else dvui.Font.theme(.body).withStyle(.italic);

            var color = dvui.themeGet().color(.control, .fill_hover);
            if (pixi.editor.colors.file_tree_palette) |*palette| {
                color = palette.getDVUIColor(layer_id);
            }

            // `process_events` must be false: Tree Branch's header `ButtonWidget.processEvents` runs
            // `dvui.clicked`, which captures on press + dragPreStart for the full button rect (~row height),
            // stealing presses before label/sink (dvui `clickedEx` press handler).
            var branch = tree.branch(@src(), .{
                .expanded = false,
                .process_events = false,
                .can_accept_children = false,
                .animation_duration = 250_000,
                .animation_easing = dvui.easing.outBack,
            }, .{
                .id_extra = layer_id,
                .expand = .horizontal,
                .corner_radius = dvui.Rect.all(1000),
                .background = false,
                .margin = .all(0),
                .padding = .all(2),
            });
            defer branch.deinit();

            if (branch.removed()) {
                removed_index = layer_index;
            } else if (branch.insertBefore()) {
                insert_before_index = layer_index;
            }

            const row_r = branch.data().borderRectScale().r;
            const row_hovered = row_r.contains(dvui.currentWindow().mouse_pt);

            if (row_hovered) {
                file.peek_layer_index = layer_index;
            }

            var min_layer_index: usize = 0;
            if (file.editor.isolate_layer) {
                if (file.peek_layer_index) |peek_layer_index| {
                    min_layer_index = peek_layer_index;
                } else if (!pixi.editor.explorer.tools.layersHovered()) {
                    min_layer_index = file.selected_layer_index;
                }
            }

            const below_mouse = dvui.currentWindow().mouse_pt.y > branch.data().contentRectScale().r.y + branch.data().contentRectScale().r.h;

            var alpha: f32 = dvui.alpha(1.0);
            if (file.editor.isolate_layer and (layer_index < min_layer_index or (below_mouse and tools.layersHovered()))) {
                alpha = dvui.alpha(0.5);
            }
            defer dvui.alphaSet(alpha);

            const ctrl_hover = dvui.themeGet().color(.control, .fill).opacity(0.5);
            var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .expand = .both,
                .background = true,
                .color_fill = if (branch.floating())
                    dvui.themeGet().color(.control, .fill_hover)
                else if (selected or (row_hovered and tree.drag_point == null))
                    ctrl_hover
                else
                    .transparent,
                .color_fill_hover = if (branch.floating()) ctrl_hover else .transparent,
                .margin = dvui.Rect{},
                .padding = dvui.Rect.all(0),
                .corner_radius = dvui.Rect.all(8),
                .box_shadow = if (branch.floating()) .{
                    .color = .black,
                    .offset = .{ .x = -2.0, .y = 2.0 },
                    .fade = 6.0,
                    .alpha = 0.25,
                    .corner_radius = dvui.Rect.all(1000),
                } else null,
            });
            defer hbox.deinit();

            // _ = dvui.icon(
            //     @src(),
            //     "LayerIcon",
            //     icons.tvg.heroicons.solid.@"square-3-stack-3d",
            //     .{
            //         .stroke_color = if (!(selected or row_hovered)) dvui.themeGet().color(.control, .fill) else if (selected) dvui.themeGet().color(.window, .text) else dvui.themeGet().color(.window, .fill),
            //         .fill_color = if (!(selected or row_hovered)) dvui.themeGet().color(.control, .fill) else if (selected) dvui.themeGet().color(.window, .text) else dvui.themeGet().color(.window, .fill),
            //     },
            //     .{ .expand = .none, .gravity_y = 0.5, .margin = .{ .x = 4, .w = 4 } },
            // );

            var color_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .expand = .none,
                .background = true,
                .gravity_y = 0.5,
                .min_size_content = .{ .w = 8.0, .h = 8.0 },
                .color_fill = color,
                .corner_radius = dvui.Rect.all(1000),
                .margin = .{ .x = 4, .w = 4 },
                .padding = dvui.Rect.all(0),
            });
            color_box.deinit();

            if (edit_layer_id != layer_id) {
                // Always use the same label wrapper so sibling widget ids (drag_sink, button_box) stay stable
                // when selection changes — otherwise the extra box only on the selected row causes a layout flash.
                var name_label_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
                    .expand = .none,
                    .background = false,
                    .gravity_y = 0.5,
                    .margin = dvui.Rect.rect(2, 0, 2, 0),
                    .padding = dvui.Rect.all(0),
                });
                defer name_label_box.deinit();

                dvui.labelNoFmt(@src(), file.layers.items(.name)[layer_index], .{}, .{
                    .expand = .none,
                    .gravity_y = 0.5,
                    .margin = dvui.Rect{},
                    .font = font,
                    .padding = dvui.Rect.all(0),
                    .color_text = if (!selected) dvui.themeGet().color(.control, .text) else dvui.themeGet().color(.window, .text),
                });

                if (file.selected_layer_index == layer_index) {
                    row_label_r = name_label_box.data().borderRectScale().r;
                }
            } else {
                var te = dvui.textEntry(@src(), .{}, .{
                    .expand = .horizontal,
                    .background = false,
                    .padding = dvui.Rect.all(0),
                    .margin = dvui.Rect.all(0),
                    .font = font,
                    .gravity_y = 0.5,
                });
                defer te.deinit();

                if (dvui.firstFrame(te.data().id)) {
                    te.textSet(file.layers.items(.name)[layer_index], true);
                    dvui.focusWidget(te.data().id, null, null);
                }

                layer_rename_hit_te_id = te.data().id;
                layer_rename_hit_rect = te.data().borderRectScale().r;

                const should_commit_rename = te.enter_pressed or dvui.focusedWidgetId() != te.data().id;
                if (should_commit_rename) {
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
                    if (te.enter_pressed) {
                        file.selected_layer_index = layer_index;
                    }
                    dvui.captureMouse(null, 0);
                    dvui.focusWidget(null, null, null);
                    edit_layer_id = null;
                    dvui.refresh(null, @src(), tree.data().id);
                }
            }

            if (edit_layer_id != layer_id) {
                var drag_sink = dvui.box(@src(), .{ .dir = .horizontal }, .{
                    .expand = .both,
                    .background = false,
                    .min_size_content = .{ .w = 0, .h = 0 },
                    .gravity_y = 0.5,
                });
                defer drag_sink.deinit();

                var button_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
                    .expand = .none,
                    .background = false,
                    .gravity_x = 1.0,
                    .gravity_y = 0.5,
                });
                defer button_box.deinit();

                if (dvui.buttonIcon(
                    @src(),
                    "collapse_button",
                    if (file.layers.items(.collapse)[layer_index]) icons.tvg.lucide.@"arrow-down-to-line" else icons.tvg.lucide.package,
                    .{ .draw_focus = false },
                    .{},
                    .{
                        .expand = .ratio,
                        .min_size_content = .{ .w = 1.0, .h = 11.0 },
                        .id_extra = layer_index,
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
                    .{
                        .expand = .ratio,
                        .min_size_content = .{ .w = 1.0, .h = 11.0 },
                        .id_extra = layer_index,
                        .corner_radius = dvui.Rect.all(1000),
                        .margin = dvui.Rect.all(1),
                    },
                )) {
                    file.layers.items(.visible)[layer_index] = !file.layers.items(.visible)[layer_index];
                }

                if (layer_hits_len < layer_hits_buf.len) {
                    layer_hits_buf[layer_hits_len] = .{
                        .label_r = row_label_r,
                        .row_r = branch.data().borderRectScale().r,
                        .buttons_r = button_box.data().borderRectScale().r,
                        .branch_usize = branch.data().id.asUsize(),
                        .layer_index = layer_index,
                        .hbox_tl = hbox.data().rectScale().r.topLeft(),
                    };
                    layer_hits_len += 1;
                }

                if (row_hovered) {
                    const mp = dvui.currentWindow().mouse_pt;
                    if (!button_box.data().borderRectScale().r.contains(mp)) {
                        dvui.cursorSet(.hand);
                    }
                }
            } else {
                var button_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
                    .expand = .none,
                    .background = false,
                    .gravity_x = 1.0,
                });
                defer button_box.deinit();

                if (dvui.buttonIcon(
                    @src(),
                    "collapse_button",
                    if (file.layers.items(.collapse)[layer_index]) icons.tvg.lucide.@"arrow-down-to-line" else icons.tvg.lucide.package,
                    .{ .draw_focus = false },
                    .{},
                    .{
                        .expand = .ratio,
                        .min_size_content = .{ .w = 1.0, .h = 11.0 },
                        .id_extra = layer_index,
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
                    .{
                        .expand = .ratio,
                        .min_size_content = .{ .w = 1.0, .h = 11.0 },
                        .id_extra = layer_index,
                        .corner_radius = dvui.Rect.all(1000),
                        .margin = dvui.Rect.all(1),
                    },
                )) {
                    file.layers.items(.visible)[layer_index] = !file.layers.items(.visible)[layer_index];
                }
            }
        }

        processLayerTreePointerEvents(tree, file, layer_hits_buf[0..layer_hits_len]);

        if (tree.drag_point != null) {
            const tail = tree.branch(@src(), .{
                .expanded = false,
                .process_events = false,
                .can_accept_children = false,
            }, .{
                .id_extra = 0x7fff_fffe,
                .expand = .horizontal,
                .min_size_content = .{ .w = 0, .h = 14 },
                .color_fill = .transparent,
                .color_fill_hover = .transparent,
                .color_fill_press = .transparent,
            });
            defer tail.deinit();
            if (tail.insertBefore()) {
                insert_before_index = file.layers.len;
            }
        }

        // Only draw shadow if the scroll bar has been scrolled some
        if (vertical_scroll > 0.0)
            pixi.dvui.drawEdgeShadow(scroll_area.data().contentRectScale(), .top, .{});

        if (file.editor.layers_scroll_info.virtual_size.h > file.editor.layers_scroll_info.viewport.h and vertical_scroll < file.editor.layers_scroll_info.scrollMax(.vertical))
            pixi.dvui.drawEdgeShadow(scroll_area.data().contentRectScale(), .bottom, .{});
    }

    if (pixi.dvui.hovered(vbox.data())) {
        return vbox.data().contentRectScale().r;
    }

    return null;
}

pub fn drawColors() !void {
    dvui.labelNoFmt(@src(), "COLORS", .{}, .{ .font = dvui.Font.theme(.title).larger(-3.0).withWeight(.bold) });

    var hbox = dvui.box(@src(), .{ .dir = .horizontal, .equal_space = true }, .{
        .expand = .horizontal,
        .background = false,
        .min_size_content = .{ .w = 64.0, .h = 64.0 },
        .margin = dvui.Rect.all(4),
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
        .margin = dvui.Rect.all(4),
        .padding = dvui.Rect.all(0),
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
        var primary_button: dvui.ButtonWidget = undefined;
        primary_button.init(@src(), .{}, button_opts);
        defer primary_button.deinit();

        primary_button.processEvents();
        primary_button.drawBackground();

        drawColorPicker(primary_button.data().rectScale().r, &pixi.editor.colors.primary) catch {};

        if (primary_button.clicked()) clicked = true;
    }

    {
        var secondary_button: dvui.ButtonWidget = undefined;
        secondary_button.init(@src(), .{}, button_opts.override(secondary_overrider));
        defer secondary_button.deinit();

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

pub fn drawPaletteControls() !void {
    var box = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .background = false,
    });
    defer box.deinit();

    dvui.labelNoFmt(@src(), "PALETTES", .{}, .{ .font = dvui.Font.theme(.title).larger(-3.0).withWeight(.bold) });

    if (dvui.buttonIcon(@src(), "PinPalettes", dvui.entypo.pin, .{ .draw_focus = false }, .{}, .{
        .expand = .none,
        .gravity_y = 0.5,
        .gravity_x = 1.0,
        .corner_radius = dvui.Rect.all(1000),
        .box_shadow = .{
            .color = .black,
            .offset = .{ .x = -2.0, .y = 2.0 },
            .fade = 6.0,
            .alpha = 0.15,
            .corner_radius = dvui.Rect.all(1000),
        },
        .rotation = std.math.pi * 0.25,
        .style = if (pixi.editor.explorer.pinned_palettes) .highlight else .control,
    })) {
        pixi.editor.explorer.pinned_palettes = !pixi.editor.explorer.pinned_palettes;
    }
}

pub fn drawPalettes() !void {
    var scroll_area = dvui.scrollArea(@src(), .{}, .{
        .expand = .both,
        .background = false,
    });
    defer scroll_area.deinit();

    // Palette search dropdown
    {
        const oldt = dvui.themeGet();
        var t = oldt;
        t.control.fill = t.window.fill;
        dvui.themeSet(t);
        defer dvui.themeSet(oldt);

        var dropdown: dvui.DropdownWidget = undefined;
        dropdown.init(@src(), .{ .label = "Palette" }, .{
            .expand = .horizontal,
            .corner_radius = dvui.Rect.all(1000),
        });

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
            dvui.labelNoFmt(@src(), "Built-in", .{}, .{
                .margin = .all(0),
                .gravity_x = 0.5,
            });
            _ = dvui.separator(@src(), .{ .expand = .horizontal });

            var it = (try assets.root.dir("palettes")).iterate();
            while (it.next()) |entry| {
                switch (entry.data) {
                    .file => |data| {
                        const ext = std.fs.path.extension(entry.name);
                        if (std.mem.eql(u8, ext, ".hex")) {
                            if (dropdown.addChoiceLabel(entry.name)) {
                                pixi.editor.colors.palette = pixi.Internal.Palette.loadFromBytes(pixi.app.allocator, entry.name, data) catch |err| {
                                    dvui.log.err("Failed to load palette: {s}", .{@errorName(err)});
                                    return error.FailedToLoadPalette;
                                };
                            }
                        }
                    },
                    .dir => |_| {},
                }
            }

            _ = dvui.separator(@src(), .{ .expand = .horizontal });
            searchPalettes(&dropdown) catch {
                dvui.log.err("Failed to search palettes", .{});
            };
        }

        _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 10, .h = 10 } });
    }

    {
        if (pixi.editor.colors.palette) |*palette| {
            var flex_box = dvui.flexbox(@src(), .{ .justify_content = .start }, .{
                .expand = .horizontal,
                .max_size_content = .{
                    .w = pixi.editor.explorer.rect.w - 20 * dvui.currentWindow().natural_scale,
                    .h = pixi.editor.explorer.rect.h - 20 * dvui.currentWindow().natural_scale,
                },
            });

            var triangles = dvui.Triangles.Builder.init(dvui.currentWindow().arena(), palette.colors.len * 300, palette.colors.len * 300 * 30) catch return;

            for (palette.colors, 0..) |color, i| {
                var anim = dvui.animate(
                    @src(),
                    .{
                        .duration = 250_000 + 10_000 * @as(i32, @intCast(i)),
                        .kind = .horizontal,
                        .easing = dvui.easing.outBack,
                    },
                    .{
                        .expand = .none,
                        .id_extra = dvui.Id.extendId(flex_box.data().id, @src(), i).update(palette.name).asUsize(),
                    },
                );
                defer anim.deinit();

                var box_widget = dvui.box(@src(), .{ .dir = .horizontal }, .{
                    .expand = .none,
                    .min_size_content = .{ .w = 24.0, .h = 24.0 },
                    .id_extra = i,
                    .background = false,
                    .margin = dvui.Rect.all(1),
                });

                const button_center = box_widget.data().rectScale().r.center();
                const dist = dvui.currentWindow().mouse_pt.diff(button_center).length();

                // Calculate scale based on mouse distance (closer = larger)
                const max_distance = 24.0 * dvui.currentWindow().natural_scale; // Maximum distance for scaling effect
                const scale_factor = if (dist < max_distance)
                    1.0 + (1.0 - (dist / max_distance)) * 0.5 // Scale up to 1.5x when very close
                else
                    1.0;

                var path = dvui.Path.Builder.init(dvui.currentWindow().arena());
                defer path.deinit();

                var rect = box_widget.data().rect.scale(scale_factor, dvui.Rect);
                rect.x = box_widget.data().rect.center().x - rect.w / 2.0;
                rect.y = box_widget.data().rect.center().y - rect.h / 2.0;

                box_widget.deinit();

                var button_widget: dvui.ButtonWidget = undefined;
                button_widget.init(@src(), .{}, .{
                    .expand = .none,
                    .rect = rect,
                    .id_extra = i,
                });

                defer button_widget.deinit();

                path.addRect(button_widget.data().rectScale().r, .all(1000));

                const base_index: u16 = @intCast(triangles.vertexes.items.len);

                const b = path.build().fillConvexTriangles(
                    dvui.currentWindow().arena(),
                    .{ .color = .{
                        .r = color[0],
                        .g = color[1],
                        .b = color[2],
                        .a = color[3],
                    }, .fade = 1.0 },
                ) catch return;
                for (b.vertexes) |vertex| {
                    triangles.appendVertex(vertex);
                }
                for (b.indices) |*index| {
                    index.* += @as(u16, @intCast(base_index));
                }
                triangles.appendTriangles(b.indices);

                if (dvui.clickedEx(button_widget.data(), .{ .buttons = .any })) |evt| {
                    switch (evt) {
                        .mouse => |mouse_evt| {
                            switch (mouse_evt.button) {
                                .left => {
                                    @memcpy(&pixi.editor.colors.primary, &color);
                                },
                                .right => {
                                    @memcpy(&pixi.editor.colors.secondary, &color);
                                },

                                else => {},
                            }
                        },

                        else => {},
                    }
                }
            }

            flex_box.deinit();

            const clip = dvui.clip(dvui.currentWindow().rect_pixels);
            defer dvui.clipSet(clip);

            dvui.renderTriangles(triangles.build(), null) catch {
                dvui.log.err("Failed to render triangles", .{});
            };
        }
    }
}
fn searchPalettes(dropdown: *dvui.DropdownWidget) !void {
    var dir_opt = std.fs.cwd().openDir(pixi.editor.palette_folder, .{ .access_sub_paths = false, .iterate = true }) catch null;
    if (dir_opt) |*dir| {
        defer dir.close();
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file) {
                const ext = std.fs.path.extension(entry.name);
                if (std.mem.eql(u8, ext, ".hex")) {
                    const label = try std.fmt.allocPrint(dvui.currentWindow().arena(), "{s}", .{entry.name});
                    if (dropdown.addChoiceLabel(label)) {
                        const abs_path = try std.fs.path.join(dvui.currentWindow().arena(), &.{ pixi.editor.palette_folder, entry.name });

                        if (pixi.editor.colors.palette) |*palette|
                            palette.deinit();

                        pixi.editor.colors.palette = pixi.Internal.Palette.loadFromFile(pixi.app.allocator, abs_path) catch |err| {
                            dvui.log.err("Failed to load palette: {s}", .{@errorName(err)});
                            return error.FailedToLoadPalette;
                        };
                    }
                }
            }
        }
    }
}

/// Geometry for one layer row, collected while drawing; used for a single chronological pointer pass.
const LayerRowHit = struct {
    row_r: dvui.Rect.Physical,
    buttons_r: dvui.Rect.Physical,
    branch_usize: usize,
    layer_index: usize,
    hbox_tl: dvui.Point.Physical,
    /// When non-null, selected row's name label rect (press+release here without a drag opens rename).
    label_r: ?dvui.Rect.Physical,
};

fn layerGestureMatches(file: *const pixi.Internal.File) bool {
    return layer_row_gesture != null and layer_row_gesture.?.file_id == file.id;
}

/// Clear in-flight gesture only (no `dragEnd`). Used before arming a new row press.
fn layerTreeClearGestureKeysOnly(_: *const pixi.Internal.File) void {
    layer_row_gesture = null;
}

/// Clear gesture and global `Dragging` (stale prestart/drag from other widgets).
fn layerTreeResetRowPointerGesture(_: *const pixi.Internal.File) void {
    dvui.dragEnd();
    layer_row_gesture = null;
}

/// Rename `textEntry` is drawn above the row; skip layer-tree handling when it already consumed the event
/// or the pointer maps to its rect (runs after `textEntry()` so rects/targets are valid this frame).
fn layerPointerRenameConsumes(e: *const dvui.Event, me: dvui.Event.Mouse) bool {
    if (e.handled) return true;
    if (layer_rename_hit_te_id) |rid| {
        if (e.target_widgetId) |tid| {
            if (tid == rid) return true;
        }
    }
    if (layer_rename_hit_rect) |r| {
        if (r.contains(me.p)) return true;
    }
    return false;
}

fn layerTreePointerInTreeSurface(tree: *pixi.dvui.TreeWidget, p: dvui.Point.Physical, floating_win: dvui.Id) bool {
    if (floating_win != dvui.subwindowCurrentId()) return false;
    const tr = tree.data().borderRectScale().r;
    if (!tr.contains(p)) return false;
    if (!dvui.clipGet().contains(p)) return false;
    return true;
}

fn layerTreePointerInTreeBorder(tree: *pixi.dvui.TreeWidget, p: dvui.Point.Physical, floating_win: dvui.Id) bool {
    if (floating_win != dvui.subwindowCurrentId()) return false;
    return tree.data().borderRectScale().r.contains(p);
}

/// While another widget holds capture, `target_widgetId` may not be the tree. Allow starting a reorder drag
/// when the pointer is over the tree border (scroll clip can disagree with visible row geometry).
fn layerTreeMotionAllowsLayerReorder(tree: *pixi.dvui.TreeWidget, e: *dvui.Event) bool {
    if (e.target_widgetId) |fwid| {
        if (fwid == tree.data().id) return true;
    }
    const cw = dvui.currentWindow();
    if (cw.dragging.state == .dragging and cw.dragging.name != null) return false;
    const me = e.evt.mouse;
    const in_surface = layerTreePointerInTreeSurface(tree, me.p, me.floating_win);
    const in_border = layerTreePointerInTreeBorder(tree, me.p, me.floating_win);
    return in_surface or in_border;
}

/// One pass over `events()` in frame order: press → motion → release.
/// Runs after layer rows (and rename `textEntry`) are built so geometry and `e.handled` reflect z-order.
fn processLayerTreePointerEvents(tree: *pixi.dvui.TreeWidget, file: *pixi.Internal.File, hits: []const LayerRowHit) void {
    if (!tree.init_options.enable_reordering) return;

    for (dvui.events()) |*e| {
        switch (e.evt) {
            .mouse => |me| {
                if (me.action == .press and me.button.pointer()) {
                    if (layerPointerRenameConsumes(e, me)) continue;

                    var row_hit: ?LayerRowHit = null;
                    var ri = hits.len;
                    while (ri > 0) {
                        ri -= 1;
                        const h = hits[ri];
                        if (h.row_r.contains(me.p) and !h.buttons_r.contains(me.p)) {
                            row_hit = h;
                            break;
                        }
                    }
                    if (row_hit) |h| {
                        const cw = dvui.currentWindow();
                        if (cw.dragging.state != .none) dvui.dragEnd();
                        layerTreeClearGestureKeysOnly(file);
                        dvui.dragPreStart(me.p, .{ .offset = h.hbox_tl.diff(me.p) });
                        layer_row_gesture = .{
                            .file_id = file.id,
                            .press_idx = h.layer_index,
                            .press_p = me.p,
                            .drag_branch = h.branch_usize,
                            .moved = false,
                            .reorder_drag = false,
                        };
                    } else {
                        layerTreeResetRowPointerGesture(file);
                    }
                    continue;
                }

                if (me.action == .motion) {
                    if (layerPointerRenameConsumes(e, me)) continue;

                    if (layer_row_gesture) |*g| {
                        if (g.file_id == file.id) {
                            const dx = me.p.x - g.press_p.x;
                            const dy = me.p.y - g.press_p.y;
                            if (dx * dx + dy * dy > 16.0) {
                                g.moved = true;
                            }
                        }
                    }

                    // After `tree.dragStart`, `drag_branch` is cleared — do not gate `matchEvent` on it.
                    if (tree.reorderDragActive()) {
                        _ = tree.matchEvent(e);
                        continue;
                    }

                    const branch_usize = if (layerGestureMatches(file)) layer_row_gesture.?.drag_branch else null;
                    if (branch_usize == null) continue;
                    _ = tree.matchEvent(e);
                    if (!layerTreeMotionAllowsLayerReorder(tree, e)) continue;

                    const prev_th = dvui.Dragging.threshold;
                    dvui.Dragging.threshold = @max(prev_th, 8.0);
                    defer dvui.Dragging.threshold = prev_th;
                    if (dvui.dragging(me.p, null)) |_| {
                        tree.dragStart(branch_usize.?, me.p);
                        if (layer_row_gesture) |*g| {
                            if (g.file_id == file.id) {
                                g.reorder_drag = true;
                                g.drag_branch = null;
                            }
                        }
                    }
                } else if (me.action == .release and me.button.pointer()) {
                    if (layerPointerRenameConsumes(e, me)) continue;

                    const sel_before = file.selected_layer_index;
                    var release_layer: ?usize = null;
                    var rj = hits.len;
                    while (rj > 0) {
                        rj -= 1;
                        const h = hits[rj];
                        if (h.row_r.contains(me.p) and !h.buttons_r.contains(me.p)) {
                            release_layer = h.layer_index;
                            break;
                        }
                    }

                    const idx_opt: ?usize = if (layerGestureMatches(file)) layer_row_gesture.?.press_idx else null;
                    const did_reorder = if (layerGestureMatches(file)) layer_row_gesture.?.reorder_drag else false;

                    var selected_on_release = false;
                    if (!did_reorder and !tree.drag_ending) {
                        if (release_layer) |rh| {
                            file.selected_layer_index = rh;
                            selected_on_release = true;
                        } else if (idx_opt) |idx| {
                            file.selected_layer_index = idx;
                            selected_on_release = true;
                        }
                    }

                    var opened_layer_rename = false;
                    const moved_while_armed = if (layerGestureMatches(file)) layer_row_gesture.?.moved else false;

                    if (!did_reorder and !tree.drag_ending and !moved_while_armed) {
                        if (idx_opt) |pi| {
                            if (release_layer) |rl| {
                                if (pi == rl and sel_before == pi) {
                                    if (layerGestureMatches(file)) {
                                        const pp = layer_row_gesture.?.press_p;
                                        for (hits) |h| {
                                            if (h.layer_index != pi) continue;
                                            if (h.label_r) |lr| {
                                                if (lr.contains(pp) and lr.contains(me.p)) {
                                                    edit_layer_id = file.layers.items(.id)[pi];
                                                    opened_layer_rename = true;
                                                }
                                            }
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if (idx_opt != null) {
                        layerTreeResetRowPointerGesture(file);
                        if (!did_reorder and !dvui.captured(tree.data().id)) {
                            dvui.captureMouse(null, e.num);
                        }
                    }

                    if (selected_on_release or opened_layer_rename) {
                        dvui.refresh(null, @src(), tree.data().id);
                    }
                }
            },
            else => {},
        }
    }
}
