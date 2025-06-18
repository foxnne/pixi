const std = @import("std");
const pixi = @import("../../pixi.zig");

const App = pixi.App;

const Popups = @import("Popups.zig");
const Editor = pixi.Editor;

pub fn draw(popups: *Popups, app: *App) !void {
    const dialog_name = "New Folder...";

    if (popups.folder) {
        imgui.openPopup(dialog_name, imgui.PopupFlags_None);
    } else return;

    const popup_width: f32 = 350;
    const popup_height: f32 = 115;

    const window_size = app.window_size;
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

    if (imgui.beginPopupModal(dialog_name, &popups.folder, modal_flags)) {
        defer imgui.endPopup();
        imgui.spacing();

        const style = imgui.getStyle();
        const spacing = style.item_spacing.x;
        const full_width = popup_width - (style.frame_padding.x * 2.0) - (imgui.calcTextSize("Name").x + 10.0);
        const half_width = (popup_width - (style.frame_padding.x * 2.0) - spacing) / 2.0;

        const base_name = std.fs.path.basename(popups.folder_path[0..]);
        var base_index: usize = 0;
        if (std.mem.indexOf(u8, popups.folder_path[0..], base_name)) |index| {
            base_index = index;
        }
        imgui.pushItemWidth(full_width);

        var input_text_flags: imgui.InputTextFlags = 0;
        input_text_flags |= imgui.InputTextFlags_AutoSelectAll;
        input_text_flags |= imgui.InputTextFlags_EnterReturnsTrue;

        const enter = imgui.inputText(
            "Name",
            popups.folder_path[base_index.. :0],
            popups.folder_path[base_index.. :0].len,
            input_text_flags,
        );

        if (imgui.buttonEx("Cancel", .{ .x = half_width, .y = 0.0 })) {
            popups.folder = false;
        }
        imgui.sameLine();
        if (imgui.buttonEx("Ok", .{ .x = half_width, .y = 0.0 }) or enter) {
            const new_path = std.mem.trimRight(u8, popups.folder_path[0..], "\u{0}");

            try std.fs.makeDirAbsolute(new_path);
            popups.folder = false;
        }

        imgui.popItemWidth();
    }
}
