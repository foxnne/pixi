const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("pixi");
const settings = pixi.settings;
const filebrowser = @import("filebrowser");

pub fn draw() void {
    if (zgui.beginMenuBar()) {
        if (zgui.beginMenu("File", true)) {
            if (zgui.menuItem("Open Folder...", .{
                .shortcut = "Cmd+F",
            })) {
                const folder = filebrowser.tinyfd_selectFolderDialog("Open project folder...", null);
                if (folder != null) {
                    pixi.editor.setProjectFolder(folder);
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
