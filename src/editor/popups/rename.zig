const std = @import("std");
const pixi = @import("root");
const zgui = @import("zgui");

pub fn draw() void {
    const dialog_name = switch (pixi.state.popups.rename_state) {
        .none => "None...",
        .rename => "Rename...",
        .duplicate => "Duplicate...",
    };

    if (pixi.state.popups.rename) {
        zgui.openPopup(dialog_name, .{});
    } else return;

    const popup_width = 350 * pixi.state.window.scale[0];
    const popup_height = 110 * pixi.state.window.scale[1];

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

    if (zgui.beginPopupModal(dialog_name, .{
        .popen = &pixi.state.popups.rename,
        .flags = .{
            .no_resize = true,
            .no_collapse = true,
        },
    })) {
        defer zgui.endPopup();
        zgui.spacing();

        const style = zgui.getStyle();
        const spacing = 5.0 * pixi.state.window.scale[0];
        const full_width = popup_width - (style.frame_padding[0] * 2.5 * pixi.state.window.scale[0]) - zgui.calcTextSize("Name", .{})[0];
        const half_width = (popup_width - (style.frame_padding[0] * 2.5 * pixi.state.window.scale[0]) - spacing) / 2.0;

        const base_name = std.fs.path.basename(pixi.state.popups.rename_path[0..]);
        var base_index: usize = 0;
        if (std.mem.indexOf(u8, pixi.state.popups.rename_path[0..], base_name)) |index| {
            base_index = index;
        }
        zgui.pushItemWidth(full_width);
        var enter = zgui.inputText("Name", .{
            .buf = pixi.state.popups.rename_path[base_index..],
            .flags = .{
                .chars_no_blank = true,
                .auto_select_all = true,
                .enter_returns_true = true,
            },
        });
        if (zgui.button("Cancel", .{ .w = half_width })) {
            pixi.state.popups.rename = false;
        }
        zgui.sameLine(.{});
        if (zgui.button("Ok", .{ .w = half_width }) or enter) {
            switch (pixi.state.popups.rename_state) {
                .rename => {
                    const old_path = std.mem.trimRight(u8, pixi.state.popups.rename_old_path[0..], "\u{0}");
                    const new_path = std.mem.trimRight(u8, pixi.state.popups.rename_path[0..], "\u{0}");

                    std.fs.renameAbsolute(old_path[0..], new_path[0..]) catch unreachable;

                    const old_path_z = pixi.state.popups.rename_old_path[0..old_path.len :0];
                    for (pixi.state.open_files.items) |*open_file| {
                        if (std.mem.eql(u8, open_file.path, old_path_z)) {
                            open_file.path = pixi.state.allocator.dupeZ(u8, new_path) catch unreachable;
                        }
                    }
                },
                .duplicate => {
                    const original_path = std.mem.trimRight(u8, pixi.state.popups.rename_old_path[0..], "\u{0}");
                    const new_path = std.mem.trimRight(u8, pixi.state.popups.rename_path[0..], "\u{0}");

                    std.fs.copyFileAbsolute(original_path, new_path, .{}) catch unreachable;
                },
                else => unreachable,
            }
            pixi.state.popups.rename_state = .none;
            pixi.state.popups.rename = false;
        }

        zgui.popItemWidth();
    }
}
