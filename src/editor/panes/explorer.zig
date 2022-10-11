const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("pixi");
const settings = pixi.settings;

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
        },
    })) {
        switch (pixi.state.sidebar) {
            .files => {
                if (pixi.state.project_folder) |path| {
                    // Header
                    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.separator, .c = pixi.state.style.background.toSlice() });
                    defer zgui.popStyleColor(.{ .count = 1 });
                    const folder = std.fs.path.basename(path);
                    zgui.text("{s}", .{folder});
                    zgui.separator();

                    // Open Files

                    // File Tree
                    recurseFiles(pixi.state.allocator, path);
                }
            },
            .tools => {},
        }
    }

    zgui.end();
}

pub fn recurseFiles(allocator: std.mem.Allocator, root_directory: [:0]const u8) void {
    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 4.0, 4.0 } });
    zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.indent_spacing, .v = 32.0 });
    defer zgui.popStyleVar(.{ .count = 2 });

    const recursor = struct {
        fn search(alloc: std.mem.Allocator, directory: []const u8) void {
            var dir = std.fs.cwd().openIterableDir(directory, .{ .access_sub_paths = true }) catch unreachable;
            defer dir.close();

            var iter = dir.iterate();
            while (iter.next() catch unreachable) |entry| {
                if (entry.kind == .File) {
                    const ext = std.fs.path.extension(entry.name);

                    if (std.mem.eql(u8, ext, ".pixi")) {
                        if (zgui.selectable(zgui.formatZ("{s}", .{entry.name}), .{})) {
                            std.log.debug("{s}", .{entry.name});
                        }
                    }
                } else if (entry.kind == .Directory) {
                    const abs_path = std.fs.path.join(alloc, &[_][]const u8{ directory, entry.name }) catch unreachable;
                    const folder = zgui.formatZ("{s}", .{entry.name});
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
