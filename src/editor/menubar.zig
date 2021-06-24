const std = @import("std");
const imgui = @import("imgui");

const new = @import("windows/new.zig");
const editor = @import("editor.zig");

pub var new_file_popup: bool = false;
pub var demo_window: bool = false;

pub fn draw() void {

    if (imgui.igBeginMenuBar()) {
        defer imgui.igEndMenuBar();

        if (imgui.igBeginMenu("File", true)) {
            defer imgui.igEndMenu();

            if (imgui.igMenuItemBool("New " ++ imgui.icons.file, "cmd+n", false, true)){
                new_file_popup = true;
            }           
     
        }

        if (imgui.igBeginMenu("View", true)) {
            defer imgui.igEndMenu();

            if (imgui.igMenuItemBool("Reset Views", 0, false, true)){

                editor.resetDockLayout();
            }

            if (imgui.igMenuItemBool("IMGUI Demo Window", 0, false, true)){

                demo_window = !demo_window;
            }
        }
    }

    if (new_file_popup)
        imgui.igOpenPopup("New File");

    if (demo_window)
        imgui.igShowDemoWindow(&demo_window);
    



}