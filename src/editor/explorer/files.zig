const std = @import("std");
const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");
const Editor = pixi.Editor;

const icons = @import("icons");

const nfd = @import("nfd");
const zstbi = @import("zstbi");

var tree_removed_path: ?[]const u8 = null;
var edit_path: ?[]const u8 = null;
var input_widget: ?*dvui.TextEntryWidget = null;

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
    var tree = dvui.TreeWidget.tree(@src(), .{ .enable_reordering = true }, .{ .background = false, .expand = .both });
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

pub fn drawFiles(path: []const u8, tree: *dvui.TreeWidget) !void {
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

    const branch = tree.branch(@src(), .{ .expanded = true }, .{
        .id_extra = 0,
        .expand = .horizontal,
        //.color_fill_hover = dvui.themeGet().color(.window, .fill),
        .color_fill = dvui.themeGet().color(.control, .fill),
    });
    defer branch.deinit();

    const color: dvui.Color = if (pixi.editor.colors.file_tree_palette) |*palette| palette.getDVUIColor(0) else dvui.themeGet().color(.control, .fill_hover);

    _ = dvui.icon(
        @src(),
        "FolderIcon",
        icons.tvg.lucide.folder,
        .{ .stroke_color = color },
        .{ .gravity_y = 0.5, .padding = dvui.Rect.all(0) },
    );

    var fmt_string = std.fmt.allocPrint(dvui.currentWindow().lifo(), comptime "{s}", .{folder}) catch unreachable;
    defer dvui.currentWindow().lifo().free(fmt_string);

    for (fmt_string, 0..) |c, i| {
        fmt_string[i] = std.ascii.toUpper(c);
    }

    dvui.labelNoFmt(@src(), fmt_string, .{}, .{
        .color_fill = color,
        .font_style = .title_4,
        .gravity_y = 0.5,
    });
    _ = dvui.icon(
        @src(),
        "DropIcon",
        if (branch.expanded) dvui.entypo.triangle_down else dvui.entypo.triangle_right,
        .{ .fill_color = color },
        .{ .gravity_y = 0.5, .padding = dvui.Rect.all(0) },
    );

    if (branch.expander(@src(), .{ .indent = 24 }, .{
        .color_border = color,
        .color_fill = dvui.themeGet().color(.control, .fill),
        .corner_radius = branch.button.wd.options.corner_radius,
        // .box_shadow = .{
        //     .color = .{ .color = .black },
        //     .offset = .{ .x = -5, .y = 5 },
        //     .shrink = 5,
        //     .fade = 10,
        //     .alpha = 0.15,
        // },
        .expand = .both,
        .margin = .{ .x = 10, .w = 5 },
        .background = true,
        .border = .{ .x = 1, .w = 1 },
    })) {
        try recurseFiles(path, tree, unique_id, filter_text);
    }
}

// fn drawRecents(editor: *Editor) !void {
//     if (imgui.collapsingHeader(pixi.fa.clock ++ "  Recents", imgui.TreeNodeFlags_DefaultOpen)) {
//         imgui.indent();
//         defer imgui.unindent();

//         if (editor.recents.folders.items.len > 0) {
//             imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text_secondary.toImguiVec4());
//             defer imgui.popStyleColor();
//             if (imgui.beginChild("Recents", .{
//                 .x = imgui.getContentRegionAvail().x,
//                 .y = 0.0,
//             }, imgui.ChildFlags_None, imgui.WindowFlags_HorizontalScrollbar)) {
//                 defer imgui.endChild();

//                 var i: usize = editor.recents.folders.items.len;
//                 while (i > 0) {
//                     i -= 1;
//                     const folder = editor.recents.folders.items[i];
//                     const label = try std.fmt.allocPrintZ(editor.arena.allocator(), "{s} {s}##{s}", .{ pixi.fa.folder, std.fs.path.basename(folder), folder });

//                     if (imgui.selectable(label)) {
//                         try editor.setProjectFolder(folder);
//                     }
//                     imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0, .y = 2.0 });
//                     imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0, .y = 6.0 });
//                     imgui.pushStyleVar(imgui.StyleVar_IndentSpacing, 16.0);
//                     imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0, .y = 10.0 });
//                     defer imgui.popStyleVarEx(4);
//                     if (imgui.beginPopupContextItem()) {
//                         defer imgui.endPopup();
//                         if (imgui.menuItem("Remove")) {
//                             const item = editor.recents.folders.orderedRemove(i);
//                             pixi.app.allocator.free(item);
//                             try editor.recents.save();
//                         }
//                     }

//                     imgui.sameLineEx(0.0, 5.0);
//                     imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text_background.toImguiVec4());
//                     imgui.text(folder);
//                     imgui.popStyleColor();
//                 }
//             }
//         }
//     }
// }

fn lessThan(_: void, lhs: std.fs.Dir.Entry, rhs: std.fs.Dir.Entry) bool {
    if (lhs.kind == .directory and rhs.kind == .file) return true;
    if (lhs.kind == .file and rhs.kind == .directory) return false;

    return std.mem.order(u8, lhs.name, rhs.name) == .lt;
}

pub fn recurseFiles(root_directory: []const u8, outer_tree: *dvui.TreeWidget, unique_id: dvui.Id, outer_filter_text: []const u8) !void {
    var color_i: usize = 0;
    var id_extra: usize = 0;

    const recursor = struct {
        fn search(directory: []const u8, tree: *dvui.TreeWidget, inner_unique_id: dvui.Id, inner_id_extra: *usize, color_id: *usize, filter_text: []const u8) !void {
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
                    search(abs_path, tree, inner_unique_id, inner_id_extra, color_id, filter_text) catch continue;
                    continue;
                }

                inner_id_extra.* = dvui.Id.update(tree.data().id, abs_path).asUsize();

                var color = dvui.themeGet().color(.control, .fill_hover);
                if (pixi.editor.colors.file_tree_palette) |*palette| {
                    color = palette.getDVUIColor(color_id.*);
                }

                const padding = dvui.Rect.all(2);

                const branch = tree.branch(@src(), .{
                    .expanded = false,
                }, .{
                    .id_extra = inner_id_extra.*,
                    .expand = .horizontal,
                    //.color_fill_hover = .fill,
                    .color_fill = dvui.themeGet().color(.control, .fill),
                    .padding = dvui.Rect.all(1),
                });
                defer branch.deinit();

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

                        if ((dvui.menuItemLabel(@src(), "Open", .{}, .{
                            .expand = .horizontal,
                        })) != null) {
                            _ = pixi.editor.openFilePath(abs_path, pixi.editor.currentGroupingID()) catch {
                                dvui.log.err("Failed to open file: {s}", .{abs_path});
                            };

                            fw2.close();
                        }

                        if ((dvui.menuItemLabel(@src(), "Open to the side", .{}, .{
                            .expand = .horizontal,
                        })) != null) {
                            _ = pixi.editor.openFilePath(abs_path, pixi.editor.newGroupingID()) catch {
                                dvui.log.err("Failed to open file: {s}", .{abs_path});
                            };

                            fw2.close();
                        }

                        _ = dvui.separator(@src(), .{ .expand = .horizontal });

                        if ((dvui.menuItemLabel(@src(), "New File...", .{}, .{ .expand = .horizontal })) != null) {
                            fw2.close();
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
                            // if (edit_path == null)
                            //     edit_path = alloc.dupe(u8, abs_path) catch null;
                            fw2.close();
                        }

                        if ((dvui.menuItemLabel(@src(), "Delete", .{}, .{
                            .expand = .horizontal,
                            .color_accent = dvui.themeGet().color(.err, .fill),
                        })) != null) {
                            fw2.close();
                        }
                    }
                }

                switch (entry.kind) {
                    .file => {
                        const ext = extension(entry.name);
                        //if (ext == .hidden) continue;
                        const icon = switch (ext) {
                            .pixi, .psd => icons.tvg.lucide.@"file-pen-line",
                            .jpg, .png, .aseprite, .pyxel, .gif => icons.tvg.lucide.@"file-image",
                            .pdf => icons.tvg.lucide.@"file-text",
                            .json, .zig, .txt, .atlas => icons.tvg.lucide.@"file-code-2",
                            .tar, ._7z, .zip => icons.tvg.lucide.@"file-lock-2",
                            else => icons.tvg.lucide.@"file-question",
                        };

                        const icon_color = color;

                        //const text_color = dvui.themeGet().color_text_press;

                        _ = dvui.icon(
                            @src(),
                            "FileIcon",
                            icon,
                            .{ .stroke_color = icon_color },
                            .{
                                .gravity_y = 0.5,
                                .padding = padding,
                            },
                        );

                        dvui.label(
                            @src(),
                            "{s}",
                            .{if (filter_text.len > 0) std.fs.path.relative(dvui.currentWindow().arena(), pixi.editor.folder.?, abs_path) catch entry.name else entry.name},
                            .{
                                .color_text = if (pixi.editor.getFileFromPath(abs_path) != null) dvui.themeGet().color(.window, .text) else dvui.themeGet().color(.control, .text),
                                .font_style = .caption,
                                .padding = padding,
                                .gravity_y = 0.5,
                            },
                        );

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
                            switch (ext) {
                                .pixi, .png => {
                                    _ = pixi.editor.openFilePath(abs_path, pixi.editor.currentGroupingID()) catch {
                                        dvui.log.err("Failed to open file: {s}", .{abs_path});
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
                            "FolderIcon",
                            if (branch.expanded) icons.tvg.lucide.@"folder-open" else icons.tvg.lucide.@"folder-closed",
                            .{
                                .stroke_color = icon_color,
                            },
                            .{
                                .gravity_y = 0.5,
                                .padding = padding,
                            },
                        );
                        dvui.label(@src(), "{s}", .{folder_name}, .{
                            .color_text = dvui.themeGet().color(.control, .text),
                            .font_style = .caption,
                            .padding = padding,
                        });
                        _ = dvui.icon(
                            @src(),
                            "DropIcon",
                            if (branch.expanded) dvui.entypo.triangle_down else dvui.entypo.triangle_right,
                            .{ .fill_color = icon_color },
                            .{
                                .gravity_y = 0.5,
                                .gravity_x = 1.0,
                                .padding = padding,
                            },
                        );

                        if (branch.expander(@src(), .{ .indent = 14 }, .{
                            .color_fill = dvui.themeGet().color(.control, .fill),
                            .color_border = color,
                            .background = true,
                            .border = .{ .x = 1, .w = 1 },
                            .expand = .horizontal,
                            .corner_radius = branch.button.wd.options.corner_radius,
                            .box_shadow = .{
                                .color = .black,
                                .offset = .{ .x = -5, .y = 5 },
                                .shrink = 5,
                                .fade = 10,
                                .alpha = 0.15,
                            },
                        })) {
                            try search(
                                abs_path,
                                tree,
                                inner_unique_id,
                                inner_id_extra,
                                color_id,
                                filter_text,
                            );
                        }
                        color_id.* = color_id.* + 1;
                    },
                    else => {},
                }
            }
        }
    }.search;

    try recursor(root_directory, outer_tree, unique_id, &id_extra, &color_i, outer_filter_text);

    return;
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
