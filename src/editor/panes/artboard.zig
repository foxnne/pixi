const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("pixi");
const settings = pixi.settings;
const editor = pixi.editor;

pub var hover_timer: f32 = 0.0;
pub var hover_label: [:0]const u8 = undefined;

pub var zoom_timer: f32 = settings.zoom_time;
pub var zoom_tooltip_timer: f32 = settings.zoom_tooltip_time;
var prev_zoom: f32 = 1.0;

var canvas_scroll_x: f32 = 0.0;
var canvas_max_scroll_x: f32 = 0.0;
var canvas_scroll_y: f32 = 0.0;
var canvas_max_scroll_y: f32 = 0.0;

var ruler_start_x: f32 = 0.0;
var ruler_end_x: f32 = 0.0;
var ruler_start_y: f32 = 0.0;
var ruler_end_y: f32 = 0.0;

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
                        })) {
                            const offset = (zgui.calcTextSize("|", .{})[0]) * 1.5;
                            zgui.setCursorPosX((ruler_start_x - canvas_scroll_x) + offset);
                            zgui.textColored(pixi.state.style.text_secondary.toSlice(), "|", .{});
                            zgui.sameLine(.{});
                            zgui.setCursorPosX((ruler_end_x - canvas_scroll_x) + offset);
                            zgui.textColored(pixi.state.style.text_secondary.toSlice(), "|", .{});
                        }
                        zgui.endChild();

                        if (zgui.beginChild("SideRuler", .{
                            .h = -1.0,
                            .w = zgui.getTextLineHeightWithSpacing(),
                            .border = false,
                            .flags = .{
                                .no_scrollbar = true,
                            },
                        })) {
                            const offset = zgui.getTextLineHeight() / 2;
                            zgui.setCursorPosY(ruler_start_y - canvas_scroll_y - offset);
                            zgui.textColored(pixi.state.style.text_secondary.toSlice(), "--", .{});
                            zgui.setCursorPosY(ruler_end_y - canvas_scroll_y - offset);
                            zgui.textColored(pixi.state.style.text_secondary.toSlice(), "--", .{});
                        }
                        zgui.endChild();
                        zgui.sameLine(.{});
                    }
                    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
                        if (zgui.beginChild(file.path, .{
                            .h = 0.0,
                            .w = 0.0,
                            .border = false,
                            .flags = .{
                                .horizontal_scrollbar = true,
                            },
                        })) {
                            if (zgui.isWindowHovered(.{
                                .child_windows = true,
                            })) {
                                if (pixi.state.controls.mouse.scrolled and pixi.state.controls.control()) {
                                    const zoom_sign = std.math.sign(pixi.state.controls.mouse.scroll);

                                    var nearest_zoom_index: usize = 0;
                                    var nearest_zoom_step: f32 = settings.zoom_steps[nearest_zoom_index];
                                    for (settings.zoom_steps) |step, i| {
                                        const step_difference = @fabs(file.zoom - step);
                                        const current_difference = @fabs(file.zoom - nearest_zoom_step);
                                        if (step_difference < current_difference) {
                                            nearest_zoom_step = step;
                                            nearest_zoom_index = i;
                                        }
                                    }

                                    const next_zoom_index = @floatToInt(usize, std.math.clamp(@intToFloat(f32, nearest_zoom_index) + zoom_sign, 0, @intToFloat(f32, settings.zoom_steps.len - 1)));
                                    const next_zoom_step = settings.zoom_steps[next_zoom_index];

                                    const zoom_step = @fabs(next_zoom_step - nearest_zoom_step) * zoom_sign;
                                    const zoom_substep = zoom_step / settings.zoom_substeps;

                                    const zoom_delta = std.math.min(pixi.state.controls.mouse.scroll, zoom_substep);
                                    file.zoom = std.math.clamp(file.zoom + zoom_delta, settings.zoom_steps[0], settings.zoom_steps[settings.zoom_steps.len - 1]);

                                    zoom_timer = 0.0;
                                    zoom_tooltip_timer = 0.0;
                                    prev_zoom = file.zoom;

                                    zoomTooltip(file.zoom);
                                } else {
                                    zoom_tooltip_timer = std.math.min(zoom_tooltip_timer + pixi.state.gctx.stats.delta_time, settings.zoom_tooltip_time);

                                    if (zoom_tooltip_timer < settings.zoom_tooltip_time or pixi.state.controls.control()) {
                                        zoomTooltip(file.zoom);
                                    } else {
                                        zoom_timer = std.math.min(zoom_timer + pixi.state.gctx.stats.delta_time, settings.zoom_time);
                                        var nearest_zoom_step: f32 = settings.zoom_steps[0];
                                        for (settings.zoom_steps) |step| {
                                            const step_difference = @fabs(file.zoom - step);
                                            const current_difference = @fabs(file.zoom - nearest_zoom_step);
                                            if (step_difference < current_difference)
                                                nearest_zoom_step = step;
                                        }
                                        if (zoom_timer < settings.zoom_time) {
                                            file.zoom = pixi.math.lerp(prev_zoom, nearest_zoom_step, zoom_timer / settings.zoom_time);
                                            zoomTooltip(file.zoom);
                                        } else {
                                            file.zoom = nearest_zoom_step;
                                        }
                                    }
                                }
                            }
                            pixi.state.controls.mouse.scrolled = false;

                            const image_width = @intToFloat(f32, file.width) * file.zoom;
                            const image_height = @intToFloat(f32, file.height) * file.zoom;

                            const dummy_width = std.math.max(zgui.getWindowWidth(), image_width * 1.5);
                            const dummy_height = std.math.max(zgui.getWindowHeight(), image_height * 1.5);

                            const dummy_x = 0;
                            const dummy_y = 0;

                            const image_x = dummy_x + (dummy_width / 2 - image_width / 2);
                            const image_y = dummy_y + (dummy_height / 2 - image_height / 2);

                            ruler_start_x = image_x;
                            ruler_end_x = image_x + image_width;
                            ruler_start_y = image_y;
                            ruler_end_y = image_y + image_height;

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
                                        .w = @intToFloat(f32, file.width) * file.zoom,
                                        .h = @intToFloat(f32, file.height) * file.zoom,
                                        .border_col = .{ 1.0, 1.0, 1.0, 1.0 },
                                    });
                                }
                            }
                        }
                        canvas_scroll_x = zgui.getScrollX();
                        canvas_max_scroll_x = zgui.getScrollMaxX();
                        canvas_scroll_y = zgui.getScrollY();
                        canvas_max_scroll_y = zgui.getScrollMaxY();
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

fn zoomTooltip(zoom: f32) void {
    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.window_padding, .v = .{ 4.0 * pixi.state.window.scale[0], 4.0 * pixi.state.window.scale[1] } });
    defer zgui.popStyleVar(.{ .count = 1 });
    zgui.beginTooltip();
    defer zgui.endTooltip();
    zgui.textColored(pixi.state.style.text.toSlice(), "{s} ", .{pixi.fa.search});
    zgui.sameLine(.{});
    zgui.textColored(pixi.state.style.text_secondary.toSlice(), "{d:0.1}", .{zoom});
}
