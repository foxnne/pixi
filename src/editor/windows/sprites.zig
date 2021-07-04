const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

const types = @import("../types/types.zig");
const Sprite = types.Sprite;

const editor = @import("../editor.zig");
const canvas = @import("../windows/canvas.zig");

var active_sprite_index: usize = 0;
var set_from_outside: bool = false;

pub fn getNumSprites() usize {
    if (canvas.getActiveFile()) |file| {
        return file.sprites.items.len;
    } else return 0;
}

pub fn getActiveSprite() ?*Sprite {
    if (canvas.getActiveFile()) |file| {

        if (file.sprites.items.len == 0)
            return null;

        if (active_sprite_index >= file.sprites.items.len and active_sprite_index > 0)
            active_sprite_index = file.sprites.items.len - 1;
        
        return &file.sprites.items[active_sprite_index];
        
    } else return null;
}

pub fn setActiveSpriteIndex(index: usize) void {
    if (canvas.getActiveFile()) |file| {
        if (file.sprites.items.len > index) {
            active_sprite_index = index;
            set_from_outside = true;
        }
    }
}

pub fn draw() void {
    if (imgui.igBegin("Sprites", 0, imgui.ImGuiWindowFlags_NoResize)) {
        defer imgui.igEnd();

        if (canvas.getActiveFile()) |file| {

            for (file.sprites.items) |sprite, i| {
                
                imgui.igPushIDInt(@intCast(c_int, i));
                if (imgui.ogSelectableBool(@ptrCast([*c]const u8, sprite.name), active_sprite_index == i, imgui.ImGuiSelectableFlags_None, .{}))
                    active_sprite_index = i;
                imgui.igPopID();
                
                if (set_from_outside and active_sprite_index == i and !imgui.igIsItemVisible()) {
                    imgui.igSetScrollHereY(0.5);
                    set_from_outside = false;
                }

                imgui.igPushIDInt(@intCast(c_int, i));
                if (imgui.igBeginPopupContextItem(@ptrCast([*c]const u8, sprite.name), imgui.ImGuiMouseButton_Right)) {
                    defer imgui.igEndPopup();

                    imgui.igText("Sprite Settings");
                    imgui.igSeparator();

                    imgui.igText("Origin");
                    _ = imgui.ogDrag(f32, "Origin X", &file.sprites.items[i].origin_x, 0.1, 0, @intToFloat(f32, file.tileWidth));
                    _ = imgui.ogDrag(f32, "Origin Y", &file.sprites.items[i].origin_y, 0.1, 0, @intToFloat(f32, file.tileHeight));


                }
                imgui.igPopID();

                
            }
        }
    }
}
