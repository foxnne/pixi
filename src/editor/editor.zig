const std = @import("std");

const upaya = @import("upaya");
const imgui = @import("imgui");
const sokol = @import("sokol");

pub const types = @import("types/types.zig");
pub const history = @import("history/history.zig");
pub const input = @import("input/input.zig");

//windows and bars
pub const menubar = @import("menubar.zig");
pub const toolbar = @import("windows/toolbar.zig");
pub const layers = @import("windows/layers.zig");
pub const animations = @import("windows/animations.zig");
pub const canvas = @import("windows/canvas.zig");
pub const sprites = @import("windows/sprites.zig");
pub const spriteedit = @import("windows/spriteedit.zig");

// popups
pub const newfile = @import("windows/newfile.zig");
pub const slice = @import("windows/slice.zig");

//editor colors
pub var background_color: imgui.ImVec4 = undefined;
pub var foreground_color: imgui.ImVec4 = undefined;
pub var text_color: imgui.ImVec4 = undefined;
pub var highlight_color_green: imgui.ImVec4 = undefined;
pub var highlight_hover_color_green: imgui.ImVec4 = undefined;
pub var highlight_color_red: imgui.ImVec4 = undefined;
pub var highlight_hover_color_red: imgui.ImVec4 = undefined;

pub var pixi_green: imgui.ImVec4 = undefined;
pub var pixi_green_hover: imgui.ImVec4 = undefined;
pub var pixi_blue: imgui.ImVec4 = undefined;
pub var pixi_blue_hover: imgui.ImVec4 = undefined;
pub var pixi_orange: imgui.ImVec4 = undefined;
pub var pixi_orange_hover: imgui.ImVec4 = undefined;

pub const checkerColor1: upaya.math.Color = .{ .value = 0xFFDDDDDD };
pub const checkerColor2: upaya.math.Color = .{ .value = 0xFFEEEEEE };

pub const gridColor: upaya.math.Color = .{ .value = 0xFF999999 };

pub fn init() void {
    background_color = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(30, 31, 39, 255));
    foreground_color = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(42, 44, 54, 255));
    text_color = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(230, 175, 137, 255));

    highlight_color_green = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(47, 179, 135, 255));
    highlight_hover_color_green = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(76, 148, 123, 255));

    highlight_color_red = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(76, 48, 67, 255));
    highlight_hover_color_red = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(105, 50, 68, 255));

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
    if (std.builtin.os.tag == .macos) {
        style.WindowRounding = 8;
    } else style.WindowRounding = 0;
    style.WindowMinSize = .{ .x = 100, .y = 100 };
    style.WindowMenuButtonPosition = imgui.ImGuiDir_None;
    style.PopupRounding = 8;
    style.WindowTitleAlign = .{ .x = 0.5, .y = 0.5 };
    style.Colors[imgui.ImGuiCol_WindowBg] = background_color;
    style.Colors[imgui.ImGuiCol_Border] = foreground_color;
    style.Colors[imgui.ImGuiCol_MenuBarBg] = foreground_color;
    style.Colors[imgui.ImGuiCol_DockingEmptyBg] = background_color;
    style.Colors[imgui.ImGuiCol_Separator] = foreground_color;
    style.Colors[imgui.ImGuiCol_TitleBg] = background_color;
    style.Colors[imgui.ImGuiCol_Tab] = background_color;
    style.Colors[imgui.ImGuiCol_TabUnfocused] = background_color;
    style.Colors[imgui.ImGuiCol_TabUnfocusedActive] = background_color;
    style.Colors[imgui.ImGuiCol_TitleBgActive] = foreground_color;
    style.Colors[imgui.ImGuiCol_TabActive] = foreground_color;
    style.Colors[imgui.ImGuiCol_TabHovered] = foreground_color;
    style.Colors[imgui.ImGuiCol_PopupBg] = background_color;
    style.Colors[imgui.ImGuiCol_Text] = text_color;
    style.Colors[imgui.ImGuiCol_ResizeGrip] = highlight_color_green;
    style.Colors[imgui.ImGuiCol_ScrollbarGrabActive] = highlight_color_green;
    style.Colors[imgui.ImGuiCol_ScrollbarGrabHovered] = highlight_hover_color_green;

    style.Colors[imgui.ImGuiCol_Header] = highlight_color_red;
    style.Colors[imgui.ImGuiCol_HeaderHovered] = highlight_hover_color_red;
    style.Colors[imgui.ImGuiCol_HeaderActive] = highlight_color_red;
    style.Colors[imgui.ImGuiCol_ScrollbarBg] = background_color;
    style.Colors[imgui.ImGuiCol_ScrollbarGrab] = foreground_color;
    style.Colors[imgui.ImGuiCol_DockingPreview] = highlight_color_green;
    style.Colors[imgui.ImGuiCol_ModalWindowDimBg] = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(10, 10, 15, 100));

    canvas.init();
    //history.init();
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
    const io = imgui.igGetIO();

    // global hotkeys
    if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_ESCAPE))
        toolbar.selected_tool = .arrow;

    if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_D))
        toolbar.selected_tool = .pencil;

    if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_E))
        toolbar.selected_tool = .eraser;

    if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_F))
        toolbar.selected_tool = .bucket;

    if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_N) and io.KeySuper)
        menubar.new_file_popup = true;

    if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_S) and !io.KeySuper)
        toolbar.selected_tool = .selection;

    if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_A) and !io.KeySuper)
        toolbar.selected_tool = .animation;

    if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_Z) and io.KeySuper and !io.KeyShift){
        if (canvas.getActiveFile()) |file| {
            file.history.undo();
        }

    }
        

    if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_Z) and io.KeySuper and io.KeyShift) {
        if (canvas.getActiveFile()) |file| {
            file.history.redo();
        }

    }
        

    if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_S) and io.KeySuper) {}
    //TODO: save

    if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_W))
        toolbar.selected_tool = .wand;

    input.update();

    menubar.draw();
    canvas.draw();
    layers.draw();
    toolbar.draw();
    animations.draw();
    sprites.draw();
    spriteedit.draw();
    newfile.draw();
    slice.draw();
}

pub fn onFileDropped(file: []const u8) void {
    if (std.mem.endsWith(u8, file, ".png")) {

        // TODO: figure out file name on windows
        const start_name = std.mem.lastIndexOf(u8, file, "/").?;
        const end_name = std.mem.indexOf(u8, file, ".").?;
        const name = std.fmt.allocPrintZ(upaya.mem.tmp_allocator, "{s}", .{file[start_name + 1 .. end_name]}) catch unreachable;
        const sprite_name = std.fmt.allocPrintZ(upaya.mem.tmp_allocator, "{s}_0", .{name}) catch unreachable;
        const file_image = upaya.Image.initFromFile(file);
        const image_width: i32 = @intCast(i32, file_image.w);
        const image_height: i32 = @intCast(i32, file_image.h);
        var temp_image = upaya.Image.init(@intCast(usize, image_width), @intCast(usize, image_height));
        temp_image.fillRect(.{ .x = 0, .y = 0, .width = image_width, .height = image_height }, upaya.math.Color.transparent);

        var new_file: types.File = .{
            .name = name,
            .width = image_width,
            .height = image_height,
            .tileWidth = image_width,
            .tileHeight = image_height,
            .background = upaya.Texture.initChecker(image_width, image_height, checkerColor1, checkerColor2),
            .temporary = .{
                .name = "Temporary",
                .id = layers.getNewID(),
                .texture = temp_image.asTexture(.nearest),
                .image = temp_image,
            },
            .layers = std.ArrayList(types.Layer).init(upaya.mem.allocator),
            .sprites = std.ArrayList(types.Sprite).init(upaya.mem.allocator),
            .animations = std.ArrayList(types.Animation).init(upaya.mem.allocator),
            .history = history.History.init(),
        };

        new_file.layers.append(.{ .name = "Layer 0", .id = layers.getNewID(), .texture = file_image.asTexture(.nearest), .image = file_image }) catch unreachable;

        new_file.sprites.append(.{
            .name = sprite_name,
            .index = 0,
            .origin_x = 0,
            .origin_y = 0,
        }) catch unreachable;

        canvas.newFile(new_file);
    }
}

pub fn shutdown() void {
    canvas.close();
}
