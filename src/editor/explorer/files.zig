const std = @import("std");
const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");
const Editor = pixi.Editor;

const icons = @import("icons");

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
    gif,
};

pub fn draw() !void {
    // var reorder = dvui.reorder(@src(), .{ .min_size_content = .{ .w = 120 }, .background = true, .border = dvui.Rect.all(1), .padding = dvui.Rect.all(4) });
    // defer reorder.deinit();
    var tree = Editor.Widgets.TreeWidget.tree(@src(), .{ .background = false, .expand = .both });
    defer tree.deinit();

    // for (entries, 0..) |entry, i| {
    //     drawSubs(tree, entry, i);
    // }

    // imgui.pushStyleColorImVec4(imgui.Col_Header, editor.theme.background.toImguiVec4());
    // imgui.pushStyleColorImVec4(imgui.Col_HeaderHovered, editor.theme.background.toImguiVec4());
    // imgui.pushStyleColorImVec4(imgui.Col_HeaderActive, editor.theme.background.toImguiVec4());
    // defer imgui.popStyleColorEx(3);

    // imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 6.0, .y = 5.0 });
    // defer imgui.popStyleVar();

    if (pixi.editor.folder) |path|
        try drawFiles(path, tree);
    // else
    //     try drawRecents(editor);
}

pub fn drawFiles(path: []const u8, tree: *Editor.Widgets.TreeWidget) !void {
    const folder = std.fs.path.basename(path);

    const branch = tree.branch(@src(), .{ .expanded = true }, .{
        .id_extra = 0,
        .expand = .horizontal,
        .color_fill_hover = .fill,
    });
    defer branch.deinit();

    const color: dvui.Color = if (pixi.editor.colors.file_tree_palette) |*palette| palette.getDVUIColor(0) else dvui.themeGet().color_fill_hover;

    _ = dvui.icon(@src(), "FolderIcon", icons.tvg.lucide.folder, .{ .fill_color = color }, .{ .gravity_y = 0.5, .padding = dvui.Rect.all(0) });
    dvui.label(@src(), "{s}", .{folder}, .{
        .color_fill = .{ .color = color },
        .font_style = .title_1,
        .gravity_y = 0.5,
    });
    _ = dvui.icon(@src(), "DropIcon", if (branch.expanded) dvui.entypo.triangle_down else dvui.entypo.triangle_right, .{ .fill_color = color }, .{ .gravity_y = 0.5, .padding = dvui.Rect.all(0) });

    if (branch.expander(@src(), .{ .indent = 14 }, .{
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
        .expand = .horizontal,
        .margin = dvui.Rect.all(5),
        .background = true,
        .border = .{ .x = 1 },
    })) {
        try recurseFiles(pixi.app.allocator, path, tree);
    }
}

// fn drawFiles(editor: *Editor, path: [:0]const u8) !void {
//     const folder = std.fs.path.basename(path);

//     const open_files_len = editor.open_files.items.len;

//     // Open files
//     if (open_files_len > 0) {
//         if (imgui.collapsingHeader(pixi.fa.file ++ "  Open Files", imgui.TreeNodeFlags_DefaultOpen)) {
//             imgui.indent();
//             defer imgui.unindent();

//             if (imgui.beginChild("OpenFiles", .{
//                 .x = 0.0,
//                 .y = @as(f32, @floatFromInt(@min(open_files_len + 1, 6))) * (imgui.getTextLineHeight() + 6.0),
//             }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
//                 defer imgui.endChild();

//                 for (editor.open_files.items, 0..) |file, i| {
//                     imgui.textColored(editor.theme.text_orange.toImguiVec4(), " " ++ pixi.fa.file_powerpoint ++ " ");
//                     imgui.sameLine();
//                     const name = std.fs.path.basename(file.path);
//                     const label = try std.fmt.allocPrintZ(editor.arena.allocator(), "{s}", .{name});
//                     if (imgui.selectable(label)) {
//                         editor.setActiveFile(i);
//                     }

//                     imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0, .y = 2.0 });
//                     imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0, .y = 6.0 });
//                     imgui.pushStyleVar(imgui.StyleVar_IndentSpacing, 16.0);
//                     imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0, .y = 10.0 });
//                     imgui.pushID(file.path);
//                     if (imgui.beginPopupContextItem()) {
//                         try contextMenuFile(editor, file.path);
//                         imgui.endPopup();
//                     }
//                     imgui.popID();
//                     imgui.popStyleVarEx(4);

//                     if (imgui.isItemHovered(imgui.HoveredFlags_DelayNormal)) {
//                         if (imgui.beginTooltip()) {
//                             defer imgui.endTooltip();

//                             imgui.textColored(editor.theme.text_secondary.toImguiVec4(), file.path);
//                         }
//                     }
//                 }
//             }
//         }
//     }

//     const index = if (std.mem.indexOf(u8, path, folder)) |i| i else 0;

//     const project_header_label = try std.fmt.allocPrintZ(editor.arena.allocator(), "{s}  {s}", .{ pixi.fa.folder, path[index.. :0] });

//     // File tree
//     var open: bool = true;
//     if (imgui.collapsingHeaderBoolPtr(
//         project_header_label,
//         &open,
//         imgui.TreeNodeFlags_DefaultOpen,
//     )) {
//         imgui.indent();
//         defer imgui.unindent();

//         imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0, .y = 2.0 });
//         imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0, .y = 6.0 });
//         imgui.pushStyleVar(imgui.StyleVar_IndentSpacing, 16.0);
//         imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0, .y = 4.0 });
//         imgui.pushID(path);
//         if (imgui.beginPopupContextItem()) {
//             try contextMenuFolder(editor, path);
//             imgui.endPopup();
//         }
//         imgui.popID();
//         imgui.popStyleVarEx(4);

//         if (imgui.beginChild("FileTree", .{
//             .x = -1.0,
//             .y = 0.0,
//         }, imgui.ChildFlags_None, imgui.WindowFlags_HorizontalScrollbar)) { // TODO: Should this also be ChildWindow?
//             // File Tree
//             try recurseFiles(pixi.app.allocator, path);
//         }
//         defer imgui.endChild();
//     }

//     if (!open) {
//         if (editor.folder) |f| {
//             pixi.app.allocator.free(f);
//         }

//         editor.folder = null;
//     }
// }

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

// TODO: Rework this, we need to build and sort before presenting, currently files are displayed however they are loaded
// When reworking, also try to reduce/remove global pointer usage, better to pass in editor or app pointers

pub fn recurseFiles(allocator: std.mem.Allocator, root_directory: []const u8, outer_tree: *Editor.Widgets.TreeWidget) !void {
    var color_i: usize = 0;
    const recursor = struct {
        fn search(alloc: std.mem.Allocator, directory: []const u8, tree: *Editor.Widgets.TreeWidget, color_id: *usize) !void {
            var dir = try std.fs.cwd().openDir(directory, .{ .access_sub_paths = true, .iterate = true });
            defer dir.close();

            var iter = dir.iterate();
            var id_extra: usize = 0;
            while (try iter.next()) |entry| {
                id_extra += 1;

                var color = dvui.themeGet().color_fill_hover;
                if (pixi.editor.colors.file_tree_palette) |*palette| {
                    color = palette.getDVUIColor(color_id.*);
                }

                const padding = dvui.Rect.all(2);

                const branch = tree.branch(@src(), .{
                    .expanded = false,
                }, .{
                    .id_extra = id_extra,
                    .expand = .horizontal,
                    .color_fill_hover = .fill,
                    .padding = dvui.Rect.all(1),
                });
                defer branch.deinit();

                {
                    var context = dvui.context(@src(), .{ .rect = branch.vbox.data().borderRectScale().r }, .{});
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

                        if ((dvui.menuItemLabel(@src(), "Rename", .{}, .{ .expand = .horizontal })) != null) {
                            fw2.close();
                        }

                        if ((dvui.menuItemLabel(@src(), "Delete", .{}, .{ .expand = .horizontal })) != null) {
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

                        // const icon_color = if (pixi.editor.colors.file_tree_palette) |*palette|
                        //     switch (ext) {
                        //         .pixi, .psd => palette.getDVUIColor(2),
                        //         .jpg, .png, .aseprite, .pyxel => palette.getDVUIColor(3),
                        //         .pdf => palette.getDVUIColor(4),
                        //         .json, .zig, .txt, .atlas => palette.getDVUIColor(5),
                        //         .tar, ._7z, .zip => palette.getDVUIColor(6),
                        //         else => palette.getDVUIColor(0),
                        //     }
                        // else
                        //     dvui.themeGet().color_fill_hover;

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
                        dvui.label(
                            @src(),
                            "{s}",
                            .{entry.name},
                            .{
                                .color_text = .{ .color = text_color },
                                .font_style = .title,
                                .padding = padding,
                            },
                        );

                        const abs_path = try std.fs.path.joinZ(
                            alloc,
                            &.{ directory, entry.name },
                        );
                        defer alloc.free(abs_path);

                        if (branch.button.clicked()) {
                            switch (ext) {
                                .pixi => {
                                    // _ = pixi.editor.openFile(abs_path) catch {
                                    //     std.log.debug("Failed to open file: {s}", .{abs_path});
                                    // };
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
                        const abs_path = try std.fs.path.joinZ(
                            pixi.editor.arena.allocator(),
                            &[_][]const u8{ directory, entry.name },
                        );
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
                            .font_style = .title,
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
                            .border = .{ .x = 1 },
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
                                alloc,
                                abs_path,
                                tree,
                                color_id,
                            );
                        }
                        color_id.* = color_id.* + 1;
                    },
                    else => {},
                }
            }
        }
    }.search;

    try recursor(allocator, root_directory, outer_tree, &color_i);

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
