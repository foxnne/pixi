const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

pub var foreground_color: upaya.math.Color = upaya.math.Color.black;
pub var background_color: upaya.math.Color = upaya.math.Color.white;


pub fn draw () void {

    imgui.ogSetNextWindowSize(.{.x = 100, .y = 500}, imgui.ImGuiCond_Always);

    if (imgui.igBegin("Toolbar", 0, imgui.ImGuiWindowFlags_NoResize)){
        defer imgui.igEnd();

        imgui.igText("Color");
        imgui.igSeparator();

        

        if (imgui.ogColoredButton(foreground_color.value, "     "))
        {

        }

        if (imgui.ogColoredButton(background_color.value, "     "))
        {

        }

        imgui.igSeparator();

        imgui.igText("Draw");
        imgui.igSeparator();


        imgui.igText("Select");
        imgui.igSeparator();

        imgui.igText("Animation");
        imgui.igSeparator();

        
        
        

    }

}