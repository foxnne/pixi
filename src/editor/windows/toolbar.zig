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
    if (imgui.igBegin("Toolbar", 0, imgui.ImGuiWindowFlags_NoResize)) {
        defer imgui.igEnd();

        const space = 5;
        const toolbar_half_width = (imgui.igGetWindowContentRegionWidth() / 2) - (space / 2);

        imgui.igText("Color");
        imgui.igSeparator();

        //imgui.ogAddRectFilled(imgui.igGetWindowDrawList(), .{}, .{.x = toolbar_half_width, .y = 40}, foreground_color.value);
        

        if (imgui.ogColoredButtonEx(foreground_color.value, "", .{.x = toolbar_half_width, .y = 40})) {}
        imgui.igSameLine(0, space);
        if (imgui.ogColoredButtonEx(background_color.value, "", .{.x = toolbar_half_width, .y = 40})) {}

        imgui.igSeparator();

        imgui.igText("Draw");
        imgui.igSeparator();

        imgui.ogPushStyleVarVec2(imgui.ImGuiStyleVar_SelectableTextAlign, .{.x = 0.5, .y = 0.5});

        if (imgui.ogSelectableBool(imgui.icons.mouse_pointer, selected_tool == .arrow, imgui.ImGuiSelectableFlags_None, .{ .x = toolbar_half_width, .y = 20 }))
            selected_tool = .arrow;
        imgui.igSameLine(0, space);
        if (imgui.ogSelectableBool(imgui.icons.hand_pointer, selected_tool == .hand, imgui.ImGuiSelectableFlags_None, .{ .x = toolbar_half_width, .y = 20 }))
            selected_tool = .hand;

        if (imgui.ogSelectableBool(imgui.icons.pencil_alt, selected_tool == .pencil, imgui.ImGuiSelectableFlags_None, .{ .x = toolbar_half_width, .y = 20 }))
            selected_tool = .pencil;
        imgui.igSameLine(0, space);
        if (imgui.ogSelectableBool(imgui.icons.eraser, selected_tool == .eraser, imgui.ImGuiSelectableFlags_None, .{ .x = toolbar_half_width, .y = 20 }))
            selected_tool = .eraser;

        imgui.igPopStyleVar(1);
        imgui.igText("Select");
        imgui.igSeparator();

        if (imgui.ogSelectableBool(imgui.icons.vector_square, selected_tool == .select, imgui.ImGuiSelectableFlags_None, .{ .x = 0, .y = 0 }))
            selected_tool = .select;

        imgui.igText("Animation");
        imgui.igSeparator();
    }
}
