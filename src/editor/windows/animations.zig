const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

pub fn draw () void {

    if (imgui.igBegin("Animations", 0, imgui.ImGuiWindowFlags_NoResize)){
        defer imgui.igEnd();

    }

}