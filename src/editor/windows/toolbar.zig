const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

pub var foreground_color: upaya.math.Color = upaya.math.Color.black;
pub var background_color: upaya.math.Color = upaya.math.Color.white;

pub var selected_tool = Tool.arrow;

pub const Tool = enum {
    arrow = 0,
    hand = 1,
    pencil = 2,
    eraser = 3,
    select = 4,
};

pub fn draw() void {
    imgui.ogSetNextWindowSize(.{ .x = 100, .y = 500 }, imgui.ImGuiCond_Always);

    

    if (imgui.igBegin("Toolbar", 0, imgui.ImGuiWindowFlags_NoResize)) {
        defer imgui.igEnd();

        imgui.igText("Color");
        imgui.igSeparator();

        if (imgui.ogColoredButton(foreground_color.value, "     ")) {}

        if (imgui.ogColoredButton(background_color.value, "     ")) {}

        imgui.igSeparator();

        imgui.igText("Draw");
        imgui.igSeparator();

        if (imgui.ogSelectableBool(imgui.icons.mouse_pointer, selected_tool == .arrow, imgui.ImGuiSelectableFlags_None, .{.x = 0, .y = 0}))
            selected_tool = .arrow;
    
        if (imgui.ogSelectableBool(imgui.icons.hand_pointer, selected_tool == .hand, imgui.ImGuiSelectableFlags_None, .{.x = 0, .y = 0}))
            selected_tool = .hand;
        
        if (imgui.ogSelectableBool(imgui.icons.pencil_alt, selected_tool == .pencil, imgui.ImGuiSelectableFlags_None, .{.x = 0, .y = 0}))
            selected_tool = .pencil;

        if (imgui.ogSelectableBool(imgui.icons.eraser, selected_tool == .eraser, imgui.ImGuiSelectableFlags_None, .{.x = 0, .y = 0}))
            selected_tool = .eraser;

        imgui.igText("Select");
        imgui.igSeparator();

        if (imgui.ogSelectableBool(imgui.icons.vector_square, selected_tool == .select, imgui.ImGuiSelectableFlags_None, .{.x = 0, .y = 0}))
            selected_tool = .select;



        imgui.igText("Animation");
        imgui.igSeparator();
    }
}
