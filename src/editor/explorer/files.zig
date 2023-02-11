const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("pixi");
const nfd = @import("nfd");

pub var hover_timer: f32 = 0.0;

pub fn draw() void {
    if (pixi.state.project_folder) |path| {
        const folder = std.fs.path.basename(path);
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 2.0 * pixi.state.window.scale[0], 5.0 * pixi.state.window.scale[1] } });

        // Open files
        const file_count = pixi.state.open_files.items.len;
        if (file_count > 0) {
            if (zgui.collapsingHeader(zgui.formatZ(" {s}  {s}", .{ pixi.fa.folder_open, "Open Files" }), .{
                .default_open = true,
            })) {
                zgui.separator();

                if (zgui.beginChild("OpenFiles", .{ .h = @intToFloat(f32, std.math.min(file_count + 1, 6)) * (zgui.getTextLineHeight() + 6.0 * pixi.state.window.scale[0]) })) {
                    zgui.spacing();

                    var hovered: bool = false;

                    for (pixi.state.open_files.items) |file, i| {
                        zgui.textColored(pixi.state.style.text_orange.toSlice(), " {s}  ", .{pixi.fa.file_powerpoint});
                        zgui.sameLine(.{});
                        const name = std.fs.path.basename(file.path);
                        const label = zgui.formatZ("{s}", .{name});
                        if (zgui.selectable(label, .{})) {
                            pixi.editor.setActiveFile(i);
                        }
                        if (zgui.isItemHovered(.{})) {
                            hovered = true;
                            hover_timer += pixi.state.gctx.stats.delta_time;

                            if (hover_timer >= 1.0) {
                                zgui.beginTooltip();
                                defer zgui.endTooltip();
                                zgui.textColored(pixi.state.style.text_secondary.toSlice(), "{s}", .{file.path});
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
        if (zgui.collapsingHeaderStatePtr(zgui.formatZ(" {s}  {s}", .{ pixi.fa.folder_open, folder }), .{
            .pvisible = &open,
            .flags = .{
                .default_open = true,
            },
        })) {
            zgui.pushStrId(path);
            if (zgui.beginPopupContextWindow()) {
                contextMenuFolder(path);
                zgui.endPopup();
            }
            zgui.popId();

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
            pixi.state.project_folder = null;
        }
    } else {
        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text_secondary.toSlice() });
        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button, .c = pixi.state.style.background.toSlice() });
        defer zgui.popStyleColor(.{ .count = 2 });
        if (zgui.button("Select a folder", .{
            .w = -1,
        })) {
            const folder = nfd.openFolderDialog(null) catch unreachable;
            if (folder) |path| {
                pixi.editor.setProjectFolder(path);
            }
        }
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
                    const ext = std.fs.path.extension(entry.name);

                    if (std.mem.eql(u8, ext, ".pixi")) {
                        zgui.textColored(pixi.state.style.text_orange.toSlice(), " {s}  ", .{pixi.fa.file_powerpoint});
                        zgui.sameLine(.{});
                        const abs_path = std.fs.path.joinZ(alloc, &.{ directory, entry.name }) catch unreachable;
                        defer alloc.free(abs_path);

                        if (zgui.selectable(zgui.formatZ("{s}", .{entry.name}), .{
                            .selected = if (pixi.editor.getFileIndex(abs_path)) |_| true else false,
                        })) {
                            _ = pixi.editor.openFile(alloc.dupeZ(u8, abs_path) catch unreachable) catch unreachable;
                        }
                        zgui.pushStrId(abs_path);
                        if (zgui.beginPopupContextItem()) {
                            contextMenuFile(abs_path);
                            zgui.endPopup();
                        }
                        zgui.popId();
                    }
                } else if (entry.kind == .Directory) {
                    const abs_path = std.fs.path.joinZ(alloc, &[_][]const u8{ directory, entry.name }) catch unreachable;
                    defer alloc.free(abs_path);
                    const folder = zgui.formatZ(" {s}  {s}", .{ pixi.fa.folder, entry.name });
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
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text.toSlice() });
    if (zgui.menuItem("New File...", .{})) {
        std.log.debug("{s}", .{folder});
    }
    if (zgui.menuItem("New File from PNG...", .{})) {
        _ = pixi.editor.importPng("Users/foxnne/dev/proj/test_file.png") catch unreachable;
    }
    if (zgui.menuItem("New Folder...", .{})) {
        std.log.debug("{s}", .{folder});
    }
    zgui.popStyleColor(.{ .count = 1 });
}

fn contextMenuFile(file: [:0]const u8) void {
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text.toSlice() });
    if (zgui.menuItem("Rename...", .{})) {
        pixi.state.popups.rename = true;
    }

    if (zgui.menuItem("Duplicate...", .{})) {
        std.log.debug("{s}", .{file});
    }
    zgui.popStyleColor(.{ .count = 1 });
}
