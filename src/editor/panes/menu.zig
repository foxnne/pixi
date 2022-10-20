const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("pixi");
const settings = pixi.settings;
const filebrowser = @import("filebrowser");
const nfd = @import("nfd");

pub fn draw() void {
    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.window_padding, .v = .{ 10.0 * pixi.state.window.scale[0], 10.0 * pixi.state.window.scale[1] }});
    defer zgui.popStyleVar(.{ .count = 1 });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text_secondary.toSlice() });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.popup_bg, .c = pixi.state.style.foreground.toSlice() });
    defer zgui.popStyleColor(.{ .count = 2 });
    if (zgui.beginMenuBar()) {
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
        if (zgui.beginMenu("About", true)) {
            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text.toSlice() });
            zgui.popStyleColor(.{ .count = 1 });
            zgui.endMenu();
        }
        zgui.endMenuBar();
    }
}
