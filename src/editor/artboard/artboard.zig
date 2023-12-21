const std = @import("std");
const pixi = @import("../../pixi.zig");
const core = @import("mach-core");
const editor = pixi.editor;
const nfd = @import("nfd");
const imgui = @import("zig-imgui");

pub const menu = @import("menu.zig");
pub const rulers = @import("rulers.zig");
pub const canvas = @import("canvas.zig");
pub const canvas_pack = @import("canvas_pack.zig");

pub const flipbook = @import("flipbook/flipbook.zig");
pub const infobar = @import("infobar.zig");

pub fn draw() void {
    imgui.pushStyleVar(imgui.StyleVar_WindowRounding, 0.0);
    defer imgui.popStyleVar();
    imgui.setNextWindowPos(.{
        .x = (pixi.state.settings.sidebar_width + pixi.state.settings.explorer_width) * pixi.content_scale[0],
        .y = 0.0,
    }, imgui.Cond_Always);
    imgui.setNextWindowSize(.{
        .x = pixi.window_size[0] - ((pixi.state.settings.explorer_width + pixi.state.settings.sidebar_width) * pixi.content_scale[0]),
        .y = pixi.window_size[1] + 5.0,
    }, imgui.Cond_None);

    imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 0.0, .y = 0.0 });
    imgui.pushStyleVar(imgui.StyleVar_TabRounding, 0.0);
    imgui.pushStyleVar(imgui.StyleVar_ChildBorderSize, 1.0);
    defer imgui.popStyleVarEx(3);

    var art_flags: imgui.WindowFlags = 0;
    art_flags |= imgui.WindowFlags_NoTitleBar;
    art_flags |= imgui.WindowFlags_NoResize;
    art_flags |= imgui.WindowFlags_NoMove;
    art_flags |= imgui.WindowFlags_NoCollapse;
    art_flags |= imgui.WindowFlags_MenuBar;

    if (imgui.begin("Art", null, art_flags)) {
        menu.draw();
        const window_height = imgui.getContentRegionAvail().y;
        const artboard_height = if (pixi.state.open_files.items.len > 0 and pixi.state.sidebar != .pack) window_height - window_height * pixi.state.settings.flipbook_height else 0.0;

        const artboard_mouse_ratio = (pixi.state.mouse.position[1] - imgui.getCursorScreenPos().y) / window_height;

        imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 0.0, .y = 0.0 });
        defer imgui.popStyleVar();
        if (imgui.beginChild("Artboard", .{
            .x = 0.0,
            .y = artboard_height,
        }, false, imgui.WindowFlags_ChildWindow)) {
            if (pixi.state.sidebar == .pack) {
                var packed_textures_flags: imgui.TabBarFlags = 0;
                packed_textures_flags |= imgui.TabBarFlags_Reorderable;

                if (imgui.beginTabBar("PackedTextures", packed_textures_flags)) {
                    defer imgui.endTabBar();

                    if (imgui.beginTabItem(
                        "Atlas.Diffusemap",
                        null,
                        imgui.TabItemFlags_None,
                    )) {
                        defer imgui.endTabItem();
                        canvas_pack.draw(.diffusemap);
                    }

                    if (imgui.beginTabItem(
                        "Atlas.Heightmap",
                        null,
                        imgui.TabItemFlags_None,
                    )) {
                        defer imgui.endTabItem();
                        canvas_pack.draw(.heightmap);
                    }
                }
            } else if (pixi.state.open_files.items.len > 0) {
                var files_flags: imgui.TabBarFlags = 0;
                files_flags |= imgui.TabBarFlags_Reorderable;
                files_flags |= imgui.TabBarFlags_AutoSelectNewTabs;

                if (imgui.beginTabBar("Files", files_flags)) {
                    defer imgui.endTabBar();

                    for (pixi.state.open_files.items, 0..) |file, i| {
                        var open: bool = true;

                        const file_name = std.fs.path.basename(file.path);

                        imgui.pushIDInt(@as(c_int, @intCast(i)));
                        defer imgui.popID();

                        const label = std.fmt.allocPrintZ(pixi.state.allocator, " {s}  {s} ", .{ pixi.fa.file_powerpoint, file_name }) catch unreachable;
                        defer pixi.state.allocator.free(label);

                        var file_tab_flags: imgui.TabItemFlags = 0;
                        file_tab_flags |= imgui.TabItemFlags_SetSelected;
                        if (file.dirty() or file.saving)
                            file_tab_flags |= imgui.TabItemFlags_UnsavedDocument;

                        if (imgui.beginTabItem(
                            label,
                            &open,
                            file_tab_flags,
                        )) {
                            imgui.endTabItem();
                        }
                        if (!open and !file.saving) {
                            pixi.editor.closeFile(i) catch unreachable;
                        }

                        if (imgui.isItemClickedEx(imgui.MouseButton_Left)) {
                            pixi.editor.setActiveFile(i);
                        }

                        if (imgui.isItemHovered(imgui.HoveredFlags_DelayShort)) {
                            imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 4.0 * pixi.content_scale[0], .y = 4.0 * pixi.content_scale[1] });
                            defer imgui.popStyleVar();
                            if (imgui.beginTooltip()) {
                                defer imgui.endTooltip();
                                imgui.textColored(pixi.state.theme.text_secondary.toImguiVec4(), file.path);
                            }
                        }
                    }

                    // Add ruler child windows to build layout, but wait to draw to them until camera has been updated.
                    if (pixi.state.settings.show_rulers) {
                        if (imgui.beginChild(
                            "TopRuler",
                            .{ .x = 0.0, .y = imgui.getTextLineHeightWithSpacing() * 1.5 },
                            false,
                            imgui.WindowFlags_NoScrollbar,
                        )) {}
                        imgui.endChild();

                        if (imgui.beginChild(
                            "SideRuler",
                            .{ .x = -1.0, .y = imgui.getTextLineHeightWithSpacing() * 1.5 },
                            false,
                            imgui.WindowFlags_NoScrollbar,
                        )) {}
                        imgui.endChild();
                        imgui.sameLine();
                    }

                    var canvas_flags: imgui.WindowFlags = 0;
                    canvas_flags |= imgui.WindowFlags_HorizontalScrollbar;

                    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
                        if (imgui.beginChild(
                            file.path,
                            .{ .x = 0.0, .y = 0.0 },
                            false,
                            canvas_flags,
                        )) {
                            canvas.draw(file);
                        }
                        imgui.endChild();

                        // Now add to ruler children windows, since we have updated the camera.
                        if (pixi.state.settings.show_rulers) {
                            rulers.draw(file);
                        }
                    }
                }
            } else {
                imgui.pushStyleColorImVec4(imgui.Col_Button, pixi.state.theme.background.toImguiVec4());
                imgui.pushStyleColorImVec4(imgui.Col_ButtonActive, pixi.state.theme.background.toImguiVec4());
                imgui.pushStyleColorImVec4(imgui.Col_ButtonHovered, pixi.state.theme.foreground.toImguiVec4());
                imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_background.toImguiVec4());
                defer imgui.popStyleColorEx(4);
                { // Draw semi-transparent logo
                    const w = @as(f32, @floatFromInt((pixi.state.background_logo.image.width) / 4)) * pixi.content_scale[0];
                    const h = @as(f32, @floatFromInt((pixi.state.background_logo.image.height) / 4)) * pixi.content_scale[1];
                    const center: [2]f32 = .{ imgui.getWindowWidth() / 2.0, imgui.getWindowHeight() / 2.0 };

                    imgui.setCursorPosX(center[0] - w / 2.0);
                    imgui.setCursorPosY(center[1] - h / 2.0);
                    imgui.imageEx(
                        pixi.state.background_logo.view_handle,
                        .{ .x = w, .y = h },
                        .{ .x = 0.0, .y = 0.0 },
                        .{ .x = 1.0, .y = 1.0 },
                        .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 0.25 },
                        .{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 0.0 },
                    );
                }
                { // Draw `Open Folder` button
                    const text: [:0]const u8 = "  Open Folder  " ++ pixi.fa.folder_open ++ " ";
                    const size = imgui.calcTextSize(text);
                    imgui.setCursorPosX((imgui.getWindowWidth() - size.x) / 2);
                    if (imgui.button(text)) {
                        pixi.state.popups.file_dialog_request = .{
                            .state = .folder,
                            .type = .project,
                        };
                    }
                    if (pixi.state.popups.file_dialog_response) |response| {
                        if (response.type == .project) {
                            pixi.editor.setProjectFolder(response.path);
                            nfd.freePath(response.path);
                            pixi.state.popups.file_dialog_response = null;
                        }
                    }
                }
            }
        }

        {
            // Draw a shadow fading from bottom to top
            const pos = imgui.getWindowPos();
            const height = imgui.getWindowHeight();
            const width = imgui.getWindowWidth();

            if (imgui.getWindowDrawList()) |draw_list|
                draw_list.addRectFilledMultiColor(
                    .{ .x = pos.x, .y = (pos.y + height) - 18 * pixi.content_scale[1] },
                    .{ .x = pos.x + width, .y = pos.y + height },
                    0x0,
                    0x0,
                    0x15000000,
                    0x15000000,
                );
        }

        imgui.endChild();

        if (pixi.state.sidebar != .pack) {
            if (pixi.state.open_files.items.len > 0) {
                const flipbook_height = window_height - artboard_height - pixi.state.settings.info_bar_height * pixi.content_scale[1];
                imgui.separator();

                var flipbook_flags: imgui.WindowFlags = 0;
                if (pixi.editor.getFile(pixi.state.open_file_index)) |_| {
                    flipbook_flags |= imgui.WindowFlags_MenuBar;
                }

                if (imgui.beginChild("Flipbook", .{
                    .x = 0.0,
                    .y = flipbook_height,
                }, false, flipbook_flags)) {
                    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
                        flipbook.menu.draw(file, artboard_mouse_ratio);

                        if (imgui.beginChild("FlipbookCanvas", .{ .x = 0.0, .y = 0.0 }, false, imgui.WindowFlags_ChildWindow)) {
                            flipbook.canvas.draw(file);
                        }
                        imgui.endChild();
                    }
                }
                imgui.endChild();
                if (pixi.state.project_folder != null or pixi.state.open_files.items.len > 0) {
                    imgui.pushStyleColorImVec4(imgui.Col_ChildBg, pixi.state.theme.highlight_primary.toImguiVec4());
                    defer imgui.popStyleColor();
                    if (imgui.beginChild("InfoBar", .{ .x = 0.0, .y = 0.0 }, false, imgui.WindowFlags_ChildWindow)) {
                        infobar.draw();
                    }
                    imgui.endChild();
                }
            }
        }

        {
            const pos = imgui.getWindowPos();
            const height = imgui.getWindowHeight();

            if (imgui.getWindowDrawList()) |draw_list|
                // Draw a shadow fading from left to right
                draw_list.addRectFilledMultiColor(
                    pos,
                    .{ .x = pos.x + 18 * pixi.content_scale[0], .y = height + pos.x },
                    0x15000000,
                    0x0,
                    0x15000000,
                    0x0,
                );
        }
    }
    imgui.end();
}
