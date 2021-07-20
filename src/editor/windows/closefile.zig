const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

const editor = @import("../editor.zig");
const menubar = editor.menubar;
const canvas = editor.canvas;

pub fn draw() void {
    const width = 300;
    const height = 150;
    const center = imgui.ogGetWindowCenter();
    imgui.ogSetNextWindowSize(.{ .x = width, .y = height }, imgui.ImGuiCond_Appearing);
    imgui.ogSetNextWindowPos(.{ .x = center.x - width / 2, .y = center.y - height / 2 }, imgui.ImGuiCond_Appearing, .{});

    if (menubar.close_file_popup)
        imgui.igOpenPopup("Close File?");

    if (imgui.igBeginPopupModal("Close File?", &menubar.close_file_popup, imgui.ImGuiWindowFlags_Popup | imgui.ImGuiWindowFlags_NoResize | imgui.ImGuiWindowFlags_Modal)) {
        defer imgui.igEndPopup();

        if (canvas.getActiveFile()) |file| {
            var close_message = std.fmt.allocPrintZ(upaya.mem.allocator, "{s} is not saved, are you sure you want to close?", .{file.name}) catch unreachable;
            defer upaya.mem.allocator.free(close_message);
            imgui.igTextWrapped(@ptrCast([*c]const u8, close_message));
            imgui.igSeparator();
            imgui.ogDummy(.{.x = 5, .y = 5});

            imgui.igSetCursorPosX(imgui.ogGetWindowCenter().x - 20);
            if (imgui.ogButton("Save")) {
                menubar.close_file_popup = false;
                if (editor.save())
                canvas.closeFile(canvas.getActiveFileIndex());
            }
            imgui.igSetCursorPosX(imgui.ogGetWindowCenter().x - 40);
            if (imgui.ogButton("Don't Save")) {
                menubar.close_file_popup = false;
                canvas.closeFile(canvas.getActiveFileIndex());
            }
            imgui.igSetCursorPosX(imgui.ogGetWindowCenter().x - 25);
            if (imgui.ogButton("Cancel")) {
                menubar.close_file_popup = false;
            }
        }
    }
}
