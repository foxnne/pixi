const std = @import("std");
const pixi = @import("../../pixi.zig");
const core = @import("mach-core");
const zgui = @import("zgui").MachImgui(core);

pub fn draw() void {
    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
        if (pixi.state.popups.heightmap) {
            zgui.openPopup("Heightmap", .{});
        } else return;

        const popup_width = 350 * pixi.content_scale[0];
        const popup_height = 115 * pixi.content_scale[1];

        var window_size = pixi.framebuffer_size;
        const window_center: [2]f32 = .{ window_size[0] / 2.0, window_size[1] / 2.0 };

        zgui.setNextWindowPos(.{
            .x = window_center[0] - popup_width / 2.0,
            .y = window_center[1] - popup_height / 2.0,
        });
        zgui.setNextWindowSize(.{
            .w = popup_width,
            .h = 0.0,
        });

        if (zgui.beginPopupModal("Heightmap", .{
            .popen = &pixi.state.popups.heightmap,
            .flags = .{
                .no_resize = true,
                .no_collapse = true,
            },
        })) {
            defer zgui.endPopup();
            zgui.spacing();

            const style = zgui.getStyle();
            const spacing = style.item_spacing[0];
            const half_width = (popup_width - (style.frame_padding[0] * 2.0 * pixi.content_scale[0]) - spacing) / 2.0;

            zgui.textWrapped("There currently is no heightmap layer, would you like to create a heightmap layer?", .{});

            zgui.spacing();

            if (zgui.button("Cancel", .{ .w = half_width })) {
                pixi.state.popups.heightmap = false;
            }
            zgui.sameLine(.{});
            if (zgui.button("Create", .{ .w = half_width })) {
                file.heightmap_layer = .{
                    .name = pixi.state.allocator.dupeZ(u8, "heightmap") catch unreachable,
                    .texture = pixi.gfx.Texture.createEmpty(file.width, file.height, .{}) catch unreachable,
                    .id = file.id(),
                };
                file.history.append(.{ .heightmap_restore_delete = .{ .action = .delete } }) catch unreachable;
                pixi.state.popups.heightmap = false;
                pixi.state.tools.set(.heightmap);
            }
        }
    }
}
