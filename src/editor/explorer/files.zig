const std = @import("std");
const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");
const Editor = pixi.Editor;

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

pub fn draw() !void {
    // var tree = try dvui.TreeWidget.init(@src(), .{}, .{ .expand = .both, .background = true, .color_fill = .{ .color = .red } });
    // defer tree.deinit();

    // try tree.install();

    // if (try tree.branch(@src(), "Files", .{ .default_expanded = true }, .{})) {
    //     if (try tree.branch(@src(), "Files2", .{ .default_expanded = true }, .{})) {
    //         if (try tree.branch(@src(), "Files4", .{ .default_expanded = true }, .{})) {
    //             if (try tree.leaf(@src(), "Files45", .{})) {}
    //             if (try tree.leaf(@src(), "Files46", .{})) {}
    //             if (try tree.branch(@src(), "Files3", .{ .default_expanded = false }, .{})) {
    //                 if (try tree.leaf(@src(), "Files34", .{})) {}
    //                 if (try tree.leaf(@src(), "Files35", .{})) {}
    //             }
    //         }
    //     }
    // }

    // if (try dvui.expander(@src(), "Files", .{}, .{ .expand = .horizontal })) {
    //     var vbox = try dvui.box(@src(), .vertical, .{ .margin = .{ .x = 10 } });
    //     defer vbox.deinit();

    //     try dvui.label(@src(), "Files", .{}, .{});
    //     if (try dvui.expander(@src(), "Other Files", .{}, .{ .expand = .horizontal, .id_extra = 1 })) {
    //         //try dvui.label(@src(), "Files");
    //     }
    // }

    // imgui.pushStyleColorImVec4(imgui.Col_Header, editor.theme.background.toImguiVec4());
    // imgui.pushStyleColorImVec4(imgui.Col_HeaderHovered, editor.theme.background.toImguiVec4());
    // imgui.pushStyleColorImVec4(imgui.Col_HeaderActive, editor.theme.background.toImguiVec4());
    // defer imgui.popStyleColorEx(3);

    // imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 6.0, .y = 5.0 });
    // defer imgui.popStyleVar();

    // if (editor.folder) |path|
    //     try drawFiles(editor, path)
    // else
    //     try drawRecents(editor);
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

// pub fn recurseFiles(allocator: std.mem.Allocator, root_directory: [:0]const u8) !void {
//     imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0, .y = 2.0 });
//     imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0, .y = 6.0 });
//     imgui.pushStyleVar(imgui.StyleVar_IndentSpacing, 16.0);
//     imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0, .y = 10.0 });
//     defer imgui.popStyleVarEx(4);

//     const recursor = struct {
//         fn search(alloc: std.mem.Allocator, directory: [:0]const u8) !void {
//             var dir = try std.fs.cwd().openDir(directory, .{ .access_sub_paths = true, .iterate = true });
//             defer dir.close();

//             var iter = dir.iterate();
//             while (try iter.next()) |entry| {
//                 switch (entry.kind) {
//                     .file => {
//                         imgui.indent();
//                         defer imgui.unindent();
//                         const ext = extension(entry.name);
//                         if (ext == .hidden) continue;
//                         const icon = switch (ext) {
//                             .pixi, .psd => pixi.fa.file_powerpoint,
//                             .jpg, .png, .aseprite, .pyxel => pixi.fa.file_image,
//                             .pdf => pixi.fa.file_pdf,
//                             .json, .zig, .txt, .atlas => pixi.fa.file_code,
//                             .tar, ._7z, .zip => pixi.fa.file_archive,
//                             else => pixi.fa.file,
//                         };

//                         const icon_color = switch (ext) {
//                             .pixi, .zig => pixi.editor.theme.text_orange.toImguiVec4(),
//                             .png, .psd => pixi.editor.theme.text_blue.toImguiVec4(),
//                             .jpg => pixi.editor.theme.highlight_primary.toImguiVec4(),
//                             .pdf => pixi.editor.theme.text_red.toImguiVec4(),
//                             .json, .atlas => pixi.editor.theme.text_yellow.toImguiVec4(),
//                             .txt, .zip, ._7z, .tar => pixi.editor.theme.text_background.toImguiVec4(),
//                             else => pixi.editor.theme.text_background.toImguiVec4(),
//                         };

//                         const text_color = switch (ext) {
//                             .pixi => pixi.editor.theme.text.toImguiVec4(),
//                             .jpg, .png, .json, .zig, .pdf, .aseprite, .pyxel, .psd, .tar, ._7z, .zip, .txt, .atlas => pixi.editor.theme.text_secondary.toImguiVec4(),
//                             else => pixi.editor.theme.text_background.toImguiVec4(),
//                         };

//                         const icon_spaced = try std.fmt.allocPrintZ(pixi.editor.arena.allocator(), " {s} ", .{icon});

//                         imgui.textColored(icon_color, icon_spaced);
//                         imgui.sameLine();

//                         const abs_path = try std.fs.path.joinZ(alloc, &.{ directory, entry.name });
//                         defer alloc.free(abs_path);

//                         imgui.pushStyleColorImVec4(imgui.Col_Text, text_color);

//                         const selectable_name = try std.fmt.allocPrintZ(pixi.editor.arena.allocator(), "{s}", .{entry.name});

//                         if (imgui.selectableEx(
//                             selectable_name,
//                             if (pixi.editor.getFileIndex(abs_path)) |_| true else false,
//                             imgui.SelectableFlags_None,
//                             .{ .x = 0.0, .y = 0.0 },
//                         )) {
//                             switch (ext) {
//                                 .pixi => {
//                                     _ = pixi.editor.openFile(abs_path) catch {
//                                         std.log.debug("Failed to open file: {s}", .{abs_path});
//                                     };
//                                 },
//                                 .png, .jpg => {
//                                     _ = pixi.editor.openReference(abs_path) catch {
//                                         std.log.debug("Failed to open reference: {s}", .{abs_path});
//                                     };
//                                 },
//                                 else => {},
//                             }
//                         }
//                         imgui.popStyleColor();

//                         imgui.pushID(abs_path);
//                         if (imgui.beginPopupContextItem()) {
//                             //try contextMenuFile(pixi.editor, abs_path);
//                             imgui.endPopup();
//                         }
//                         imgui.popID();
//                     },
//                     .directory => {
//                         const abs_path = try std.fs.path.joinZ(pixi.editor.arena.allocator(), &[_][]const u8{ directory, entry.name });
//                         const folder = try std.fmt.allocPrintZ(pixi.editor.arena.allocator(), " {s} {s}", .{ pixi.fa.folder, entry.name });
//                         imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.editor.theme.text_secondary.toImguiVec4());
//                         defer imgui.popStyleColor();

//                         if (imgui.treeNode(folder)) {
//                             imgui.pushID(abs_path);
//                             if (imgui.beginPopupContextItem()) {
//                                 try contextMenuFolder(pixi.editor, abs_path);
//                                 imgui.endPopup();
//                             }
//                             imgui.popID();

//                             try search(alloc, abs_path);

//                             imgui.treePop();
//                         } else {
//                             imgui.pushID(abs_path);
//                             if (imgui.beginPopupContextItem()) {
//                                 try contextMenuFolder(pixi.editor, abs_path);
//                                 imgui.endPopup();
//                             }
//                             imgui.popID();
//                         }
//                     },
//                     else => {},
//                 }
//             }
//         }
//     }.search;

//     try recursor(allocator, root_directory);

//     return;
// }

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
