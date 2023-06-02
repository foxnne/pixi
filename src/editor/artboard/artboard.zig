const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("root");
const editor = pixi.editor;
const nfd = @import("nfd");

pub const menu = @import("menu.zig");
pub const rulers = @import("rulers.zig");
pub const canvas = @import("canvas.zig");

pub const flipbook = @import("flipbook/flipbook.zig");
pub const infobar = @import("infobar/infobar.zig");

pub var path_hover_timer: f32 = 0.0;

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
        menu.draw();
        const window_height = zgui.getContentRegionAvail()[1];
        const artboard_height = if (pixi.state.open_files.items.len > 0) window_height - window_height * pixi.state.settings.flipbook_height else 0.0;

        const artboard_mouse_ratio = (pixi.state.controls.mouse.position.y - zgui.getCursorScreenPos()[1]) / window_height;

        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 0.0, 0.0 } });
        defer zgui.popStyleVar(.{ .count = 1 });
        if (zgui.beginChild("Artboard", .{
            .w = 0.0,
            .h = artboard_height,
            .border = false,
            .flags = .{},
        })) {
            if (pixi.state.open_files.items.len > 0) {
                if (zgui.beginTabBar("Files", .{
                    .reorderable = true,
                    .auto_select_new_tabs = true,
                })) {
                    defer zgui.endTabBar();

                    var hovered: bool = false;
                    for (pixi.state.open_files.items, 0..) |file, i| {
                        var open: bool = true;

                        const file_name = std.fs.path.basename(file.path);

                        zgui.pushIntId(@intCast(i32, i));
                        defer zgui.popId();

                        const label = zgui.formatZ(" {s}  {s} ", .{ pixi.fa.file_powerpoint, file_name });

                        if (zgui.beginTabItem(label, .{
                            .p_open = &open,
                            .flags = .{
                                .set_selected = pixi.state.open_file_index == i,
                                .unsaved_document = file.dirty(),
                            },
                        })) {
                            zgui.endTabItem();
                        }
                        if (!open) {
                            pixi.editor.closeFile(i) catch unreachable;
                        }

                        if (zgui.isItemClicked(.left)) {
                            pixi.editor.setActiveFile(i);
                        }

                        if (zgui.isItemHovered(.{})) {
                            hovered = true;
                            path_hover_timer += pixi.state.gctx.stats.delta_time;

                            if (path_hover_timer >= 1.0) {
                                zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.window_padding, .v = .{ 4.0 * pixi.state.window.scale[0], 4.0 * pixi.state.window.scale[1] } });
                                defer zgui.popStyleVar(.{ .count = 1 });
                                if (zgui.beginTooltip()) {
                                    defer zgui.endTooltip();
                                    zgui.textColored(pixi.state.style.text_secondary.toSlice(), "{s}", .{file.path});
                                }
                            }
                        }
                    }

                    if (!hovered) path_hover_timer = 0.0;

                    // Add ruler child windows to build layout, but wait to draw to them until camera has been updated.
                    if (pixi.state.settings.show_rulers) {
                        if (zgui.beginChild("TopRuler", .{
                            .h = zgui.getTextLineHeightWithSpacing() * 1.5,
                            .border = false,
                            .flags = .{
                                .no_scrollbar = true,
                            },
                        })) {}
                        zgui.endChild();

                        if (zgui.beginChild("SideRuler", .{
                            .h = -1.0,
                            .w = zgui.getTextLineHeightWithSpacing() * 1.5,
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
                            canvas.draw(file);
                        }
                        zgui.endChild();

                        // Now add to ruler children windows, since we have updated the camera.
                        if (pixi.state.settings.show_rulers) {
                            rulers.draw(file);
                        }
                    }
                }
            } else {
                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button, .c = pixi.state.style.background.toSlice() });
                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button_active, .c = pixi.state.style.background.toSlice() });
                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button_hovered, .c = pixi.state.style.foreground.toSlice() });
                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text_background.toSlice() });
                defer zgui.popStyleColor(.{ .count = 4 });
                { // Draw semi-transparent logo
                    const w = @intToFloat(f32, (pixi.state.background_logo.image.width) / 4) * pixi.state.window.scale[0];
                    const h = @intToFloat(f32, (pixi.state.background_logo.image.height) / 4) * pixi.state.window.scale[1];
                    const center: [2]f32 = .{ zgui.getWindowWidth() / 2.0, zgui.getWindowHeight() / 2.0 };

                    zgui.setCursorPosX(center[0] - w / 2.0);
                    zgui.setCursorPosY(center[1] - h / 2.0);
                    zgui.image(pixi.state.gctx.lookupResource(pixi.state.background_logo.view_handle).?, .{
                        .w = w,
                        .h = h,
                        .tint_col = .{ 1.0, 1.0, 1.0, 0.25 },
                    });
                }
                { // Draw `Open Folder` button
                    const text: [:0]const u8 = "  Open Folder  " ++ pixi.fa.folder_open ++ " ";
                    const size = zgui.calcTextSize(text, .{});
                    zgui.setCursorPosX((zgui.getWindowWidth() - size[0]) / 2);
                    if (zgui.button(text, .{})) {
                        const folder = nfd.openFolderDialog(null) catch unreachable;
                        if (folder) |path| {
                            defer nfd.freePath(path);
                            pixi.editor.setProjectFolder(path);
                        }
                    }
                }
            }
        }
        zgui.endChild();

        if (pixi.state.open_files.items.len > 0) {
            const flipbook_height = window_height - artboard_height - pixi.state.settings.info_bar_height * pixi.state.window.scale[1];
            zgui.separator();

            if (zgui.beginChild("Flipbook", .{
                .w = 0.0,
                .h = flipbook_height,
                .border = false,
                .flags = .{
                    .menu_bar = if (pixi.editor.getFile(pixi.state.open_file_index)) |_| true else false,
                },
            })) {
                if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
                    flipbook.menu.draw(file, artboard_mouse_ratio);

                    if (zgui.beginChild("FlipbookCanvas", .{})) {
                        flipbook.canvas.draw(file);
                    }
                    zgui.endChild();
                }
            }
            zgui.endChild();
            if (pixi.state.project_folder != null or pixi.state.open_files.items.len > 0) {
                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.child_bg, .c = pixi.state.style.highlight_primary.toSlice() });
                defer zgui.popStyleColor(.{ .count = 1 });
                if (zgui.beginChild("InfoBar", .{})) {
                    infobar.draw();
                }
                zgui.endChild();
            }
        }
    }
    zgui.end();
}
