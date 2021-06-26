const upaya = @import("upaya");
const imgui = @import("imgui");
const sokol = @import("sokol");

//windows and bars
pub const menuBar = @import("menubar.zig");
pub const toolBar = @import("windows/toolbar.zig");
pub const layers = @import("windows/layers.zig");
pub const animations = @import("windows/animations.zig");
pub const canvas = @import("windows/canvas.zig");
pub const sprites = @import("windows/sprites.zig");
pub const spriteedit = @import("windows/spriteedit.zig");
pub const new = @import("windows/new.zig");

//editor colors
var background_color: imgui.ImVec4 = undefined;
var foreground_color: imgui.ImVec4 = undefined;
var text_color: imgui.ImVec4 = undefined;
var highlight: imgui.ImVec4 = undefined;

pub fn init() void {
    background_color = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(35, 36, 44, 255));
    foreground_color = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(42, 44, 54, 255));

    // set colors, move this to its own file soon?
    var style = imgui.igGetStyle();
    style.TabRounding = 2;
    style.FrameRounding = 8;
    style.WindowBorderSize = 1;
    style.WindowRounding = 8;
    style.WindowMinSize = .{ .x = 100, .y = 100 };
    style.WindowMenuButtonPosition = imgui.ImGuiDir_None;
    style.PopupRounding = 8;
    style.Colors[imgui.ImGuiCol_WindowBg] = background_color;
    style.Colors[imgui.ImGuiCol_MenuBarBg] = foreground_color;
    style.Colors[imgui.ImGuiCol_TitleBg] = background_color;
    style.Colors[imgui.ImGuiCol_Tab] = background_color;
    style.Colors[imgui.ImGuiCol_TabUnfocused] = background_color;
    style.Colors[imgui.ImGuiCol_TabUnfocusedActive] = background_color;
    style.Colors[imgui.ImGuiCol_TitleBgActive] = foreground_color;
    style.Colors[imgui.ImGuiCol_TabActive] = foreground_color;
    style.Colors[imgui.ImGuiCol_TabHovered] = foreground_color;
    style.Colors[imgui.ImGuiCol_PopupBg] = foreground_color;

    style.Colors[imgui.ImGuiCol_Text] = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(206, 163, 127, 255));
    style.Colors[imgui.ImGuiCol_ModalWindowDimBg] = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(10, 10, 15, 100));

    canvas.init();
}

pub fn setupDockLayout(id: imgui.ImGuiID) void {
    var dock_main_id = id;

    var bottom_id = imgui.igDockBuilderSplitNode(dock_main_id, imgui.ImGuiDir_Down, 0.2, null, &dock_main_id);
    var left_id = imgui.igDockBuilderSplitNode(dock_main_id, imgui.ImGuiDir_Left, 0.05, null, &dock_main_id);
    var mid_id: imgui.ImGuiID = 0;
    var right_id = imgui.igDockBuilderSplitNode(dock_main_id, imgui.ImGuiDir_Right, 0.15, null, &mid_id);

    imgui.igDockBuilderDockWindow("Canvas", mid_id);
    imgui.igDockBuilderDockWindow("Toolbar", left_id);
    imgui.igDockBuilderDockWindow("Layers", right_id);

    var bottom_left_id =  imgui.igDockBuilderSplitNode(bottom_id, imgui.ImGuiDir_Right, 0.2, null, &bottom_id);
    var bottom_mid_id = imgui.igDockBuilderSplitNode(bottom_id, imgui.ImGuiDir_Right, 0.8, null, &bottom_id);
    //var bottom_right_id = imgui.igDockBuilderSplitNode(bottom_id, imgui.ImGuiDir_Right, 0.33, null, &bottom_mid_id);

    imgui.igDockBuilderDockWindow("Animations", bottom_left_id);
    imgui.igDockBuilderDockWindow("SpriteEdit", bottom_mid_id);
    imgui.igDockBuilderDockWindow("Sprites", bottom_id);

    imgui.igDockBuilderFinish(id);
}

pub fn resetDockLayout() void {}

pub fn update() void {
    menuBar.draw();
    canvas.draw();
    layers.draw();
    toolBar.draw();
    animations.draw();
    sprites.draw();
    spriteedit.draw();
    new.draw();
}

pub fn onFileDropped(file: []const u8) void {}

pub fn shutdown() void {
    canvas.close();
}
