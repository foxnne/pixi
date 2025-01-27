const std = @import("std");
const pixi = @import("../../pixi.zig");
const Core = @import("mach").Core;
const Editor = pixi.Editor;
const Packer = pixi.Packer;
const imgui = @import("zig-imgui");

pub const PackTexture = enum {
    texture,
    heightmap,
};

pub fn draw(mode: PackTexture, editor: *Editor, packer: *Packer) void {
    if (switch (mode) {
        .texture => editor.atlas.texture,
        .heightmap => editor.atlas.heightmap,
    }) |texture| {
        var canvas_flags: imgui.WindowFlags = 0;
        canvas_flags |= imgui.WindowFlags_HorizontalScrollbar;
        if (imgui.beginChild(
            "PackerCanvas",
            .{ .x = 0.0, .y = 0.0 },
            imgui.ChildFlags_None,
            canvas_flags,
        )) {
            const window_width = imgui.getWindowWidth();
            const window_height = imgui.getWindowHeight();
            const file_width = @as(f32, @floatFromInt(texture.image.width));
            const file_height = @as(f32, @floatFromInt(texture.image.height));

            var camera = &packer.camera;

            // Handle zooming, panning and extents
            {
                var sprite_camera: pixi.gfx.Camera = .{
                    .zoom = @min(window_width / file_width, window_height / file_height),
                };
                sprite_camera.setNearestZoomFloor();
                if (!camera.zoom_initialized) {
                    camera.zoom_initialized = true;
                    camera.zoom = sprite_camera.zoom;
                }
                sprite_camera.setNearestZoomFloor();
                camera.min_zoom = @min(sprite_camera.zoom, 1.0);

                camera.processPanZoom(.packer);
            }

            if (imgui.isWindowHovered(imgui.HoveredFlags_None)) {
                camera.processZoomTooltip();
            }

            const width: f32 = @floatFromInt(texture.image.width);
            const height: f32 = @floatFromInt(texture.image.height);

            const center_offset: [2]f32 = .{ -width / 2.0, -height / 2.0 };
            camera.drawTexture(texture.view_handle, texture.image.width, texture.image.height, center_offset, 0xFFFFFFFF);
            camera.drawRect(.{ center_offset[0], center_offset[1], width, height }, 2.0, pixi.editor.theme.text_secondary.toU32());
        }
        imgui.endChild();

        // Draw the packed atlas texture
        {}
    }
}
