const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

pub var foreground_color: upaya.math.Color = upaya.math.Color.black;
pub var background_color: upaya.math.Color = upaya.math.Color.white;

pub var selected_tool = Tool.arrow;
pub var contiguous_fill: bool = true;

pub const Tool = enum(usize) {
    arrow = 0,
    hand = 1,
    selection = 2,
    wand = 3,

    pencil = 4,
    eraser = 5,
    bucket = 6,
    dropper = 7,

    animation = 8,
};

pub fn draw() void {
    if (imgui.igBegin("Toolbar", 0, imgui.ImGuiWindowFlags_NoResize)) {
        defer imgui.igEnd();

        const space = 5;
        const toolbar_half_width = (imgui.igGetWindowContentRegionWidth() / 2) - (space / 2);

        //color tools
        imgui.igText("Color");
        imgui.igSeparator();

        // foreground color and picker
        var cursor_pos = imgui.ogGetCursorScreenPos();
        imgui.ogDummy(.{ .x = toolbar_half_width, .y = 40 });
        imgui.ogAddRectFilled(imgui.igGetWindowDrawList(), cursor_pos, .{ .x = toolbar_half_width, .y = 40 }, foreground_color.value);

        if (imgui.igBeginPopupContextItem("Foreground Context Menu", imgui.ImGuiMouseButton_Left)) {
            defer imgui.igEndPopup();
            var color: imgui.ImVec4 = foreground_color.asImVec4();
            if (imgui.igColorPicker3("Foreground", @ptrCast([*c]f32, &color), imgui.ImGuiColorEditFlags_PickerHueWheel)) {
                foreground_color = upaya.math.Color.fromRgba(color.x, color.y, color.z, color.w);
            }
        }

        // background color and picker
        imgui.igSameLine(0, space);
        cursor_pos = imgui.ogGetCursorScreenPos();
        imgui.ogDummy(.{ .x = toolbar_half_width, .y = 40 });
        imgui.ogAddRectFilled(imgui.igGetWindowDrawList(), cursor_pos, .{ .x = toolbar_half_width, .y = 40 }, background_color.value);

        if (imgui.igBeginPopupContextItem("Background Context Menu", imgui.ImGuiMouseButton_Left)) {
            defer imgui.igEndPopup();
            var color: imgui.ImVec4 = background_color.asImVec4();
            if (imgui.igColorPicker3("Background", @ptrCast([*c]f32, &color), imgui.ImGuiColorEditFlags_PickerHueWheel)) {
                background_color = upaya.math.Color.fromRgba(color.x, color.y, color.z, color.w);
            }
        }

        imgui.ogPushStyleVarVec2(imgui.ImGuiStyleVar_SelectableTextAlign, .{ .x = 0.5, .y = 0.5 });

        //animation tools
        imgui.igText("Selection");
        imgui.igSeparator();

        if (imgui.ogSelectableBool(imgui.icons.mouse_pointer, selected_tool == .arrow, imgui.ImGuiSelectableFlags_None, .{ .x = toolbar_half_width, .y = 20 }))
            selected_tool = .arrow;
        if (imgui.igIsItemHovered(imgui.ImGuiHoveredFlags_None)) {
            imgui.igBeginTooltip();
            imgui.igText("Pointer (esc)");
            imgui.igEndTooltip();
        }

        imgui.igSameLine(0, space);
        if (imgui.ogSelectableBool(imgui.icons.hand_pointer, selected_tool == .hand, imgui.ImGuiSelectableFlags_None, .{ .x = toolbar_half_width, .y = 20 }))
            selected_tool = .hand;
        if (imgui.igIsItemHovered(imgui.ImGuiHoveredFlags_None)) {
            imgui.igBeginTooltip();
            imgui.igText("Pan (space + " ++ imgui.icons.mouse ++ ")");
            imgui.igEndTooltip();
        }

        if (imgui.ogSelectableBool(imgui.icons.border_style, selected_tool == .selection, imgui.ImGuiSelectableFlags_None, .{ .x = toolbar_half_width, .y = 20 }))
            selected_tool = .selection;
        if (imgui.igIsItemHovered(imgui.ImGuiHoveredFlags_None)) {
            imgui.igBeginTooltip();
            imgui.igText("Select (s)");
            imgui.igEndTooltip();
        }

        imgui.igSameLine(0, space);
        if (imgui.ogSelectableBool(imgui.icons.magic, selected_tool == .wand, imgui.ImGuiSelectableFlags_None, .{ .x = toolbar_half_width, .y = 20 }))
            selected_tool = .wand;
        if (imgui.igIsItemHovered(imgui.ImGuiHoveredFlags_None)) {
            imgui.igBeginTooltip();
            imgui.igText("Wand (w)");
            imgui.igEndTooltip();
        }

        // draw tools
        imgui.igText("Draw");
        imgui.igSeparator();

        if (imgui.ogSelectableBool(imgui.icons.pencil_alt, selected_tool == .pencil, imgui.ImGuiSelectableFlags_None, .{ .x = toolbar_half_width, .y = 20 }))
            selected_tool = .pencil;
        if (imgui.igIsItemHovered(imgui.ImGuiHoveredFlags_None)) {
            imgui.igBeginTooltip();
            imgui.igText("Draw (d)");
            imgui.igEndTooltip();
        }

        imgui.igSameLine(0, space);
        if (imgui.ogSelectableBool(imgui.icons.eraser, selected_tool == .eraser, imgui.ImGuiSelectableFlags_None, .{ .x = toolbar_half_width, .y = 20 }))
            selected_tool = .eraser;
        if (imgui.igIsItemHovered(imgui.ImGuiHoveredFlags_None)) {
            imgui.igBeginTooltip();
            imgui.igText("Erase (e)");
            imgui.igEndTooltip();
        }

        if (imgui.ogSelectableBool(imgui.icons.fill, selected_tool == .bucket, imgui.ImGuiSelectableFlags_None, .{ .x = toolbar_half_width, .y = 20 }))
            selected_tool = .bucket;

        if (imgui.igIsItemHovered(imgui.ImGuiHoveredFlags_None)) {
            imgui.igBeginTooltip();
            imgui.igText("Fill (f)");
            imgui.igEndTooltip();
        }

        imgui.igSameLine(0, space);
        if (imgui.ogSelectableBool(imgui.icons.eye_dropper, selected_tool == .dropper, imgui.ImGuiSelectableFlags_None, .{ .x = toolbar_half_width, .y = 20 }))
            selected_tool = .dropper;

        if (imgui.igIsItemHovered(imgui.ImGuiHoveredFlags_None)) {
            imgui.igBeginTooltip();
            imgui.igText("Dropper (right " ++ imgui.icons.mouse ++ ")");
            imgui.igEndTooltip();
        }

        if (selected_tool == .bucket) {
            _ = imgui.igCheckbox("Contiguous", &contiguous_fill);
        }

        //animation tools
        imgui.igText("Animation");
        imgui.igSeparator();

        if (imgui.ogSelectableBool(imgui.icons.border_none, selected_tool == .animation, imgui.ImGuiSelectableFlags_None, .{ .x = toolbar_half_width, .y = 20 }))
            selected_tool = .animation;
        if (imgui.igIsItemHovered(imgui.ImGuiHoveredFlags_None)) {
            imgui.igBeginTooltip();
            imgui.igText("Animation (a)");
            imgui.igEndTooltip();
        }
        imgui.igPopStyleVar(1);
    }
}
