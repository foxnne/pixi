const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

const types = @import("../types/types.zig");
const editor = @import("../editor.zig");
const canvas = editor.canvas;
const sprites = editor.sprites;
const toolbar = editor.toolbar;

const Animation = types.Animation;

var animation_name_buffer: [128]u8 = [_]u8{0} ** 128;

pub const State = enum(usize) {
    pause = 0,
    play = 1,
};

pub var animation_state: State = .pause;
pub var new_animation_popup: bool = false;

var active_animation_index: usize = 0;

pub fn newAnimation(animation: *Animation) void {
    if (canvas.getActiveFile()) |file| {
        file.animations.insert(0, animation);
        active_animation_index = 0;
    }
}

pub fn getActiveAnimation() ?*Animation {
    if (canvas.getActiveFile()) |file| {
        if (active_animation_index < file.animations.items.len) {
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
                if (getActiveAnimation()) |animation| {
                    elapsed_time += imgui.igGetIO().DeltaTime;

                    if (elapsed_time > 1 / @intToFloat(f32, animation.fps)) {
                        elapsed_time = 0;

                        if (sprites.getActiveSprite()) |sprite| {
                            if (sprite.index + 1 >= animation.start + animation.length or sprite.index < animation.start) {
                                sprites.setActiveSpriteIndex(animation.start);
                            } else {
                                sprites.setActiveSpriteIndex(sprite.index + 1);
                            }
                        }
                    }
                }
            }

            // add new animation
            if (imgui.ogColoredButton(0x00000000, imgui.icons.plus_circle)) {
                var new_animation: Animation = .{
                    .name = "New Animation\u{0}",
                    .start = 0,
                    .length = 1,
                    .fps = 8,
                };

                file.animations.insert(0, new_animation) catch unreachable;
                toolbar.selected_tool = .animation;
            }

            imgui.igSameLine(0, 5);
            // delete selection 
            if (imgui.ogColoredButton(0x00000000, imgui.icons.minus_circle)) {
                _ = file.animations.swapRemove(active_animation_index);
                sprites.resetNames();
            }

            imgui.igSameLine(0, 5);
            var play_pause_icon = if (animation_state == .pause) imgui.icons.play else imgui.icons.pause;
            if (imgui.ogColoredButton(0x00000000, play_pause_icon)) {
                if (animation_state == .pause) {
                    animation_state = .play;
                } else animation_state = .pause;
            }
            imgui.igSeparator();

            for (file.animations.items) |animation, i| {
                imgui.igPushIDInt(@intCast(c_int, i));
                if (imgui.ogSelectableBool(@ptrCast([*c]const u8, animation.name), i == active_animation_index, imgui.ImGuiSelectableFlags_DrawHoveredWhenHeld, .{}))
                    active_animation_index = i;

                if (imgui.igBeginPopupContextItem("Animation Settings", imgui.ImGuiMouseButton_Right)) {
                    defer imgui.igEndPopup();
                    imgui.igText("Animation Settings");
                    imgui.igSeparator();

                    for (animation.name) |c, j|
                        animation_name_buffer[j] = c;

                    if (imgui.ogInputText("Name", &animation_name_buffer, animation_name_buffer.len)) {}

                    var name = std.mem.trimRight(u8, animation_name_buffer[0..], "\u{0}");
                    file.animations.items[i].name = std.fmt.allocPrintZ(upaya.mem.tmp_allocator, "{s}", .{name}) catch unreachable;

                    _ = imgui.ogDrag(usize, "Fps", &file.animations.items[i].fps, 0.1, 1, 60);
                    if (imgui.ogDrag(usize, "Start", &file.animations.items[i].start, 0.1, 0, file.sprites.items.len - 1)) {}
                    if (imgui.ogDrag(usize, "Length", &file.animations.items[i].length, 0.1, 1, file.sprites.items.len - 1 - file.animations.items[i].start)) {}

                    //TODO: Only trigger this if start, length, or name changes. for some reason the bool for ogInputText isn't true on every character change (missing last)
                    sprites.resetNames();
                }

                imgui.igPopID();
            }
        }
    }

    if (new_animation_popup)
        imgui.igOpenPopup("New Animation");
}
