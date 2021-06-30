const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");
const sokol = @import("sokol");

const editor = @import("editor.zig");

const new = @import("windows/new.zig");
const canvas = @import("windows/canvas.zig");

pub var new_file_popup: bool = false;
pub var slice_popup: bool = false;
pub var demo_window: bool = false;

pub fn draw() void {
    if (imgui.igBeginMenuBar()) {
        defer imgui.igEndMenuBar();

        var header_color = editor.highlight_color;
        var header_hover_color = editor.highlight_hover_color;
        header_color = upaya.colors.hsvShiftColor(header_color, 0.8, 0, 0);
        header_hover_color = upaya.colors.hsvShiftColor(header_color, 0.8, 0, 0);
        imgui.igPushStyleColorVec4(imgui.ImGuiCol_Header, header_color);
        imgui.igPushStyleColorVec4(imgui.ImGuiCol_HeaderActive, header_hover_color);
        imgui.igPushStyleColorVec4(imgui.ImGuiCol_HeaderHovered, header_hover_color);

        if (imgui.igBeginMenu("File", true)) {
            defer imgui.igEndMenu();

            if (imgui.igMenuItemBool(imgui.icons.file ++ " New", "cmd+n", false, true))
                new_file_popup = true;

            if (imgui.igMenuItemBool(imgui.icons.box_open ++ " Open...", "", false, true)) {}

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

            if (imgui.igMenuItemBool(imgui.icons.door_closed ++ " Close", "cmd+q", false, true)) {
                editor.shutdown();
            }
        }

        if (imgui.igBeginMenu("Document", true)) {
            defer imgui.igEndMenu();

            if (imgui.igMenuItemBool(imgui.icons.square ++ " Resize Canvas...", "", false, canvas.getNumberOfFiles() > 0)) {}

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

    imgui.igPopStyleColor(3);

    if (new_file_popup)
        imgui.igOpenPopup("New File");

    if (slice_popup)
        imgui.igOpenPopup("Slice");

    if (demo_window)
        imgui.igShowDemoWindow(&demo_window);
}
