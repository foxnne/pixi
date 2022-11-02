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

var new_zoom: f32 = 1.0;
var zoom_changed: bool = false;

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

                    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
                        if (zgui.beginChild(file.path, .{
                            .h = 0.0,
                            .w = 0.0,
                            .border = false,
                            .flags = .{
                                .always_horizontal_scrollbar = true,
                                .always_vertical_scrollbar = true,
                            },
                        })) {
                            const image_width = @intToFloat(f32, file.width);
                            const image_height = @intToFloat(f32, file.height);

                            if (zoom_changed) {
                                file.zoom = new_zoom;
                                zoom_changed = false;
                            } else {
                                if (zgui.isWindowHovered(.{})) {
                                    const zoom_step: f32 = 2.0;

                                    if (pixi.state.controls.mouse.scrolled and pixi.state.controls.control()) {
                                        const sign = std.math.sign(pixi.state.controls.mouse.scroll);
                                        if (sign > 0.0) {
                                            new_zoom = file.zoom * zoom_step;
                                            zoom_changed = true;
                                        } else {
                                            new_zoom = file.zoom / zoom_step;
                                            zoom_changed = true;
                                        }
                                    }
                                }

                                const window_pos = zgui.getWindowPos();
                                const mouse_window: [2]f32 = .{ pixi.state.controls.mouse.position.x - window_pos[0], pixi.state.controls.mouse.position.y - window_pos[1] };
                                if (zoom_changed) {
                                    
                                    const scroll: [2]f32 = .{ zgui.getScrollX(), zgui.getScrollY() };
                                    const mouse_image: [2]f32 = .{
                                        (scroll[0] + mouse_window[0]) / ((image_width / 1000.0) * file.zoom),
                                        (scroll[1] + mouse_window[1]) / ((image_height  / 1000.0) * file.zoom),
                                    };

                                    {
                                        zgui.setCursorPos(.{ 0.0, 0.0});
                                        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 0.0, 0.0 } });
                                        defer zgui.popStyleVar(.{ .count = 1 });
                                        zgui.dummy(.{
                                            .w = @floor(image_width * new_zoom),
                                            .h = @floor(image_height * new_zoom),
                                        });
                                        zgui.setCursorPos(.{ 0.0, 0.0});
                                    }

                                    const new_mouse_image: [2]f32 = .{
                                        mouse_image[0] * ((image_width / 1000.0) * new_zoom),
                                        mouse_image[1] * ((image_height / 1000.0) * new_zoom),
                                    };
                                    const new_scroll: [2]f32 = .{
                                        new_mouse_image[0] - mouse_window[0],
                                        new_mouse_image[1] - mouse_window[1],
                                    };

                                    zgui.setScrollX(new_scroll[0]);
                                    zgui.setScrollY(new_scroll[1]);
                                }

                                const draw_list = zgui.getWindowDrawList();
                                draw_list.addCircle(.{
                                    .p = .{ window_pos[0] + mouse_window[0], window_pos[1] + mouse_window[1]},
                                    .r = 24.0,
                                    .col = 0xffffffff,
                                });
                            }

                            pixi.state.controls.mouse.scrolled = false;

                            zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 0.0, 0.0 } });
                            defer zgui.popStyleVar(.{ .count = 1 });
                            var i: usize = file.layers.items.len;
                            while (i > 0) {
                                i -= 1;
                                const layer = file.layers.items[i];
                                if (pixi.state.gctx.lookupResource(layer.texture_view_handle)) |texture_id| {
                                    zgui.setCursorPos(.{ 0.0, 0.0});
                                    zgui.image(texture_id, .{
                                        .w = image_width * file.zoom,
                                        .h = image_height * file.zoom,
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

fn zoomTooltip(zoom: f32) void {
    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.window_padding, .v = .{ 4.0 * pixi.state.window.scale[0], 4.0 * pixi.state.window.scale[1] } });
    defer zgui.popStyleVar(.{ .count = 1 });
    zgui.beginTooltip();
    defer zgui.endTooltip();
    zgui.textColored(pixi.state.style.text.toSlice(), "{s} ", .{pixi.fa.search});
    zgui.sameLine(.{});
    zgui.textColored(pixi.state.style.text_secondary.toSlice(), "{d:0.1}", .{zoom});
}
