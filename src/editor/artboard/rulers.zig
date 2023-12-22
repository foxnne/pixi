const std = @import("std");
const pixi = @import("../../pixi.zig");
const core = @import("mach-core");
const imgui = @import("zig-imgui");

pub fn draw(file: *pixi.storage.Internal.Pixi) void {
    const file_width = @as(f32, @floatFromInt(file.width));
    const file_height = @as(f32, @floatFromInt(file.height));
    const tile_width = @as(f32, @floatFromInt(file.tile_width));
    const tile_height = @as(f32, @floatFromInt(file.tile_height));
    const tiles_wide = @divExact(file.width, file.tile_width);
    const tiles_tall = @divExact(file.height, file.tile_height);
    const text_size = imgui.calcTextSize("0");
    const layer_position: [2]f32 = .{
        -file_width / 2,
        -file_height / 2,
    };
    if (imgui.beginChild("TopRuler", .{ .x = 0.0, .y = 0.0 }, false, imgui.WindowFlags_ChildWindow)) {
        const window_tl = imgui.getCursorScreenPos();
        const layer_tl = file.camera.matrix().transformVec2(layer_position);
        const line_length = imgui.getWindowHeight() / 2.0;
        const tl: [2]f32 = .{ window_tl.x + layer_tl[0] + imgui.getTextLineHeightWithSpacing() * 1.5 / 2, window_tl.y };

        if (imgui.getWindowDrawList()) |draw_list| {
            var i: usize = 0;
            while (i < @as(usize, @intCast(tiles_wide))) : (i += 1) {
                const offset = .{ (@as(f32, @floatFromInt(i)) * tile_width) * file.camera.zoom, 0.0 };
                if (tile_width * file.camera.zoom > text_size.x * 4.0) {
                    const text = std.fmt.allocPrintZ(pixi.state.allocator, "{d}", .{i}) catch unreachable;
                    defer pixi.state.allocator.free(text);

                    draw_list.addText(
                        .{ .x = tl[0] + offset[0] + (tile_width / 2.0 * file.camera.zoom) - (text_size.x / 2.0), .y = tl[1] + 4.0 * pixi.content_scale[1] },
                        pixi.state.theme.text_secondary.toU32(),
                        text.ptr,
                    );
                }
                draw_list.addLineEx(
                    .{ .x = tl[0] + offset[0], .y = tl[1] + line_length / 2.0 },
                    .{ .x = tl[0] + offset[0], .y = tl[1] + line_length / 2.0 + line_length },
                    pixi.state.theme.text_secondary.toU32(),
                    1.0,
                );
            }
            draw_list.addLineEx(
                .{ .x = tl[0] + file_width * file.camera.zoom, .y = tl[1] + line_length / 2.0 },
                .{ .x = tl[0] + file_width * file.camera.zoom, .y = tl[1] + line_length / 2.0 + line_length },
                pixi.state.theme.text_secondary.toU32(),
                1.0,
            );
        }
        imgui.endChild();
    }

    if (imgui.beginChild("SideRuler", .{ .x = 0.0, .y = 0.0 }, false, imgui.WindowFlags_ChildWindow)) {
        const window_tl = imgui.getCursorScreenPos();
        const layer_tl = file.camera.matrix().transformVec2(layer_position);
        const tl: [2]f32 = .{ window_tl.x + (text_size.x / 2.0), window_tl.y + layer_tl[1] + 1.0 };

        if (imgui.getWindowDrawList()) |draw_list| {
            var i: usize = 0;
            while (i < @as(usize, @intCast(tiles_tall))) : (i += 1) {
                const offset = .{ 0.0, @as(f32, @floatFromInt(i)) * tile_height * file.camera.zoom };

                if (tile_height * file.camera.zoom > text_size.x * 4.0) {
                    const text = std.fmt.allocPrintZ(pixi.state.allocator, "{d}", .{i}) catch unreachable;
                    defer pixi.state.allocator.free(text);

                    draw_list.addText(.{ .x = tl[0], .y = tl[1] + offset[1] + (tile_height / 2.0 * file.camera.zoom) - (text_size.y / 2.0) }, pixi.state.theme.text_secondary.toU32(), text.ptr);
                }
                draw_list.addLineEx(
                    .{ .x = tl[0], .y = tl[1] + offset[1] },
                    .{ .x = tl[0] + imgui.getWindowWidth() / 2.0, .y = tl[1] + offset[1] },
                    pixi.state.theme.text_secondary.toU32(),
                    1.0,
                );
            }
            draw_list.addLineEx(
                .{ .x = tl[0], .y = tl[1] + file_height * file.camera.zoom },
                .{ .x = tl[0] + imgui.getWindowWidth() / 2.0, .y = tl[1] + file_height * file.camera.zoom },
                pixi.state.theme.text_secondary.toU32(),
                1.0,
            );
        }
        imgui.endChild();
    }
}
