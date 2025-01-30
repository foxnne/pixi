const std = @import("std");

const pixi = @import("../../pixi.zig");

const Core = @import("mach").Core;
const App = pixi.App;
const Editor = pixi.Editor;
const Packer = pixi.Packer;

const nfd = @import("nfd");
const imgui = @import("zig-imgui");

pub const Artboard = @This();

pub const mach_module = .artboard;
pub const mach_systems = .{ .init, .deinit, .draw };

pub const menu = @import("menu.zig");
pub const rulers = @import("rulers.zig");
pub const canvas = @import("canvas.zig");
pub const canvas_pack = @import("canvas_pack.zig");

pub const flipbook = @import("flipbook/flipbook.zig");
pub const infobar = @import("infobar.zig");

open_file_index_0: usize,
open_file_index_1: usize,

pub fn init(artboard: *Artboard) void {
    artboard.* = .{
        .open_file_index_0 = 0,
        .open_file_index_1 = 0,
    };
}

pub fn deinit() void {}

pub fn draw(artboard: *Artboard, core: *Core, app: *App, editor: *Editor, packer: *Packer) !void {
    imgui.pushStyleVar(imgui.StyleVar_WindowRounding, 0.0);
    defer imgui.popStyleVar();
    imgui.setNextWindowPos(.{
        .x = editor.settings.sidebar_width + editor.settings.explorer_width + editor.settings.explorer_grip,
        .y = 0.0,
    }, imgui.Cond_Always);
    imgui.setNextWindowSize(.{
        .x = app.window_size[0] - editor.settings.explorer_width - editor.settings.sidebar_width - editor.settings.explorer_grip,
        .y = app.window_size[1] + 5.0,
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
        try menu.draw(editor);

        defer {
            const shadow_color = pixi.math.Color.initFloats(0.0, 0.0, 0.0, editor.settings.shadow_opacity).toU32();
            // Draw a shadow fading from bottom to top
            const pos = imgui.getWindowPos();
            const height = imgui.getWindowHeight();
            const width = imgui.getWindowWidth();

            if (imgui.getWindowDrawList()) |draw_list| {
                draw_list.addRectFilledMultiColor(
                    .{ .x = pos.x, .y = (pos.y + height) - editor.settings.shadow_length },
                    .{ .x = pos.x + width, .y = pos.y + height },
                    0x0,
                    0x0,
                    shadow_color,
                    shadow_color,
                );
            }
        }

        const art_width = imgui.getWindowWidth();

        const window_height = imgui.getContentRegionAvail().y;
        const window_width = imgui.getContentRegionAvail().x;
        const artboard_height = if (editor.open_files.items.len > 0 and editor.explorer.pane != .pack) window_height - window_height * editor.settings.flipbook_height else 0.0;

        const artboard_flipbook_ratio = (app.mouse.position[1] - imgui.getCursorScreenPos().y) / window_height;

        const split_index: usize = if (editor.settings.split_artboard) 3 else 1;

        for (0..split_index) |artboard_index| {
            const artboard_0 = artboard_index == 0;
            const artboard_grip = artboard_index == 1;
            const artboard_name = if (artboard_0) "Artboard_0" else if (artboard_grip) "Artboard_Grip" else "Artboard_1";

            var artboard_width: f32 = 0.0;

            if (artboard_0 and editor.settings.split_artboard) {
                artboard_width = window_width * editor.settings.split_artboard_ratio;
            } else if (artboard_grip) {
                artboard_width = editor.settings.explorer_grip;
            } else {
                artboard_width = 0.0;
            }

            const not_active: bool = (artboard_0 and artboard.open_file_index_0 != editor.open_file_index) or (!artboard_0 and !artboard_grip and artboard.open_file_index_1 != editor.open_file_index);

            const artboard_color: pixi.math.Color = if (artboard_grip or (not_active and editor.settings.split_artboard)) pixi.editor.theme.foreground else pixi.editor.theme.background;

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
                    const mouse_clicked: bool = app.mouse.anyButtonDown();

                    if (editor.explorer.pane == .pack) {
                        drawCanvasPack(editor, packer);
                    } else if (editor.open_files.items.len > 0) {
                        var files_flags: imgui.TabBarFlags = 0;
                        files_flags |= imgui.TabBarFlags_Reorderable;
                        files_flags |= imgui.TabBarFlags_AutoSelectNewTabs;

                        if (imgui.beginTabBar("FilesTabBar", files_flags)) {
                            defer imgui.endTabBar();

                            for (editor.open_files.items, 0..) |file, i| {
                                var open: bool = true;

                                const file_name = std.fs.path.basename(file.path);

                                imgui.pushIDInt(@as(c_int, @intCast(i)));
                                defer imgui.popID();

                                const label = try std.fmt.allocPrintZ(editor.arena.allocator(), " {s}  {s} ", .{ pixi.fa.file_powerpoint, file_name });

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
                                    if (artboard.open_file_index_0 == i) artboard.open_file_index_0 = 0;
                                    if (artboard.open_file_index_1 == i) artboard.open_file_index_1 = 0;

                                    try editor.closeFile(i);
                                    break; // This ensures we dont use after free
                                }

                                if (imgui.isItemClickedEx(imgui.MouseButton_Left)) {
                                    if (artboard_0) {
                                        artboard.open_file_index_0 = i;
                                    } else if (!artboard_grip) {
                                        artboard.open_file_index_1 = i;
                                    }
                                }

                                if (imgui.isItemHovered(imgui.HoveredFlags_DelayNormal)) {
                                    imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 4.0, .y = 4.0 });
                                    defer imgui.popStyleVar();
                                    if (imgui.beginTooltip()) {
                                        defer imgui.endTooltip();
                                        imgui.textColored(editor.theme.text_secondary.toImguiVec4(), file.path);
                                    }
                                }
                            }

                            const show_rulers: bool = editor.settings.show_rulers;

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

                            var open_file_index = if (artboard_0) artboard.open_file_index_0 else if (!artboard_grip) artboard.open_file_index_1 else 0;

                            if (window_hovered and mouse_clicked) {
                                editor.setActiveFile(open_file_index);
                            }

                            if (!editor.settings.split_artboard) open_file_index = editor.open_file_index;

                            if (editor.getFile(open_file_index)) |file| {
                                if (imgui.beginChild(
                                    file.path,
                                    .{ .x = 0.0, .y = 0.0 },
                                    imgui.ChildFlags_None,
                                    canvas_flags,
                                )) {
                                    try canvas.draw(file, core, app, editor);
                                }
                                imgui.endChild();

                                // Now add to ruler children windows, since we have updated the camera.
                                if (show_rulers) {
                                    try rulers.draw(file, editor);
                                }
                            }
                        }
                    } else {
                        try drawLogoScreen(app, editor);
                    }
                } else {
                    drawGrip(art_width, app, editor);
                }
            }

            imgui.endChild();
        }

        if (editor.explorer.pane != .pack) {
            if (editor.open_files.items.len > 0) {
                const flipbook_height = window_height - artboard_height - editor.settings.info_bar_height;

                var flipbook_flags: imgui.WindowFlags = 0;
                flipbook_flags |= imgui.WindowFlags_MenuBar;

                if (imgui.beginChild("Flipbook", .{
                    .x = 0.0,
                    .y = flipbook_height,
                }, imgui.ChildFlags_None, flipbook_flags)) {
                    if (editor.getFile(editor.open_file_index)) |file| {
                        try flipbook.menu.draw(file, artboard_flipbook_ratio, editor);
                        if (editor.explorer.pane == .keyframe_animations or file.flipbook_view == .timeline) {
                            try flipbook.timeline.draw(file, editor);
                        } else {
                            if (imgui.beginChild(
                                "FlipbookCanvas",
                                .{ .x = 0.0, .y = 0.0 },
                                imgui.ChildFlags_None,
                                imgui.WindowFlags_ChildWindow,
                            )) {
                                defer imgui.endChild();
                                try flipbook.canvas.draw(file, app, editor);
                            }
                        }
                    }
                }
                imgui.endChild();

                if (editor.project_folder != null or editor.open_files.items.len > 0) {
                    imgui.pushStyleColorImVec4(imgui.Col_ChildBg, pixi.editor.theme.highlight_primary.toImguiVec4());
                    defer imgui.popStyleColor();
                    if (imgui.beginChild("InfoBar", .{ .x = -1.0, .y = 0.0 }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
                        infobar.draw(editor);
                    }
                    imgui.endChild();
                }
            }
        }
    }
    imgui.end();
}

pub fn drawLogoScreen(app: *App, editor: *Editor) !void {
    imgui.pushStyleColorImVec4(imgui.Col_Button, editor.theme.background.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_Border, editor.theme.background.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_ButtonActive, editor.theme.background.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_ButtonHovered, editor.theme.foreground.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text_background.toImguiVec4());
    defer imgui.popStyleColorEx(5);
    { // Draw semi-transparent logo

        const logo_sprite = app.assets.atlas.sprites[pixi.atlas.logo_0_default];

        const src: [4]f32 = .{
            @floatFromInt(logo_sprite.source[0]),
            @floatFromInt(logo_sprite.source[1]),
            @floatFromInt(logo_sprite.source[2]),
            @floatFromInt(logo_sprite.source[3]),
        };

        const w = src[2] * 32.0;
        const h = src[3] * 32.0;
        const center: [2]f32 = .{ imgui.getWindowWidth() / 2.0, imgui.getWindowHeight() / 2.0 };

        const inv_w = 1.0 / @as(f32, @floatFromInt(app.assets.atlas_texture.image.width));
        const inv_h = 1.0 / @as(f32, @floatFromInt(app.assets.atlas_texture.image.height));

        imgui.setCursorPosX(center[0] - w / 2.0);
        imgui.setCursorPosY(center[1] - h / 2.0);
        imgui.imageEx(
            app.assets.atlas_texture.view_handle,
            .{ .x = w, .y = h },
            .{ .x = src[0] * inv_w, .y = src[1] * inv_h },
            .{ .x = (src[0] + src[2]) * inv_w, .y = (src[1] + src[3]) * inv_h },
            .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 0.30 },
            .{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 0.0 },
        );
        imgui.dummy(.{ .x = 1.0, .y = 15.0 });
    }
    { // Draw `Open Folder` button
        const text: [:0]const u8 = "  Open Folder  " ++ pixi.fa.folder_open ++ " ";
        const size = imgui.calcTextSize(text);
        imgui.setCursorPosX((imgui.getWindowWidth() / 2.0) - size.x / 2.0);
        if (imgui.buttonEx(text, .{ .x = size.x, .y = 0.0 })) {
            editor.popups.file_dialog_request = .{
                .state = .folder,
                .type = .project,
            };
        }
        if (editor.popups.file_dialog_response) |response| {
            if (response.type == .project) {
                try editor.setProjectFolder(response.path);
                nfd.freePath(response.path);
                editor.popups.file_dialog_response = null;
            }
        }
    }
}

pub fn drawGrip(window_width: f32, app: *App, editor: *Editor) void {
    imgui.setCursorPosY(0.0);
    imgui.setCursorPosX(0.0);

    const avail = imgui.getContentRegionAvail().y;
    const curs_y = imgui.getCursorPosY();

    var color = editor.theme.text_background.toImguiVec4();

    _ = imgui.invisibleButton("ArtboardGripButton", .{
        .x = editor.settings.explorer_grip,
        .y = -1.0,
    }, imgui.ButtonFlags_None);

    var hovered_flags: imgui.HoveredFlags = 0;
    hovered_flags |= imgui.HoveredFlags_AllowWhenOverlapped;
    hovered_flags |= imgui.HoveredFlags_AllowWhenBlockedByActiveItem;

    if (imgui.isItemHovered(hovered_flags)) {
        imgui.setMouseCursor(imgui.MouseCursor_ResizeEW);
        color = editor.theme.text.toImguiVec4();

        if (imgui.isMouseDoubleClicked(imgui.MouseButton_Left)) {
            editor.settings.split_artboard = !editor.settings.split_artboard;
        }
    }

    if (imgui.isItemActive()) {
        color = editor.theme.text.toImguiVec4();
        const prev = app.mouse.previous_position;
        const cur = app.mouse.position;

        const diff = (cur[0] - prev[0]) / window_width;

        imgui.setMouseCursor(imgui.MouseCursor_ResizeEW);
        editor.settings.split_artboard_ratio = std.math.clamp(
            editor.settings.split_artboard_ratio + diff,
            0.1,
            0.9,
        );
    }

    imgui.setCursorPosY(curs_y + avail / 2.0);
    imgui.setCursorPosX(editor.settings.explorer_grip / 2.0 - imgui.calcTextSize(pixi.fa.grip_lines_vertical).x / 2.0);
    imgui.textColored(color, pixi.fa.grip_lines_vertical);
}

pub fn drawCanvasPack(editor: *Editor, packer: *Packer) void {
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
            canvas_pack.draw(.texture, editor, packer);
        }

        if (imgui.beginTabItem(
            "Atlas.Heightmap",
            null,
            imgui.TabItemFlags_None,
        )) {
            defer imgui.endTabItem();
            canvas_pack.draw(.heightmap, editor, packer);
        }
    }
}
