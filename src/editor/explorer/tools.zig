const std = @import("std");
const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");
const icons = @import("icons");

var removed_index: ?usize = null;
var insert_before_index: ?usize = null;

pub fn draw() !void {
    drawTools() catch {};
    drawLayers() catch {};
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
    if (pixi.editor.getFile(pixi.editor.open_file_index)) |file| {
        dvui.labelNoFmt(@src(), "LAYERS", .{}, .{ .font_style = .title });

        var scroll_area = dvui.scrollArea(@src(), .{}, .{
            .expand = .horizontal,
            .background = false,
            .corner_radius = dvui.Rect.all(1000),
            .max_size_content = .{ .h = 300, .w = std.math.floatMax(f32) },
        });
        defer scroll_area.deinit();

        var reorderable = pixi.dvui.reorder(@src(), .{
            .expand = .horizontal,
            .background = false,
        });
        defer reorderable.deinit();

        if (insert_before_index) |insert_before| {
            if (removed_index) |removed| {
                const layer = file.layers.get(removed);
                file.layers.orderedRemove(removed);

                if (insert_before <= file.layers.len) {
                    file.layers.insert(pixi.app.allocator, if (removed > insert_before) insert_before + 1 else insert_before, layer) catch {
                        std.log.err("Failed to insert layer", .{});
                    };
                } else {
                    std.log.info("Inserting layer at end", .{});
                    file.layers.insert(pixi.app.allocator, if (removed > insert_before) file.layers.len else 0, layer) catch {
                        std.log.err("Failed to insert layer", .{});
                    };
                }

                insert_before_index = null;
                removed_index = null;
            }
        }

        const box = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .horizontal,
            .background = false,
            .corner_radius = dvui.Rect.all(1000),
            .margin = .{ .h = 4, .w = 4, .x = 4, .y = 4 },
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
            });
            defer r.deinit();

            if (r.removed()) {
                removed_index = layer_index;
            } else if (r.insertBefore()) {
                insert_before_index = layer_index;
            }

            var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .expand = .horizontal,
                .background = true,
                .color_fill = .fill_window,
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

            _ = pixi.dvui.ReorderWidget.draggable(@src(), .{ .reorderable = r, .tvg_bytes = icons.tvg.lucide.@"grip-horizontal", .color = .fromTheme(.text_press) }, .{ .expand = .none, .gravity_y = 0.5, .margin = .{ .x = 4, .w = 4 } });

            dvui.labelNoFmt(@src(), file.layers.items(.name)[layer_index], .{}, .{ .gravity_y = 0.5 });

            var button_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .expand = .none,
                .background = false,
                .gravity_x = 1.0,
            });
            defer button_box.deinit();

            if (dvui.buttonIcon(@src(), "hide_button", if (file.layers.items(.visible)[layer_index]) icons.tvg.lucide.eye else icons.tvg.lucide.@"eye-closed", .{}, .{}, .{
                .expand = .none,
                .id_extra = layer_index,
                .gravity_y = 0.5,
                .corner_radius = dvui.Rect.all(1000),
            })) {
                file.layers.items(.visible)[layer_index] = !file.layers.items(.visible)[layer_index];
            }
        }

        if (reorderable.finalSlot()) {
            insert_before_index = file.layers.len;
        }
    }
}
