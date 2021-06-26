const std = @import("std");
const imgui = @import("imgui");
const sokol = @import("sokol");

const editor = @import("editor.zig");

const new = @import("windows/new.zig");
const canvas = @import("windows/canvas.zig");

pub var new_file_popup: bool = false;
pub var demo_window: bool = false;

pub fn draw() void {
    if (imgui.igBeginMenuBar()) {
        defer imgui.igEndMenuBar();

        if (imgui.igBeginMenu("File", true)) {
            defer imgui.igEndMenu();

            if (imgui.igMenuItemBool("New " ++ imgui.icons.file, "cmd+n", false, true))
                new_file_popup = true;

            if (imgui.igMenuItemBool("Open... " ++ imgui.icons.box_open, "", false, true)) {}

            if (imgui.igMenuItemBool("Save", "cmd+s", false, true)) {}
            if (imgui.igMenuItemBool("Save As...", "cmd+shift+s", false, true)) {}

            imgui.igSeparator();

            if (imgui.igBeginMenu("Export", canvas.getNumberOfFiles() > 0)) {
                defer imgui.igEndMenu();

                if (imgui.igMenuItemBool("Image", "", false, true)) {}
            }

            if (imgui.igBeginMenu("Import", canvas.getNumberOfFiles() > 0)) {
                defer imgui.igEndMenu();

                if (imgui.igMenuItemBool("Image", "", false, true)) {}
            }

            imgui.igSeparator();

            if (imgui.igMenuItemBool("Close " ++ imgui.icons.door_closed, "cmd+q", false, true)) {
                editor.shutdown();
            }
            
        }

        if (imgui.igBeginMenu("Document", true)) {
            defer imgui.igEndMenu();

            if(imgui.igMenuItemBool("Resize Canvas...", "", false, canvas.getNumberOfFiles() > 0)) {

            }
        }

        if (imgui.igBeginMenu("View", true)) {
            defer imgui.igEndMenu();

            if (imgui.igMenuItemBool("Reset Views", 0, false, true)) {
                editor.resetDockLayout();
            }

            if (imgui.igMenuItemBool("IMGUI Demo Window", 0, false, true)) {
                demo_window = !demo_window;
            }
        }
    }

    if (new_file_popup)
        imgui.igOpenPopup("New File");

    if (demo_window)
        imgui.igShowDemoWindow(&demo_window);
}
