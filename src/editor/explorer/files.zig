const std = @import("std");
const pixi = @import("../../pixi.zig");
const core = @import("mach-core");
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

pub fn draw() void {
    imgui.pushStyleColorImVec4(imgui.Col_HeaderHovered, pixi.state.theme.background.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_HeaderActive, pixi.state.theme.background.toImguiVec4());
    defer imgui.popStyleColorEx(2);

    if (pixi.state.project_folder) |path| {
        const folder = std.fs.path.basename(path);
        imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0 * pixi.content_scale[0], .y = 5.0 * pixi.content_scale[1] });

        // Open files
        const file_count = pixi.state.open_files.items.len;
        if (file_count > 0) {
            imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_secondary.toImguiVec4());
            imgui.separatorText("Open Files  " ++ pixi.fa.file_powerpoint);
            imgui.popStyleColor();

            if (imgui.beginChild("OpenFiles", .{
                .x = -1.0,
                .y = @as(f32, @floatFromInt(@min(file_count + 1, 6))) * (imgui.getTextLineHeight() + 6.0 * pixi.content_scale[0]),
            }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
                defer imgui.endChild();
                imgui.spacing();

                for (pixi.state.open_files.items, 0..) |file, i| {
                    imgui.textColored(pixi.state.theme.text_orange.toImguiVec4(), " " ++ pixi.fa.file_powerpoint ++ " ");
                    imgui.sameLine();
                    const name = std.fs.path.basename(file.path);
                    const label = std.fmt.allocPrintZ(pixi.state.allocator, "{s}", .{name}) catch unreachable;
                    defer pixi.state.allocator.free(label);
                    if (imgui.selectable(label)) {
                        pixi.editor.setActiveFile(i);
                    }

                    imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0 * pixi.content_scale[0], .y = 2.0 * pixi.content_scale[1] });
                    imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0 * pixi.content_scale[0], .y = 6.0 * pixi.content_scale[1] });
                    imgui.pushStyleVar(imgui.StyleVar_IndentSpacing, 16.0 * pixi.content_scale[0]);
                    imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0 * pixi.content_scale[0], .y = 10.0 * pixi.content_scale[1] });
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

                            imgui.textColored(pixi.state.theme.text_secondary.toImguiVec4(), file.path);
                        }
                    }
                }
            }
        }

        const index = if (std.mem.indexOf(u8, path, folder)) |i| i else 0;

        imgui.spacing();
        imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_secondary.toImguiVec4());
        imgui.separatorText("Project Folder  " ++ pixi.fa.folder_open);
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

            imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0 * pixi.content_scale[0], .y = 2.0 * pixi.content_scale[1] });
            imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0 * pixi.content_scale[0], .y = 6.0 * pixi.content_scale[1] });
            imgui.pushStyleVar(imgui.StyleVar_IndentSpacing, 16.0 * pixi.content_scale[0]);
            imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0 * pixi.content_scale[0], .y = 4.0 * pixi.content_scale[1] });
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
                recurseFiles(pixi.state.allocator, path);
            }
            defer imgui.endChild();
        }

        imgui.popStyleVar();

        if (!open) {
            if (pixi.state.project_folder) |f| {
                pixi.state.allocator.free(f);
            }

            pixi.state.project_folder = null;
        }
    } else {
        imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_background.toImguiVec4());
        imgui.textWrapped("Open a folder to begin editing.");
        imgui.popStyleColor();

        if (pixi.state.recents.folders.items.len > 0) {
            imgui.spacing();
            imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_secondary.toImguiVec4());
            imgui.separatorText("Recents  " ++ pixi.fa.clock);
            imgui.popStyleColor();
            imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_secondary.toImguiVec4());
            defer imgui.popStyleColor();
            if (imgui.beginChild("Recents", .{
                .x = imgui.getWindowWidth() - pixi.state.settings.explorer_grip * pixi.content_scale[0],
                .y = 0.0,
            }, imgui.ChildFlags_None, imgui.WindowFlags_HorizontalScrollbar)) {
                defer imgui.endChild();

                var i: usize = pixi.state.recents.folders.items.len;
                while (i > 0) {
                    i -= 1;
                    const folder = pixi.state.recents.folders.items[i];
                    const label = std.fmt.allocPrintZ(pixi.state.allocator, "{s} {s}##{s}", .{ pixi.fa.folder, std.fs.path.basename(folder), folder }) catch unreachable;
                    defer pixi.state.allocator.free(label);

                    if (imgui.selectable(label)) {
                        pixi.editor.setProjectFolder(folder);
                    }
                    imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0 * pixi.content_scale[0], .y = 2.0 * pixi.content_scale[1] });
                    imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0 * pixi.content_scale[0], .y = 6.0 * pixi.content_scale[1] });
                    imgui.pushStyleVar(imgui.StyleVar_IndentSpacing, 16.0 * pixi.content_scale[0]);
                    imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0 * pixi.content_scale[0], .y = 10.0 * pixi.content_scale[1] });
                    defer imgui.popStyleVarEx(4);
                    if (imgui.beginPopupContextItem()) {
                        defer imgui.endPopup();
                        if (imgui.menuItem("Remove")) {
                            const item = pixi.state.recents.folders.orderedRemove(i);
                            pixi.state.allocator.free(item);
                            pixi.state.recents.save() catch unreachable;
                        }
                    }

                    imgui.sameLineEx(0.0, 5.0 * pixi.content_scale[0]);
                    imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_background.toImguiVec4());
                    imgui.text(folder);
                    imgui.popStyleColor();
                }
            }
        }
    }
}

pub fn recurseFiles(allocator: std.mem.Allocator, root_directory: [:0]const u8) void {
    imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0 * pixi.content_scale[0], .y = 2.0 * pixi.content_scale[1] });
    imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0 * pixi.content_scale[0], .y = 6.0 * pixi.content_scale[1] });
    imgui.pushStyleVar(imgui.StyleVar_IndentSpacing, 16.0 * pixi.content_scale[0]);
    imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0 * pixi.content_scale[0], .y = 10.0 * pixi.content_scale[1] });
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
                        .pixi, .psd => pixi.fa.file_powerpoint,
                        .jpg, .png, .aseprite, .pyxel => pixi.fa.file_image,
                        .pdf => pixi.fa.file_pdf,
                        .json, .zig, .txt, .atlas => pixi.fa.file_code,
                        .tar, ._7z, .zip => pixi.fa.file_archive,
                        else => pixi.fa.file,
                    };

                    const icon_color = switch (ext) {
                        .pixi, .zig => pixi.state.theme.text_orange.toImguiVec4(),
                        .png, .psd => pixi.state.theme.text_blue.toImguiVec4(),
                        .jpg => pixi.state.theme.highlight_primary.toImguiVec4(),
                        .pdf => pixi.state.theme.text_red.toImguiVec4(),
                        .json, .atlas => pixi.state.theme.text_yellow.toImguiVec4(),
                        .txt, .zip, ._7z, .tar => pixi.state.theme.text_background.toImguiVec4(),
                        else => pixi.state.theme.text_background.toImguiVec4(),
                    };

                    const text_color = switch (ext) {
                        .pixi => pixi.state.theme.text.toImguiVec4(),
                        .jpg, .png, .json, .zig, .pdf, .aseprite, .pyxel, .psd, .tar, ._7z, .zip, .txt, .atlas => pixi.state.theme.text_secondary.toImguiVec4(),
                        else => pixi.state.theme.text_background.toImguiVec4(),
                    };

                    const icon_spaced = std.fmt.allocPrintZ(pixi.state.allocator, " {s} ", .{icon}) catch unreachable;
                    defer pixi.state.allocator.free(icon_spaced);

                    imgui.textColored(icon_color, icon_spaced);
                    imgui.sameLine();

                    const abs_path = std.fs.path.joinZ(alloc, &.{ directory, entry.name }) catch unreachable;
                    defer alloc.free(abs_path);

                    imgui.pushStyleColorImVec4(imgui.Col_Text, text_color);

                    const selectable_name = std.fmt.allocPrintZ(pixi.state.allocator, "{s}", .{entry.name}) catch unreachable;
                    defer pixi.state.allocator.free(selectable_name);

                    if (imgui.selectableEx(
                        selectable_name,
                        if (pixi.editor.getFileIndex(abs_path)) |_| true else false,
                        imgui.SelectableFlags_None,
                        .{ .x = 0.0, .y = 0.0 },
                    )) {
                        if (ext == .pixi)
                            _ = pixi.editor.openFile(abs_path) catch unreachable;
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
                    const folder = std.fmt.allocPrintZ(alloc, "{s}  {s}", .{ pixi.fa.folder, entry.name }) catch unreachable;
                    defer alloc.free(folder);
                    imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_secondary.toImguiVec4());
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
    imgui.pushStyleColorImVec4(imgui.Col_Separator, pixi.state.theme.foreground.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text.toImguiVec4());
    defer imgui.popStyleColorEx(2);
    if (imgui.menuItem("New File...")) {
        const new_file_path = std.fs.path.joinZ(pixi.state.allocator, &[_][]const u8{ folder, "New_file.pixi" }) catch unreachable;
        defer pixi.state.allocator.free(new_file_path);
        pixi.state.popups.fileSetupNew(new_file_path);
    }
    if (imgui.menuItem("New File from PNG...")) {
        pixi.state.popups.file_dialog_request = .{
            .state = .file,
            .type = .new_png,
            .filter = "png",
        };
    }

    if (pixi.state.popups.file_dialog_response) |response| {
        if (response.type == .new_png) {
            const new_file_path = std.fmt.allocPrintZ(pixi.state.allocator, "{s}.pixi", .{response.path[0 .. response.path.len - 4]}) catch unreachable;
            defer pixi.state.allocator.free(new_file_path);
            pixi.state.popups.fileSetupImportPng(new_file_path, response.path);

            nfd.freePath(response.path);
            pixi.state.popups.file_dialog_response = null;
        }
    }
    if (imgui.menuItem("New Folder...")) {
        std.log.debug("{s}", .{folder});
    }

    imgui.separator();
}

fn contextMenuFile(file: [:0]const u8) void {
    imgui.pushStyleColorImVec4(imgui.Col_Separator, pixi.state.theme.foreground.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text.toImguiVec4());

    const ext = extension(file);

    switch (ext) {
        .png => {
            if (imgui.menuItem("Import...")) {
                const new_file_path = std.fmt.allocPrintZ(pixi.state.allocator, "{s}.pixi", .{file[0 .. file.len - 4]}) catch unreachable;
                defer pixi.state.allocator.free(new_file_path);
                pixi.state.popups.fileSetupImportPng(new_file_path, file);
            }
        },
        .pixi => {
            if (imgui.menuItem("Re-slice...")) {
                pixi.state.popups.fileSetupSlice(file);
            }
        },
        else => {},
    }

    imgui.separator();

    if (imgui.menuItem("Rename...")) {
        pixi.state.popups.rename_path = [_:0]u8{0} ** std.fs.MAX_PATH_BYTES;
        pixi.state.popups.rename_old_path = [_:0]u8{0} ** std.fs.MAX_PATH_BYTES;
        @memcpy(pixi.state.popups.rename_path[0..], file);
        @memcpy(pixi.state.popups.rename_old_path[0..], file);
        pixi.state.popups.rename = true;
        pixi.state.popups.rename_state = .rename;
    }

    if (imgui.menuItem("Duplicate...")) {
        pixi.state.popups.rename_path = [_:0]u8{0} ** std.fs.MAX_PATH_BYTES;
        pixi.state.popups.rename_old_path = [_:0]u8{0} ** std.fs.MAX_PATH_BYTES;
        @memcpy(pixi.state.popups.rename_old_path[0..], file);

        const ex = std.fs.path.extension(file);

        if (std.mem.indexOf(u8, file, ex)) |ext_i| {
            const new_base_name = std.fmt.allocPrintZ(pixi.state.allocator, "{s}{s}{s}", .{ file[0..ext_i], "_copy", ex }) catch unreachable;
            defer pixi.state.allocator.free(new_base_name);
            @memcpy(pixi.state.popups.rename_path[0..], new_base_name);

            pixi.state.popups.rename = true;
            pixi.state.popups.rename_state = .duplicate;
        }
    }
    imgui.separator();
    imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_red.toImguiVec4());
    if (imgui.menuItem("Delete")) {
        std.fs.deleteFileAbsolute(file) catch unreachable;
        if (pixi.editor.getFileIndex(file)) |index| {
            pixi.editor.closeFile(index) catch unreachable;
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
