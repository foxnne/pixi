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

pub fn resetNames() void {
    if (canvas.getActiveFile()) |file| {
        for (file.sprites.items) |_, i| {
            const file_name = std.mem.trimRight(u8, file.name, "\u{0}");
            const name = std.fmt.allocPrint(upaya.mem.allocator, "{s}_{d}", .{ file_name, i }) catch unreachable;
            file.sprites.items[i].name = upaya.mem.allocator.dupeZ(u8, name) catch unreachable;
            upaya.mem.allocator.free(name);
        }

        for (file.animations.items) |animation| {
            var i = animation.start;
            while (i < animation.start + animation.length) : (i += 1) {
                const animation_index = i - animation.start;

                var animation_name = std.mem.trimRight(u8, animation.name, "\u{0}");

                const name = std.fmt.allocPrint(upaya.mem.allocator, "{s}_{d}", .{ animation_name, animation_index }) catch unreachable;
                file.sprites.items[i].name = upaya.mem.allocator.dupeZ(u8, name) catch unreachable;
                upaya.mem.allocator.free(name);
            }
        }
    }
}

pub fn draw() void {
    if (imgui.igBegin("Sprites", 0, imgui.ImGuiWindowFlags_NoResize)) {
        defer imgui.igEnd();

        if (canvas.getActiveFile()) |file| {
            for (file.sprites.items) |sprite, i| {
                imgui.igPushIDInt(@intCast(c_int, i));

                const sprite_name_z = upaya.mem.allocator.dupeZ(u8, sprite.name) catch unreachable;
                defer upaya.mem.allocator.free(sprite_name_z);
                if (imgui.ogSelectableBool(@ptrCast([*c]const u8, sprite_name_z), active_sprite_index == i, imgui.ImGuiSelectableFlags_None, .{}))
                    active_sprite_index = i;

                if (set_from_outside and active_sprite_index == i and !imgui.igIsItemVisible() and !imgui.igIsWindowHovered(imgui.ImGuiHoveredFlags_None)) {
                    imgui.igSetScrollHereY(0.5);
                    set_from_outside = false;
                }

                if (imgui.igBeginPopupContextItem("Sprite Settings", imgui.ImGuiMouseButton_Right)) {
                    defer imgui.igEndPopup();

                    //TODO: make undoable, confirmation of settings change button triggers so undo queue isnt filled with tiny changes
                    imgui.igText("Sprite Settings");
                    imgui.igSeparator();

                    imgui.igText("Origin");
                    _ = imgui.ogDrag(f32, "Origin X", &file.sprites.items[i].origin_x, 0.1, 0, @intToFloat(f32, file.tileWidth));
                    _ = imgui.ogDrag(f32, "Origin Y", &file.sprites.items[i].origin_y, 0.1, 0, @intToFloat(f32, file.tileHeight));
                }
                imgui.igPopID();
            }

            if (imgui.igIsWindowFocused(imgui.ImGuiFocusedFlags_None)) {

                // down/right arrow changes sprite
                if (imgui.ogKeyPressed(upaya.sokol.SAPP_KEYCODE_DOWN) or imgui.ogKeyPressed(upaya.sokol.SAPP_KEYCODE_RIGHT)) {
                    setActiveSpriteIndex(active_sprite_index + 1);
                }

                // up/left arrow changes sprite
                if ((imgui.ogKeyPressed(upaya.sokol.SAPP_KEYCODE_UP)or imgui.ogKeyPressed(upaya.sokol.SAPP_KEYCODE_LEFT) )and @intCast(i32, active_sprite_index) - 1 >= 0) {
                    setActiveSpriteIndex(active_sprite_index - 1);
                }
            }
        }
    }
}
