const std = @import("std");
const pixi = @import("../../../pixi.zig");
const mach = @import("core");
const zgui = @import("zgui").MachImgui(mach);

const spacer: [:0]const u8 = "    ";

pub fn draw() void {
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.theme.text_background.toSlice() });
    defer zgui.popStyleColor(.{ .count = 1 });

    const h = zgui.getTextLineHeightWithSpacing() + 6.0 * pixi.content_scale[1];
    const y = (zgui.getContentRegionAvail()[1] - h) / 2;
    const spacing: f32 = 3.0 * pixi.content_scale[0];
    zgui.setCursorPosY(y);
    zgui.setCursorPosX(5.0 * pixi.content_scale[0]);

    if (pixi.state.project_folder) |path| {
        zgui.setCursorPosY(y + 2.0 * pixi.content_scale[1]);
        zgui.textColored(pixi.state.theme.foreground.toSlice(), "{s}", .{pixi.fa.folder_open});
        zgui.setCursorPosY(y);
        zgui.sameLine(.{ .spacing = spacing });
        zgui.text("{s}", .{path});

        zgui.sameLine(.{});
        zgui.text(spacer, .{});
        zgui.sameLine(.{});
    }

    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
        zgui.setCursorPosY(y + spacing);
        zgui.textColored(pixi.state.theme.foreground.toSlice(), "{s} ", .{pixi.fa.chess_board});
        zgui.setCursorPosY(y);
        zgui.sameLine(.{ .spacing = spacing });
        zgui.text("{d}px by {d}px", .{ file.width, file.height });

        zgui.sameLine(.{});
        zgui.text(spacer, .{});
        zgui.sameLine(.{});

        zgui.setCursorPosY(y + spacing);
        zgui.textColored(pixi.state.theme.foreground.toSlice(), "{s} ", .{pixi.fa.border_all});
        zgui.setCursorPosY(y);
        zgui.sameLine(.{ .spacing = spacing });
        zgui.text("{d}px by {d}px", .{ file.tile_width, file.tile_height });
    }
}
