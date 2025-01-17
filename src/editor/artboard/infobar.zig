const std = @import("std");

const Pixi = @import("../../Pixi.zig");
const Core = @import("mach").Core;
const Editor = Pixi.Editor;

const imgui = @import("zig-imgui");

const spacer: [:0]const u8 = "    ";

pub fn draw(editor: *Editor) void {
    imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.foreground.toImguiVec4());
    defer imgui.popStyleColor();

    const h = imgui.getTextLineHeightWithSpacing() + 6.0;
    const y = (imgui.getContentRegionAvail().y - h) / 2;
    const spacing: f32 = 3.0;
    imgui.setCursorPosY(y);
    imgui.setCursorPosX(5.0);

    if (editor.project_folder) |path| {
        imgui.setCursorPosY(y + 2.0);
        imgui.textColored(editor.theme.foreground.toImguiVec4(), Pixi.fa.folder_open);
        imgui.setCursorPosY(y);
        imgui.sameLineEx(0.0, spacing);
        imgui.text(path);

        imgui.sameLine();
        imgui.text(spacer);
        imgui.sameLine();
    }

    if (editor.getFile(editor.open_file_index)) |file| {
        imgui.setCursorPosY(y + spacing);
        imgui.textColored(editor.theme.foreground.toImguiVec4(), Pixi.fa.chess_board);
        imgui.setCursorPosY(y);
        imgui.sameLineEx(0.0, spacing);
        imgui.text("%dpx by %dpx", file.width, file.height);

        imgui.sameLine();
        imgui.text(spacer);
        imgui.sameLine();

        imgui.setCursorPosY(y + spacing);
        imgui.textColored(editor.theme.foreground.toImguiVec4(), Pixi.fa.border_all);
        imgui.setCursorPosY(y);
        imgui.sameLineEx(0.0, spacing);
        imgui.text("%dpx by %dpx", file.tile_width, file.tile_height);

        imgui.sameLine();
        imgui.text(spacer);
        imgui.sameLine();
    }

    if (editor.saving()) {
        imgui.setCursorPosY(y + spacing);
        imgui.textColored(editor.theme.foreground.toImguiVec4(), Pixi.fa.save);
        imgui.setCursorPosY(y);
        imgui.sameLineEx(0.0, spacing);
        imgui.text("Saving!...");
    }
}
