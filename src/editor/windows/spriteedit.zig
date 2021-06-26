const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

pub fn draw () void {

    if (imgui.igBegin("SpriteEdit", 0, imgui.ImGuiWindowFlags_None)){
        defer imgui.igEnd();

    }

}