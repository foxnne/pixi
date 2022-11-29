const std = @import("std");
const pixi = @import("pixi");
const zgui = @import("zgui");

pub fn draw(file: *pixi.storage.Internal.Pixi) void {
    const file_width = @intToFloat(f32, file.width);
    const file_height = @intToFloat(f32, file.height);
    const tile_width = @intToFloat(f32, file.tile_width);
    const tile_height = @intToFloat(f32, file.tile_height);
    const tiles_wide = @divExact(file.width, file.tile_width);
    const tiles_tall = @divExact(file.height, file.tile_height);
    const text_size = zgui.calcTextSize("0", .{});
    const layer_position: [2]f32 = .{
        -file_width / 2,
        -file_height / 2,
    };
    if (zgui.beginChild("TopRuler", .{})) {
        const draw_list = zgui.getWindowDrawList();
        const window_tl = zgui.getCursorScreenPos();
        const layer_tl = file.camera.matrix().transformVec2(layer_position);
        const line_length = zgui.getWindowHeight() / 2.0;
        const tl: [2]f32 = .{ window_tl[0] + layer_tl[0] + zgui.getTextLineHeightWithSpacing() * 1.5 / 2, window_tl[1] };

        var i: usize = 0;
        while (i < @intCast(usize, tiles_wide)) : (i += 1) {
            const offset = .{ (@intToFloat(f32, i) * tile_width) * file.camera.zoom, 0.0 };
            if (tile_width * file.camera.zoom > text_size[0] * 4.0)
                draw_list.addText(.{ tl[0] + offset[0] + (tile_width / 2.0 * file.camera.zoom) - (text_size[0] / 2.0), tl[1] + 4.0 * pixi.state.window.scale[1] }, pixi.state.style.text_secondary.toU32(), "{d}", .{i});
            draw_list.addLine(.{
                .p1 = .{ tl[0] + offset[0], tl[1] + line_length / 2.0 },
                .p2 = .{ tl[0] + offset[0], tl[1] + line_length / 2.0 + line_length },
                .col = pixi.state.style.text_secondary.toU32(),
                .thickness = 1.0,
            });
        }
        draw_list.addLine(.{
            .p1 = .{ tl[0] + file_width * file.camera.zoom, tl[1] + line_length / 2.0 },
            .p2 = .{ tl[0] + file_width * file.camera.zoom, tl[1] + line_length / 2.0 + line_length },
            .col = pixi.state.style.text_secondary.toU32(),
            .thickness = 1.0,
        });
        zgui.endChild();
    }

    if (zgui.beginChild("SideRuler", .{})) {
        const draw_list = zgui.getWindowDrawList();
        const window_tl = zgui.getCursorScreenPos();
        const layer_tl = file.camera.matrix().transformVec2(layer_position);
        const tl: [2]f32 = .{ window_tl[0] + (text_size[0] / 2.0), window_tl[1] + layer_tl[1] + 1.0 };

        var i: usize = 0;
        while (i < @intCast(usize, tiles_tall)) : (i += 1) {
            const offset = .{ 0.0, @intToFloat(f32, i) * tile_height * file.camera.zoom };

            if (tile_height * file.camera.zoom > text_size[0] * 4.0)
                draw_list.addText(.{ tl[0], tl[1] + offset[1] + (tile_height / 2.0 * file.camera.zoom) - (text_size[1] / 2.0) }, pixi.state.style.text_secondary.toU32(), "{d}", .{i});
            draw_list.addLine(.{
                .p1 = .{ tl[0], tl[1] + offset[1] },
                .p2 = .{ tl[0] + zgui.getWindowWidth() / 2.0, tl[1] + offset[1] },
                .col = pixi.state.style.text_secondary.toU32(),
                .thickness = 1.0,
            });
        }
        draw_list.addLine(.{
            .p1 = .{ tl[0], tl[1] + file_height * file.camera.zoom },
            .p2 = .{ tl[0] + zgui.getWindowWidth() / 2.0, tl[1] + file_height * file.camera.zoom },
            .col = pixi.state.style.text_secondary.toU32(),
            .thickness = 1.0,
        });
        zgui.endChild();
    }
}
