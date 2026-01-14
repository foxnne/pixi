const std = @import("std");
const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");

pub var mode: enum(usize) {
    single_tile,
    grid,
} = .single_tile;

pub var tile_size: [2]u32 = .{ 32, 32 };
pub var grid_size: [2]u32 = .{ 1, 1 };

pub fn dialog(id: dvui.Id) anyerror!bool {

    // Reference our parent path so it remains alive until the dialog is closed
    _ = dvui.dataGetSlice(null, id, "_parent_path", []u8);

    var outer_box = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both });
    defer outer_box.deinit();

    var valid: bool = true;

    {
        const hbox = dvui.box(@src(), .{ .dir = .horizontal, .equal_space = true }, .{ .expand = .horizontal, .corner_radius = .all(100000) });
        defer hbox.deinit();

        for (0..2) |i| {
            const color = if (i == @intFromEnum(mode)) dvui.themeGet().color(.window, .fill).lighten(-4) else dvui.themeGet().color(.control, .fill);
            const button_opts: dvui.Options = .{
                .padding = if (i == 0) .{ .x = 4, .y = 4, .h = 4 } else .{ .y = 4, .h = 4, .w = 4 },
                .margin = .{ .y = 2, .h = 4 },
                .corner_radius = if (i == 0) .{ .x = 100000, .h = 100000 } else .{ .y = 100000, .w = 100000 },
                .expand = .horizontal,
                .color_fill = color,
                .id_extra = i,
            };

            var button: dvui.ButtonWidget = undefined;
            button.init(@src(), .{}, button_opts);
            defer button.deinit();

            if (i != @intFromEnum(mode)) {
                button.processEvents();
            }

            button.drawBackground();

            if (i == 0) {
                dvui.labelNoFmt(@src(), "Single Tile", .{}, button_opts.strip().override(button.style()).override(.{ .gravity_x = 0.5, .gravity_y = 0.5 }));
                if (button.clicked()) {
                    mode = .single_tile;
                    _ = dvui.dataSet(null, id, "_id_extra", id.update("single_tile").asUsize());
                }
            } else {
                dvui.labelNoFmt(@src(), "Grid", .{}, button_opts.strip().override(button.style()).override(.{ .gravity_x = 0.5, .gravity_y = 0.5 }));
                if (button.clicked()) {
                    mode = .grid;
                    _ = dvui.dataSet(null, id, "_id_extra", id.update("grid").asUsize());
                }
            }
        }
    }

    {
        var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer hbox.deinit();

        {
            dvui.label(@src(), "{s}", .{if (mode == .single_tile) "Width:" else "Column Width:"}, .{ .gravity_y = 0.5 });
            const result = dvui.textEntryNumber(@src(), u32, .{ .min = 1, .max = 4096, .value = &tile_size[0], .show_min_max = true }, .{
                .box_shadow = .{ .color = .black, .alpha = 0.25, .offset = .{ .x = -4, .y = 4 }, .fade = 8 },
                .label = .{ .label_widget = .prev },
                .gravity_x = 1.0,
            });
            if (result.value == .Valid) {
                tile_size[0] = result.value.Valid;
            } else {
                valid = false;
            }
        }
    }

    {
        var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer hbox.deinit();

        {
            dvui.label(@src(), "{s}", .{if (mode == .single_tile) "Height:" else "Row Height:"}, .{ .gravity_y = 0.5 });
            const result = dvui.textEntryNumber(@src(), u32, .{ .min = 1, .max = 4096, .value = &tile_size[1] }, .{
                .box_shadow = .{ .color = .black, .alpha = 0.25, .offset = .{ .x = -4, .y = 4 }, .fade = 8 },
                .label = .{ .label_widget = .prev },
                .gravity_x = 1.0,
            });
            if (result.value == .Valid) {
                tile_size[1] = result.value.Valid;
            } else {
                valid = false;
            }
        }
    }

    if (mode == .grid) {
        {
            {
                var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .both });
                defer hbox.deinit();

                dvui.label(@src(), "Columns:", .{}, .{ .gravity_y = 0.5 });
                const result = dvui.textEntryNumber(@src(), u32, .{ .min = 1, .max = @divTrunc(4096, tile_size[0]), .value = &grid_size[0] }, .{
                    .box_shadow = .{ .color = .black, .alpha = 0.25, .offset = .{ .x = -4, .y = 4 }, .fade = 8 },
                    .label = .{ .label_widget = .prev },
                    .gravity_x = 1.0,
                });
                if (result.value == .Valid) {
                    grid_size[0] = result.value.Valid;
                } else {
                    valid = false;
                }
            }
            {
                var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .both });
                defer hbox.deinit();
                dvui.label(@src(), "Rows:", .{}, .{ .gravity_y = 0.5 });
                const result = dvui.textEntryNumber(@src(), u32, .{ .min = 1, .max = @divTrunc(4096, tile_size[1]), .value = &grid_size[1] }, .{
                    .box_shadow = .{ .color = .black, .alpha = 0.25, .offset = .{ .x = -4, .y = 4 }, .fade = 8 },
                    .label = .{ .label_widget = .prev },
                    .gravity_x = 1.0,
                });
                if (result.value == .Valid) {
                    grid_size[1] = result.value.Valid;
                } else {
                    valid = false;
                }
            }
        }
    }
    return valid;
}

pub fn callAfter(id: dvui.Id, response: dvui.enums.DialogResponse) anyerror!void {
    _ = dvui.dataGetSlice(null, id, "_parent_path", []u8) orelse {
        dvui.log.err("Lost data for dialog {x}\n", .{id});
        dvui.dialogRemove(id);
        return;
    };

    switch (response) {
        .ok => {},
        .cancel => {},
        else => {},
    }
}
