const std = @import("std");

const pixi = @import("../../pixi.zig");

const Core = @import("mach").Core;
const App = pixi.App;
const Editor = pixi.Editor;
const Packer = pixi.Packer;

const nfd = @import("nfd");
const imgui = @import("zig-imgui");

pub fn draw(app: *App, editor: *Editor, packer: *Packer) !void {
    imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 6.0, .y = 5.0 });
    defer imgui.popStyleVar();
    imgui.pushStyleColorImVec4(imgui.Col_Button, editor.theme.highlight_secondary.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_ButtonActive, editor.theme.highlight_secondary.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_ButtonHovered, editor.theme.hover_secondary.toImguiVec4());
    defer imgui.popStyleColorEx(3);

    const window_size = imgui.getContentRegionAvail();

    switch (packer.target) {
        .all_open => {
            if (editor.open_files.items.len <= 1) {
                packer.target = .project;
            }
        },
        .single_open => {
            if (editor.open_files.items.len == 0)
                packer.target = .project;
        },
        else => {},
    }

    const preview_text = switch (packer.target) {
        .project => "Full Project",
        .all_open => "All Open Files",
        .single_open => "Current Open File",
    };

    if (imgui.beginCombo("Files", preview_text.ptr, imgui.ComboFlags_None)) {
        defer imgui.endCombo();
        if (imgui.menuItem("Full Project")) {
            packer.target = .project;
        }

        {
            const enabled = if (editor.getFile(editor.open_file_index)) |_| true else false;
            if (imgui.menuItemEx("Current Open File", null, false, enabled)) {
                packer.target = .single_open;
            }
        }

        {
            const enabled = if (editor.open_files.items.len > 1) true else false;
            if (imgui.menuItemEx("All Open Files", null, false, enabled)) {
                packer.target = .all_open;
            }
        }
    }

    // _ = imgui.checkbox("Pack tileset", &pixi.app.pack_tileset);
    // if (imgui.isItemHovered(imgui.HoveredFlags_DelayNormal)) {
    //     if (imgui.beginTooltip()) {
    //         defer imgui.endTooltip();
    //         imgui.textColored(pixi.editor.theme.text_secondary.toImguiVec4(), "Do not tightly pack sprites, pack a uniform grid");
    //     }
    // }

    {
        var packable: bool = true;
        if (packer.target == .project and editor.project_folder == null) packable = false;
        if (packer.target == .all_open and editor.open_files.items.len <= 1) packable = false;
        if (editor.saving()) {
            imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text_background.toImguiVec4());
            defer imgui.popStyleColor();
            imgui.textWrapped("Please wait until all files are done saving.");
            packable = false;
        }

        if (!packable)
            imgui.beginDisabled(true);
        if (imgui.buttonEx("Pack", .{ .x = window_size.x, .y = 0.0 })) {
            switch (packer.target) {
                .project => {
                    if (editor.project_folder) |folder| {
                        try pixi.Packer.recurseFiles(folder);
                        try packer.packAndClear();
                    }
                },
                .all_open => {
                    for (editor.open_files.items) |*file| {
                        try packer.append(file);
                    }
                    try packer.packAndClear();
                },
                .single_open => {
                    if (editor.getFile(editor.open_file_index)) |file| {
                        try packer.append(file);
                        try packer.packAndClear();
                    }
                },
            }
        }
        if (!packable)
            imgui.endDisabled();

        if (packer.target == .project and editor.project_folder == null) {
            imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text_background.toImguiVec4());
            defer imgui.popStyleColor();
            imgui.textWrapped("Select a project folder to pack.");
        }

        if (editor.atlas.data) |data| {
            imgui.text("Atlas Details");
            imgui.text("Sprites: %d", data.sprites.len);
            imgui.text("Animations: %d", data.animations.len);
            if (editor.atlas.texture) |texture| {
                imgui.text("Atlas size: %dx%d", texture.image.width, texture.image.height);
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
                        const label = try std.fmt.allocPrintZ(
                            editor.arena.allocator(),
                            "{s} {s}",
                            .{ pixi.fa.file_download, std.fs.path.basename(exp) },
                        );

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
