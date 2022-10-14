const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("pixi");
const settings = pixi.settings;
const nfd = @import("nfd");

pub fn draw() void {
    zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.window_rounding, .v = 0.0 });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.window_bg, .c = pixi.state.style.foreground.toSlice() });
    defer zgui.popStyleVar(.{ .count = 1 });
    defer zgui.popStyleColor(.{ .count = 1 });
    zgui.setNextWindowPos(.{
        .x = settings.sidebar_width * pixi.state.window.scale[0],
        .y = 0,
        .cond = .always,
    });
    zgui.setNextWindowSize(.{
        .w = settings.explorer_width * pixi.state.window.scale[0],
        .h = pixi.state.window.size[1] * pixi.state.window.scale[1],
    });

    if (zgui.begin("Explorer", .{
        .flags = .{
            .no_title_bar = true,
            .no_resize = true,
            .no_move = true,
            .no_collapse = true,
            .horizontal_scrollbar = true,
            .menu_bar = true,
        },
    })) {
        switch (pixi.state.sidebar) {
            .files => {
                if (pixi.state.project_folder) |path| {
                    // Header
                    const folder = std.fs.path.basename(path);
                    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 0.0, 10.0 * pixi.state.window.scale[1] } });
                    if (zgui.beginMenuBar()) {
                        zgui.popStyleVar(.{ .count = 1 });
                        zgui.text("  {s}  {s}", .{ pixi.fa.folder, folder });
                        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text_secondary.toSlice() });
                        defer zgui.popStyleColor(.{ .count = 1 });
                        zgui.dummy(.{ .w = 24.0 * pixi.state.window.scale[0], .h = settings.zgui_font_size * pixi.state.window.scale[1] });
                        if (zgui.beginMenu(pixi.fa.ellipsis_h, true)) {
                            if (zgui.menuItem("Close folder", .{})) {
                                pixi.state.project_folder = null;
                            }
                            zgui.endMenu();
                        }
                        zgui.endMenuBar();
                    }
                    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.separator, .c = pixi.state.style.background.toSlice() });
                    zgui.separator();
                    zgui.spacing();
                    zgui.popStyleColor(.{ .count = 1 });

                    // Open Files

                    // File Tree
                    recurseFiles(pixi.state.allocator, path);
                } else {
                    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 0.0, 8.0 * pixi.state.window.scale[1] } });
                    defer zgui.popStyleVar(.{ .count = 1 });
                    if (zgui.beginMenuBar()) {
                        zgui.text("Explorer", .{});
                        zgui.endMenuBar();
                    }
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
            },
            .tools => {},
        }
    }

    zgui.end();
}

pub fn recurseFiles(allocator: std.mem.Allocator, root_directory: [:0]const u8) void {
    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 2.0 * pixi.state.window.scale[0], 2.0 * pixi.state.window.scale[1] } });
    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 4.0 * pixi.state.window.scale[0], 6.0 * pixi.state.window.scale[1] } });
    zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.indent_spacing, .v = 16.0 * pixi.state.window.scale[0] });
    defer zgui.popStyleVar(.{ .count = 3 });

    const recursor = struct {
        fn search(alloc: std.mem.Allocator, directory: []const u8) void {
            var dir = std.fs.cwd().openIterableDir(directory, .{ .access_sub_paths = true }) catch unreachable;
            defer dir.close();

            var iter = dir.iterate();
            while (iter.next() catch unreachable) |entry| {
                if (entry.kind == .File) {
                    const ext = std.fs.path.extension(entry.name);

                    if (std.mem.eql(u8, ext, ".pixi")) {
                        zgui.textColored(pixi.state.style.text_orange.toSlice(), " {s}  ", .{pixi.fa.file_powerpoint});
                        zgui.sameLine(.{});
                        if (zgui.selectable(zgui.formatZ("{s}", .{entry.name}), .{})) {}
                    }
                } else if (entry.kind == .Directory) {
                    const abs_path = std.fs.path.join(alloc, &[_][]const u8{ directory, entry.name }) catch unreachable;
                    const folder = zgui.formatZ(" {s}  {s}", .{ pixi.fa.folder, entry.name });
                    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text_secondary.toSlice() });
                    defer zgui.popStyleColor(.{ .count = 1 });
                    if (zgui.treeNode(folder)) {
                        search(alloc, abs_path);
                        zgui.treePop();
                    }

                    alloc.free(abs_path);
                }
            }
        }
    }.search;

    recursor(allocator, root_directory);

    return;
}
