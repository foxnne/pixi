const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("pixi");
const settings = pixi.settings;

const spacer: [:0]const u8 = "    ";

pub fn draw() void {
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.background.toSlice() });
    defer zgui.popStyleColor(.{ .count = 1 });

    const h = zgui.getTextLineHeightWithSpacing();
    const y = (zgui.getWindowHeight() - h) / 2;
    const spacing: f32 = 2.0 * pixi.state.window.scale[0];
    zgui.setCursorPosY(y);
    zgui.setCursorPosX(5.0 * pixi.state.window.scale[0]);

    if (pixi.state.project_folder) |path| {
        zgui.setCursorPosY(y + 2.0 * pixi.state.window.scale[1]);
        zgui.textColored(pixi.state.style.foreground.toSlice(), "{s}", .{pixi.fa.folder_open});
        zgui.setCursorPosY(y);
        zgui.sameLine(.{ .spacing = spacing });
        zgui.text("{s}", .{path});
        zgui.sameLine(.{});
        zgui.text(spacer, .{});
        zgui.sameLine(.{});
    }

    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
        zgui.setCursorPosY(y + 2.0 * pixi.state.window.scale[1]);
        zgui.textColored(pixi.state.style.foreground.toSlice(), "{s} ", .{pixi.fa.ruler_combined});
        zgui.setCursorPosY(y);
        zgui.sameLine(.{ .spacing = spacing });
        zgui.text("{d}px X {d}px", .{ file.width, file.height });
    }
}
