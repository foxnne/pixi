const std = @import("std");
const pixi = @import("pixi");
const zgui = @import("zgui");

pub fn draw() void {
    if (pixi.state.popups.new_file) {
        zgui.openPopup("New File...", .{});
    } else return;

    const popup_width = 450 * pixi.state.window.scale[0];
    const popup_height = 260 * pixi.state.window.scale[1];

    const window_size = pixi.state.window.size * pixi.state.window.scale;
    const window_center: [2]f32 = .{ window_size[0] / 2.0, window_size[1] / 2.0 };

    zgui.setNextWindowPos(.{
        .x = window_center[0] - popup_width / 2.0,
        .y = window_center[1] - popup_height / 2.0,
    });
    zgui.setNextWindowSize(.{
        .w = popup_width,
        .h = popup_height,
    });

    if (zgui.beginPopupModal("New File...", .{
        .popen = &pixi.state.popups.new_file,
        .flags = .{
            .no_resize = true,
            .no_collapse = true,
        },
    })) {
        defer zgui.endPopup();

        const style = zgui.getStyle();

        const full_width = popup_width - (style.frame_padding[0] * 2.5 * pixi.state.window.scale[0]) - zgui.calcTextSize("Tile Height", .{})[0];
        const base_name_index = if (std.mem.lastIndexOf(u8, pixi.state.popups.new_file_path[0..], &[_]u8 { std.fs.path.sep })) |index| index + 1 else 0;

        zgui.pushItemWidth(full_width);
        _ = zgui.inputText("Name", .{
            .buf = pixi.state.popups.new_file_path[base_name_index..],
            .flags = .{
                .chars_no_blank = true,
                .auto_select_all = true,
                .enter_returns_true = true,
            },
        });

        zgui.spacing();
        _ = zgui.sliderInt("Tile Width", .{
            .v = &pixi.state.popups.new_file_tile_size[0],
            .min = 1,
            .max = pixi.state.settings.max_file_size[0],
        });
        _ = zgui.sliderInt("Tile Height", .{
            .v = &pixi.state.popups.new_file_tile_size[1],
            .min = 1,
            .max = pixi.state.settings.max_file_size[1],
        });
        zgui.spacing();
        zgui.separator();
        zgui.spacing();
        _ = zgui.sliderInt("Tiles Wide", .{ .v = &pixi.state.popups.new_file_tiles[0], .min = 1, .max = @divTrunc(pixi.state.settings.max_file_size[0], pixi.state.popups.new_file_tile_size[0]) });

        _ = zgui.sliderInt("Tiles High", .{ .v = &pixi.state.popups.new_file_tiles[1], .min = 1, .max = @divTrunc(pixi.state.settings.max_file_size[1], pixi.state.popups.new_file_tile_size[1]) });
        zgui.popItemWidth();
        zgui.spacing();
        zgui.spacing();

        const spacing = 5.0 * pixi.state.window.scale[0];
        const half_width = (popup_width - (style.frame_padding[0] * 2.5 * pixi.state.window.scale[0]) - spacing) / 2.0;
        if (zgui.button("Cancel", .{ .w = half_width })) {
            pixi.state.popups.new_file = false;
        }
        zgui.sameLine(.{ .spacing = spacing });
        if (zgui.button("Ok", .{ .w = half_width })) {
            const new_file_path = std.mem.trimRight(u8, pixi.state.popups.new_file_path[0..], "\u{0}");
            const ext = std.fs.path.extension(new_file_path);
            if (std.mem.eql(u8, ".pixi", ext)) {
                if (pixi.editor.newFile(pixi.state.allocator.dupeZ(u8, new_file_path) catch unreachable) catch unreachable) {
                    if (pixi.editor.getFile(0)) |file| {
                        _ = file.save() catch unreachable;
                    }
                }
                pixi.state.popups.new_file = false;
            }
        }
    }
}
