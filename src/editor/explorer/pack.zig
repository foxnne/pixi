const std = @import("std");
const Pixi = @import("../../Pixi.zig");
const core = @import("mach").core;
const nfd = @import("nfd");
const imgui = @import("zig-imgui");

pub fn draw() !void {
    imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 6.0 * Pixi.app.content_scale[0], .y = 5.0 * Pixi.app.content_scale[1] });
    defer imgui.popStyleVar();
    imgui.pushStyleColorImVec4(imgui.Col_Button, Pixi.editor.theme.highlight_secondary.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_ButtonActive, Pixi.editor.theme.highlight_secondary.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_ButtonHovered, Pixi.editor.theme.hover_secondary.toImguiVec4());
    defer imgui.popStyleColorEx(3);

    const window_size = imgui.getContentRegionAvail();

    switch (Pixi.app.packer.target) {
        .all_open => {
            if (Pixi.app.open_files.items.len <= 1) {
                Pixi.app.packer.target = .project;
            }
        },
        .single_open => {
            if (Pixi.app.open_files.items.len == 0)
                Pixi.app.packer.target = .project;
        },
        else => {},
    }

    const preview_text = switch (Pixi.app.packer.target) {
        .project => "Full Project",
        .all_open => "All Open Files",
        .single_open => "Current Open File",
    };

    if (imgui.beginCombo("Files", preview_text.ptr, imgui.ComboFlags_None)) {
        defer imgui.endCombo();
        if (imgui.menuItem("Full Project")) {
            Pixi.app.packer.target = .project;
        }

        {
            const enabled = if (Pixi.Editor.getFile(Pixi.app.open_file_index)) |_| true else false;
            if (imgui.menuItemEx("Current Open File", null, false, enabled)) {
                Pixi.app.packer.target = .single_open;
            }
        }

        {
            const enabled = if (Pixi.app.open_files.items.len > 1) true else false;
            if (imgui.menuItemEx("All Open Files", null, false, enabled)) {
                Pixi.app.packer.target = .all_open;
            }
        }
    }

    // _ = imgui.checkbox("Pack tileset", &Pixi.app.pack_tileset);
    // if (imgui.isItemHovered(imgui.HoveredFlags_DelayNormal)) {
    //     if (imgui.beginTooltip()) {
    //         defer imgui.endTooltip();
    //         imgui.textColored(Pixi.editor.theme.text_secondary.toImguiVec4(), "Do not tightly pack sprites, pack a uniform grid");
    //     }
    // }

    {
        var packable: bool = true;
        if (Pixi.app.packer.target == .project and Pixi.app.project_folder == null) packable = false;
        if (Pixi.app.packer.target == .all_open and Pixi.app.open_files.items.len <= 1) packable = false;
        if (Pixi.Editor.saving()) {
            imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_background.toImguiVec4());
            defer imgui.popStyleColor();
            imgui.textWrapped("Please wait until all files are done saving.");
            packable = false;
        }

        if (!packable)
            imgui.beginDisabled(true);
        if (imgui.buttonEx("Pack", .{ .x = window_size.x, .y = 0.0 })) {
            switch (Pixi.app.packer.target) {
                .project => {
                    if (Pixi.app.project_folder) |folder| {
                        try Pixi.Packer.recurseFiles(Pixi.app.allocator, folder);
                        try Pixi.app.packer.packAndClear();
                    }
                },
                .all_open => {
                    for (Pixi.app.open_files.items) |*file| {
                        try Pixi.app.packer.append(file);
                    }
                    try Pixi.app.packer.packAndClear();
                },
                .single_open => {
                    if (Pixi.Editor.getFile(Pixi.app.open_file_index)) |file| {
                        try Pixi.app.packer.append(file);
                        try Pixi.app.packer.packAndClear();
                    }
                },
            }
        }
        if (!packable)
            imgui.endDisabled();

        if (Pixi.app.packer.target == .project and Pixi.app.project_folder == null) {
            imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_background.toImguiVec4());
            defer imgui.popStyleColor();
            imgui.textWrapped("Select a project folder to pack.");
        }

        if (Pixi.app.atlas.external) |atlas| {
            imgui.text("Atlas Details");
            imgui.text("Sprites: %d", atlas.sprites.len);
            imgui.text("Animations: %d", atlas.animations.len);
            if (Pixi.app.atlas.diffusemap) |diffusemap| {
                imgui.text("Atlas size: %dx%d", diffusemap.image.width, diffusemap.image.height);
            }

            if (imgui.buttonEx("Export", .{ .x = window_size.x, .y = 0.0 })) {
                Pixi.app.popups.file_dialog_request = .{
                    .state = .save,
                    .type = .export_atlas,
                };
            }

            if (Pixi.app.popups.file_dialog_response) |response| {
                if (response.type == .export_atlas) {
                    try Pixi.app.recents.appendExport(try Pixi.app.allocator.dupeZ(u8, response.path));
                    try Pixi.app.recents.save();
                    try Pixi.app.atlas.save(response.path);
                    nfd.freePath(response.path);
                    Pixi.app.popups.file_dialog_response = null;
                }
            }

            if (Pixi.app.recents.exports.items.len > 0) {
                if (imgui.buttonEx("Repeat Last Export", .{ .x = window_size.x, .y = 0.0 })) {
                    try Pixi.app.atlas.save(Pixi.app.recents.exports.getLast());
                }
                imgui.textWrapped(Pixi.app.recents.exports.getLast());

                imgui.spacing();
                imgui.separatorText("Recents");
                imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_secondary.toImguiVec4());
                defer imgui.popStyleColor();
                if (imgui.beginChild("Recents", .{
                    .x = imgui.getWindowWidth() - Pixi.app.settings.explorer_grip * Pixi.app.content_scale[0],
                    .y = 0.0,
                }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
                    defer imgui.endChild();

                    var i: usize = Pixi.app.recents.exports.items.len;
                    while (i > 0) {
                        i -= 1;
                        const exp = Pixi.app.recents.exports.items[i];
                        const label = try std.fmt.allocPrintZ(Pixi.app.allocator, "{s} {s}", .{ Pixi.fa.file_download, std.fs.path.basename(exp) });
                        defer Pixi.app.allocator.free(label);

                        if (imgui.selectable(label)) {
                            const exp_out = Pixi.app.recents.exports.swapRemove(i);
                            try Pixi.app.recents.appendExport(exp_out);
                        }
                        imgui.sameLineEx(0.0, 5.0 * Pixi.app.content_scale[0]);
                        imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_background.toImguiVec4());
                        imgui.text(exp);
                        imgui.popStyleColor();
                    }
                }
            }
        }
    }
}
