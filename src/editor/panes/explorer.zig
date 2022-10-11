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
        .h = pixi.state.window.size[1] * pixi.state.window.scale[1] + 5.0,
    });

    if (zgui.begin("Explorer", .{
        .flags = .{
            .no_title_bar = true,
            .no_resize = true,
            .no_move = true,
            .no_collapse = true,
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
                    // var dir = std.fs.cwd().openDir(path, .{ .access_sub_paths = true }) catch unreachable;
                    // defer dir.close();
                    recurseFiles(pixi.state.allocator, path);
                    // for (files) |file| {
                    //     zgui.text("{s}", .{file});
                    //     pixi.state.allocator.free(file);
                    // }
                    // pixi.state.allocator.free(files);

                }
            },
            .tools => {},
        }
    }

    zgui.end();
}

pub fn recurseFiles(allocator: std.mem.Allocator, root_directory: [:0]const u8) void {
    //var list = std.ArrayList([:0]const u8).init(allocator);

    const recursor = struct {
        fn search(alloc: std.mem.Allocator, directory: []const u8) void {
            var dir = std.fs.cwd().openIterableDir(directory, .{ .access_sub_paths = true }) catch unreachable;
            defer dir.close();

            var iter = dir.iterate();
            while (iter.next() catch unreachable) |entry| {
                if (entry.kind == .File) {
                    if (zgui.selectable(zgui.formatZ("{s}", .{entry.name}), .{})) {}
                    //const name_null_term = std.mem.concat(alloc, u8, &[_][]const u8{ entry.name, "\x00" }) catch unreachable;
                    //const abs_path = std.fs.path.join(alloc, &[_][]const u8{ directory, name }) catch unreachable;
                    //filelist.append(abs_path[0 .. abs_path.len - 1 :0]) catch unreachable;
                } else if (entry.kind == .Directory) {
                    const name = entry.name[0..];
                    const abs_path = std.fs.path.join(alloc, &[_][]const u8{ directory, name }) catch unreachable;
                    const folder = zgui.formatZ("{s}", .{name});
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
    //return list.toOwnedSlice();
}
