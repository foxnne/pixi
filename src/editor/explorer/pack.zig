const std = @import("std");
const Pixi = @import("../../Pixi.zig");
const Core = @import("mach").Core;
const Editor = Pixi.Editor;
const nfd = @import("nfd");
const imgui = @import("zig-imgui");

pub fn draw(_: *Core, app: *Pixi, editor: *Editor) !void {
    imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 6.0, .y = 5.0 });
    defer imgui.popStyleVar();
    imgui.pushStyleColorImVec4(imgui.Col_Button, editor.theme.highlight_secondary.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_ButtonActive, editor.theme.highlight_secondary.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_ButtonHovered, editor.theme.hover_secondary.toImguiVec4());
    defer imgui.popStyleColorEx(3);

    const window_size = imgui.getContentRegionAvail();

    switch (app.packer.target) {
        .all_open => {
            if (editor.open_files.items.len <= 1) {
                app.packer.target = .project;
            }
        },
        .single_open => {
            if (editor.open_files.items.len == 0)
                app.packer.target = .project;
        },
        else => {},
    }

    const preview_text = switch (app.packer.target) {
        .project => "Full Project",
        .all_open => "All Open Files",
        .single_open => "Current Open File",
    };

    if (imgui.beginCombo("Files", preview_text.ptr, imgui.ComboFlags_None)) {
        defer imgui.endCombo();
        if (imgui.menuItem("Full Project")) {
            app.packer.target = .project;
        }

        {
            const enabled = if (editor.getFile(editor.open_file_index)) |_| true else false;
            if (imgui.menuItemEx("Current Open File", null, false, enabled)) {
                app.packer.target = .single_open;
            }
        }

        {
            const enabled = if (editor.open_files.items.len > 1) true else false;
            if (imgui.menuItemEx("All Open Files", null, false, enabled)) {
                app.packer.target = .all_open;
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
        if (app.packer.target == .project and editor.project_folder == null) packable = false;
        if (app.packer.target == .all_open and editor.open_files.items.len <= 1) packable = false;
        if (editor.saving()) {
            imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text_background.toImguiVec4());
            defer imgui.popStyleColor();
            imgui.textWrapped("Please wait until all files are done saving.");
            packable = false;
        }

        if (!packable)
            imgui.beginDisabled(true);
        if (imgui.buttonEx("Pack", .{ .x = window_size.x, .y = 0.0 })) {
            switch (app.packer.target) {
                .project => {
                    if (editor.project_folder) |folder| {
                        try Pixi.Packer.recurseFiles(app.allocator, folder);
                        try app.packer.packAndClear();
                    }
                },
                .all_open => {
                    for (editor.open_files.items) |*file| {
                        try app.packer.append(file);
                    }
                    try app.packer.packAndClear();
                },
                .single_open => {
                    if (editor.getFile(editor.open_file_index)) |file| {
                        try app.packer.append(file);
                        try app.packer.packAndClear();
                    }
                },
            }
        }
        if (!packable)
            imgui.endDisabled();

        if (app.packer.target == .project and editor.project_folder == null) {
            imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text_background.toImguiVec4());
            defer imgui.popStyleColor();
            imgui.textWrapped("Select a project folder to pack.");
        }

        if (editor.atlas.external) |atlas| {
            imgui.text("Atlas Details");
            imgui.text("Sprites: %d", atlas.sprites.len);
            imgui.text("Animations: %d", atlas.animations.len);
            if (editor.atlas.diffusemap) |diffusemap| {
                imgui.text("Atlas size: %dx%d", diffusemap.image.width, diffusemap.image.height);
            }

            if (imgui.buttonEx("Export", .{ .x = window_size.x, .y = 0.0 })) {
                editor.popups.file_dialog_request = .{
                    .state = .save,
                    .type = .export_atlas,
                };
            }

            if (editor.popups.file_dialog_response) |response| {
                if (response.type == .export_atlas) {
                    try editor.recents.appendExport(try app.allocator.dupeZ(u8, response.path));
                    try editor.recents.save();
                    try editor.atlas.save(response.path);
                    nfd.freePath(response.path);
                    editor.popups.file_dialog_response = null;
                }
            }

            if (editor.recents.exports.items.len > 0) {
                if (imgui.buttonEx("Repeat Last Export", .{ .x = window_size.x, .y = 0.0 })) {
                    try editor.atlas.save(editor.recents.exports.getLast());
                }
                imgui.textWrapped(editor.recents.exports.getLast());

                imgui.spacing();
                imgui.separatorText("Recents");
                imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text_secondary.toImguiVec4());
                defer imgui.popStyleColor();
                if (imgui.beginChild("Recents", .{
                    .x = imgui.getWindowWidth() - editor.settings.explorer_grip,
                    .y = 0.0,
                }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
                    defer imgui.endChild();

                    var i: usize = editor.recents.exports.items.len;
                    while (i > 0) {
                        i -= 1;
                        const exp = editor.recents.exports.items[i];
                        const label = try std.fmt.allocPrintZ(app.allocator, "{s} {s}", .{ Pixi.fa.file_download, std.fs.path.basename(exp) });
                        defer app.allocator.free(label);

                        if (imgui.selectable(label)) {
                            const exp_out = editor.recents.exports.swapRemove(i);
                            try editor.recents.appendExport(exp_out);
                        }
                        imgui.sameLineEx(0.0, 5.0);
                        imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text_background.toImguiVec4());
                        imgui.text(exp);
                        imgui.popStyleColor();
                    }
                }
            }
        }
    }
}
