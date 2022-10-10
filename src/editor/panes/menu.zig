const zgui = @import("zgui");
const pixi = @import("pixi");
const settings = pixi.settings;

pub fn draw() void {
    if (zgui.beginMenuBar()) {
        if (zgui.beginMenu("File", true)) {
            if (zgui.menuItem("Open Folder...", .{
                .shortcut = "Cmd+F",
            })) {}
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
