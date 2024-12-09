const std = @import("std");
const pixi = @import("../../Pixi.zig");
const core = @import("mach").core;
const imgui = @import("zig-imgui");

const spacer: [:0]const u8 = "    ";

pub fn draw() void {
    imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.foreground.toImguiVec4());
    defer imgui.popStyleColor();

    const h = imgui.getTextLineHeightWithSpacing() + 6.0 * pixi.content_scale[1];
    const y = (imgui.getContentRegionAvail().y - h) / 2;
    const spacing: f32 = 3.0 * pixi.content_scale[0];
    imgui.setCursorPosY(y);
    imgui.setCursorPosX(5.0 * pixi.content_scale[0]);

    if (pixi.state.project_folder) |path| {
        imgui.setCursorPosY(y + 2.0 * pixi.content_scale[1]);
        imgui.textColored(pixi.state.theme.foreground.toImguiVec4(), pixi.fa.folder_open);
        imgui.setCursorPosY(y);
        imgui.sameLineEx(0.0, spacing);
        imgui.text(path);

        imgui.sameLine();
        imgui.text(spacer);
        imgui.sameLine();
    }

    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
        imgui.setCursorPosY(y + spacing);
        imgui.textColored(pixi.state.theme.foreground.toImguiVec4(), pixi.fa.chess_board);
        imgui.setCursorPosY(y);
        imgui.sameLineEx(0.0, spacing);
        imgui.text("%dpx by %dpx", file.width, file.height);

        imgui.sameLine();
        imgui.text(spacer);
        imgui.sameLine();

        imgui.setCursorPosY(y + spacing);
        imgui.textColored(pixi.state.theme.foreground.toImguiVec4(), pixi.fa.border_all);
        imgui.setCursorPosY(y);
        imgui.sameLineEx(0.0, spacing);
        imgui.text("%dpx by %dpx", file.tile_width, file.tile_height);

        imgui.sameLine();
        imgui.text(spacer);
        imgui.sameLine();
    }

    if (pixi.editor.saving()) {
        imgui.setCursorPosY(y + spacing);
        imgui.textColored(pixi.state.theme.foreground.toImguiVec4(), pixi.fa.save);
        imgui.setCursorPosY(y);
        imgui.sameLineEx(0.0, spacing);
        imgui.text("Saving!...");
    }
}
