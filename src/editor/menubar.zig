const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");
const sokol = @import("sokol");

const editor = @import("editor.zig");
const canvas = editor.canvas;

pub var new_file_popup: bool = false;
pub var close_file_popup: bool = false;
pub var slice_popup: bool = false;
pub var demo_window: bool = false;

pub fn draw() void {
    if (imgui.igBeginMenuBar()) {
        defer imgui.igEndMenuBar();

        const mod_name = if (std.builtin.os.tag == .windows) "ctrl" else if (std.builtin.os.tag == .linux) "super" else "cmd";

        if (imgui.igBeginMenu("File", true)) {
            defer imgui.igEndMenu();

            if (imgui.igMenuItemBool(imgui.icons.file ++ "  New", mod_name ++ "+n", false, true))
                new_file_popup = true;

            if (imgui.igMenuItemBool(imgui.icons.box_open ++ " Open...", "", false, true)) {
                // Temporary flags that get reset on next update.
                // Needed for file dialogs.
                upaya.inputBlocked = true;
                upaya.inputClearRequired = true;
                var path = upaya.filebrowser.openFileDialog("Choose a file to open...", "", "*.pixi");
                if (path != null){
                    var in_path = path[0..std.mem.len(path)];
                    if (std.mem.endsWith(u8, in_path, ".pixi")) {
                        editor.load(in_path);
                    }

                }
                
            }

            if (imgui.igMenuItemBool("Save", mod_name ++ "+s", false, true)) {
                _ = editor.save();
            }
            if (imgui.igMenuItemBool("Save As...", mod_name ++ "+shift+s", false, true)) {
                if (canvas.getActiveFile()) |file| {
                    file.path = null;
                }
                _ = editor.save();
            }

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

            if (imgui.igMenuItemBool(imgui.icons.door_closed ++ " Close", if (std.builtin.os.tag == .windows) "alt+f4" else mod_name ++ "+q", false, true)) {
                editor.shutdown();
            }
        }

        if (imgui.igBeginMenu("Edit", true)) {
            defer imgui.igEndMenu();

            var numUndos: usize = 0;
            var numRedos: usize = 0;

            if (canvas.getActiveFile()) |file| {
                numUndos = file.history.getNumberOfUndos();
                numRedos = file.history.getNumberOfRedos();
            }

            if (imgui.igMenuItemBool(imgui.icons.undo ++ " Undo", mod_name ++ "+z", false, numUndos > 0)) {
                if (canvas.getActiveFile()) |file| {
                    file.history.undo();
                }
            }

            if (imgui.igMenuItemBool(imgui.icons.redo ++ " Redo", mod_name ++ "+shift+z", false, numRedos > 0)) {
                if (canvas.getActiveFile()) |file| {
                    file.history.redo();
                }
            }
            imgui.igSeparator();
        }

        if (imgui.igBeginMenu("Document", true)) {
            defer imgui.igEndMenu();

            if (imgui.igMenuItemBool(imgui.icons.arrows_alt ++ " Resize Canvas...", "", false, canvas.getNumberOfFiles() > 0)) {}

            var sliceable: bool = false;
            if (canvas.getActiveFile()) |file| {
                if (file.width == file.tileWidth and file.height == file.tileHeight)
                    sliceable = true;
            }

            if (imgui.igMenuItemBool(imgui.icons.pizza_slice ++ " Slice...", "", false, sliceable)) {
                slice_popup = true;
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

    if (slice_popup)
        imgui.igOpenPopup("Slice");

    if (demo_window)
        imgui.igShowDemoWindow(&demo_window);
}
