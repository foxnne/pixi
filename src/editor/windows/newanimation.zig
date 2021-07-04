const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

const editor = @import("../editor.zig");
const canvas = editor.canvas;
const animations = editor.animations;
const sprites = editor.sprites;


const types = @import("../types/types.zig");
const File = types.File;
const Layer = types.Layer;
const Sprite = types.Sprite;
const Animation = types.Animation;

var start_index: i32 = 0;
var length: i32 = 1;

var name_buffer: [128]u8 = [_]u8{0} ** 128;

var new_animation: Animation = .{
    .name = "New Animation",
    .start = 0,
    .length = 1,
    .fps = 8,
};

pub fn draw() void {
    if (canvas.getActiveFile()) |file| {
        const width = 400;
        const height = 150;
        const center = imgui.ogGetWindowCenter();
        imgui.ogSetNextWindowSize(.{ .x = width, .y = height }, imgui.ImGuiCond_Always);
        imgui.ogSetNextWindowPos(.{ .x = center.x - width / 2, .y = center.y - height / 2 }, imgui.ImGuiCond_Appearing, .{});
        if (imgui.igBeginPopupModal("New Animation", &animations.new_animation_popup, imgui.ImGuiWindowFlags_Popup | imgui.ImGuiWindowFlags_NoResize)) {
            defer imgui.igEndPopup();


            
            if (imgui.igInputTextWithHint("Name", "New Animation", &name_buffer, name_buffer.len, imgui.ImGuiInputTextFlags_None, null, null)) {
                name_buffer[127] = 0;
            }

            _ = imgui.ogDrag(usize, "Start Index", &new_animation.start, 0.1, 0, file.sprites.items.len - 1);
            if (new_animation.length > (file.sprites.items.len - 1) - new_animation.start) new_animation.length = (file.sprites.items.len - 1) - new_animation.start;
            _ = imgui.ogDrag(usize, "Length", &new_animation.length, 0.1, 0, (file.sprites.items.len - 1) - new_animation.start);

            if (imgui.ogButton("Create")) {
                var name = std.mem.trimRight(u8, name_buffer[0..], "\u{0}");
                new_animation.name = std.fmt.allocPrintZ(upaya.mem.tmp_allocator, "{s}", .{name}) catch unreachable;
                file.animations.append(new_animation) catch unreachable;
                animations.new_animation_popup = false;
                var i: usize = 0;
                while (i < new_animation.length) : (i += 1){
                    
                        file.sprites.items[i + new_animation.start].name = std.fmt.allocPrintZ(upaya.mem.tmp_allocator, "{s}_{d}", .{name, i}) catch unreachable;
                    
                }
            }
        }
    }
}
