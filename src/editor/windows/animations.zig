const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

const types = @import("../types/types.zig");
const editor = @import("../editor.zig");
const canvas = editor.canvas;
const sprites = editor.sprites;

const Animation = types.Animation;

pub const State = enum(usize) {
    pause = 0,
    play = 1,
};

pub var animation_state: State = .pause;
pub var new_animation_popup: bool = false;

var active_animation_index: usize = 0;

pub fn newAnimation (animation: *Animation) void {
    if (canvas.getActiveFile()) |file| {
        file.animations.insert(0, animation);
        active_animation_index = 0;
    }
}

pub fn getAnimation () ?*Animation {
    if (canvas.getActiveFile()) |file| {
        if (active_animation_index < file.animations.items.len){
            return &file.animations.items[active_animation_index];
        }
        
    }
    return null;
}

var elapsed_time: f32 = 0;

pub fn draw() void {
    if (imgui.igBegin("Animations", 0, imgui.ImGuiWindowFlags_NoResize)) {
        defer imgui.igEnd();

        if (canvas.getActiveFile()) |file| {

            // advance frame if playing
            if (animation_state == .play) {
                if (getAnimation()) |animation| {
                    elapsed_time += imgui.igGetIO().DeltaTime;

                    if (elapsed_time > 1 / @intToFloat(f32, animation.fps)) {
                        elapsed_time = 0;

                        if (sprites.getActiveSprite()) |sprite| {

                            if (sprite.index + 1 >= animation.start + animation.length  or sprite.index < animation.start)
                            {
                                sprites.setActiveSpriteIndex(animation.start);
                            } else {
                                sprites.setActiveSpriteIndex(sprite.index + 1);
                            }

                        }

                    }
                }
            }

            if (imgui.ogColoredButton(0x00000000, imgui.icons.plus_circle)) {
                new_animation_popup = true;
            }

            imgui.igSameLine(0, 5);
            if (imgui.ogColoredButton(0x00000000, imgui.icons.minus_circle)) {}
            imgui.igSameLine(0, 5);
            var play_pause_icon = if (animation_state == .pause) imgui.icons.play else imgui.icons.pause;
            if (imgui.ogColoredButton(0x00000000, play_pause_icon)) {
                if (animation_state == .pause) {
                    animation_state = .play;
                } else animation_state = .pause;
            }
            imgui.igSeparator();

            for (file.animations.items) |animation, i| {

                if (imgui.ogSelectableBool(@ptrCast([*c]const u8, animation.name), i == active_animation_index, imgui.ImGuiSelectableFlags_DrawHoveredWhenHeld, .{}))
                    active_animation_index = i;


                
            }
        }
    }

    if (new_animation_popup)
        imgui.igOpenPopup("New Animation");
}
