const std = @import("std");

const Pixi = @import("../../Pixi.zig");
const Editor = Pixi.Editor;

const imgui = @import("zig-imgui");

pub fn draw(editor: *Editor) !void {
    if (editor.getFile(editor.open_file_index)) |file| {
        if (editor.popups.heightmap) {
            imgui.openPopup("Heightmap", imgui.PopupFlags_None);
        } else return;

        const popup_width: f32 = 350;
        const popup_height: f32 = 115;

        const window_size = Pixi.app.window_size;
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

        if (imgui.beginPopupModal(
            "Heightmap",
            &editor.popups.heightmap,
            modal_flags,
        )) {
            defer imgui.endPopup();
            imgui.spacing();

            const style = imgui.getStyle();
            const spacing = style.item_spacing.x;
            const half_width = (popup_width - (style.frame_padding.x * 2.0) - spacing) / 2.0;

            imgui.textWrapped("There currently is no heightmap layer, would you like to create a heightmap layer?");

            imgui.spacing();

            if (imgui.buttonEx("Cancel", .{ .x = half_width, .y = 0.0 })) {
                editor.popups.heightmap = false;
            }
            imgui.sameLine();
            if (imgui.buttonEx("Create", .{ .x = half_width, .y = 0.0 })) {
                file.heightmap.layer = .{
                    .name = try Pixi.app.allocator.dupeZ(u8, "heightmap"),
                    .texture = try Pixi.gfx.Texture.createEmpty(file.width, file.height, .{}),
                    .id = file.newId(),
                };
                try file.history.append(.{ .heightmap_restore_delete = .{ .action = .delete } });
                editor.popups.heightmap = false;
                editor.tools.set(.heightmap);
            }
        }
    }
}
