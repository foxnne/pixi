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

    if (editor.project) |*project| {
        if (editor.folder) |project_folder| {
            const project_path = try std.fs.path.joinZ(
                editor.arena.allocator(),
                &.{ project_folder, ".pixiproject" },
            );

            imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.editor.theme.text_background.toImguiVec4());
            imgui.text("Paths are relative to:");
            imgui.textWrapped(project_folder);
            imgui.text("Settings are being saved to:");
            imgui.textWrapped(project_path);
            imgui.popStyleColor();
        } else {
            editor.project.?.deinit();
            editor.project = null;
        }

        var disable_hotkeys = false;
        {
            if (imgui.inputText(
                "Atlas Output",
                editor.buffers.atlas_path[0..],
                editor.buffers.atlas_path.len,
                imgui.InputTextFlags_AutoSelectAll,
            )) {
                const trimmed_text = std.mem.trim(u8, &editor.buffers.atlas_path, "\u{0}");
                project.packed_atlas_output = trimmed_text;
                try project.save();
            }
            if (imgui.isItemFocused()) disable_hotkeys = true;

            if (project.packed_atlas_output) |packed_atlas_output| {
                if (!std.mem.eql(u8, ".atlas", std.fs.path.extension(packed_atlas_output))) {
                    imgui.textColored(pixi.editor.theme.text_red.toImguiVec4(), "Atlas file path must end with .atlas extension!");
                }
                if (std.mem.eql(u8, packed_atlas_output, "")) {
                    project.packed_heightmap_output = null;
                    try project.save();
                }
            }
        }

        {
            if (imgui.inputText(
                "Texture Output",
                editor.buffers.texture_path[0..],
                editor.buffers.texture_path.len,
                imgui.InputTextFlags_AutoSelectAll,
            )) {
                const trimmed_text = std.mem.trim(u8, &editor.buffers.texture_path, "\u{0}");
                project.packed_texture_output = trimmed_text;
                try project.save();
            }
            if (imgui.isItemFocused()) disable_hotkeys = true;
            if (project.packed_texture_output) |packed_texture_output| {
                if (!std.mem.eql(u8, ".png", std.fs.path.extension(packed_texture_output)))
                    imgui.textColored(pixi.editor.theme.text_red.toImguiVec4(), "Texture file path must end with .png extension!");

                if (std.mem.eql(u8, packed_texture_output, "")) {
                    project.packed_heightmap_output = null;
                    try project.save();
                }
            }
        }

        {
            if (imgui.inputText(
                "Heightmap Output",
                editor.buffers.heightmap_path[0..],
                editor.buffers.heightmap_path.len,
                imgui.InputTextFlags_AutoSelectAll,
            )) {
                const trimmed_text = std.mem.trim(u8, &editor.buffers.heightmap_path, "\u{0}");
                project.packed_heightmap_output = trimmed_text;
                try project.save();
            }
            if (imgui.isItemFocused()) disable_hotkeys = true;
            if (project.packed_heightmap_output) |packed_heightmap_output| {
                if (!std.mem.eql(u8, ".png", std.fs.path.extension(packed_heightmap_output))) {
                    imgui.textColored(pixi.editor.theme.text_red.toImguiVec4(), "Heightmap file path must end with .png extension!");
                }
                if (std.mem.eql(u8, packed_heightmap_output, "")) {
                    project.packed_heightmap_output = null;
                    try project.save();
                }
            }
        }

        {
            if (imgui.checkbox("Pack and Export on save", &project.pack_on_save)) {
                try project.save();
            }
        }

        if (imgui.buttonEx("Pack and Export", .{ .x = window_size.x, .y = 0.0 })) {
            if (editor.folder) |project_folder| {
                packer.target = .project;
                try packer.appendProject();
                try packer.packAndClear();
                try project.exportAssets(project_folder);
            }
        }

        editor.hotkeys.disable = disable_hotkeys;
    } else {
        imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text_background.toImguiVec4());
        imgui.textWrapped("No .pixiproject file found at project folder, would you like to create a project file to specify constant output paths and other project-specific behaviors?");
        imgui.popStyleColor();

        if (imgui.buttonEx("Create Project", .{ .x = window_size.x, .y = 0.0 })) {
            if (editor.folder != null) {
                editor.project = .{};
            }

            if (editor.project) |*project| try project.save();
        }

        {
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

            var packable: bool = true;
            if (packer.target == .project and editor.folder == null) packable = false;
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
                        try packer.appendProject();
                        try packer.packAndClear();
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

            if (packer.target == .project and editor.folder == null) {
                imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text_background.toImguiVec4());
                defer imgui.popStyleColor();
                imgui.textWrapped("Select a project folder to pack.");
            }
        }

        if (editor.atlas.data) |data| {
            imgui.text("Atlas Details");
            imgui.text("Sprites: %d", data.sprites.len);
            imgui.text("Animations: %d", data.animations.len);
            if (editor.atlas.texture) |texture| {
                imgui.text("Atlas size: %dx%d", texture.width, texture.height);
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

                    const atlas_path = try std.fmt.allocPrintZ(editor.arena.allocator(), "{s}.atlas", .{response.path});
                    const texture_path = try std.fmt.allocPrintZ(editor.arena.allocator(), "{s}.png", .{response.path});
                    const heightmap_path = try std.fmt.allocPrintZ(editor.arena.allocator(), "{s}_h.png", .{response.path});

                    try editor.atlas.save(atlas_path, .data);
                    try editor.atlas.save(texture_path, .texture);
                    try editor.atlas.save(heightmap_path, .heightmap);

                    nfd.freePath(response.path);
                    editor.popups.file_dialog_response = null;
                }
            }

            if (editor.recents.exports.items.len > 0) {
                if (imgui.buttonEx("Repeat Last Export", .{ .x = window_size.x, .y = 0.0 })) {
                    const atlas_path = try std.fmt.allocPrintZ(editor.arena.allocator(), "{s}.atlas", .{editor.recents.exports.getLast()});
                    const texture_path = try std.fmt.allocPrintZ(editor.arena.allocator(), "{s}.png", .{editor.recents.exports.getLast()});
                    const heightmap_path = try std.fmt.allocPrintZ(editor.arena.allocator(), "{s}_h.png", .{editor.recents.exports.getLast()});

                    try editor.atlas.save(atlas_path, .data);
                    try editor.atlas.save(texture_path, .texture);
                    try editor.atlas.save(heightmap_path, .heightmap);
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
