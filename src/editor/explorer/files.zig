const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("root");
const nfd = @import("nfd");
const zstbi = @import("zstbi");

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

pub var hover_timer: f32 = 0.0;

pub fn draw() void {
    if (pixi.state.project_folder) |path| {
        const folder = std.fs.path.basename(path);
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 2.0 * pixi.state.window.scale[0], 5.0 * pixi.state.window.scale[1] } });

        // Open files
        const file_count = pixi.state.open_files.items.len;
        if (file_count > 0) {
            if (zgui.collapsingHeader(zgui.formatZ("{s}  {s}", .{ pixi.fa.folder_open, "Open Files" }), .{
                .default_open = true,
            })) {
                zgui.separator();

                if (zgui.beginChild("OpenFiles", .{ .h = @intToFloat(f32, std.math.min(file_count + 1, 6)) * (zgui.getTextLineHeight() + 6.0 * pixi.state.window.scale[0]) })) {
                    zgui.spacing();

                    var hovered: bool = false;

                    for (pixi.state.open_files.items, 0..) |file, i| {
                        zgui.textColored(pixi.state.style.text_orange.toSlice(), " {s}  ", .{pixi.fa.file_powerpoint});
                        zgui.sameLine(.{});
                        const name = std.fs.path.basename(file.path);
                        const label = zgui.formatZ("{s}", .{name});
                        if (zgui.selectable(label, .{})) {
                            pixi.editor.setActiveFile(i);
                        }

                        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 2.0 * pixi.state.window.scale[0], 2.0 * pixi.state.window.scale[1] } });
                        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 4.0 * pixi.state.window.scale[0], 6.0 * pixi.state.window.scale[1] } });
                        zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.indent_spacing, .v = 16.0 * pixi.state.window.scale[0] });
                        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.window_padding, .v = .{ 10.0 * pixi.state.window.scale[0], 10.0 * pixi.state.window.scale[1] } });
                        zgui.pushStrId(file.path);
                        if (zgui.beginPopupContextItem()) {
                            contextMenuFile(file.path);
                            zgui.endPopup();
                        }
                        zgui.popId();
                        zgui.popStyleVar(.{ .count = 4 });

                        if (zgui.isItemHovered(.{})) {
                            hovered = true;
                            hover_timer += pixi.state.gctx.stats.delta_time;

                            if (hover_timer >= 1.0) {
                                if (zgui.beginTooltip()) {
                                    defer zgui.endTooltip();
                                    zgui.textColored(pixi.state.style.text_secondary.toSlice(), "{s}", .{file.path});
                                }
                            }
                        }
                    }

                    if (!hovered) hover_timer = 0.0;
                }
                defer zgui.endChild();
            }
        }

        // File tree
        var open: bool = true;
        if (zgui.collapsingHeaderStatePtr(zgui.formatZ("{s}  {s}", .{ pixi.fa.folder_open, folder }), .{
            .pvisible = &open,
            .flags = .{
                .default_open = true,
            },
        })) {
            zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 2.0 * pixi.state.window.scale[0], 2.0 * pixi.state.window.scale[1] } });
            zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 4.0 * pixi.state.window.scale[0], 6.0 * pixi.state.window.scale[1] } });
            zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.indent_spacing, .v = 16.0 * pixi.state.window.scale[0] });
            zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.window_padding, .v = .{ 10.0 * pixi.state.window.scale[0], 10.0 * pixi.state.window.scale[1] } });
            zgui.pushStrId(path);
            if (zgui.beginPopupContextItem()) {
                contextMenuFolder(path);
                zgui.endPopup();
            }
            zgui.popId();
            zgui.popStyleVar(.{ .count = 4 });

            zgui.separator();
            zgui.spacing();

            if (zgui.beginChild("FileTree", .{ .flags = .{
                .horizontal_scrollbar = true,
            } })) {
                zgui.spacing();
                // File Tree
                recurseFiles(pixi.state.allocator, path);
            }
            defer zgui.endChild();
        }
        zgui.popStyleVar(.{ .count = 1 });

        if (!open) {
            if (pixi.state.project_folder) |f| {
                pixi.state.allocator.free(f);
            }

            pixi.state.project_folder = null;
        }
    } else {
        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text_background.toSlice() });
        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button, .c = pixi.state.style.background.toSlice() });
        defer zgui.popStyleColor(.{ .count = 2 });

        zgui.textWrapped("Open a folder to begin editing.", .{});
    }
}

pub fn recurseFiles(allocator: std.mem.Allocator, root_directory: [:0]const u8) void {
    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 2.0 * pixi.state.window.scale[0], 2.0 * pixi.state.window.scale[1] } });
    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 4.0 * pixi.state.window.scale[0], 6.0 * pixi.state.window.scale[1] } });
    zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.indent_spacing, .v = 16.0 * pixi.state.window.scale[0] });
    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.window_padding, .v = .{ 10.0 * pixi.state.window.scale[0], 10.0 * pixi.state.window.scale[1] } });
    defer zgui.popStyleVar(.{ .count = 4 });

    const recursor = struct {
        fn search(alloc: std.mem.Allocator, directory: [:0]const u8) void {
            var dir = std.fs.cwd().openIterableDir(directory, .{ .access_sub_paths = true }) catch unreachable;
            defer dir.close();

            var iter = dir.iterate();
            while (iter.next() catch unreachable) |entry| {
                if (entry.kind == .File) {
                    zgui.indent(.{});
                    defer zgui.unindent(.{});
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
                        .pixi, .zig => pixi.state.style.text_orange.toSlice(),
                        .png, .psd => pixi.state.style.text_blue.toSlice(),
                        .jpg => pixi.state.style.highlight_primary.toSlice(),
                        .pdf => pixi.state.style.text_red.toSlice(),
                        .json, .atlas => pixi.state.style.text_yellow.toSlice(),
                        .txt, .zip, ._7z, .tar => pixi.state.style.text_background.toSlice(),
                        else => pixi.state.style.text_background.toSlice(),
                    };

                    const text_color = switch (ext) {
                        .pixi => pixi.state.style.text.toSlice(),
                        .jpg, .png, .json, .zig, .pdf, .aseprite, .pyxel, .psd, .tar, ._7z, .zip, .txt, .atlas => pixi.state.style.text_secondary.toSlice(),
                        else => pixi.state.style.text_background.toSlice(),
                    };

                    zgui.textColored(icon_color, " {s} ", .{icon});
                    zgui.sameLine(.{});

                    const abs_path = std.fs.path.joinZ(alloc, &.{ directory, entry.name }) catch unreachable;
                    defer alloc.free(abs_path);

                    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = text_color });
                    if (zgui.selectable(zgui.formatZ("{s}", .{entry.name}), .{
                        .selected = if (pixi.editor.getFileIndex(abs_path)) |_| true else false,
                    })) {
                        if (ext == .pixi)
                            _ = pixi.editor.openFile(alloc.dupeZ(u8, abs_path) catch unreachable) catch unreachable;
                    }
                    zgui.popStyleColor(.{ .count = 1 });

                    zgui.pushStrId(abs_path);
                    if (zgui.beginPopupContextItem()) {
                        contextMenuFile(abs_path);
                        zgui.endPopup();
                    }
                    zgui.popId();
                } else if (entry.kind == .Directory) {
                    const abs_path = std.fs.path.joinZ(alloc, &[_][]const u8{ directory, entry.name }) catch unreachable;
                    defer alloc.free(abs_path);
                    const folder = zgui.formatZ("{s}  {s}", .{ pixi.fa.folder, entry.name });
                    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text_secondary.toSlice() });
                    defer zgui.popStyleColor(.{ .count = 1 });

                    if (zgui.treeNode(folder)) {
                        zgui.pushStrId(abs_path);
                        if (zgui.beginPopupContextItem()) {
                            contextMenuFolder(abs_path);
                            zgui.endPopup();
                        }
                        zgui.popId();

                        search(alloc, abs_path);

                        zgui.treePop();
                    } else {
                        zgui.pushStrId(abs_path);
                        if (zgui.beginPopupContextItem()) {
                            contextMenuFolder(abs_path);
                            zgui.endPopup();
                        }
                        zgui.popId();
                    }
                }
            }
        }
    }.search;

    recursor(allocator, root_directory);

    return;
}

fn contextMenuFolder(folder: [:0]const u8) void {
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.separator, .c = pixi.state.style.foreground.toSlice() });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text.toSlice() });
    defer zgui.popStyleColor(.{ .count = 2 });
    if (zgui.menuItem("New File...", .{})) {
        const new_file_path = std.fs.path.joinZ(pixi.state.allocator, &[_][]const u8{ folder, "New_file.pixi" }) catch unreachable;
        defer pixi.state.allocator.free(new_file_path);
        pixi.state.popups.fileSetupNew(new_file_path);
    }
    if (zgui.menuItem("New File from PNG...", .{})) {
        const png_path = nfd.openFileDialog("png", null) catch unreachable;

        if (png_path) |path| {
            defer nfd.freePath(path);
            var new_file_path = std.fmt.allocPrintZ(pixi.state.allocator, "{s}.pixi", .{path[0 .. path.len - 4]}) catch unreachable;
            defer pixi.state.allocator.free(new_file_path);
            pixi.state.popups.fileSetupImportPng(new_file_path, path);
        }
    }
    if (zgui.menuItem("New Folder...", .{})) {
        std.log.debug("{s}", .{folder});
    }
}

fn contextMenuFile(file: [:0]const u8) void {
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.separator, .c = pixi.state.style.foreground.toSlice() });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text.toSlice() });

    const ext = extension(file);

    switch (ext) {
        .png => {
            if (zgui.menuItem("Import...", .{})) {
                var new_file_path = std.fmt.allocPrintZ(pixi.state.allocator, "{s}.pixi", .{file[0 .. file.len - 4]}) catch unreachable;
                defer pixi.state.allocator.free(new_file_path);
                pixi.state.popups.fileSetupImportPng(new_file_path, file);
            }
        },
        .pixi => {
            if (zgui.menuItem("Re-slice...", .{})) {
                pixi.state.popups.fileSetupSlice(file);
            }
        },
        else => {},
    }

    zgui.separator();

    if (zgui.menuItem("Rename...", .{})) {
        pixi.state.popups.rename_path = [_]u8{0} ** std.fs.MAX_PATH_BYTES;
        pixi.state.popups.rename_old_path = [_]u8{0} ** std.fs.MAX_PATH_BYTES;
        std.mem.copy(u8, pixi.state.popups.rename_path[0..], file);
        std.mem.copy(u8, pixi.state.popups.rename_old_path[0..], file);
        pixi.state.popups.rename = true;
    }

    if (zgui.menuItem("Duplicate...", .{})) {}
    zgui.separator();
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text_red.toSlice() });
    if (zgui.menuItem("Delete", .{})) {
        std.fs.deleteFileAbsolute(file) catch unreachable;
        if (pixi.editor.getFileIndex(file)) |index| {
            pixi.editor.closeFile(index) catch unreachable;
        }
    }
    zgui.popStyleColor(.{ .count = 3 });
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
