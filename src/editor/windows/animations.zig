const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

const canvas = @import("canvas.zig");

var active_animation_index: usize = 0;

pub fn draw() void {
    if (imgui.igBegin("Animations", 0, imgui.ImGuiWindowFlags_NoResize)) {
        defer imgui.igEnd();

        if (canvas.getActiveFile()) |_| {
            if (imgui.ogColoredButton(0x00000000, imgui.icons.plus_circle)) {}
            imgui.igSameLine(0, 5);
            if (imgui.ogColoredButton(0x00000000, imgui.icons.minus_circle)) {}
            imgui.igSameLine(0, 5);
            if (imgui.ogColoredButton(0x00000000, imgui.icons.play_circle)) {}
            
        

            imgui.igSeparator();
        }
    }
}
