const std = @import("std");
const Pixi = @import("../../Pixi.zig");
const core = @import("mach").core;
const nfd = @import("nfd");
const imgui = @import("zig-imgui");

pub fn draw() void {
    imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 6.0 * Pixi.state.content_scale[0], .y = 5.0 * Pixi.state.content_scale[1] });
    defer imgui.popStyleVar();
    imgui.pushStyleColorImVec4(imgui.Col_Button, Pixi.editor.theme.highlight_secondary.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_ButtonActive, Pixi.editor.theme.highlight_secondary.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_ButtonHovered, Pixi.editor.theme.hover_secondary.toImguiVec4());
    defer imgui.popStyleColorEx(3);

    const window_size = imgui.getContentRegionAvail();

    switch (Pixi.state.pack_target) {
        .all_open => {
            if (Pixi.state.open_files.items.len <= 1) {
                Pixi.state.pack_target = .project;
            }
        },
        .single_open => {
            if (Pixi.state.open_files.items.len == 0)
                Pixi.state.pack_target = .project;
        },
        else => {},
    }

    const preview_text = switch (Pixi.state.pack_target) {
        .project => "Full Project",
        .all_open => "All Open Files",
        .single_open => "Current Open File",
    };

    if (imgui.beginCombo("Files", preview_text.ptr, imgui.ComboFlags_None)) {
        defer imgui.endCombo();
        if (imgui.menuItem("Full Project")) {
            Pixi.state.pack_target = .project;
        }

        {
            const enabled = if (Pixi.Editor.getFile(Pixi.state.open_file_index)) |_| true else false;
            if (imgui.menuItemEx("Current Open File", null, false, enabled)) {
                Pixi.state.pack_target = .single_open;
            }
        }

        {
            const enabled = if (Pixi.state.open_files.items.len > 1) true else false;
            if (imgui.menuItemEx("All Open Files", null, false, enabled)) {
                Pixi.state.pack_target = .all_open;
            }
        }
    }

    // _ = imgui.checkbox("Pack tileset", &pixi.state.pack_tileset);
    // if (imgui.isItemHovered(imgui.HoveredFlags_DelayNormal)) {
    //     if (imgui.beginTooltip()) {
    //         defer imgui.endTooltip();
    //         imgui.textColored(Pixi.editor.theme.text_secondary.toImguiVec4(), "Do not tightly pack sprites, pack a uniform grid");
    //     }
    // }

    {
        var packable: bool = true;
        if (Pixi.state.pack_target == .project and Pixi.state.project_folder == null) packable = false;
        if (Pixi.state.pack_target == .all_open and Pixi.state.open_files.items.len <= 1) packable = false;
        if (Pixi.Editor.saving()) {
            imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_background.toImguiVec4());
            defer imgui.popStyleColor();
            imgui.textWrapped("Please wait until all files are done saving.");
            packable = false;
        }

        if (!packable)
            imgui.beginDisabled(true);
        if (imgui.buttonEx("Pack", .{ .x = window_size.x, .y = 0.0 })) {
            switch (Pixi.state.pack_target) {
                .project => {
                    if (Pixi.state.project_folder) |folder| {
                        Pixi.Packer.recurseFiles(Pixi.state.allocator, folder) catch unreachable;
                        Pixi.state.packer.packAndClear() catch unreachable;
                    }
                },
                .all_open => {
                    for (Pixi.state.open_files.items) |*file| {
                        Pixi.state.packer.append(file) catch unreachable;
                    }
                    Pixi.state.packer.packAndClear() catch unreachable;
                },
                .single_open => {
                    if (Pixi.Editor.getFile(Pixi.state.open_file_index)) |file| {
                        Pixi.state.packer.append(file) catch unreachable;
                        Pixi.state.packer.packAndClear() catch unreachable;
                    }
                },
            }
        }
        if (!packable)
            imgui.endDisabled();

        if (Pixi.state.pack_target == .project and Pixi.state.project_folder == null) {
            imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_background.toImguiVec4());
            defer imgui.popStyleColor();
            imgui.textWrapped("Select a project folder to pack.");
        }

        if (Pixi.state.atlas.external) |atlas| {
            imgui.text("Atlas Details");
            imgui.text("Sprites: %d", atlas.sprites.len);
            imgui.text("Animations: %d", atlas.animations.len);
            if (Pixi.state.atlas.diffusemap) |diffusemap| {
                imgui.text("Atlas size: %dx%d", diffusemap.image.width, diffusemap.image.height);
            }

            if (imgui.buttonEx("Export", .{ .x = window_size.x, .y = 0.0 })) {
                Pixi.state.popups.file_dialog_request = .{
                    .state = .save,
                    .type = .export_atlas,
                };
            }

            if (Pixi.state.popups.file_dialog_response) |response| {
                if (response.type == .export_atlas) {
                    Pixi.state.recents.appendExport(Pixi.state.allocator.dupeZ(u8, response.path) catch unreachable) catch unreachable;
                    Pixi.state.recents.save() catch unreachable;
                    Pixi.state.atlas.save(response.path) catch unreachable;
                    nfd.freePath(response.path);
                    Pixi.state.popups.file_dialog_response = null;
                }
            }

            if (Pixi.state.recents.exports.items.len > 0) {
                if (imgui.buttonEx("Repeat Last Export", .{ .x = window_size.x, .y = 0.0 })) {
                    Pixi.state.atlas.save(Pixi.state.recents.exports.getLast()) catch unreachable;
                }
                imgui.textWrapped(Pixi.state.recents.exports.getLast());

                imgui.spacing();
                imgui.separatorText("Recents");
                imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_secondary.toImguiVec4());
                defer imgui.popStyleColor();
                if (imgui.beginChild("Recents", .{
                    .x = imgui.getWindowWidth() - Pixi.state.settings.explorer_grip * Pixi.state.content_scale[0],
                    .y = 0.0,
                }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
                    defer imgui.endChild();

                    var i: usize = Pixi.state.recents.exports.items.len;
                    while (i > 0) {
                        i -= 1;
                        const exp = Pixi.state.recents.exports.items[i];
                        const label = std.fmt.allocPrintZ(Pixi.state.allocator, "{s} {s}", .{ Pixi.fa.file_download, std.fs.path.basename(exp) }) catch unreachable;
                        defer Pixi.state.allocator.free(label);

                        if (imgui.selectable(label)) {
                            const exp_out = Pixi.state.recents.exports.swapRemove(i);
                            Pixi.state.recents.appendExport(exp_out) catch unreachable;
                        }
                        imgui.sameLineEx(0.0, 5.0 * Pixi.state.content_scale[0]);
                        imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_background.toImguiVec4());
                        imgui.text(exp);
                        imgui.popStyleColor();
                    }
                }
            }
        }
    }
}
