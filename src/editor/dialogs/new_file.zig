const std = @import("std");
const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");

pub var mode: enum(usize) {
    single,
    grid,
} = .single;

pub var columns: u32 = 1;
pub var rows: u32 = 1;
pub var column_width: u32 = 32;
pub var row_height: u32 = 32;

pub const max_size: [2]u32 = .{ 4096, 4096 };
pub const min_size: [2]u32 = .{ 1, 1 };

pub fn dialog(id: dvui.Id) anyerror!bool {

    // Reference our parent path so it remains alive until the dialog is closed
    _ = dvui.dataGetSlice(null, id, "_parent_path", []u8);

    var outer_box = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both });
    defer outer_box.deinit();

    {
        var valid: bool = true;

        var unique_id = id.update(if (mode == .single) "single" else "grid");

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
                    dvui.labelNoFmt(@src(), "Single", .{}, button_opts.strip().override(button.style()).override(.{ .gravity_x = 0.5, .gravity_y = 0.5 }));
                    if (button.clicked()) {
                        mode = .single;
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
                dvui.label(@src(), "{s}", .{if (mode == .single) "Width (x):" else "Column Width (x):"}, .{ .gravity_y = 0.5, .gravity_x = 0.0 });
                const result = dvui.textEntryNumber(@src(), u32, .{ .min = min_size[0], .max = max_size[0], .value = &column_width, .show_min_max = true }, .{
                    .box_shadow = .{ .color = .black, .alpha = 0.25, .offset = .{ .x = -4, .y = 4 }, .fade = 8 },
                    .label = .{ .label_widget = .prev },
                    .gravity_x = 1.0,
                    .id_extra = unique_id.asUsize(),
                });
                if (result.value == .Valid) {
                    column_width = result.value.Valid;
                } else {
                    valid = false;
                }
            }
        }

        {
            var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
            defer hbox.deinit();

            {
                dvui.label(@src(), "{s}", .{if (mode == .single) "Height (y):" else "Row Height (y):"}, .{ .gravity_y = 0.5, .gravity_x = 0.0 });
                const result = dvui.textEntryNumber(@src(), u32, .{ .min = min_size[1], .max = max_size[1], .value = &row_height, .show_min_max = true }, .{
                    .box_shadow = .{ .color = .black, .alpha = 0.25, .offset = .{ .x = -4, .y = 4 }, .fade = 8 },
                    .label = .{ .label_widget = .prev },
                    .gravity_x = 1.0,
                    .id_extra = unique_id.asUsize(),
                });
                if (result.value == .Valid) {
                    row_height = result.value.Valid;
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

                    dvui.label(@src(), "Columns (x):", .{}, .{ .gravity_y = 0.5 });
                    const result = dvui.textEntryNumber(@src(), u32, .{ .min = 1, .max = @divTrunc(max_size[0], column_width), .value = &columns, .show_min_max = true }, .{
                        .box_shadow = .{ .color = .black, .alpha = 0.25, .offset = .{ .x = -4, .y = 4 }, .fade = 8 },
                        .label = .{ .label_widget = .prev },
                        .gravity_x = 1.0,
                        .id_extra = unique_id.asUsize(),
                    });
                    if (result.value == .Valid) {
                        columns = result.value.Valid;
                    } else {
                        valid = false;
                    }
                }
                {
                    var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .both });
                    defer hbox.deinit();
                    dvui.label(@src(), "Rows (y):", .{}, .{ .gravity_y = 0.5 });
                    const result = dvui.textEntryNumber(@src(), u32, .{ .min = 1, .max = @divTrunc(max_size[1], row_height), .value = &rows, .show_min_max = true }, .{
                        .box_shadow = .{ .color = .black, .alpha = 0.25, .offset = .{ .x = -4, .y = 4 }, .fade = 8 },
                        .label = .{ .label_widget = .prev },
                        .gravity_x = 1.0,
                        .id_extra = unique_id.asUsize(),
                    });
                    if (result.value == .Valid) {
                        rows = result.value.Valid;
                    } else {
                        valid = false;
                    }
                }
            }
        }
        _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 10, .h = 10 } });

        {
            var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
            defer hbox.deinit();

            dvui.label(
                @src(),
                "{d} px x {d} px",
                .{ column_width * (if (mode == .single) 1 else columns), row_height * (if (mode == .single) 1 else rows) },
                .{
                    .gravity_x = 0.5,
                    .font = dvui.themeGet().font_title.larger(-6),
                },
            );
        }

        return valid;
    }

    return false;
}

/// Returns a physical rect that the dialog should animate into after closing, or null if the dialog should be removed without animation
pub fn callAfter(id: dvui.Id, response: dvui.enums.DialogResponse) anyerror!void {
    const path = dvui.dataGetSlice(null, id, "_parent_path", []u8) orelse {
        dvui.log.err("Lost data for dialog {x}\n", .{id});
        dvui.dialogRemove(id);
        return error.LostData;
    };

    switch (response) {
        .ok => {
            const new_path = try std.fs.path.join(dvui.currentWindow().arena(), &.{ path, "untitled.pixi" });

            var file = pixi.editor.newFile(new_path, .{
                .column_width = column_width,
                .row_height = row_height,
                .columns = if (mode == .single) 1 else columns,
                .rows = if (mode == .single) 1 else rows,
            }) catch {
                dvui.log.err("Failed to create file: {s}", .{path});
                return error.FailedToCreateFile;
            };

            file.saveAsync() catch {
                dvui.log.err("Failed to save file: {s}", .{new_path});
                return error.FailedToSaveFile;
            };

            pixi.Editor.Explorer.files.new_file_path = pixi.app.allocator.dupe(u8, new_path) catch {
                dvui.log.err("Failed to duplicate path: {s}", .{new_path});
                return error.FailedToDuplicatePath;
            };
        },
        .cancel => {},
        else => {},
    }
}
