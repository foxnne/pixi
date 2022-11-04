const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("pixi");
const editor = pixi.editor;

pub var hover_timer: f32 = 0.0;
pub var hover_label: [:0]const u8 = undefined;

pub var zoom_timer: f32 = 0.2;
pub var zoom_tooltip_timer: f32 = 0.6;

pub fn draw() void {
    zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.window_rounding, .v = 0.0 });
    defer zgui.popStyleVar(.{ .count = 1 });
    zgui.setNextWindowPos(.{
        .x = (pixi.state.settings.sidebar_width + pixi.state.settings.explorer_width) * pixi.state.window.scale[0],
        .y = 0,
        .cond = .always,
    });
    zgui.setNextWindowSize(.{
        .w = (pixi.state.window.size[0] - pixi.state.settings.explorer_width - pixi.state.settings.sidebar_width) * pixi.state.window.scale[0],
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
                            zgui.endTabItem();
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

                    if (pixi.state.settings.show_rulers) {
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

                    var flags: zgui.WindowFlags = .{
                        .horizontal_scrollbar = true,
                    };

                    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
                        if (zgui.beginChild(file.path, .{
                            .h = 0.0,
                            .w = 0.0,
                            .border = false,
                            .flags = flags,
                        })) {
                            const file_width = @intToFloat(f32, file.width);
                            const file_height = @intToFloat(f32, file.height);

                            const texture_position: [2]f32 = .{
                                -file_width / 2,
                                -file_height / 2,
                            };

                            // Handle controls while canvas is hovered
                            if (zgui.isWindowHovered(.{})) {
                                if (pixi.state.controls.mouse.scroll_x) |x| {
                                    if (!pixi.state.controls.zoom() and zoom_timer >= pixi.state.settings.zoom_time) {
                                        file.camera.position[0] -= x * pixi.state.settings.pan_sensitivity;
                                    }
                                    pixi.state.controls.mouse.scroll_x = null;
                                }
                                if (pixi.state.controls.mouse.scroll_y) |y| {
                                    if (pixi.state.controls.zoom()) {
                                        zoom_timer = 0.0;
                                        zoom_tooltip_timer = 0.0;
                                        file.camera.zoom = findNewZoom(file);
                                    } else if (zoom_timer >= pixi.state.settings.zoom_time) {
                                        file.camera.position[1] -= y * pixi.state.settings.pan_sensitivity;
                                    }
                                    pixi.state.controls.mouse.scroll_y = null;
                                }
                                const mouse_drag_delta = zgui.getMouseDragDelta(.middle, .{ .lock_threshold = 0.0 });
                                if (mouse_drag_delta[0] != 0.0 or mouse_drag_delta[1] != 0.0) {
                                    file.camera.position[0] -= mouse_drag_delta[0] * (1 / file.camera.zoom);
                                    file.camera.position[1] -= mouse_drag_delta[1] * (1 / file.camera.zoom);
                                    zgui.resetMouseDragDelta(.middle);
                                }
                            }

                            // Round to nearest pixel perfect zoom step when zoom key is released
                            if (!pixi.state.controls.zoom()) {
                                zoom_timer = std.math.min(zoom_timer + pixi.state.gctx.stats.delta_time, pixi.state.settings.zoom_time);
                                const nearest_zoom_index = findNearestZoomIndex(file);
                                if (zoom_timer < pixi.state.settings.zoom_time) {
                                    file.camera.zoom = pixi.math.lerp(file.camera.zoom, pixi.state.settings.zoom_steps[nearest_zoom_index], zoom_timer / pixi.state.settings.zoom_time);
                                } else {
                                    file.camera.zoom = pixi.state.settings.zoom_steps[nearest_zoom_index];
                                }
                            }

                            // Draw current zoom tooltip
                            if (zoom_tooltip_timer < pixi.state.settings.zoom_tooltip_time) {
                                zoom_tooltip_timer = std.math.min(zoom_tooltip_timer + pixi.state.gctx.stats.delta_time, pixi.state.settings.zoom_tooltip_time);
                                zoomTooltip(file.camera.zoom);
                            }

                            // Lock camera from moving too far away from canvas
                            file.camera.position[0] = std.math.clamp(file.camera.position[0], -(texture_position[0] + file_width), texture_position[0] + file_width);
                            file.camera.position[1] = std.math.clamp(file.camera.position[1], -(texture_position[1] + file_height), texture_position[1] + file_height);

                            // Draw all layers in reverse order
                            var i: usize = file.layers.items.len;
                            while (i > 0) {
                                i -= 1;
                                file.camera.drawLayer(file.layers.items[i], texture_position, pixi.state.style.text_secondary.toU32());
                            }
                        }
                        zgui.endChild();
                    }
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
            zgui.endChild();
        }
        const flipbook_height = if (pixi.state.project_folder != null or pixi.state.open_files.items.len > 0) zgui.getContentRegionAvail()[1] - pixi.state.settings.info_bar_height * pixi.state.window.scale[1] else 0.0;

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

fn zoomTooltip(zoom: f32) void {
    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.window_padding, .v = .{ 4.0 * pixi.state.window.scale[0], 4.0 * pixi.state.window.scale[1] } });
    defer zgui.popStyleVar(.{ .count = 1 });
    zgui.beginTooltip();
    defer zgui.endTooltip();
    zgui.textColored(pixi.state.style.text.toSlice(), "{s} ", .{pixi.fa.search});
    zgui.sameLine(.{});
    zgui.textColored(pixi.state.style.text_secondary.toSlice(), "{d:0.1}", .{zoom});
}

fn findNearestZoomIndex(file: *pixi.storage.Internal.Pixi) usize {
    var nearest_zoom_index: usize = 0;
    var nearest_zoom_step: f32 = pixi.state.settings.zoom_steps[nearest_zoom_index];
    for (pixi.state.settings.zoom_steps) |step, i| {
        const step_difference = @fabs(file.camera.zoom - step);
        const current_difference = @fabs(file.camera.zoom - nearest_zoom_step);
        if (step_difference < current_difference) {
            nearest_zoom_step = step;
            nearest_zoom_index = i;
        }
    }
    return nearest_zoom_index;
}

fn findNewZoom(file: *pixi.storage.Internal.Pixi) f32 {
    if (pixi.state.controls.mouse.scroll_y) |scroll| {
        const nearest_zoom_index = findNearestZoomIndex(file);

        const t = @intToFloat(f32, nearest_zoom_index) / @intToFloat(f32, pixi.state.settings.zoom_steps.len - 1);
        const sensitivity = pixi.math.lerp(pixi.state.settings.zoom_min_sensitivity, pixi.state.settings.zoom_max_sensitivity, t);
        const zoom_delta = scroll * sensitivity;

        return std.math.clamp(file.camera.zoom + zoom_delta, pixi.state.settings.zoom_steps[0], pixi.state.settings.zoom_steps[pixi.state.settings.zoom_steps.len - 1]);
    }
    return file.camera.zoom;
}
