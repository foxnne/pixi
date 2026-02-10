const std = @import("std");
const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");
const Editor = pixi.Editor;

const icons = @import("icons");

const nfd = @import("nfd");
const zstbi = @import("zstbi");

pub var tree_removed_path: ?[]const u8 = null;
pub var selected_id: ?usize = null;
pub var edit_id: ?usize = null;

// These two are currently set from a dialog callafter function
// If close_rect is not null, the dialog will animate into that rect then close
pub var new_file_path: ?[]const u8 = null;
pub var new_file_close_rect: ?dvui.Rect.Physical = null;

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
    gif,
};

pub fn draw() !void {
    var tree = pixi.dvui.TreeWidget.tree(@src(), .{ .enable_reordering = true }, .{ .background = false, .expand = .both });
    defer tree.deinit();

    if (pixi.editor.folder) |path| {
        try drawFiles(path, tree);
    } else {
        dvui.labelNoFmt(
            @src(),
            "Open a project folder to begin.",
            .{},
            .{ .color_text = dvui.themeGet().color(.control, .text) },
        );

        if (dvui.button(@src(), "Open Folder", .{ .draw_focus = false }, .{ .expand = .horizontal, .style = .highlight })) {
            if (try dvui.dialogNativeFolderSelect(dvui.currentWindow().arena(), .{ .title = "Open Project Folder" })) |folder| {
                try pixi.editor.setProjectFolder(folder);
            }
        }
    }
}

pub fn drawFiles(path: []const u8, tree: *pixi.dvui.TreeWidget) !void {
    const unique_id = dvui.parentGet().extendId(@src(), 0);

    var filter_hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
    dvui.icon(
        @src(),
        "FilterIcon",
        icons.tvg.lucide.search,
        .{ .stroke_color = dvui.themeGet().color(.window, .text) },
        .{ .gravity_y = 0.5, .padding = dvui.Rect.all(0) },
    );
    const filter_text_edit = dvui.textEntry(@src(), .{ .placeholder = "Filter..." }, .{ .expand = .horizontal });
    const filter_text = filter_text_edit.getText();
    filter_text_edit.deinit();
    filter_hbox.deinit();

    const folder = std.fs.path.basename(path);

    const branch = tree.branch(@src(), .{
        .expanded = true,
        .animation_duration = 450_000,
        .animation_easing = dvui.easing.outBack,
    }, .{
        .id_extra = 0,
        .expand = .horizontal,
        .color_fill = dvui.themeGet().color(.control, .fill),
    });
    defer branch.deinit();

    if (new_file_path) |focus_path| {
        if (std.mem.eql(u8, focus_path, folder)) {
            new_file_close_rect = branch.button.data().borderRectScale().r;
        }
    }

    { // Add right click context menu for item options
        var context = dvui.context(@src(), .{ .rect = branch.button.data().borderRectScale().r }, .{});
        defer context.deinit();

        if (context.activePoint()) |point| {
            var fw2 = dvui.floatingMenu(@src(), .{ .from = dvui.Rect.Natural.fromPoint(point) }, .{ .box_shadow = .{
                .color = .black,
                .offset = .{ .x = 0, .y = 0 },
                .shrink = 0,
                .fade = 10,
                .alpha = 0.15,
            } });
            defer fw2.deinit();

            if ((dvui.menuItemLabel(@src(), "Close", .{}, .{
                .expand = .horizontal,
            })) != null) {
                if (pixi.editor.folder) |f| {
                    pixi.app.allocator.free(f);
                    pixi.editor.folder = null;
                }

                fw2.close();
            }
        }
    }

    if (branch.button.clicked()) {
        selected_id = null;
        //close_rect = branch.button.data().borderRectScale().r;
    }

    const color = dvui.themeGet().color(.control, .fill_hover);

    _ = dvui.icon(
        @src(),
        "FolderIcon",
        if (branch.expanded) icons.tvg.entypo.@"down-open" else icons.tvg.entypo.@"right-open",
        .{ .fill_color = color },
        .{ .gravity_y = 0.5, .padding = dvui.Rect.all(0) },
    );

    var fmt_string = std.fmt.allocPrint(dvui.currentWindow().lifo(), comptime "{s}", .{folder}) catch unreachable;
    defer dvui.currentWindow().lifo().free(fmt_string);

    for (fmt_string, 0..) |c, i| {
        fmt_string[i] = std.ascii.toUpper(c);
    }

    dvui.labelNoFmt(@src(), fmt_string, .{}, .{
        .color_fill = color,
        .font = dvui.Font.theme(.title).larger(-3.0).withWeight(.bold),
        .gravity_y = 0.5,
    });

    if (branch.expander(@src(), .{ .indent = 24 }, .{
        .color_fill = dvui.themeGet().color(.control, .fill),
        .corner_radius = .all(8),
        .expand = .both,
        .margin = .{ .x = 10, .w = 5 },
        .background = true,
    })) {
        var box = dvui.box(@src(), .{
            .dir = .vertical,
        }, .{
            .expand = .horizontal,
            .background = false,
            .gravity_y = 0.2,
        });
        defer box.deinit();

        try recurseFiles(path, tree, unique_id, filter_text);
    }
}

fn lessThan(_: void, lhs: std.fs.Dir.Entry, rhs: std.fs.Dir.Entry) bool {
    if (lhs.kind == .directory and rhs.kind == .file) return true;
    if (lhs.kind == .file and rhs.kind == .directory) return false;

    return std.mem.order(u8, lhs.name, rhs.name) == .lt;
}

pub fn editableLabel(id_extra: usize, label: []const u8, color: dvui.Color, kind: std.fs.Dir.Entry.Kind, full_path: []const u8) !void {
    const padding = dvui.Rect.all(2);

    const selected: bool = if (selected_id) |id| id_extra == id else false;
    const editing: bool = if (edit_id) |id| id_extra == id else false;

    if (editing) {
        var te = dvui.textEntry(@src(), .{}, .{
            .expand = .horizontal,
            .background = false,
            .padding = dvui.Rect.all(0),
            .margin = dvui.Rect.all(0),
            .color_text = dvui.themeGet().color(.window, .text),
            .gravity_y = 0.5,
            .id_extra = id_extra,
        });
        defer te.deinit();

        // Text edit should handle any click events, so if we find one unhandled after the text edit
        // we can assume the mouse was clicked anywhere else and that the edit needs to be confirmed.
        for (dvui.events()) |*event| {
            switch (event.evt) {
                .mouse => |mouse| {
                    if (mouse.action == .press and selected and editing and !event.handled) {
                        selected_id = null;
                        edit_id = null;
                    }
                },
                else => {},
            }
        }

        if (dvui.firstFrame(te.data().id)) {
            te.textSet(label, true);

            if (std.mem.indexOf(u8, label, ".")) |idx| {
                if (idx == 0) {
                    te.textLayout.selection.moveCursor(1, false);
                    te.textLayout.selection.moveCursor(label.len - 1, true);
                } else {
                    te.textLayout.selection.moveCursor(0, false);
                    te.textLayout.selection.moveCursor(idx, true);
                }
            }

            dvui.focusWidget(te.data().id, null, null);
        }

        if (te.enter_pressed or !selected) {
            const parent_folder = std.fs.path.dirname(full_path);
            var new_path: []const u8 = undefined;

            defer edit_id = null;

            const valid_path = blk: {
                std.fs.accessAbsolute(full_path, .{}) catch {
                    break :blk false;
                };

                break :blk true;
            };

            if (parent_folder) |folder| {
                new_path = try std.fs.path.join(dvui.currentWindow().arena(), &.{ folder, te.getText() });
            } else {
                new_path = try std.fs.path.join(dvui.currentWindow().arena(), &.{te.getText()});
            }

            if (!std.mem.eql(u8, label, te.getText()) and te.getText().len > 0 and valid_path) {
                switch (kind) {
                    .directory => {
                        std.fs.renameAbsolute(full_path, new_path) catch dvui.log.err("Failed to rename folder: {s} to {s}", .{ label, te.getText() });

                        for (pixi.editor.open_files.values()) |*file| {
                            if (std.mem.containsAtLeast(u8, file.path, 1, full_path)) {
                                const file_name = dvui.currentWindow().arena().dupe(u8, std.fs.path.basename(file.path)) catch "Failed to duplicate path";
                                pixi.app.allocator.free(file.path);
                                file.path = try std.fs.path.join(pixi.app.allocator, &.{ new_path, file_name });
                            }
                        }
                    },
                    .file => {
                        std.fs.renameAbsolute(full_path, new_path) catch dvui.log.err("Failed to rename file: {s} to {s}", .{ label, te.getText() });

                        if (pixi.editor.getFileFromPath(full_path)) |file| {
                            pixi.app.allocator.free(file.path);
                            file.path = pixi.app.allocator.dupe(u8, new_path) catch {
                                dvui.log.err("Failed to duplicate path: {s}", .{new_path});
                                return error.FailedToDuplicatePath;
                            };
                        }
                    },
                    else => {},
                }
            }
        }
    } else if (selected) {
        if (dvui.labelClick(@src(), "{s}", .{label}, .{}, .{
            .gravity_y = 0.5,
            //.margin = dvui.Rect.all(2),
            .padding = padding,
            .id_extra = id_extra,
            .color_text = color,
        })) {
            edit_id = id_extra;
        }
    } else {
        dvui.label(@src(), "{s}", .{label}, .{
            .color_text = color,
            .padding = padding,
            .id_extra = id_extra,
        });
    }
}

pub fn recurseFiles(root_directory: []const u8, outer_tree: *pixi.dvui.TreeWidget, unique_id: dvui.Id, outer_filter_text: []const u8) !void {
    var color_i: usize = 0;
    var id_extra: usize = 0;

    const recursor = struct {
        fn search(directory: []const u8, tree: *pixi.dvui.TreeWidget, inner_unique_id: dvui.Id, inner_id_extra: *usize, color_id: *usize, filter_text: []const u8, parent_branch: ?*pixi.dvui.TreeWidget.Branch) !void {
            var dir = std.fs.cwd().openDir(directory, .{ .access_sub_paths = true, .iterate = true }) catch return;
            defer dir.close();

            // Collect all files/folders in the directory and sort them alphabetically
            var files = std.array_list.Managed(std.fs.Dir.Entry).init(dvui.currentWindow().arena());

            var iter = dir.iterate();
            while (try iter.next()) |entry| {
                try files.append(.{
                    .name = dvui.currentWindow().arena().dupe(u8, entry.name) catch "Arena failed to allocate",
                    .kind = entry.kind,
                });
            }

            std.mem.sort(
                std.fs.Dir.Entry,
                files.items,
                {},
                lessThan,
            );

            for (files.items) |entry| {
                const abs_path = try std.fs.path.join(
                    dvui.currentWindow().arena(),
                    &.{ directory, entry.name },
                );

                if (entry.kind == .file) {
                    if (std.ascii.indexOfIgnoreCase(entry.name, filter_text) == null) {
                        continue;
                    }
                } else if (filter_text.len > 0) {
                    search(abs_path, tree, inner_unique_id, inner_id_extra, color_id, filter_text, null) catch continue;
                    continue;
                }

                inner_id_extra.* = dvui.Id.update(tree.data().id, abs_path).asUsize();

                var color = dvui.themeGet().color(.control, .fill);
                if (pixi.editor.colors.palette) |*palette| {
                    color = palette.getDVUIColor(color_id.*);
                }

                const padding = dvui.Rect.all(2);

                const selected: bool = if (selected_id) |id| inner_id_extra.* == id else false;
                const editing: bool = if (edit_id) |id| inner_id_extra.* == id else false;

                const branch_id = tree.data().id.update(abs_path);

                var expanded = false;
                const expanded_indent: f32 = 14.0;

                if (pixi.editor.explorer.open_branches.get(branch_id) != null) {
                    expanded = true;
                }

                // Make sure we open any parent paths of the new file close path
                if (new_file_path) |path| {
                    if (std.fs.path.dirname(path)) |d| {
                        if (std.mem.containsAtLeast(u8, d, 1, abs_path)) {
                            expanded = true;
                        }
                    }
                }

                const branch = tree.branch(@src(), .{
                    .expanded = expanded,
                    .animation_duration = 450_000,
                    .animation_easing = dvui.easing.outBack,
                    .process_events = !editing,
                }, .{
                    .id_extra = inner_id_extra.*,
                    .expand = .horizontal,
                    //.color_fill_hover = .fill,
                    .color_fill = if (selected) dvui.themeGet().color(.window, .fill) else dvui.themeGet().color(.control, .fill),
                    .padding = dvui.Rect.all(1),
                });
                defer branch.deinit();

                if (new_file_path) |path| {
                    if (std.mem.eql(u8, path, abs_path)) {
                        if (!dvui.firstFrame(branch.data().id)) {
                            if ((parent_branch != null and !parent_branch.?.expanding()) or branch.button.data().rect.h > 10.0) {
                                edit_id = inner_id_extra.*;
                                selected_id = inner_id_extra.*;
                                var close_rect = branch.button.data().borderRectScale().r;
                                close_rect.h = @max(10.0, close_rect.h);
                                new_file_close_rect = close_rect;
                                new_file_path = null;
                            }
                        }
                    }
                }

                const current_point = dvui.currentWindow().mouse_pt;

                const max_distance = if (!expanded) branch.data().borderRectScale().r.h * 3.0 else branch.data().borderRectScale().r.w / 8.0;

                var dx: f32 = std.math.floatMax(f32);

                if (current_point.x < branch.data().borderRectScale().r.x + if (expanded) (expanded_indent * dvui.currentWindow().natural_scale) else 0.0) {
                    dx = std.math.floatMax(f32);
                } else if (current_point.x > branch.data().borderRectScale().r.bottomRight().x) {
                    dx = @abs(current_point.x - branch.data().borderRectScale().r.bottomRight().x);
                } else {
                    dx = 0.0;
                }

                var dy: f32 = std.math.floatMax(f32);

                if (current_point.y < branch.data().borderRectScale().r.y) {
                    dy = @abs(current_point.y - branch.data().borderRectScale().r.y);
                } else if (current_point.y > branch.data().borderRectScale().r.bottomRight().y) {
                    dy = @abs(current_point.y - branch.data().borderRectScale().r.bottomRight().y);
                } else {
                    dy = 0.0;
                }

                const distance = @sqrt(dx * dx + dy * dy);

                const t = 1.0 - (distance / max_distance);

                color = dvui.themeGet().color(.control, .fill_hover).lerp(color, t);

                if (branch.floating()) {
                    if (dvui.dataGetSlice(null, inner_unique_id, "removed_path", []u8) == null)
                        dvui.dataSetSlice(null, inner_unique_id, "removed_path", abs_path);
                }

                if (branch.insertBefore()) {
                    if (dvui.dataGetSlice(null, inner_unique_id, "removed_path", []u8)) |removed_path| {
                        const old_sub_path = std.fs.path.basename(removed_path);

                        const new_path = try std.fs.path.join(dvui.currentWindow().arena(), &.{ if (entry.kind == .directory) abs_path else directory, old_sub_path });

                        if (!std.mem.eql(u8, removed_path, new_path)) {
                            std.fs.renameAbsolute(removed_path, new_path) catch dvui.log.err("Failed to move {s} to {s}", .{ removed_path, new_path });

                            if (pixi.editor.getFileFromPath(removed_path)) |file| {
                                pixi.app.allocator.free(file.path);
                                file.path = pixi.app.allocator.dupe(u8, new_path) catch {
                                    dvui.log.err("Failed to duplicate path: {s}", .{new_path});
                                    return error.FailedToDuplicatePath;
                                };
                            }
                        }

                        dvui.dataRemove(null, inner_unique_id, "removed_path");
                    }
                }

                { // Add right click context menu for item options
                    var context = dvui.context(@src(), .{ .rect = branch.button.data().borderRectScale().r }, .{ .id_extra = inner_id_extra.* });
                    defer context.deinit();

                    if (context.activePoint()) |point| {
                        var fw2 = dvui.floatingMenu(@src(), .{ .from = dvui.Rect.Natural.fromPoint(point) }, .{ .box_shadow = .{
                            .color = .black,
                            .offset = .{ .x = 0, .y = 0 },
                            .shrink = 0,
                            .fade = 10,
                            .alpha = 0.15,
                        } });
                        defer fw2.deinit();

                        selected_id = inner_id_extra.*;

                        if (entry.kind == .file) {
                            if ((dvui.menuItemLabel(@src(), "Open", .{}, .{
                                .expand = .horizontal,
                            })) != null) {
                                _ = pixi.editor.openFilePath(abs_path, pixi.editor.currentGroupingID()) catch |err| {
                                    dvui.log.err("Failed to open file: {any}", .{err});
                                };

                                fw2.close();
                            }

                            if ((dvui.menuItemLabel(@src(), "Open to the side", .{}, .{
                                .expand = .horizontal,
                            })) != null) {
                                _ = pixi.editor.openFilePath(abs_path, if (pixi.editor.open_files.count() == 0) pixi.editor.currentGroupingID() else pixi.editor.newGroupingID()) catch {
                                    dvui.log.err("Failed to open file: {s}", .{abs_path});
                                };

                                fw2.close();
                            }

                            _ = dvui.separator(@src(), .{ .expand = .horizontal });
                        }

                        if ((dvui.menuItemLabel(@src(), "New File...", .{}, .{ .expand = .horizontal })) != null) {
                            defer fw2.close();

                            // Create a generic dialog that contains typical okay and cancel buttons and header
                            // The displayFn will be called during the drawing of the dialog, prior to ok and cancel buttons
                            var mutex = pixi.dvui.dialog(@src(), .{
                                .displayFn = pixi.Editor.Dialogs.NewFile.dialog,
                                .callafterFn = pixi.Editor.Dialogs.NewFile.callAfter,
                                .title = "New File...",
                                .ok_label = "Create",
                                .cancel_label = "Cancel",
                                .resizeable = false,

                                .default = .ok,
                                .id_extra = branch_id.asUsize(),
                            });
                            dvui.dataSetSlice(null, mutex.id, "_parent_path", abs_path);
                            mutex.mutex.unlock();
                        }

                        if ((dvui.menuItemLabel(@src(), "New Folder...", .{}, .{ .expand = .horizontal })) != null) {
                            switch (entry.kind) {
                                .directory => {
                                    const new_folder_path = try std.fs.path.join(dvui.currentWindow().arena(), &.{ abs_path, "New Folder" });
                                    std.fs.makeDirAbsolute(new_folder_path) catch dvui.log.err("Failed to create folder: {s}", .{new_folder_path});
                                },
                                .file => {
                                    const new_folder_path = try std.fs.path.join(dvui.currentWindow().arena(), &.{ directory, "New Folder" });
                                    std.fs.makeDirAbsolute(new_folder_path) catch dvui.log.err("Failed to create folder: {s}", .{new_folder_path});
                                },
                                else => {},
                            }

                            fw2.close();
                        }

                        if ((dvui.menuItemLabel(@src(), "Rename", .{}, .{
                            .expand = .horizontal,
                        })) != null) {
                            edit_id = inner_id_extra.*;
                            fw2.close();
                        }

                        if ((dvui.menuItemLabel(@src(), "Delete", .{}, .{
                            .expand = .horizontal,
                            .style = .err,
                        })) != null) {
                            defer fw2.close();

                            if (entry.kind == .file) {
                                std.fs.deleteFileAbsolute(abs_path) catch dvui.log.err("Failed to delete file: {s}", .{abs_path});
                            } else if (entry.kind == .directory) {
                                std.fs.deleteDirAbsolute(abs_path) catch dvui.log.err("Failed to delete folder: {s}", .{abs_path});
                            }
                        }
                    }
                }

                switch (entry.kind) {
                    .file => {
                        const ext = extension(entry.name);
                        //if (ext == .hidden) continue;
                        const icon = switch (ext) {
                            .pixi, .psd => icons.tvg.lucide.@"file-pen-line",
                            .jpg, .png, .aseprite, .pyxel, .gif => icons.tvg.entypo.picture,
                            .pdf => icons.tvg.entypo.@"doc-text",
                            .json, .zig, .txt, .atlas => icons.tvg.entypo.code,
                            .tar, ._7z, .zip => icons.tvg.entypo.archive,
                            else => icons.tvg.entypo.archive,
                        };

                        const icon_color = color;

                        const file_icon_color: dvui.Color = if (ext == .pixi) .transparent else icon_color;

                        if (ext == .pixi) {
                            _ = pixi.dvui.sprite(
                                @src(),
                                .{ .source = pixi.editor.atlas.source, .sprite = pixi.editor.atlas.data.sprites[pixi.atlas.sprites.logo_default], .scale = 2.0 },
                                .{ .gravity_y = 0.5, .margin = padding, .padding = padding, .background = false },
                            );
                        } else {
                            dvui.icon(
                                @src(),
                                "FileIcon",
                                icon,
                                .{ .stroke_color = file_icon_color, .fill_color = file_icon_color },
                                .{
                                    .gravity_y = 0.5,
                                    .padding = padding,
                                    .background = false,
                                },
                            );
                        }

                        editableLabel(
                            inner_id_extra.*,
                            if (filter_text.len > 0) std.fs.path.relative(dvui.currentWindow().arena(), pixi.editor.folder.?, abs_path) catch entry.name else entry.name,
                            if (pixi.editor.getFileFromPath(abs_path) != null) dvui.themeGet().color(.window, .text) else dvui.themeGet().color(.control, .text),
                            entry.kind,
                            abs_path,
                        ) catch {
                            dvui.log.err("Failed to draw editable label", .{});
                        };

                        if (pixi.editor.getFileFromPath(abs_path)) |file| {
                            if (file.dirty()) {
                                _ = dvui.icon(
                                    @src(),
                                    "DirtyIcon",
                                    icons.tvg.lucide.@"circle-small",
                                    .{ .stroke_color = dvui.themeGet().color(.window, .text) },
                                    .{ .gravity_y = 0.5 },
                                );
                            }
                        }

                        if (branch.button.clicked()) {
                            selected_id = inner_id_extra.*;
                            switch (ext) {
                                .pixi, .png => {
                                    _ = pixi.editor.openFilePath(abs_path, pixi.editor.currentGroupingID()) catch |err| {
                                        dvui.log.err("{any}: {s}", .{ err, abs_path });
                                    };
                                },
                                else => {},
                            }
                        }
                    },
                    .directory => {
                        const folder_name = std.fs.path.basename(abs_path);
                        const icon_color = color;

                        _ = dvui.icon(
                            @src(),
                            "DropIcon",
                            if (branch.expanded) icons.tvg.entypo.@"down-open" else icons.tvg.entypo.@"right-open",
                            .{
                                .fill_color = icon_color,
                                .stroke_color = icon_color,
                                .stroke_width = 2,
                            },
                            .{
                                .gravity_y = 0.5,
                                .padding = padding,
                            },
                        );

                        _ = dvui.icon(
                            @src(),
                            "FolderIcon",
                            if (branch.expanded) icons.tvg.entypo.folder else icons.tvg.entypo.folder,
                            .{
                                .fill_color = icon_color,
                                .stroke_color = icon_color,
                                .stroke_width = 2,
                            },
                            .{
                                .gravity_y = 0.5,
                                .padding = padding,
                            },
                        );

                        editableLabel(
                            inner_id_extra.*,
                            folder_name,
                            dvui.themeGet().color(.control, .text),
                            entry.kind,
                            abs_path,
                        ) catch {
                            dvui.log.err("Failed to draw editable label", .{});
                        };

                        if (branch.button.clicked()) {
                            selected_id = inner_id_extra.*;
                        }

                        if (branch.expander(@src(), .{ .indent = expanded_indent }, .{
                            .color_fill = dvui.themeGet().color(.control, .fill),
                            .color_border = color.lerp(dvui.themeGet().color(.control, .fill), 1.0 - t),
                            .background = true,
                            .border = .{ .x = 1, .w = 0 },
                            .expand = .horizontal,
                            .corner_radius = .all(8),
                            .box_shadow = .{
                                .color = .black,
                                .offset = .{ .x = -10, .y = 0 },
                                .shrink = 10,
                                .fade = 10,
                                .alpha = 0.15 * t,
                            },
                        })) {
                            pixi.editor.explorer.open_branches.put(branch_id, {}) catch {
                                dvui.log.debug("Failed to track branch state!", .{});
                            };
                            try search(
                                abs_path,
                                tree,
                                inner_unique_id,
                                inner_id_extra,
                                color_id,
                                filter_text,
                                branch,
                            );
                        } else {
                            if (pixi.editor.explorer.open_branches.contains(branch_id)) {
                                _ = pixi.editor.explorer.open_branches.remove(branch_id);
                            }
                        }
                        color_id.* = color_id.* + 1;
                    },
                    else => {},
                }
            }
        }
    }.search;

    try recursor(root_directory, outer_tree, unique_id, &id_extra, &color_i, outer_filter_text, null);

    return;
}

pub fn extension(file: []const u8) Extension {
    const ext = std.fs.path.extension(file);
    if (std.mem.eql(u8, ext, "")) return .hidden;
    if (std.mem.eql(u8, ext, ".pixi")) return .pixi;
    if (std.mem.eql(u8, ext, ".atlas")) return .atlas;
    if (std.mem.eql(u8, ext, ".png")) return .png;
    if (std.mem.eql(u8, ext, ".gif")) return .gif;
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
