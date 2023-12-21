const std = @import("std");
const pixi = @import("../../pixi.zig");
const core = @import("mach-core");
const imgui = @import("zig-imgui");

pub fn draw() void {
    const dialog_name = switch (pixi.state.popups.rename_state) {
        .none => "None...",
        .rename => "Rename...",
        .duplicate => "Duplicate...",
    };

    if (pixi.state.popups.rename) {
        imgui.openPopup(dialog_name, imgui.PopupFlags_None);
    } else return;

    const popup_width = 350 * pixi.content_scale[0];
    const popup_height = 115 * pixi.content_scale[1];

    var window_size = pixi.framebuffer_size;
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

    if (imgui.beginPopupModal(dialog_name, &pixi.state.popups.rename, modal_flags)) {
        defer imgui.endPopup();
        imgui.spacing();

        const style = imgui.getStyle();
        const spacing = style.item_spacing.x;
        const full_width = popup_width - (style.frame_padding.x * 2.0 * pixi.content_scale[0]) - imgui.calcTextSize("Name").x;
        const half_width = (popup_width - (style.frame_padding.x * 2.0 * pixi.content_scale[0]) - spacing) / 2.0;

        const base_name = std.fs.path.basename(pixi.state.popups.rename_path[0..]);
        var base_index: usize = 0;
        if (std.mem.indexOf(u8, pixi.state.popups.rename_path[0..], base_name)) |index| {
            base_index = index;
        }
        imgui.pushItemWidth(full_width);

        var input_text_flags: imgui.InputTextFlags = 0;
        input_text_flags |= imgui.InputTextFlags_AutoSelectAll;
        input_text_flags |= imgui.InputTextFlags_EnterReturnsTrue;

        var enter = imgui.inputText(
            "Name",
            pixi.state.popups.rename_path[base_index..],
            pixi.state.popups.rename_path[base_index..].len,
            input_text_flags,
        );

        if (imgui.buttonEx("Cancel", .{ .x = half_width, .y = 0.0 })) {
            pixi.state.popups.rename = false;
        }
        imgui.sameLine();
        if (imgui.buttonEx("Ok", .{ .x = half_width, .y = 0.0 }) or enter) {
            switch (pixi.state.popups.rename_state) {
                .rename => {
                    const old_path = std.mem.trimRight(u8, pixi.state.popups.rename_old_path[0..], "\u{0}");
                    const new_path = std.mem.trimRight(u8, pixi.state.popups.rename_path[0..], "\u{0}");

                    std.fs.renameAbsolute(old_path[0..], new_path[0..]) catch unreachable;

                    const old_path_z = pixi.state.popups.rename_old_path[0..old_path.len :0];
                    for (pixi.state.open_files.items) |*open_file| {
                        if (std.mem.eql(u8, open_file.path, old_path_z)) {
                            pixi.state.allocator.free(open_file.path);
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

        imgui.popItemWidth();
    }
}
