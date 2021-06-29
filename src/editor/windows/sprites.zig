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
        if (active_sprite_index >= file.sprites.items.len)
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

                if (imgui.ogSelectableBool(@ptrCast([*c]const u8, sprite.name), active_sprite_index == i, imgui.ImGuiSelectableFlags_None, .{}))
                    active_sprite_index = i;

         

                if (set_from_outside and active_sprite_index == i) {
                    imgui.igSetScrollHereY(0.5);
                    set_from_outside = false;
                }

                

                if (imgui.igBeginPopupContextItem(@ptrCast([*c]const u8, sprite.name), imgui.ImGuiMouseButton_Right)) {
                    defer imgui.igEndPopup();
                }

                
            }
        }
    }
}
