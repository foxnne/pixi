const std = @import("std");
const pixi = @import("../../pixi.zig");
const core = @import("mach").core;
const editor = pixi.editor;
const nfd = @import("nfd");
const imgui = @import("zig-imgui");

pub const menu = @import("menu.zig");
pub const rulers = @import("rulers.zig");
pub const canvas = @import("canvas.zig");

pub fn draw() void {
    imgui.pushStyleVar(imgui.StyleVar_TabRounding, 0.0);
    imgui.pushStyleVar(imgui.StyleVar_ChildBorderSize, 0.0);
    defer imgui.popStyleVarEx(2);

    imgui.pushStyleColorImVec4(imgui.Col_ChildBg, pixi.state.theme.background.toImguiVec4());
    defer imgui.popStyleColor();

    if (imgui.beginChild("CopyArtboard", .{
        .x = 0.0,
        .y = 0.0,
    }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
        defer imgui.endChild();
        if (pixi.state.open_files.items.len > 0) {
            var files_flags: imgui.TabBarFlags = 0;
            files_flags |= imgui.TabBarFlags_Reorderable;
            files_flags |= imgui.TabBarFlags_AutoSelectNewTabs;

            if (imgui.beginTabBar("CopyFilesTabBar", files_flags)) {
                defer imgui.endTabBar();

                for (pixi.state.open_files.items, 0..) |file, i| {
                    var open: bool = true;

                    const file_name = std.fs.path.basename(file.path);

                    imgui.pushIDInt(@as(c_int, @intCast(i)));
                    defer imgui.popID();

                    const label = std.fmt.allocPrintZ(pixi.state.allocator, " {s}  {s} ", .{ pixi.fa.file_powerpoint, file_name }) catch unreachable;
                    defer pixi.state.allocator.free(label);

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
                        pixi.editor.closeFile(i) catch unreachable;
                    }

                    if (imgui.isItemClickedEx(imgui.MouseButton_Left)) {
                        pixi.editor.setCopyFile(i);
                    }

                    if (imgui.isItemHovered(imgui.HoveredFlags_DelayNormal)) {
                        imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 4.0 * pixi.content_scale[0], .y = 4.0 * pixi.content_scale[1] });
                        defer imgui.popStyleVar();
                        if (imgui.beginTooltip()) {
                            defer imgui.endTooltip();
                            imgui.textColored(pixi.state.theme.text_secondary.toImguiVec4(), file.path);
                        }
                    }
                }

                var canvas_flags: imgui.WindowFlags = 0;
                canvas_flags |= imgui.WindowFlags_HorizontalScrollbar;

                if (pixi.editor.getFile(pixi.state.copy_file_index)) |file| {
                    if (imgui.beginChild(
                        "CopyChild",
                        .{ .x = 0.0, .y = 0.0 },
                        imgui.ChildFlags_None,
                        canvas_flags,
                    )) {
                        canvas.draw(file);
                    }
                    imgui.endChild();
                }
            }
        } else {
            imgui.pushStyleColorImVec4(imgui.Col_Button, pixi.state.theme.background.toImguiVec4());
            imgui.pushStyleColorImVec4(imgui.Col_ButtonActive, pixi.state.theme.background.toImguiVec4());
            imgui.pushStyleColorImVec4(imgui.Col_ButtonHovered, pixi.state.theme.foreground.toImguiVec4());
            imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_background.toImguiVec4());
            defer imgui.popStyleColorEx(4);
            { // Draw semi-transparent logo
                const logo_sprite = pixi.state.assets.atlas.sprites[pixi.assets.pixi_atlas.logo_0_default];

                const src: [4]f32 = .{
                    @floatFromInt(logo_sprite.source[0]),
                    @floatFromInt(logo_sprite.source[1]),
                    @floatFromInt(logo_sprite.source[2]),
                    @floatFromInt(logo_sprite.source[3]),
                };

                const w = src[2] * 32.0 * pixi.content_scale[0];
                const h = src[3] * 32.0 * pixi.content_scale[0];
                const center: [2]f32 = .{ imgui.getWindowWidth() / 2.0, imgui.getWindowHeight() / 2.0 };

                const inv_w = 1.0 / @as(f32, @floatFromInt(pixi.state.assets.atlas_png.image.width));
                const inv_h = 1.0 / @as(f32, @floatFromInt(pixi.state.assets.atlas_png.image.height));

                imgui.setCursorPosX(center[0] - w / 2.0);
                imgui.setCursorPosY(center[1] - h / 2.0);
                imgui.imageEx(
                    pixi.state.assets.atlas_png.view_handle,
                    .{ .x = w, .y = h },
                    .{ .x = src[0] * inv_w, .y = src[1] * inv_h },
                    .{ .x = (src[0] + src[2]) * inv_w, .y = (src[1] + src[3]) * inv_h },
                    .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 0.30 },
                    .{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 0.0 },
                );
                imgui.spacing();
            }
            { // Draw `Open Folder` button
                const text: [:0]const u8 = "  Open Folder  " ++ pixi.fa.folder_open ++ " ";
                const size = imgui.calcTextSize(text);
                imgui.setCursorPosX((imgui.getWindowWidth() / 2.0) - size.x / 2.0);
                if (imgui.buttonEx(text, .{ .x = size.x, .y = 0.0 })) {
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
}
