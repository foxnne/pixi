const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");
const canvas = @import("../windows/canvas.zig");
const menubar = @import("../menubar.zig");

var new_canvas: canvas.Canvas = .{.width = 1, .height = 1, .tileWidth = 1, .tileHeight = 1};
var tiles_wide: i32 = 1;
var tiles_tall: i32 = 1;
        
pub fn draw () void {

    imgui.ogSetNextWindowSize(.{.x = 300, .y = 180}, imgui.ImGuiCond_Always);
    if (imgui.igBeginPopupModal("New File",&menubar.new_file_popup,imgui.ImGuiWindowFlags_Popup)){
        defer imgui.igEndPopup();

        
        _ = imgui.ogDrag(i32, "Tile Width", &new_canvas.tileWidth, 1, 1, 1024);
        _ = imgui.ogDrag(i32, "Tile Height", &new_canvas.tileHeight, 1, 1, 1024);
        _ = imgui.ogDrag(i32, "Tiles Wide", &tiles_wide, 1, 1, 1024);
        _ = imgui.ogDrag(i32, "Tiles Tall", &tiles_tall, 1, 1, 1024);
        
        if (imgui.ogButton("Create")) {

            new_canvas.height = new_canvas.tileHeight * tiles_tall;
            new_canvas.width = new_canvas.tileWidth * tiles_wide;

            //canvas.activeCanvas = new_canvas;
            //canvas.init();
            var name = std.fmt.allocPrint(upaya.mem.allocator, "New File{d}", .{canvas.getNumberOfFiles()}) catch unreachable;
            canvas.newFile(name, new_canvas);
            menubar.new_file_popup = false;
        }
    }

    // if (imgui.igBeginPopup("NewFile", imgui.ImGuiWindowFlags_Popup)){
    //     defer imgui.igEndPopup();

    //     imgui.igText("test");
    // }
}