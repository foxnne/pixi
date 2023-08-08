const std = @import("std");
const pixi = @import("../../pixi.zig");
const core = @import("core");
const zgui = @import("zgui").MachImgui(core);
const nfd = @import("nfd");

pub fn draw() void {
    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 6.0 * pixi.content_scale[0], 5.0 * pixi.content_scale[1] } });
    defer zgui.popStyleVar(.{ .count = 1 });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button, .c = pixi.state.theme.highlight_secondary.toSlice() });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button_active, .c = pixi.state.theme.highlight_secondary.toSlice() });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button_hovered, .c = pixi.state.theme.hover_secondary.toSlice() });
    defer zgui.popStyleColor(.{ .count = 3 });

    const window_size = zgui.getContentRegionAvail();

    switch (pixi.state.pack_target) {
        .all_open => {
            if (pixi.state.open_files.items.len <= 1) {
                pixi.state.pack_target = .project;
            }
        },
        .single_open => {
            if (pixi.state.open_files.items.len == 0)
                pixi.state.pack_target = .project;
        },
        else => {},
    }

    const preview_text = switch (pixi.state.pack_target) {
        .project => "Full Project",
        .all_open => "All Open Files",
        .single_open => "Current Open File",
    };

    if (zgui.beginCombo("Files", .{ .preview_value = preview_text.ptr })) {
        defer zgui.endCombo();
        if (zgui.menuItem("Full Project", .{})) {
            pixi.state.pack_target = .project;
        }

        {
            const enabled = if (pixi.editor.getFile(pixi.state.open_file_index)) |_| true else false;
            if (zgui.menuItem("Current Open File", .{ .enabled = enabled })) {
                pixi.state.pack_target = .single_open;
            }
        }

        {
            const enabled = if (pixi.state.open_files.items.len > 1) true else false;
            if (zgui.menuItem("All Open Files", .{ .enabled = enabled })) {
                pixi.state.pack_target = .all_open;
            }
        }
    }

    {
        var packable: bool = true;
        if (pixi.state.pack_target == .project and pixi.state.project_folder == null) packable = false;
        if (pixi.state.pack_target == .all_open and pixi.state.open_files.items.len <= 1) packable = false;
        if (pixi.editor.saving()) {
            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.theme.text_background.toSlice() });
            defer zgui.popStyleColor(.{ .count = 1 });
            zgui.textWrapped("Please wait until all files are done saving.", .{});
            packable = false;
        }

        if (!packable)
            zgui.beginDisabled(.{});
        if (zgui.button("Pack", .{ .w = window_size[0] })) {
            switch (pixi.state.pack_target) {
                .project => {
                    if (pixi.state.project_folder) |folder| {
                        recurseFiles(pixi.state.allocator, folder) catch unreachable;
                        pixi.state.packer.packAndClear() catch unreachable;
                    }
                },
                .all_open => {
                    for (pixi.state.open_files.items) |*file| {
                        pixi.state.packer.append(file) catch unreachable;
                    }
                    pixi.state.packer.packAndClear() catch unreachable;
                },
                .single_open => {
                    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
                        pixi.state.packer.append(file) catch unreachable;
                        pixi.state.packer.packAndClear() catch unreachable;
                    }
                },
            }
        }
        if (!packable)
            zgui.endDisabled();

        if (pixi.state.pack_target == .project and pixi.state.project_folder == null) {
            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.theme.text_background.toSlice() });
            defer zgui.popStyleColor(.{ .count = 1 });
            zgui.textWrapped("Select a project folder to pack.", .{});
        }

        if (pixi.state.atlas.external) |atlas| {
            zgui.text("Atlas Details", .{});
            zgui.text("Sprites: {d}", .{atlas.sprites.len});
            zgui.text("Animations: {d}", .{atlas.animations.len});
            if (pixi.state.atlas.diffusemap) |diffusemap| {
                zgui.text("Atlas size: {d}x{d}", .{ diffusemap.image.width, diffusemap.image.height });
            }

            if (zgui.button("Export", .{ .w = window_size[0] })) {
                pixi.state.popups.file_dialog_request = .{
                    .state = .save,
                    .type = .export_atlas,
                };
            }

            if (pixi.state.popups.file_dialog_response) |response| {
                if (response.type == .export_atlas) {
                    pixi.state.recents.appendExport(pixi.state.allocator.dupeZ(u8, response.path) catch unreachable) catch unreachable;
                    pixi.state.recents.save() catch unreachable;
                    pixi.state.atlas.save(response.path) catch unreachable;
                    nfd.freePath(response.path);
                    pixi.state.popups.file_dialog_request = null;
                }
            }

            if (pixi.state.recents.exports.items.len > 0) {
                if (zgui.button("Repeat Last Export", .{ .w = window_size[0] })) {
                    pixi.state.atlas.save(pixi.state.recents.exports.getLast()) catch unreachable;
                }
                zgui.textWrapped("{s}", .{pixi.state.recents.exports.getLast()});

                zgui.spacing();
                zgui.text("Recents", .{});
                zgui.separator();
                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.theme.text_secondary.toSlice() });
                defer zgui.popStyleColor(.{ .count = 1 });
                if (zgui.beginChild("Recents", .{
                    .w = zgui.getWindowWidth() - pixi.state.settings.explorer_grip * pixi.content_scale[0],
                    .h = 0.0,
                    .flags = .{
                        .horizontal_scrollbar = true,
                    },
                })) {
                    defer zgui.endChild();

                    var i: usize = pixi.state.recents.exports.items.len;
                    while (i > 0) {
                        i -= 1;
                        const exp = pixi.state.recents.exports.items[i];
                        var label = std.fmt.allocPrintZ(pixi.state.allocator, "{s} {s}", .{ pixi.fa.file_download, std.fs.path.basename(exp) }) catch unreachable;
                        defer pixi.state.allocator.free(label);

                        if (zgui.selectable(label, .{})) {
                            const exp_out = pixi.state.recents.exports.swapRemove(i);
                            pixi.state.recents.appendExport(exp_out) catch unreachable;
                        }
                        zgui.sameLine(.{ .spacing = 5.0 * pixi.content_scale[0] });
                        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.theme.text_background.toSlice() });
                        zgui.text("{s}", .{exp});
                        zgui.popStyleColor(.{ .count = 1 });
                    }
                }
            }
        }
    }
}

pub fn recurseFiles(allocator: std.mem.Allocator, root_directory: [:0]const u8) !void {
    const recursor = struct {
        fn search(alloc: std.mem.Allocator, directory: [:0]const u8) !void {
            var dir = try std.fs.cwd().openIterableDir(directory, .{ .access_sub_paths = true });
            defer dir.close();

            var iter = dir.iterate();
            while (try iter.next()) |entry| {
                if (entry.kind == .file) {
                    const ext = std.fs.path.extension(entry.name);
                    if (std.mem.eql(u8, ext, ".pixi")) {
                        const abs_path = try std.fs.path.joinZ(alloc, &.{ directory, entry.name });
                        defer alloc.free(abs_path);

                        if (pixi.editor.getFileIndex(abs_path)) |index| {
                            if (pixi.editor.getFile(index)) |file| {
                                try pixi.state.packer.append(file);
                            }
                        } else {
                            if (try pixi.editor.loadFile(abs_path)) |file| {
                                try pixi.state.packer.open_files.append(file);
                                try pixi.state.packer.append(&pixi.state.packer.open_files.items[pixi.state.packer.open_files.items.len - 1]);
                            }
                        }
                    }
                } else if (entry.kind == .directory) {
                    const abs_path = try std.fs.path.joinZ(alloc, &[_][]const u8{ directory, entry.name });
                    defer alloc.free(abs_path);
                    try search(alloc, abs_path);
                }
            }
        }
    }.search;

    try recursor(allocator, root_directory);

    return;
}
