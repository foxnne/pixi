const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");
const canvas = @import("../windows/canvas.zig");
const menubar = @import("../menubar.zig");

const types = @import("../types/types.zig");
const File = types.File;
const Layer = types.Layer;

const checkerColor1: upaya.math.Color = .{ .value = 0xFFDDDDDD };
const checkerColor2: upaya.math.Color = .{ .value = 0xFFEEEEEE };

var new_file: File = .{
    .name = "untitled",
    .width = 32,
    .height = 32,
    .tileWidth = 32,
    .tileHeight = 32,
    .background = undefined,
    .layers = undefined,
};
var tiles_wide: i32 = 1;
var tiles_tall: i32 = 1;

pub fn draw() void {

    const width = 300;
    const height = 150;
    const center = imgui.ogGetWindowCenter();
    imgui.ogSetNextWindowSize(.{ .x = width, .y = height }, imgui.ImGuiCond_Always);
    imgui.ogSetNextWindowPos(.{ .x = center.x - width/2, .y = center.y - height/ 2 }, imgui.ImGuiCond_Always, .{});
    if (imgui.igBeginPopupModal("New File", &menubar.new_file_popup, imgui.ImGuiWindowFlags_Popup | imgui.ImGuiWindowFlags_NoResize)) {
        defer imgui.igEndPopup();

        _ = imgui.ogDrag(i32, "Tile Width", &new_file.tileWidth, 1, 1, 1024);
        _ = imgui.ogDrag(i32, "Tile Height", &new_file.tileHeight, 1, 1, 1024);
        _ = imgui.ogDrag(i32, "Tiles Wide", &tiles_wide, 1, 1, 1024);
        _ = imgui.ogDrag(i32, "Tiles Tall", &tiles_tall, 1, 1, 1024);

        if (imgui.ogButton("Create")) {

            new_file.height = new_file.tileHeight * tiles_tall;
            new_file.width = new_file.tileWidth * tiles_wide;

            var name = std.fmt.allocPrint(upaya.mem.allocator, "untitled_{d}", .{canvas.getNumberOfFiles()}) catch unreachable;
            defer upaya.mem.allocator.free(name);

            new_file.name = std.mem.dupe(upaya.mem.allocator, u8, name) catch unreachable;
            new_file.background = upaya.Texture.initChecker(new_file.width, new_file.height, checkerColor1, checkerColor2);
            new_file.layers = std.ArrayList(Layer).init(upaya.mem.allocator);
            new_file.layers.append(.{.name = "Layer 0", .texture = upaya.Texture.initTransparent(new_file.width, new_file.height)}) catch unreachable;

            canvas.newFile(new_file);
            menubar.new_file_popup = false;
        }
    }
}
