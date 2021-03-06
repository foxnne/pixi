const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

const editor = @import("../editor.zig");
const canvas = editor.canvas;
const menubar = editor.menubar;
const sprites = editor.sprites;

const types = @import("../types/types.zig");
const File = types.File;
const Layer = types.Layer;
const Sprite = types.Sprite;

var tiles_wide: i32 = 1;
var tiles_tall: i32 = 1;

pub fn draw() void {
    if (canvas.getActiveFile()) |file| {
        const width = 300;
        const height = 110;
        const center = imgui.ogGetWindowCenter();
        imgui.ogSetNextWindowSize(.{ .x = width, .y = height }, imgui.ImGuiCond_Appearing);
        imgui.ogSetNextWindowPos(.{ .x = center.x - width / 2, .y = center.y - height / 2 }, imgui.ImGuiCond_Appearing, .{});
        if (imgui.igBeginPopupModal("Slice", &menubar.slice_popup, imgui.ImGuiWindowFlags_Popup | imgui.ImGuiWindowFlags_NoResize)) {
            defer imgui.igEndPopup();

            _ = imgui.ogDrag(i32, "Tiles Wide", &tiles_wide, 1, 1, 1024);
            _ = imgui.ogDrag(i32, "Tiles Tall", &tiles_tall, 1, 1, 1024);

            var remainder_height = @mod(file.height, tiles_tall);
            var remainder_width = @mod(file.width, tiles_wide);

            imgui.ogPushDisabled(remainder_height != 0 or remainder_width != 0);

            imgui.igSeparator();
            
            if (imgui.ogButtonEx("Slice", .{.x = imgui.igGetWindowWidth() - 20, .y = 20})) {
                sprites.setActiveSpriteIndex(0);

                file.tileHeight = @divExact(file.height, tiles_tall);
                file.tileWidth = @divExact(file.width, tiles_wide);

                file.sprites.clearRetainingCapacity();

                var i: usize = 0;
                while (i < tiles_tall * tiles_wide) : (i += 1) {
                    var name = std.fmt.allocPrint(upaya.mem.allocator, "{s}_{d}", .{ file.name, i }) catch unreachable;
                    defer upaya.mem.allocator.free(name);
                    file.sprites.append(.{
                        .name = upaya.mem.allocator.dupe(u8, name) catch unreachable,
                        .index = i,
                        .origin_x = @intToFloat(f32, @divTrunc(file.tileWidth, 2)),
                        .origin_y = @intToFloat(f32, @divTrunc(file.tileHeight, 2)),
                    }) catch unreachable;
                }

                menubar.slice_popup = false;
            }
            if (remainder_height != 0 or remainder_width != 0) {
                
                imgui.igBeginTooltip();
                imgui.igText("Width or Height not divisible by Tiles wide or Tiles tall!");
                imgui.igEndTooltip();

                imgui.ogPopDisabled(true);
            }

            
        }
    }
}
