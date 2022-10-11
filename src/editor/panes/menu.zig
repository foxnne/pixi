const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("pixi");
const settings = pixi.settings;
const filebrowser = @import("filebrowser");
const nfd = @import("nfd");

pub fn draw() void {
    if (zgui.beginMenuBar()) {
        if (zgui.beginMenu("File", true)) {
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

            zgui.endMenu();
        }
        if (zgui.beginMenu("Edit", true)) {
            zgui.endMenu();
        }
        if (zgui.beginMenu("Tools", true)) {
            zgui.endMenu();
        }
        if (zgui.beginMenu("About", true)) {
            zgui.endMenu();
        }
        zgui.endMenuBar();
    }
}
