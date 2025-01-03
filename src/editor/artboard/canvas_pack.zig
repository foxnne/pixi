const std = @import("std");
const Pixi = @import("../../Pixi.zig");
const core = @import("mach").core;
const imgui = @import("zig-imgui");

pub const PackTexture = enum {
    diffusemap,
    heightmap,
};

pub fn draw(mode: PackTexture) void {
    if (switch (mode) {
        .diffusemap => Pixi.state.atlas.diffusemap,
        .heightmap => Pixi.state.atlas.heightmap,
    }) |texture| {
        const window_width = imgui.getWindowWidth();
        const window_height = imgui.getWindowHeight();
        const file_width = @as(f32, @floatFromInt(texture.image.width));
        const file_height = @as(f32, @floatFromInt(texture.image.height));

        var camera = &Pixi.state.pack_camera;

        // Handle zooming, panning and extents
        {
            var sprite_camera: Pixi.gfx.Camera = .{
                .zoom = @min(window_width / file_width, window_height / file_height),
            };
            sprite_camera.setNearestZoomFloor();
            if (!camera.zoom_initialized) {
                camera.zoom_initialized = true;
                camera.zoom = sprite_camera.zoom;
            }
            sprite_camera.setNearestZoomFloor();
            camera.min_zoom = @min(sprite_camera.zoom, 1.0);

            camera.processPanZoom(.primary);
        }

        if (imgui.isWindowHovered(imgui.HoveredFlags_None)) {
            camera.processZoomTooltip();
        }

        // Draw the packed atlas texture
        {
            const width: f32 = @floatFromInt(texture.image.width);
            const height: f32 = @floatFromInt(texture.image.height);

            const center_offset: [2]f32 = .{ -width / 2.0, -height / 2.0 };
            camera.drawTexture(texture.view_handle, texture.image.width, texture.image.height, center_offset, 0xFFFFFFFF);
            camera.drawRect(.{ center_offset[0], center_offset[1], width, height }, 2.0, Pixi.editor.theme.text_secondary.toU32());
        }
    }
}
