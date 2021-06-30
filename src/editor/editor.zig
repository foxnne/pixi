const std = @import("std");

const upaya = @import("upaya");
const imgui = @import("imgui");
const sokol = @import("sokol");

pub const types = @import("types/types.zig");

//windows and bars
pub const menuBar = @import("menubar.zig");
pub const toolBar = @import("windows/toolbar.zig");
pub const layers = @import("windows/layers.zig");
pub const animations = @import("windows/animations.zig");
pub const canvas = @import("windows/canvas.zig");
pub const sprites = @import("windows/sprites.zig");
pub const spriteedit = @import("windows/spriteedit.zig");
pub const new = @import("windows/new.zig");
pub const slice = @import("windows/slice.zig");

//editor colors
pub var background_color: imgui.ImVec4 = undefined;
pub var foreground_color: imgui.ImVec4 = undefined;
pub var text_color: imgui.ImVec4 = undefined;
pub var highlight_color: imgui.ImVec4 = undefined;
pub var highlight_hover_color: imgui.ImVec4 = undefined;

pub var pixi_green: imgui.ImVec4 = undefined;
pub var pixi_green_hover: imgui.ImVec4 = undefined;
pub var pixi_blue: imgui.ImVec4 = undefined;
pub var pixi_blue_hover: imgui.ImVec4 = undefined;
pub var pixi_orange: imgui.ImVec4 = undefined;
pub var pixi_orange_hover: imgui.ImVec4 = undefined;

pub fn init() void {
    background_color = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(35, 36, 44, 255));
    foreground_color = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(42, 44, 54, 255));
    text_color = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(230, 175, 137, 255));
    highlight_color = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(47, 179, 135, 150));
    highlight_hover_color = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(76, 148, 123, 255));

    pixi_green = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(103, 193, 123, 150));
    pixi_green_hover = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(64, 133, 103, 150));
    pixi_blue = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(74, 143, 167, 150));
    pixi_blue_hover = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(49, 69, 132, 150));
    pixi_orange = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(194, 109, 92, 150));
    pixi_orange_hover = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(140, 80, 88, 150));

    // set colors, move this to its own file soon?
    var style = imgui.igGetStyle();
    style.TabRounding = 2;
    style.FrameRounding = 8;
    style.WindowBorderSize = 1;
    style.WindowRounding = 8;
    style.WindowMinSize = .{ .x = 100, .y = 100 };
    style.WindowMenuButtonPosition = imgui.ImGuiDir_None;
    style.PopupRounding = 8;
    style.WindowTitleAlign = .{ .x = 0.5, .y = 0.5};
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
    style.Colors[imgui.ImGuiCol_Text] = text_color;
    style.Colors[imgui.ImGuiCol_Header] = highlight_color;
    style.Colors[imgui.ImGuiCol_HeaderHovered] = highlight_hover_color;
    style.Colors[imgui.ImGuiCol_HeaderActive] = highlight_color;
    style.Colors[imgui.ImGuiCol_ScrollbarBg] = background_color;
    style.Colors[imgui.ImGuiCol_ScrollbarGrab] = foreground_color;
    style.Colors[imgui.ImGuiCol_ModalWindowDimBg] = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(10, 10, 15, 100));

    canvas.init();
}

pub fn setupDockLayout(id: imgui.ImGuiID) void {
    var dock_main_id = id;

    var bottom_id = imgui.igDockBuilderSplitNode(dock_main_id, imgui.ImGuiDir_Down, 0.3, null, &dock_main_id);
    var left_id = imgui.igDockBuilderSplitNode(dock_main_id, imgui.ImGuiDir_Left, 0.05, null, &dock_main_id);
    var mid_id: imgui.ImGuiID = 0;
    var right_id = imgui.igDockBuilderSplitNode(dock_main_id, imgui.ImGuiDir_Right, 0.15, null, &mid_id);

    imgui.igDockBuilderDockWindow("Canvas", mid_id);
    imgui.igDockBuilderDockWindow("Toolbar", left_id);
    imgui.igDockBuilderDockWindow("Layers", right_id);

    var bottom_right_id = imgui.igDockBuilderSplitNode(bottom_id, imgui.ImGuiDir_Right, 0.2, null, &bottom_id);
    var bottom_mid_id = imgui.igDockBuilderSplitNode(bottom_id, imgui.ImGuiDir_Right, 0.8, null, &bottom_id);

    imgui.igDockBuilderDockWindow("Animations", bottom_right_id);
    imgui.igDockBuilderDockWindow("SpriteEdit", bottom_mid_id);
    imgui.igDockBuilderDockWindow("Sprites", bottom_id);

    imgui.igDockBuilderFinish(id);
}

pub fn resetDockLayout() void {
    //TODO
}

pub fn update() void {
    menuBar.draw();
    canvas.draw();
    layers.draw();
    toolBar.draw();
    animations.draw();
    sprites.draw();
    spriteedit.draw();
    new.draw();
    slice.draw();
}

pub fn onFileDropped(file: []const u8) void {

    if (std.mem.endsWith(u8, file, ".png")) {

        // TODO: figure out file name on windows
        const start_name = std.mem.lastIndexOf(u8, file, "/").?;
        const end_name = std.mem.indexOf(u8, file, ".").?;
        const name = std.fmt.allocPrint(upaya.mem.allocator, "{s}\u{0}", .{file[start_name + 1..end_name]}) catch unreachable;
        defer upaya.mem.allocator.free(name);
        const file_image = upaya.Image.initFromFile(file);
        const image_width: i32 = @intCast(i32, file_image.w);
        const image_height: i32 = @intCast(i32, file_image.h);

        var new_file: types.File = .{
            .name = std.mem.dupe(upaya.mem.allocator, u8, name) catch unreachable,
            .width = image_width,
            .height = image_height,
            .tileWidth = image_width,
            .tileHeight = image_height,
            .background = upaya.Texture.initChecker(image_width, image_height, new.checkerColor1, new.checkerColor2),
            .layers = std.ArrayList(types.Layer).init(upaya.mem.allocator),
            .sprites = std.ArrayList(types.Sprite).init(upaya.mem.allocator),
        };

        new_file.layers.append(.{
            .name = "Layer 0\u{0}",
            .texture = file_image.asTexture(.nearest),
            .image = file_image
        }) catch unreachable;

        new_file.sprites.append(.{
            .name = std.mem.dupe(upaya.mem.allocator, u8, name) catch unreachable,
            .index = 0,
            .origin = .{},
        }) catch unreachable;

        canvas.newFile(new_file);        
    }
}

pub fn shutdown() void {
    canvas.close();
}
