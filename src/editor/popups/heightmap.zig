const std = @import("std");
const Pixi = @import("../../Pixi.zig");
const core = @import("mach").core;
const imgui = @import("zig-imgui");

pub fn draw() void {
    if (Pixi.Editor.getFile(Pixi.state.open_file_index)) |file| {
        if (Pixi.state.popups.heightmap) {
            imgui.openPopup("Heightmap", imgui.PopupFlags_None);
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

        if (imgui.beginPopupModal(
            "Heightmap",
            &Pixi.state.popups.heightmap,
            modal_flags,
        )) {
            defer imgui.endPopup();
            imgui.spacing();

            const style = imgui.getStyle();
            const spacing = style.item_spacing.x;
            const half_width = (popup_width - (style.frame_padding.x * 2.0 * Pixi.state.content_scale[0]) - spacing) / 2.0;

            imgui.textWrapped("There currently is no heightmap layer, would you like to create a heightmap layer?");

            imgui.spacing();

            if (imgui.buttonEx("Cancel", .{ .x = half_width, .y = 0.0 })) {
                Pixi.state.popups.heightmap = false;
            }
            imgui.sameLine();
            if (imgui.buttonEx("Create", .{ .x = half_width, .y = 0.0 })) {
                file.heightmap.layer = .{
                    .name = Pixi.state.allocator.dupeZ(u8, "heightmap") catch unreachable,
                    .texture = Pixi.gfx.Texture.createEmpty(file.width, file.height, .{}) catch unreachable,
                    .id = file.newId(),
                };
                file.history.append(.{ .heightmap_restore_delete = .{ .action = .delete } }) catch unreachable;
                Pixi.state.popups.heightmap = false;
                Pixi.state.tools.set(.heightmap);
            }
        }
    }
}
