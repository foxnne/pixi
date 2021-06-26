const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

var open_foreground: bool = false;
var open_background: bool = false;

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

        //color tools
        imgui.igText("Color");
        imgui.igSeparator();

        imgui.igPushStyleColorU32(imgui.ImGuiCol_ButtonHovered, foreground_color.value);
        imgui.igPushStyleColorU32(imgui.ImGuiCol_ButtonActive, foreground_color.value);
        if (imgui.ogColoredButtonEx(foreground_color.value, "", .{ .x = toolbar_half_width, .y = 40 }))
            open_foreground = true;
        imgui.igPopStyleColor(2);

        if (imgui.igBeginPopup("Foreground Color", imgui.ImGuiWindowFlags_None)) {
            defer imgui.igEndPopup();
            var color: imgui.ImVec4 = foreground_color.asImVec4();
            if (imgui.igColorPicker3("Foreground", @ptrCast([*c]f32, &color), imgui.ImGuiColorEditFlags_DisplayRGB)) {
                foreground_color = upaya.math.Color.fromRgba(color.x, color.y, color.z, color.w);
            }
        }

        imgui.igSameLine(0, space);
        imgui.igPushStyleColorU32(imgui.ImGuiCol_ButtonHovered, background_color.value);
        if (imgui.ogColoredButtonEx(background_color.value, "", .{ .x = toolbar_half_width, .y = 40 })) {}
        imgui.igPopStyleColor(1);

        // draw tools
        imgui.igText("Draw");
        imgui.igSeparator();
        imgui.ogPushStyleVarVec2(imgui.ImGuiStyleVar_SelectableTextAlign, .{ .x = 0.5, .y = 0.5 });

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

        //animation tools
        imgui.igText("Animation");
        imgui.igSeparator();
    }

    if (open_foreground) {
        imgui.igOpenPopup("Foreground Color");
    }
}
