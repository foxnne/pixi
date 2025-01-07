const std = @import("std");
const Pixi = @import("../../Pixi.zig");
const core = @import("mach").core;
const imgui = @import("zig-imgui");

pub fn draw() !void {
    const dialog_name = switch (Pixi.state.popups.rename_state) {
        .none => "None...",
        .rename => "Rename...",
        .duplicate => "Duplicate...",
    };

    if (Pixi.state.popups.rename) {
        imgui.openPopup(dialog_name, imgui.PopupFlags_None);
    } else return;

    const popup_width = 350 * Pixi.state.content_scale[0];
    const popup_height = 115 * Pixi.state.content_scale[1];

    const window_size = Pixi.state.window_size;
    const window_center: [2]f32 = .{ window_size[0] / 2.0, window_size[1] / 2.0 };

    imgui.setNextWindowPos(.{
        .x = window_center[0] - popup_width / 2.0,
        .y = window_center[1] - popup_height / 2.0,
    }, imgui.Cond_None);
    imgui.setNextWindowSize(.{
        .x = popup_width,
        .y = 0.0,
    }, imgui.Cond_None);

    var modal_flags: imgui.WindowFlags = 0;
    modal_flags |= imgui.WindowFlags_NoResize;
    modal_flags |= imgui.WindowFlags_NoCollapse;

    if (imgui.beginPopupModal(dialog_name, &Pixi.state.popups.rename, modal_flags)) {
        defer imgui.endPopup();
        imgui.spacing();

        const style = imgui.getStyle();
        const spacing = style.item_spacing.x;
        const full_width = popup_width - (style.frame_padding.x * 2.0 * Pixi.state.content_scale[0]) - imgui.calcTextSize("Name").x;
        const half_width = (popup_width - (style.frame_padding.x * 2.0 * Pixi.state.content_scale[0]) - spacing) / 2.0;

        const base_name = std.fs.path.basename(Pixi.state.popups.rename_path[0..]);
        var base_index: usize = 0;
        if (std.mem.indexOf(u8, Pixi.state.popups.rename_path[0..], base_name)) |index| {
            base_index = index;
        }
        imgui.pushItemWidth(full_width);

        var input_text_flags: imgui.InputTextFlags = 0;
        input_text_flags |= imgui.InputTextFlags_AutoSelectAll;
        input_text_flags |= imgui.InputTextFlags_EnterReturnsTrue;

        const enter = imgui.inputText(
            "Name",
            Pixi.state.popups.rename_path[base_index.. :0],
            Pixi.state.popups.rename_path[base_index.. :0].len,
            input_text_flags,
        );

        if (imgui.buttonEx("Cancel", .{ .x = half_width, .y = 0.0 })) {
            Pixi.state.popups.rename = false;
        }
        imgui.sameLine();
        if (imgui.buttonEx("Ok", .{ .x = half_width, .y = 0.0 }) or enter) {
            switch (Pixi.state.popups.rename_state) {
                .rename => {
                    const old_path = std.mem.trimRight(u8, Pixi.state.popups.rename_old_path[0..], "\u{0}");
                    const new_path = std.mem.trimRight(u8, Pixi.state.popups.rename_path[0..], "\u{0}");

                    try std.fs.renameAbsolute(old_path[0..], new_path[0..]);

                    const old_path_z = Pixi.state.popups.rename_old_path[0..old_path.len :0];
                    for (Pixi.state.open_files.items) |*open_file| {
                        if (std.mem.eql(u8, open_file.path, old_path_z)) {
                            Pixi.state.allocator.free(open_file.path);
                            open_file.path = try Pixi.state.allocator.dupeZ(u8, new_path);
                        }
                    }
                },
                .duplicate => {
                    const original_path = std.mem.trimRight(u8, Pixi.state.popups.rename_old_path[0..], "\u{0}");
                    const new_path = std.mem.trimRight(u8, Pixi.state.popups.rename_path[0..], "\u{0}");

                    try std.fs.copyFileAbsolute(original_path, new_path, .{});
                },
                else => unreachable,
            }
            Pixi.state.popups.rename_state = .none;
            Pixi.state.popups.rename = false;
        }

        imgui.popItemWidth();
    }
}
