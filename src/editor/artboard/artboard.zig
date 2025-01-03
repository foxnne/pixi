const std = @import("std");
const Pixi = @import("../../Pixi.zig");
const Core = @import("mach").Core;
const editor = Pixi.Editor;
const nfd = @import("nfd");
const imgui = @import("zig-imgui");

pub const menu = @import("menu.zig");
pub const rulers = @import("rulers.zig");
pub const canvas = @import("canvas.zig");
pub const canvas_pack = @import("canvas_pack.zig");

pub const flipbook = @import("flipbook/flipbook.zig");
pub const infobar = @import("infobar.zig");

pub var artboard_0_open_file_index: usize = 0;
pub var artboard_1_open_file_index: usize = 0;

pub fn draw(core: *Core) void {
    imgui.pushStyleVar(imgui.StyleVar_WindowRounding, 0.0);
    defer imgui.popStyleVar();
    imgui.setNextWindowPos(.{
        .x = (Pixi.state.settings.sidebar_width + Pixi.state.settings.explorer_width + Pixi.state.settings.explorer_grip) * Pixi.state.content_scale[0],
        .y = 0.0,
    }, imgui.Cond_Always);
    imgui.setNextWindowSize(.{
        .x = (Pixi.state.window_size[0] - ((Pixi.state.settings.explorer_width + Pixi.state.settings.sidebar_width + Pixi.state.settings.explorer_grip)) * Pixi.state.content_scale[0]),
        .y = (Pixi.state.window_size[1] + 5.0) * Pixi.state.content_scale[1],
    }, imgui.Cond_None);

    imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 0.0, .y = 0.5 });
    imgui.pushStyleVar(imgui.StyleVar_TabRounding, 0.0);
    imgui.pushStyleVar(imgui.StyleVar_ChildBorderSize, 1.0);
    defer imgui.popStyleVarEx(3);

    var art_flags: imgui.WindowFlags = 0;
    art_flags |= imgui.WindowFlags_NoTitleBar;
    art_flags |= imgui.WindowFlags_NoResize;
    art_flags |= imgui.WindowFlags_NoMove;
    art_flags |= imgui.WindowFlags_NoCollapse;
    art_flags |= imgui.WindowFlags_MenuBar;
    art_flags |= imgui.WindowFlags_NoBringToFrontOnFocus;

    if (imgui.begin("Art", null, art_flags)) {
        menu.draw();

        const art_width = imgui.getWindowWidth();

        const window_height = imgui.getContentRegionAvail().y;
        const window_width = imgui.getContentRegionAvail().x;
        const artboard_height = if (Pixi.state.open_files.items.len > 0 and Pixi.state.sidebar != .pack) window_height - window_height * Pixi.state.settings.flipbook_height else 0.0;

        const artboard_flipbook_ratio = (Pixi.state.mouse.position[1] - imgui.getCursorScreenPos().y) / window_height;

        const split_index: usize = if (Pixi.state.settings.split_artboard) 3 else 1;

        for (0..split_index) |artboard_index| {
            const artboard_0 = artboard_index == 0;
            const artboard_grip = artboard_index == 1;
            const artboard_name = if (artboard_0) "Artboard_0" else if (artboard_grip) "Artboard_Grip" else "Artboard_1";

            var artboard_width: f32 = 0.0;

            if (artboard_0 and Pixi.state.settings.split_artboard) {
                artboard_width = window_width * Pixi.state.settings.split_artboard_ratio;
            } else if (artboard_grip) {
                artboard_width = Pixi.state.settings.explorer_grip;
            } else {
                artboard_width = 0.0;
            }

            const not_active: bool = (artboard_0 and artboard_0_open_file_index != Pixi.state.open_file_index) or (!artboard_0 and !artboard_grip and artboard_1_open_file_index != Pixi.state.open_file_index);

            const artboard_color: Pixi.math.Color = if (artboard_grip or (not_active and Pixi.state.settings.split_artboard)) Pixi.editor.theme.foreground else Pixi.editor.theme.background;

            imgui.pushStyleColor(imgui.Col_ChildBg, artboard_color.toU32());
            defer imgui.popStyleColor();

            imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 0.0, .y = 0.0 });
            defer imgui.popStyleVar();

            if (!artboard_0) imgui.sameLine();

            if (imgui.beginChild(artboard_name, .{
                .x = artboard_width,
                .y = artboard_height,
            }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
                if (!artboard_grip) {
                    const window_hovered: bool = imgui.isWindowHovered(imgui.HoveredFlags_ChildWindows);
                    const mouse_clicked: bool = Pixi.state.mouse.anyButtonDown();

                    // defer {
                    //     const shadow_color = pixi.math.Color.initFloats(0.0, 0.0, 0.0, pixi.state.settings.shadow_opacity).toU32();
                    //     // Draw a shadow fading from bottom to top
                    //     const pos = imgui.getWindowPos();
                    //     const width = imgui.getWindowWidth();

                    //     if (imgui.getWindowDrawList()) |draw_list| {
                    //         draw_list.addRectFilledMultiColor(
                    //             .{ .x = pos.x, .y = pos.y },
                    //             .{ .x = pos.x + width, .y = pos.y + pixi.state.settings.shadow_length },
                    //             shadow_color,
                    //             shadow_color,
                    //             0x0,
                    //             0x0,
                    //         );
                    //     }
                    // }

                    if (Pixi.state.sidebar == .pack) {
                        drawCanvasPack();
                    } else if (Pixi.state.open_files.items.len > 0) {
                        var files_flags: imgui.TabBarFlags = 0;
                        files_flags |= imgui.TabBarFlags_Reorderable;
                        files_flags |= imgui.TabBarFlags_AutoSelectNewTabs;

                        if (imgui.beginTabBar("FilesTabBar", files_flags)) {
                            defer imgui.endTabBar();

                            for (Pixi.state.open_files.items, 0..) |file, i| {
                                var open: bool = true;

                                const file_name = std.fs.path.basename(file.path);

                                imgui.pushIDInt(@as(c_int, @intCast(i)));
                                defer imgui.popID();

                                const label = std.fmt.allocPrintZ(Pixi.state.allocator, " {s}  {s} ", .{ Pixi.fa.file_powerpoint, file_name }) catch unreachable;
                                defer Pixi.state.allocator.free(label);

                                var file_tab_flags: imgui.TabItemFlags = 0;
                                file_tab_flags |= imgui.TabItemFlags_None;
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
                                    if (artboard_0_open_file_index == i) artboard_0_open_file_index = 0;
                                    if (artboard_1_open_file_index == i) artboard_1_open_file_index = 0;

                                    Pixi.Editor.closeFile(i) catch unreachable;
                                    break; // This ensures we dont use after free
                                }

                                if (imgui.isItemClickedEx(imgui.MouseButton_Left)) {
                                    if (artboard_0) {
                                        artboard_0_open_file_index = i;
                                    } else if (!artboard_grip) {
                                        artboard_1_open_file_index = i;
                                    }
                                }

                                if (imgui.isItemHovered(imgui.HoveredFlags_DelayNormal)) {
                                    imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 4.0 * Pixi.state.content_scale[0], .y = 4.0 * Pixi.state.content_scale[1] });
                                    defer imgui.popStyleVar();
                                    if (imgui.beginTooltip()) {
                                        defer imgui.endTooltip();
                                        imgui.textColored(Pixi.editor.theme.text_secondary.toImguiVec4(), file.path);
                                    }
                                }
                            }

                            const show_rulers: bool = Pixi.state.settings.show_rulers;

                            // Add ruler child windows to build layout, but wait to draw to them until camera has been updated.
                            if (show_rulers) {
                                if (imgui.beginChild(
                                    "TopRuler",
                                    .{ .x = -1.0, .y = imgui.getTextLineHeightWithSpacing() * 1.5 },
                                    imgui.ChildFlags_None,
                                    imgui.WindowFlags_NoScrollbar,
                                )) {}
                                imgui.endChild();

                                if (imgui.beginChild(
                                    "SideRuler",
                                    .{ .x = imgui.getTextLineHeightWithSpacing() * 1.5, .y = -1.0 },
                                    imgui.ChildFlags_None,
                                    imgui.WindowFlags_NoScrollbar,
                                )) {}
                                imgui.endChild();
                                imgui.sameLine();
                            }

                            var canvas_flags: imgui.WindowFlags = 0;
                            canvas_flags |= imgui.WindowFlags_HorizontalScrollbar;

                            var open_file_index = if (artboard_0) artboard_0_open_file_index else if (!artboard_grip) artboard_1_open_file_index else 0;

                            if (window_hovered and mouse_clicked) {
                                Pixi.Editor.setActiveFile(open_file_index);
                            }

                            if (!Pixi.state.settings.split_artboard) open_file_index = Pixi.state.open_file_index;

                            if (Pixi.Editor.getFile(open_file_index)) |file| {
                                if (imgui.beginChild(
                                    file.path,
                                    .{ .x = 0.0, .y = 0.0 },
                                    imgui.ChildFlags_None,
                                    canvas_flags,
                                )) {
                                    canvas.draw(file, core);
                                }
                                imgui.endChild();

                                // Now add to ruler children windows, since we have updated the camera.
                                if (show_rulers) {
                                    rulers.draw(file);
                                }
                            }
                        }
                    } else {
                        drawLogoScreen();
                    }
                } else {
                    drawGrip(art_width);
                }
            }

            imgui.endChild();
        }

        if (Pixi.state.sidebar != .pack) {
            if (Pixi.state.open_files.items.len > 0) {
                const flipbook_height = window_height - artboard_height - Pixi.state.settings.info_bar_height * Pixi.state.content_scale[1];

                var flipbook_flags: imgui.WindowFlags = 0;
                flipbook_flags |= imgui.WindowFlags_MenuBar;

                if (imgui.beginChild("Flipbook", .{
                    .x = 0.0,
                    .y = flipbook_height,
                }, imgui.ChildFlags_None, flipbook_flags)) {
                    if (Pixi.Editor.getFile(Pixi.state.open_file_index)) |file| {
                        flipbook.menu.draw(file, artboard_flipbook_ratio);
                        if (Pixi.state.sidebar == .keyframe_animations or file.flipbook_view == .timeline) {
                            flipbook.timeline.draw(file);
                        } else {
                            if (imgui.beginChild("FlipbookCanvas", .{ .x = 0.0, .y = 0.0 }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
                                defer imgui.endChild();
                                flipbook.canvas.draw(file);
                            }
                        }
                    }
                }
                imgui.endChild();

                if (Pixi.state.project_folder != null or Pixi.state.open_files.items.len > 0) {
                    imgui.pushStyleColorImVec4(imgui.Col_ChildBg, Pixi.editor.theme.highlight_primary.toImguiVec4());
                    defer imgui.popStyleColor();
                    if (imgui.beginChild("InfoBar", .{ .x = -1.0, .y = 0.0 }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
                        infobar.draw();
                    }
                    imgui.endChild();
                }
            }
        }

        // {
        //     const shadow_color = pixi.math.Color.initFloats(0.0, 0.0, 0.0, pixi.state.settings.shadow_opacity).toU32();
        //     const pos = imgui.getWindowPos();
        //     const height = imgui.getWindowHeight();

        //     if (imgui.getWindowDrawList()) |draw_list|
        //         // Draw a shadow fading from left to right
        //         draw_list.addRectFilledMultiColor(
        //             pos,
        //             .{ .x = pos.x + pixi.state.settings.shadow_length, .y = height + pos.x },
        //             shadow_color,
        //             0x0,
        //             shadow_color,
        //             0x0,
        //         );
        // }
    }
    imgui.end();
}

pub fn drawLogoScreen() void {
    imgui.pushStyleColorImVec4(imgui.Col_Button, Pixi.editor.theme.background.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_Border, Pixi.editor.theme.background.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_ButtonActive, Pixi.editor.theme.background.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_ButtonHovered, Pixi.editor.theme.foreground.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_background.toImguiVec4());
    defer imgui.popStyleColorEx(5);
    { // Draw semi-transparent logo
        const logo_sprite = Pixi.state.loaded_assets.atlas.sprites[Pixi.assets.pixi_atlas.logo_0_default];

        const src: [4]f32 = .{
            @floatFromInt(logo_sprite.source[0]),
            @floatFromInt(logo_sprite.source[1]),
            @floatFromInt(logo_sprite.source[2]),
            @floatFromInt(logo_sprite.source[3]),
        };

        const w = src[2] * 32.0 * Pixi.state.content_scale[0];
        const h = src[3] * 32.0 * Pixi.state.content_scale[0];
        const center: [2]f32 = .{ imgui.getWindowWidth() / 2.0, imgui.getWindowHeight() / 2.0 };

        const inv_w = 1.0 / @as(f32, @floatFromInt(Pixi.state.loaded_assets.atlas_png.image.width));
        const inv_h = 1.0 / @as(f32, @floatFromInt(Pixi.state.loaded_assets.atlas_png.image.height));

        imgui.setCursorPosX(center[0] - w / 2.0);
        imgui.setCursorPosY(center[1] - h / 2.0);
        imgui.imageEx(
            Pixi.state.loaded_assets.atlas_png.view_handle,
            .{ .x = w, .y = h },
            .{ .x = src[0] * inv_w, .y = src[1] * inv_h },
            .{ .x = (src[0] + src[2]) * inv_w, .y = (src[1] + src[3]) * inv_h },
            .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 0.30 },
            .{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 0.0 },
        );
        imgui.dummy(.{ .x = 1.0, .y = 15.0 });
    }
    { // Draw `Open Folder` button
        const text: [:0]const u8 = "  Open Folder  " ++ Pixi.fa.folder_open ++ " ";
        const size = imgui.calcTextSize(text);
        imgui.setCursorPosX((imgui.getWindowWidth() / 2.0) - size.x / 2.0);
        if (imgui.buttonEx(text, .{ .x = size.x, .y = 0.0 })) {
            Pixi.state.popups.file_dialog_request = .{
                .state = .folder,
                .type = .project,
            };
        }
        if (Pixi.state.popups.file_dialog_response) |response| {
            if (response.type == .project) {
                Pixi.Editor.setProjectFolder(response.path);
                nfd.freePath(response.path);
                Pixi.state.popups.file_dialog_response = null;
            }
        }
    }
}

pub fn drawGrip(window_width: f32) void {
    imgui.setCursorPosY(0.0);
    imgui.setCursorPosX(0.0);

    const avail = imgui.getContentRegionAvail().y;
    const curs_y = imgui.getCursorPosY();

    var color = Pixi.editor.theme.text_background.toImguiVec4();

    _ = imgui.invisibleButton("ArtboardGripButton", .{
        .x = Pixi.state.settings.explorer_grip,
        .y = -1.0,
    }, imgui.ButtonFlags_None);

    var hovered_flags: imgui.HoveredFlags = 0;
    hovered_flags |= imgui.HoveredFlags_AllowWhenOverlapped;
    hovered_flags |= imgui.HoveredFlags_AllowWhenBlockedByActiveItem;

    if (imgui.isItemHovered(hovered_flags)) {
        imgui.setMouseCursor(imgui.MouseCursor_ResizeEW);
        color = Pixi.editor.theme.text.toImguiVec4();

        if (imgui.isMouseDoubleClicked(imgui.MouseButton_Left)) {
            Pixi.state.settings.split_artboard = !Pixi.state.settings.split_artboard;
        }
    }

    if (imgui.isItemActive()) {
        color = Pixi.editor.theme.text.toImguiVec4();
        const prev = Pixi.state.mouse.previous_position;
        const cur = Pixi.state.mouse.position;

        const diff = (cur[0] - prev[0]) / window_width;

        imgui.setMouseCursor(imgui.MouseCursor_ResizeEW);
        Pixi.state.settings.split_artboard_ratio = std.math.clamp(
            Pixi.state.settings.split_artboard_ratio + diff,
            0.1,
            0.9,
        );
    }

    imgui.setCursorPosY(curs_y + avail / 2.0);
    imgui.setCursorPosX(Pixi.state.settings.explorer_grip / 2.0 - imgui.calcTextSize(Pixi.fa.grip_lines_vertical).x / 2.0);
    imgui.textColored(color, Pixi.fa.grip_lines_vertical);
}

pub fn drawCanvasPack() void {
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
}
