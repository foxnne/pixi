const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("pixi");
const settings = pixi.settings;
const editor = pixi.editor;

pub var hover_timer: f32 = 0.0;
pub var hover_label: [:0]const u8 = undefined;

pub fn draw() void {
    zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.window_rounding, .v = 0.0 });
    defer zgui.popStyleVar(.{ .count = 1 });
    zgui.setNextWindowPos(.{
        .x = (settings.sidebar_width + settings.explorer_width) * pixi.state.window.scale[0],
        .y = 0,
        .cond = .always,
    });
    zgui.setNextWindowSize(.{
        .w = (pixi.state.window.size[0] - settings.explorer_width - settings.sidebar_width) * pixi.state.window.scale[0],
        .h = pixi.state.window.size[1] * pixi.state.window.scale[1] + 5.0,
    });

    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.window_padding, .v = .{ 0.0, 0.0 } });
    zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.tab_rounding, .v = 0.0 });
    zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.child_border_size, .v = 1.0 });
    defer zgui.popStyleVar(.{ .count = 3 });
    if (zgui.begin("Art", .{
        .flags = .{
            .no_title_bar = true,
            .no_resize = true,
            .no_move = true,
            .no_collapse = true,
            .menu_bar = true,
        },
    })) {
        editor.menu.draw();

        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 0.0, 0.0 } });
        defer zgui.popStyleVar(.{ .count = 1 });
        if (zgui.beginChild("Artboard", .{
            .w = 0.0,
            .h = pixi.state.window.size[1] / 1.5 * pixi.state.window.scale[1],
            .border = false,
            .flags = .{},
        })) {
            defer zgui.endChild();
            if (pixi.state.open_files.items.len > 0) {
                if (zgui.beginTabBar("Files", .{
                    .reorderable = true,
                    .auto_select_new_tabs = true,
                })) {
                    defer zgui.endTabBar();

                    for (pixi.state.open_files.items) |file, i| {
                        var open: bool = true;

                        const file_name = std.fs.path.basename(file.path);

                        zgui.pushIntId(@intCast(i32, i));
                        defer zgui.popId();

                        const label = zgui.formatZ("  {s}  {s} ", .{ pixi.fa.file_powerpoint, file_name });

                        if (zgui.beginTabItem(label, .{
                            .p_open = &open,
                            .flags = .{
                                .set_selected = pixi.state.open_file_index == i,
                                .unsaved_document = file.dirty,
                            },
                        })) {
                            defer zgui.endTabItem();
                        }
                        if (zgui.isItemClicked(.left)) {
                            pixi.editor.setActiveFile(i);
                        }
                        if (zgui.isItemHovered(.{})) {
                            if (std.mem.eql(u8, label, hover_label)) {
                                hover_timer += pixi.state.gctx.stats.delta_time;
                            } else {
                                hover_label = label;
                                hover_timer = 0.0;
                            }

                            if (hover_timer >= 1.0) {
                                zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.window_padding, .v = .{ 4.0 * pixi.state.window.scale[0], 4.0 * pixi.state.window.scale[1] } });
                                defer zgui.popStyleVar(.{ .count = 1 });
                                zgui.beginTooltip();
                                defer zgui.endTooltip();
                                zgui.textColored(pixi.state.style.text_secondary.toSlice(), "{s}", .{file.path});
                            }
                        }

                        if (!open) {
                            pixi.editor.closeFile(i) catch unreachable;
                        }
                    }

                    if (pixi.settings.show_rulers) {
                        if (zgui.beginChild("TopRuler", .{
                            .h = zgui.getTextLineHeightWithSpacing(),
                            .border = false,
                            .flags = .{
                                .no_scrollbar = true,
                            },
                        })) {}
                        zgui.endChild();

                        if (zgui.beginChild("SideRuler", .{
                            .h = -1.0,
                            .w = zgui.getTextLineHeightWithSpacing(),
                            .border = false,
                            .flags = .{
                                .no_scrollbar = true,
                            },
                        })) {}
                        zgui.endChild();
                        zgui.sameLine(.{});
                    }

                    if (zgui.beginChild("Canvas", .{
                        .h = 0.0,
                        .w = 0.0,
                        .border = false,
                        .flags = .{
                            .horizontal_scrollbar = true,
                        },
                    })) {
                        if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
                            const image_width = @intToFloat(f32, file.width) * pixi.state.camera.zoom;
                            const image_height = @intToFloat(f32, file.height) * pixi.state.camera.zoom;

                            const dummy_width = std.math.max(zgui.getWindowWidth(), image_width * 1.5);
                            const dummy_height = std.math.max(zgui.getWindowHeight(), image_height * 1.5);

                            const dummy_x = 0;
                            const dummy_y = 0;

                            const image_x = dummy_x + (dummy_width / 2 - image_width / 2);
                            const image_y = dummy_y + (dummy_height / 2 - image_height / 2);

                            var i: usize = file.layers.items.len;
                            while (i > 0) {
                                i -= 1;
                                const layer = file.layers.items[i];
                                if (pixi.state.gctx.lookupResource(layer.texture_view_handle)) |texture_id| {
                                    zgui.setCursorPosX(dummy_x);
                                    zgui.setCursorPosY(dummy_y);
                                    zgui.dummy(.{
                                        .w = dummy_width,
                                        .h = dummy_height,
                                    });

                                    zgui.setCursorPosX(image_x);
                                    zgui.setCursorPosY(image_y);
                                    zgui.image(texture_id, .{
                                        .w = @intToFloat(f32, file.width) * pixi.state.camera.zoom,
                                        .h = @intToFloat(f32, file.height) * pixi.state.camera.zoom,
                                        .border_col = .{ 1.0, 1.0, 1.0, 1.0 },
                                    });
                                }
                            }
                        }
                    }
                    zgui.endChild();
                }
            } else {
                const w = @intToFloat(f32, (pixi.state.background_logo.width) / 4) * pixi.state.window.scale[0];
                const h = @intToFloat(f32, (pixi.state.background_logo.height) / 4) * pixi.state.window.scale[1];
                zgui.setCursorPosX((zgui.getWindowWidth() - w) / 2);
                zgui.setCursorPosY((zgui.getWindowHeight() - h) / 2);
                zgui.image(pixi.state.gctx.lookupResource(pixi.state.background_logo.view_handle).?, .{
                    .w = w,
                    .h = h,
                    .tint_col = .{ 1.0, 1.0, 1.0, 0.25 },
                });
                const text = zgui.formatZ("Open Folder    {s}  ", .{pixi.fa.file});
                const size = zgui.calcTextSize(text, .{});
                zgui.setCursorPosX((zgui.getWindowWidth() - size[0]) / 2);
                zgui.textColored(pixi.state.style.text_background.toSlice(), "Open File    {s}  ", .{pixi.fa.file});
            }
        }
        const flipbook_height = if (pixi.state.project_folder != null or pixi.state.open_files.items.len > 0) zgui.getContentRegionAvail()[1] - pixi.settings.info_bar_height * pixi.state.window.scale[1] else 0.0;

        zgui.separator();
        if (zgui.beginChild("Flipbook", .{
            .w = 0.0,
            .h = flipbook_height,
            .border = false,
            .flags = .{},
        })) {}
        zgui.endChild();

        if (pixi.state.project_folder != null or pixi.state.open_files.items.len > 0) {
            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.child_bg, .c = pixi.state.style.highlight_primary.toSlice() });
            defer zgui.popStyleColor(.{ .count = 1 });
            if (zgui.beginChild("InfoBar", .{})) {
                pixi.editor.infobar.draw();
            }
            zgui.endChild();
        }
    }
    zgui.end();
}
