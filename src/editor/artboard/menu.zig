const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("root");
const settings = pixi.settings;
const zstbi = @import("zstbi");
const nfd = @import("nfd");

pub fn draw() void {
    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.window_padding, .v = .{ 10.0 * pixi.state.window.scale[0], 10.0 * pixi.state.window.scale[1] } });
    defer zgui.popStyleVar(.{ .count = 1 });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text_secondary.toSlice() });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.popup_bg, .c = pixi.state.style.foreground.toSlice() });
    defer zgui.popStyleColor(.{ .count = 2 });
    if (zgui.beginMenuBar()) {
        defer zgui.endMenuBar();
        if (zgui.beginMenu("File", true)) {
            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text.toSlice() });
            if (zgui.menuItem("Open Folder...", .{
                .shortcut = "Cmd+F",
            })) {
                const folder = nfd.openFolderDialog(null) catch unreachable;
                if (folder) |path| {
                    pixi.editor.setProjectFolder(path);
                }
            }
            if (zgui.beginMenu("Recents", true)) {
                zgui.endMenu();
            }

            zgui.separator();

            const file = pixi.editor.getFile(pixi.state.open_file_index);

            if (zgui.menuItem("Export as .png...", .{
                .shortcut = "Cmd+P",
                .enabled = file != null,
            })) {
                pixi.state.popups.export_to_png = true;
            }

            if (zgui.menuItem("Save", .{
                .shortcut = "Cmd+S",
                .enabled = file != null and file.?.dirty(),
            })) {
                if (file) |f| {
                    f.save() catch unreachable;
                }
            }

            // if (zgui.beginMenu("Export as .png", true)) {
            //     if (zgui.menuItem("Selected Sprite...", .{})) {
            //         if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
            //             if (nfd.saveFileDialog(
            //                 "png",
            //                 null,
            //             ) catch unreachable) |path| {
            //                 var sprite_image = file.spriteToImage(file.selected_sprite_index) catch unreachable;
            //                 var rescaled_image = sprite_image.resize(sprite_image.width * 16, sprite_image.height * 16);

            //                 const path_name = zgui.formatZ("{s}", .{path});
            //                 rescaled_image.writeToFile(path_name, .png) catch unreachable;

            //                 sprite_image.deinit();
            //                 rescaled_image.deinit();
            //                 nfd.freePath(path);
            //             }
            //         }
            //     }
            //     if (zgui.menuItem("Selected Animation...", .{})) {}
            //     if (zgui.menuItem("Selected Layer...", .{})) {}
            //     if (zgui.menuItem("All Layers...", .{})) {}
            //     if (zgui.menuItem("Entire Canvas...", .{})) {}
            //     zgui.endMenu();
            // }

            zgui.popStyleColor(.{ .count = 1 });
            zgui.endMenu();
        }
        if (zgui.beginMenu("Edit", true)) {
            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text.toSlice() });
            zgui.popStyleColor(.{ .count = 1 });
            zgui.endMenu();
        }
        if (zgui.beginMenu("Tools", true)) {
            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text.toSlice() });
            zgui.popStyleColor(.{ .count = 1 });
            zgui.endMenu();
        }
        if (zgui.menuItem("About", .{})) {
            pixi.state.popups.about = true;
        }
    }
}
