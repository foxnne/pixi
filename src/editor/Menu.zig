const std = @import("std");
const pixi = @import("../pixi.zig");
const dvui = @import("dvui");
const Editor = pixi.Editor;
const settings = pixi.settings;
const zstbi = @import("zstbi");
const builtin = @import("builtin");
const icons = @import("icons");

pub var mouse_distance: f32 = std.math.floatMax(f32);

pub fn draw() !dvui.App.Result {
    var m = dvui.menu(@src(), .horizontal, .{});
    defer m.deinit();

    const current_highlight_style = dvui.themeGet().highlight;
    var theme = dvui.themeGet();
    theme.highlight.fill = theme.color(.control, .fill_hover);
    dvui.themeSet(theme);
    defer {
        theme.highlight = current_highlight_style;
        dvui.themeSet(theme);
    }

    if (menuItem(@src(), "File", .{ .submenu = true }, .{
        .expand = .horizontal,
        //.color_accent = dvui.themeGet().color(.window, .fill),

    })) |r| {
        var animator = dvui.animate(@src(), .{
            .kind = .alpha,
            .duration = 250_000,
        }, .{
            .expand = .both,
        });
        defer animator.deinit();

        var fw = dvui.floatingMenu(@src(), .{ .from = r }, .{});
        defer fw.deinit();

        if (menuItemWithHotkey(@src(), "Open Folder", dvui.currentWindow().keybinds.get("open_folder") orelse .{}, .{}, .{
            .expand = .horizontal,
            //.style = .control,
        }) != null) {
            if (try dvui.dialogNativeFolderSelect(dvui.currentWindow().arena(), .{ .title = "Open Project Folder" })) |folder| {
                try pixi.editor.setProjectFolder(folder);
            }
        }

        if (menuItemWithHotkey(@src(), "Open Files", dvui.currentWindow().keybinds.get("open_files") orelse .{}, .{}, .{
            .expand = .horizontal,
            //.style = .control,
        }) != null) {
            if (try dvui.dialogNativeFileOpenMultiple(dvui.currentWindow().arena(), .{
                .title = "Open Files...",
                .filter_description = ".pixi, .png",
                .filters = &.{ "*.pixi", "*.png" },
            })) |files| {
                for (files) |file| {
                    _ = pixi.editor.openFilePath(file, pixi.editor.open_artboard_grouping) catch {
                        std.log.err("Failed to open file: {s}", .{file});
                    };
                }
            }
        }
    }

    if (menuItem(@src(), "View", .{ .submenu = true }, .{
        .expand = .horizontal,
    })) |r| {
        var animator = dvui.animate(@src(), .{
            .kind = .alpha,
            .duration = 250_000,
        }, .{
            .expand = .both,
        });
        defer animator.deinit();

        var fw = dvui.floatingMenu(@src(), .{ .from = r }, .{});
        defer fw.deinit();

        if (menuItem(
            @src(),
            if (pixi.editor.explorer.paned.split_ratio.* == 0.0) "Expand Explorer" else "Collapse Explorer",
            .{},
            .{
                .expand = .horizontal,
                .color_accent = dvui.themeGet().color(.window, .fill),
            },
        ) != null) {
            if (pixi.editor.explorer.paned.split_ratio.* == 0.0) {
                pixi.editor.explorer.open();
            } else {
                pixi.editor.explorer.close();
            }

            fw.close();
        }

        _ = dvui.separator(@src(), .{ .expand = .horizontal });

        if (menuItem(@src(), "Show DVUI Demo", .{}, .{ .expand = .horizontal, .color_accent = dvui.themeGet().color(.window, .fill) }) != null) {
            dvui.Examples.show_demo_window = !dvui.Examples.show_demo_window;
            fw.close();
        }
    }

    if (menuItem(
        @src(),
        "Edit",
        .{ .submenu = true },
        .{
            .expand = .horizontal,
            //.style = .control,
        },
    )) |r| {
        var animator = dvui.animate(@src(), .{
            .kind = .alpha,
            .duration = 250_000,
        }, .{
            .expand = .both,
        });
        defer animator.deinit();

        var fw = dvui.floatingMenu(@src(), .{ .from = r }, .{});
        defer fw.deinit();

        if (menuItemWithHotkey(@src(), "Undo", dvui.currentWindow().keybinds.get("undo") orelse .{}, .{}, .{
            .expand = .horizontal,
            //.style = .control,
        }) != null) {
            if (pixi.editor.activeFile()) |file| {
                file.history.undoRedo(file, .undo) catch {
                    std.log.err("Failed to undo", .{});
                };
            }
        }

        if (menuItemWithHotkey(@src(), "Redo", dvui.currentWindow().keybinds.get("redo") orelse .{}, .{}, .{
            .expand = .horizontal,
            //.style = .control,
        }) != null) {
            if (pixi.editor.activeFile()) |file| {
                file.history.undoRedo(file, .redo) catch {
                    std.log.err("Failed to redo", .{});
                };
            }
        }
    }

    return .ok;
}

pub fn menuItemWithHotkey(src: std.builtin.SourceLocation, label_str: []const u8, hotkey: dvui.enums.Keybind, init_opts: dvui.MenuItemWidget.InitOptions, opts: dvui.Options) ?dvui.Rect.Natural {
    var mi = dvui.menuItem(src, init_opts, opts);

    var ret: ?dvui.Rect.Natural = null;
    if (mi.activeRect()) |r| {
        ret = r;
    }

    pixi.dvui.labelWithKeybind(label_str, hotkey, opts);

    mi.deinit();

    return ret;
}

pub fn menuItem(src: std.builtin.SourceLocation, label_str: []const u8, init_opts: dvui.MenuItemWidget.InitOptions, opts: dvui.Options) ?dvui.Rect.Natural {
    var mi = dvui.menuItem(src, init_opts, opts);

    var ret: ?dvui.Rect.Natural = null;
    if (mi.activeRect()) |r| {
        ret = r;
    }

    dvui.labelNoFmt(@src(), label_str, .{}, opts.strip());

    mi.deinit();

    return ret;
}
