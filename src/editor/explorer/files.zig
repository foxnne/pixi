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

    if (pixi.editor.folder) |path|
        try drawFiles(path, tree);
    // else
    //     try drawRecents(editor);
}

pub fn drawFiles(path: []const u8, tree: *dvui.TreeWidget) !void {
    const unique_id = dvui.parentGet().extendId(@src(), 0);

    var filter_hbox = dvui.box(@src(), .horizontal, .{ .expand = .horizontal });
    dvui.icon(
        @src(),
        "FilterIcon",
        icons.tvg.lucide.search,
        .{ .fill_color = dvui.themeGet().color_text },
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
        .color_fill_hover = .fill,
    });
    defer branch.deinit();

    const color: dvui.Color = if (pixi.editor.colors.file_tree_palette) |*palette| palette.getDVUIColor(0) else dvui.themeGet().color_fill_hover;

    _ = dvui.icon(
        @src(),
        "FolderIcon",
        icons.tvg.lucide.folder,
        .{ .fill_color = color },
        .{ .gravity_y = 0.5, .padding = dvui.Rect.all(0) },
    );
    dvui.label(@src(), "{s}", .{folder}, .{
        .color_fill = .{ .color = color },
        .font_style = .heading,
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
        .color_border = .{ .color = color },
        .color_fill = .fill_window,
        .corner_radius = branch.button.wd.options.corner_radius,
        .box_shadow = .{
            .color = .{ .color = .black },
            .offset = .{ .x = -5, .y = 5 },
            .shrink = 5,
            .blur = 10,
            .alpha = 0.15,
        },
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

pub fn recurseFiles(root_directory: []const u8, outer_tree: *dvui.TreeWidget, unique_id: dvui.WidgetId, outer_filter_text: []const u8) !void {
    var color_i: usize = 0;
    var id_extra: usize = 0;

    const recursor = struct {
        fn search(directory: []const u8, tree: *dvui.TreeWidget, inner_unique_id: dvui.WidgetId, inner_id_extra: *usize, color_id: *usize, filter_text: []const u8) !void {
            var dir = std.fs.cwd().openDir(directory, .{ .access_sub_paths = true, .iterate = true }) catch return;
            defer dir.close();

            // Collect all files/folders in the directory and sort them alphabetically
            var files = std.ArrayList(std.fs.Dir.Entry).init(dvui.currentWindow().arena());

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

                inner_id_extra.* = dvui.hashIdKey(tree.data().id, abs_path);

                var color = dvui.themeGet().color_fill_hover;
                if (pixi.editor.colors.file_tree_palette) |*palette| {
                    color = palette.getDVUIColor(color_id.*);
                }

                const padding = dvui.Rect.all(2);

                const branch = tree.branch(@src(), .{
                    .expanded = false,
                }, .{
                    .id_extra = inner_id_extra.*,
                    .expand = .horizontal,
                    .color_fill_hover = .fill,
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
                            std.fs.renameAbsolute(removed_path, new_path) catch std.log.err("Failed to move {s} to {s}", .{ removed_path, new_path });
                        }

                        dvui.dataRemove(null, inner_unique_id, "removed_path");
                    }
                }

                { // Add right click context menu for item options
                    var context = dvui.context(@src(), .{ .rect = branch.button.data().borderRectScale().r }, .{ .id_extra = inner_id_extra.* });
                    defer context.deinit();

                    if (context.activePoint()) |point| {
                        var fw2 = dvui.floatingMenu(@src(), .{ .from = dvui.Rect.Natural.fromPoint(point) }, .{ .box_shadow = .{
                            .color = .{ .color = .black },
                            .offset = .{ .x = 0, .y = 0 },
                            .shrink = 0,
                            .blur = 10,
                            .alpha = 0.15,
                        } });
                        defer fw2.deinit();

                        if ((dvui.menuItemLabel(@src(), "New File...", .{}, .{ .expand = .horizontal })) != null) {
                            fw2.close();
                        }

                        if ((dvui.menuItemLabel(@src(), "New Folder...", .{}, .{ .expand = .horizontal })) != null) {
                            switch (entry.kind) {
                                .directory => {
                                    const new_folder_path = try std.fs.path.join(dvui.currentWindow().arena(), &.{ abs_path, "New Folder" });
                                    std.fs.makeDirAbsolute(new_folder_path) catch std.log.err("Failed to create folder: {s}", .{new_folder_path});
                                },
                                .file => {
                                    const new_folder_path = try std.fs.path.join(dvui.currentWindow().arena(), &.{ directory, "New Folder" });
                                    std.fs.makeDirAbsolute(new_folder_path) catch std.log.err("Failed to create folder: {s}", .{new_folder_path});
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
                            .color_accent = .err,
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

                        const text_color = dvui.themeGet().color_text;

                        _ = dvui.icon(
                            @src(),
                            "FileIcon",
                            icon,
                            .{ .fill_color = icon_color },
                            .{
                                .gravity_y = 0.5,
                                .padding = padding,
                            },
                        );

                        if (edit_path) |path| {
                            if (std.mem.eql(u8, path, abs_path)) {
                                const te = dvui.textEntry(@src(), .{ .placeholder = entry.name }, .{ .expand = .horizontal });

                                if (dvui.firstFrame(te.data().id)) {
                                    dvui.focusWidget(te.data().id, null, null);
                                }

                                if (dvui.focusedWidgetId() != te.data().id) {
                                    edit_path = null;
                                }

                                // if (te.text.len > 0) {
                                //     const new_path = try std.fs.path.join(alloc, &.{ directory, te.text });
                                //     defer alloc.free(new_path);

                                //     // if (!std.mem.eql(u8, path, new_path)) {
                                //     //     try std.fs.renameAbsolute(path, new_path);
                                //     // }
                                // }
                                te.deinit();
                            } else {
                                dvui.label(
                                    @src(),
                                    "{s}",
                                    .{entry.name},
                                    .{
                                        .color_text = .{ .color = text_color },
                                        .font_style = .body,
                                        .padding = padding,
                                    },
                                );
                            }
                        } else {
                            dvui.label(
                                @src(),
                                "{s}",
                                .{if (filter_text.len > 0) std.fs.path.relative(dvui.currentWindow().arena(), pixi.editor.folder.?, abs_path) catch entry.name else entry.name},
                                .{
                                    .color_text = .{ .color = text_color },
                                    .font_style = .body,
                                    .padding = padding,
                                },
                            );
                        }

                        if (branch.button.clicked()) {
                            switch (ext) {
                                .pixi => {
                                    _ = pixi.editor.openFile(abs_path) catch {
                                        std.log.debug("Failed to open file: {s}", .{abs_path});
                                    };
                                },
                                .png, .jpg => {
                                    // _ = pixi.editor.openReference(abs_path) catch {
                                    //     std.log.debug("Failed to open reference: {s}", .{abs_path});
                                    // };
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
                                .fill_color = icon_color,
                            },
                            .{
                                .gravity_y = 0.5,
                                .padding = padding,
                            },
                        );
                        dvui.label(@src(), "{s}", .{folder_name}, .{
                            .color_text = .{ .color = dvui.themeGet().color_text },
                            .font_style = .body,
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
                            .color_fill = .fill_window,
                            .color_border = .{ .color = color },
                            .background = true,
                            .border = .{ .x = 1, .w = 1 },
                            .expand = .horizontal,
                            .corner_radius = branch.button.wd.options.corner_radius,
                            .box_shadow = .{
                                .color = .{ .color = .black },
                                .offset = .{ .x = -5, .y = 5 },
                                .shrink = 5,
                                .blur = 10,
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

// fn contextMenuFolder(editor: *Editor, folder: [:0]const u8) !void {
//     imgui.pushStyleColorImVec4(imgui.Col_Separator, editor.theme.foreground.toImguiVec4());
//     imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text.toImguiVec4());
//     defer imgui.popStyleColorEx(2);
//     if (imgui.menuItem("New File...")) {
//         const new_file_path = try std.fs.path.joinZ(editor.arena.allocator(), &[_][]const u8{ folder, "New_file.pixi" });
//         editor.popups.fileSetupNew(new_file_path);
//     }
//     if (imgui.menuItem("New File from PNG...")) {
//         editor.popups.file_dialog_request = .{
//             .state = .file,
//             .type = .new_png,
//             .filter = "png",
//         };
//     }

//     if (editor.popups.file_dialog_response) |response| {
//         if (response.type == .new_png) {
//             const new_file_path = try std.fmt.allocPrintZ(
//                 editor.arena.allocator(),
//                 "{s}.pixi",
//                 .{response.path[0 .. response.path.len - 4]},
//             );
//             editor.popups.fileSetupImportPng(new_file_path, response.path);

//             nfd.freePath(response.path);
//             editor.popups.file_dialog_response = null;
//         }
//     }
//     if (imgui.menuItem("New Folder...")) {
//         const folder_name = try std.fs.path.joinZ(editor.arena.allocator(), &[_][]const u8{ folder, "New Folder" });
//         @memcpy(editor.popups.folder_path[0..folder_name.len], folder_name);
//         editor.popups.folder = true;
//     }

//     imgui.separator();
// }

// fn contextMenuFile(editor: *Editor, file: [:0]const u8) !void {
//     imgui.pushStyleColorImVec4(imgui.Col_Separator, editor.theme.foreground.toImguiVec4());
//     imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text.toImguiVec4());

//     const ext = extension(file);

//     switch (ext) {
//         .png => {
//             if (imgui.menuItem("Import...")) {
//                 const new_file_path = try std.fmt.allocPrintZ(
//                     editor.arena.allocator(),
//                     "{s}.pixi",
//                     .{file[0 .. file.len - 4]},
//                 );
//                 editor.popups.fileSetupImportPng(new_file_path, file);
//             }
//         },
//         .pixi => {
//             if (imgui.menuItem("Re-slice...")) {
//                 editor.popups.fileSetupSlice(file);
//             }
//         },
//         else => {},
//     }

//     imgui.separator();

//     if (imgui.menuItem("Rename...")) {
//         editor.popups.rename_path = [_:0]u8{0} ** std.fs.max_path_bytes;
//         editor.popups.rename_old_path = [_:0]u8{0} ** std.fs.max_path_bytes;
//         @memcpy(editor.popups.rename_path[0..file.len], file);
//         @memcpy(editor.popups.rename_old_path[0..file.len], file);
//         editor.popups.rename = true;
//         editor.popups.rename_state = .rename;
//     }

//     if (imgui.menuItem("Duplicate...")) {
//         editor.popups.rename_path = [_:0]u8{0} ** std.fs.max_path_bytes;
//         editor.popups.rename_old_path = [_:0]u8{0} ** std.fs.max_path_bytes;
//         @memcpy(editor.popups.rename_old_path[0..file.len], file);

//         const ex = std.fs.path.extension(file);

//         if (std.mem.indexOf(u8, file, ex)) |ext_i| {
//             const new_base_name = try std.fmt.allocPrintZ(
//                 editor.arena.allocator(),
//                 "{s}{s}{s}",
//                 .{ file[0..ext_i], "_copy", ex },
//             );
//             @memcpy(editor.popups.rename_path[0..new_base_name.len], new_base_name);

//             editor.popups.rename = true;
//             editor.popups.rename_state = .duplicate;
//         }
//     }
//     imgui.separator();
//     imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text_red.toImguiVec4());
//     if (imgui.menuItem("Delete")) {
//         try std.fs.deleteFileAbsolute(file);
//         if (editor.getFileIndex(file)) |index| {
//             try editor.closeFile(index);
//         }
//     }
//     imgui.popStyleColorEx(3);
// }

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
