const std = @import("std");
const Pixi = @import("../../Pixi.zig");
const nfd = @import("nfd");
const zstbi = @import("zstbi");
const imgui = @import("zig-imgui");

pub const Extension = enum {
    unsupported,
    hidden,
    pixi,
    atlas,
    png,
    jpg,
    pdf,
    psd,
    aseprite,
    pyxel,
    json,
    zig,
    txt,
    zip,
    _7z,
    tar,
};

pub fn draw() !void {
    imgui.pushStyleColorImVec4(imgui.Col_HeaderHovered, Pixi.editor.theme.background.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_HeaderActive, Pixi.editor.theme.background.toImguiVec4());
    defer imgui.popStyleColorEx(2);

    if (Pixi.state.project_folder) |path| {
        const folder = std.fs.path.basename(path);
        imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0 * Pixi.state.content_scale[0], .y = 5.0 * Pixi.state.content_scale[1] });

        // Open files
        const file_count = Pixi.state.open_files.items.len;
        if (file_count > 0) {
            imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_secondary.toImguiVec4());
            imgui.separatorText("Open Files  " ++ Pixi.fa.file_powerpoint);
            imgui.popStyleColor();

            if (imgui.beginChild("OpenFiles", .{
                .x = -1.0,
                .y = @as(f32, @floatFromInt(@min(file_count + 1, 6))) * (imgui.getTextLineHeight() + 6.0 * Pixi.state.content_scale[0]),
            }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
                defer imgui.endChild();
                imgui.spacing();

                for (Pixi.state.open_files.items, 0..) |file, i| {
                    imgui.textColored(Pixi.editor.theme.text_orange.toImguiVec4(), " " ++ Pixi.fa.file_powerpoint ++ " ");
                    imgui.sameLine();
                    const name = std.fs.path.basename(file.path);
                    const label = std.fmt.allocPrintZ(Pixi.state.allocator, "{s}", .{name}) catch unreachable;
                    defer Pixi.state.allocator.free(label);
                    if (imgui.selectable(label)) {
                        Pixi.Editor.setActiveFile(i);
                    }

                    imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0 * Pixi.state.content_scale[0], .y = 2.0 * Pixi.state.content_scale[1] });
                    imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0 * Pixi.state.content_scale[0], .y = 6.0 * Pixi.state.content_scale[1] });
                    imgui.pushStyleVar(imgui.StyleVar_IndentSpacing, 16.0 * Pixi.state.content_scale[0]);
                    imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0 * Pixi.state.content_scale[0], .y = 10.0 * Pixi.state.content_scale[1] });
                    imgui.pushID(file.path);
                    if (imgui.beginPopupContextItem()) {
                        contextMenuFile(file.path);
                        imgui.endPopup();
                    }
                    imgui.popID();
                    imgui.popStyleVarEx(4);

                    if (imgui.isItemHovered(imgui.HoveredFlags_DelayNormal)) {
                        if (imgui.beginTooltip()) {
                            defer imgui.endTooltip();

                            imgui.textColored(Pixi.editor.theme.text_secondary.toImguiVec4(), file.path);
                        }
                    }
                }
            }
        }

        const index = if (std.mem.indexOf(u8, path, folder)) |i| i else 0;

        imgui.spacing();
        imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_secondary.toImguiVec4());
        imgui.separatorText("Project Folder  " ++ Pixi.fa.folder_open);
        imgui.popStyleColor();

        // File tree
        var open: bool = true;
        if (imgui.collapsingHeaderBoolPtr(
            path[index.. :0],
            &open,
            imgui.TreeNodeFlags_DefaultOpen,
        )) {
            imgui.indent();
            defer imgui.unindent();

            imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0 * Pixi.state.content_scale[0], .y = 2.0 * Pixi.state.content_scale[1] });
            imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0 * Pixi.state.content_scale[0], .y = 6.0 * Pixi.state.content_scale[1] });
            imgui.pushStyleVar(imgui.StyleVar_IndentSpacing, 16.0 * Pixi.state.content_scale[0]);
            imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0 * Pixi.state.content_scale[0], .y = 4.0 * Pixi.state.content_scale[1] });
            imgui.pushID(path);
            if (imgui.beginPopupContextItem()) {
                contextMenuFolder(path);
                imgui.endPopup();
            }
            imgui.popID();
            imgui.popStyleVarEx(4);

            if (imgui.beginChild("FileTree", .{
                .x = -1.0,
                .y = 0.0,
            }, imgui.ChildFlags_None, imgui.WindowFlags_HorizontalScrollbar)) { // TODO: Should this also be ChildWindow?
                // File Tree
                recurseFiles(Pixi.state.allocator, path);
            }
            defer imgui.endChild();
        }

        imgui.popStyleVar();

        if (!open) {
            if (Pixi.state.project_folder) |f| {
                Pixi.state.allocator.free(f);
            }

            Pixi.state.project_folder = null;
        }
    } else {
        imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_background.toImguiVec4());
        imgui.textWrapped("Open a folder to begin editing.");
        imgui.popStyleColor();

        if (Pixi.state.recents.folders.items.len > 0) {
            imgui.spacing();
            imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_secondary.toImguiVec4());
            imgui.separatorText("Recents  " ++ Pixi.fa.clock);
            imgui.popStyleColor();
            imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_secondary.toImguiVec4());
            defer imgui.popStyleColor();
            if (imgui.beginChild("Recents", .{
                .x = imgui.getWindowWidth() - Pixi.state.settings.explorer_grip * Pixi.state.content_scale[0],
                .y = 0.0,
            }, imgui.ChildFlags_None, imgui.WindowFlags_HorizontalScrollbar)) {
                defer imgui.endChild();

                var i: usize = Pixi.state.recents.folders.items.len;
                while (i > 0) {
                    i -= 1;
                    const folder = Pixi.state.recents.folders.items[i];
                    const label = std.fmt.allocPrintZ(Pixi.state.allocator, "{s} {s}##{s}", .{ Pixi.fa.folder, std.fs.path.basename(folder), folder }) catch unreachable;
                    defer Pixi.state.allocator.free(label);

                    if (imgui.selectable(label)) {
                        try Pixi.Editor.setProjectFolder(folder);
                    }
                    imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0 * Pixi.state.content_scale[0], .y = 2.0 * Pixi.state.content_scale[1] });
                    imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0 * Pixi.state.content_scale[0], .y = 6.0 * Pixi.state.content_scale[1] });
                    imgui.pushStyleVar(imgui.StyleVar_IndentSpacing, 16.0 * Pixi.state.content_scale[0]);
                    imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0 * Pixi.state.content_scale[0], .y = 10.0 * Pixi.state.content_scale[1] });
                    defer imgui.popStyleVarEx(4);
                    if (imgui.beginPopupContextItem()) {
                        defer imgui.endPopup();
                        if (imgui.menuItem("Remove")) {
                            const item = Pixi.state.recents.folders.orderedRemove(i);
                            Pixi.state.allocator.free(item);
                            Pixi.state.recents.save() catch unreachable;
                        }
                    }

                    imgui.sameLineEx(0.0, 5.0 * Pixi.state.content_scale[0]);
                    imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_background.toImguiVec4());
                    imgui.text(folder);
                    imgui.popStyleColor();
                }
            }
        }
    }
}

pub fn recurseFiles(allocator: std.mem.Allocator, root_directory: [:0]const u8) void {
    imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0 * Pixi.state.content_scale[0], .y = 2.0 * Pixi.state.content_scale[1] });
    imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0 * Pixi.state.content_scale[0], .y = 6.0 * Pixi.state.content_scale[1] });
    imgui.pushStyleVar(imgui.StyleVar_IndentSpacing, 16.0 * Pixi.state.content_scale[0]);
    imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0 * Pixi.state.content_scale[0], .y = 10.0 * Pixi.state.content_scale[1] });
    defer imgui.popStyleVarEx(4);

    const recursor = struct {
        fn search(alloc: std.mem.Allocator, directory: [:0]const u8) void {
            var dir = std.fs.cwd().openDir(directory, .{ .access_sub_paths = true, .iterate = true }) catch unreachable;
            defer dir.close();

            var iter = dir.iterate();
            while (iter.next() catch unreachable) |entry| {
                if (entry.kind == .file) {
                    imgui.indent();
                    defer imgui.unindent();
                    const ext = extension(entry.name);
                    if (ext == .hidden) continue;
                    const icon = switch (ext) {
                        .pixi, .psd => Pixi.fa.file_powerpoint,
                        .jpg, .png, .aseprite, .pyxel => Pixi.fa.file_image,
                        .pdf => Pixi.fa.file_pdf,
                        .json, .zig, .txt, .atlas => Pixi.fa.file_code,
                        .tar, ._7z, .zip => Pixi.fa.file_archive,
                        else => Pixi.fa.file,
                    };

                    const icon_color = switch (ext) {
                        .pixi, .zig => Pixi.editor.theme.text_orange.toImguiVec4(),
                        .png, .psd => Pixi.editor.theme.text_blue.toImguiVec4(),
                        .jpg => Pixi.editor.theme.highlight_primary.toImguiVec4(),
                        .pdf => Pixi.editor.theme.text_red.toImguiVec4(),
                        .json, .atlas => Pixi.editor.theme.text_yellow.toImguiVec4(),
                        .txt, .zip, ._7z, .tar => Pixi.editor.theme.text_background.toImguiVec4(),
                        else => Pixi.editor.theme.text_background.toImguiVec4(),
                    };

                    const text_color = switch (ext) {
                        .pixi => Pixi.editor.theme.text.toImguiVec4(),
                        .jpg, .png, .json, .zig, .pdf, .aseprite, .pyxel, .psd, .tar, ._7z, .zip, .txt, .atlas => Pixi.editor.theme.text_secondary.toImguiVec4(),
                        else => Pixi.editor.theme.text_background.toImguiVec4(),
                    };

                    const icon_spaced = std.fmt.allocPrintZ(Pixi.state.allocator, " {s} ", .{icon}) catch unreachable;
                    defer Pixi.state.allocator.free(icon_spaced);

                    imgui.textColored(icon_color, icon_spaced);
                    imgui.sameLine();

                    const abs_path = std.fs.path.joinZ(alloc, &.{ directory, entry.name }) catch unreachable;
                    defer alloc.free(abs_path);

                    imgui.pushStyleColorImVec4(imgui.Col_Text, text_color);

                    const selectable_name = std.fmt.allocPrintZ(Pixi.state.allocator, "{s}", .{entry.name}) catch unreachable;
                    defer Pixi.state.allocator.free(selectable_name);

                    if (imgui.selectableEx(
                        selectable_name,
                        if (Pixi.Editor.getFileIndex(abs_path)) |_| true else false,
                        imgui.SelectableFlags_None,
                        .{ .x = 0.0, .y = 0.0 },
                    )) {
                        switch (ext) {
                            .pixi => {
                                _ = Pixi.Editor.openFile(abs_path) catch {
                                    std.log.debug("Failed to open file: {s}", .{abs_path});
                                };
                            },
                            .png, .jpg => {
                                _ = Pixi.Editor.openReference(abs_path) catch {
                                    std.log.debug("Failed to open file: {s}", .{abs_path});
                                };
                            },
                            else => {},
                        }
                    }
                    imgui.popStyleColor();

                    imgui.pushID(abs_path);
                    if (imgui.beginPopupContextItem()) {
                        contextMenuFile(abs_path);
                        imgui.endPopup();
                    }
                    imgui.popID();
                } else if (entry.kind == .directory) {
                    const abs_path = std.fs.path.joinZ(alloc, &[_][]const u8{ directory, entry.name }) catch unreachable;
                    defer alloc.free(abs_path);
                    const folder = std.fmt.allocPrintZ(alloc, "{s}  {s}", .{ Pixi.fa.folder, entry.name }) catch unreachable;
                    defer alloc.free(folder);
                    imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_secondary.toImguiVec4());
                    defer imgui.popStyleColor();

                    if (imgui.treeNode(folder)) {
                        imgui.pushID(abs_path);
                        if (imgui.beginPopupContextItem()) {
                            contextMenuFolder(abs_path);
                            imgui.endPopup();
                        }
                        imgui.popID();

                        search(alloc, abs_path);

                        imgui.treePop();
                    } else {
                        imgui.pushID(abs_path);
                        if (imgui.beginPopupContextItem()) {
                            contextMenuFolder(abs_path);
                            imgui.endPopup();
                        }
                        imgui.popID();
                    }
                }
            }
        }
    }.search;

    recursor(allocator, root_directory);

    return;
}

fn contextMenuFolder(folder: [:0]const u8) void {
    imgui.pushStyleColorImVec4(imgui.Col_Separator, Pixi.editor.theme.foreground.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text.toImguiVec4());
    defer imgui.popStyleColorEx(2);
    if (imgui.menuItem("New File...")) {
        const new_file_path = std.fs.path.joinZ(Pixi.state.allocator, &[_][]const u8{ folder, "New_file.pixi" }) catch unreachable;
        defer Pixi.state.allocator.free(new_file_path);
        Pixi.state.popups.fileSetupNew(new_file_path);
    }
    if (imgui.menuItem("New File from PNG...")) {
        Pixi.state.popups.file_dialog_request = .{
            .state = .file,
            .type = .new_png,
            .filter = "png",
        };
    }

    if (Pixi.state.popups.file_dialog_response) |response| {
        if (response.type == .new_png) {
            const new_file_path = std.fmt.allocPrintZ(Pixi.state.allocator, "{s}.pixi", .{response.path[0 .. response.path.len - 4]}) catch unreachable;
            defer Pixi.state.allocator.free(new_file_path);
            Pixi.state.popups.fileSetupImportPng(new_file_path, response.path);

            nfd.freePath(response.path);
            Pixi.state.popups.file_dialog_response = null;
        }
    }
    if (imgui.menuItem("New Folder...")) {
        std.log.debug("{s}", .{folder});
    }

    imgui.separator();
}

fn contextMenuFile(file: [:0]const u8) void {
    imgui.pushStyleColorImVec4(imgui.Col_Separator, Pixi.editor.theme.foreground.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text.toImguiVec4());

    const ext = extension(file);

    switch (ext) {
        .png => {
            if (imgui.menuItem("Import...")) {
                const new_file_path = std.fmt.allocPrintZ(Pixi.state.allocator, "{s}.pixi", .{file[0 .. file.len - 4]}) catch unreachable;
                defer Pixi.state.allocator.free(new_file_path);
                Pixi.state.popups.fileSetupImportPng(new_file_path, file);
            }
        },
        .pixi => {
            if (imgui.menuItem("Re-slice...")) {
                Pixi.state.popups.fileSetupSlice(file);
            }
        },
        else => {},
    }

    imgui.separator();

    if (imgui.menuItem("Rename...")) {
        Pixi.state.popups.rename_path = [_:0]u8{0} ** std.fs.max_path_bytes;
        Pixi.state.popups.rename_old_path = [_:0]u8{0} ** std.fs.max_path_bytes;
        @memcpy(Pixi.state.popups.rename_path[0..file.len], file);
        @memcpy(Pixi.state.popups.rename_old_path[0..file.len], file);
        Pixi.state.popups.rename = true;
        Pixi.state.popups.rename_state = .rename;
    }

    if (imgui.menuItem("Duplicate...")) {
        Pixi.state.popups.rename_path = [_:0]u8{0} ** std.fs.max_path_bytes;
        Pixi.state.popups.rename_old_path = [_:0]u8{0} ** std.fs.max_path_bytes;
        @memcpy(Pixi.state.popups.rename_old_path[0..file.len], file);

        const ex = std.fs.path.extension(file);

        if (std.mem.indexOf(u8, file, ex)) |ext_i| {
            const new_base_name = std.fmt.allocPrintZ(Pixi.state.allocator, "{s}{s}{s}", .{ file[0..ext_i], "_copy", ex }) catch unreachable;
            defer Pixi.state.allocator.free(new_base_name);
            @memcpy(Pixi.state.popups.rename_path[0..new_base_name.len], new_base_name);

            Pixi.state.popups.rename = true;
            Pixi.state.popups.rename_state = .duplicate;
        }
    }
    imgui.separator();
    imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_red.toImguiVec4());
    if (imgui.menuItem("Delete")) {
        std.fs.deleteFileAbsolute(file) catch unreachable;
        if (Pixi.Editor.getFileIndex(file)) |index| {
            Pixi.Editor.closeFile(index) catch unreachable;
        }
    }
    imgui.popStyleColorEx(3);
}

pub fn extension(file: []const u8) Extension {
    const ext = std.fs.path.extension(file);
    if (std.mem.eql(u8, ext, "")) return .hidden;
    if (std.mem.eql(u8, ext, ".pixi")) return .pixi;
    if (std.mem.eql(u8, ext, ".atlas")) return .atlas;
    if (std.mem.eql(u8, ext, ".png")) return .png;
    if (std.mem.eql(u8, ext, ".jpg")) return .jpg;
    if (std.mem.eql(u8, ext, ".pdf")) return .pdf;
    if (std.mem.eql(u8, ext, ".psd")) return .psd;
    if (std.mem.eql(u8, ext, ".aseprite")) return .aseprite;
    if (std.mem.eql(u8, ext, ".pyxel")) return .pyxel;
    if (std.mem.eql(u8, ext, ".json")) return .json;
    if (std.mem.eql(u8, ext, ".zig")) return .zig;
    if (std.mem.eql(u8, ext, ".zip")) return .zip;
    if (std.mem.eql(u8, ext, ".7z")) return ._7z;
    if (std.mem.eql(u8, ext, ".tar")) return .tar;
    if (std.mem.eql(u8, ext, ".txt")) return .txt;
    return .unsupported;
}
