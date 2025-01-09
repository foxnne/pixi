const std = @import("std");
const Pixi = @import("../../Pixi.zig");
const core = @import("mach").core;
const imgui = @import("zig-imgui");

pub fn draw() !void {
    if (Pixi.Editor.getFile(Pixi.app.open_file_index)) |file| {
        if (Pixi.app.popups.heightmap) {
            imgui.openPopup("Heightmap", imgui.PopupFlags_None);
        } else return;

        const popup_width = 350 * Pixi.app.content_scale[0];
        const popup_height = 115 * Pixi.app.content_scale[1];

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
            &Pixi.app.popups.heightmap,
            modal_flags,
        )) {
            defer imgui.endPopup();
            imgui.spacing();

            const style = imgui.getStyle();
            const spacing = style.item_spacing.x;
            const half_width = (popup_width - (style.frame_padding.x * 2.0 * Pixi.app.content_scale[0]) - spacing) / 2.0;

            imgui.textWrapped("There currently is no heightmap layer, would you like to create a heightmap layer?");

            imgui.spacing();

            if (imgui.buttonEx("Cancel", .{ .x = half_width, .y = 0.0 })) {
                Pixi.app.popups.heightmap = false;
            }
            imgui.sameLine();
            if (imgui.buttonEx("Create", .{ .x = half_width, .y = 0.0 })) {
                file.heightmap.layer = .{
                    .name = try Pixi.app.allocator.dupeZ(u8, "heightmap"),
                    .texture = try Pixi.gfx.Texture.createEmpty(file.width, file.height, .{}),
                    .id = file.newId(),
                };
                try file.history.append(.{ .heightmap_restore_delete = .{ .action = .delete } });
                Pixi.app.popups.heightmap = false;
                Pixi.app.tools.set(.heightmap);
            }
        }
    }
}
