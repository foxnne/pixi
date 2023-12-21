const std = @import("std");
const pixi = @import("../../pixi.zig");
const core = @import("mach-core");
const imgui = @import("zig-imgui");

pub const PackTexture = enum {
    diffusemap,
    heightmap,
};

pub fn draw(mode: PackTexture) void {
    if (switch (mode) {
        .diffusemap => pixi.state.atlas.diffusemap,
        .heightmap => pixi.state.atlas.heightmap,
    }) |texture| {
        const window_width = imgui.getWindowWidth();
        const window_height = imgui.getWindowHeight();
        const file_width = @as(f32, @floatFromInt(texture.image.width));
        const file_height = @as(f32, @floatFromInt(texture.image.height));

        var camera = &pixi.state.pack_camera;

        const canvas_center_offset: [2]f32 = .{ -file_width / 2.0, -file_height / 2.0 };

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
            const min_zoom = @min(sprite_camera.zoom, 1.0);

            camera.processPanZoom();

            // Lock camera from zooming in or out too far for the flipbook
            camera.zoom = std.math.clamp(camera.zoom, min_zoom, pixi.state.settings.zoom_steps[pixi.state.settings.zoom_steps.len - 1]);

            // Lock camera from moving too far away from canvas
            camera.position[0] = std.math.clamp(camera.position[0], -(canvas_center_offset[0] + file_width), canvas_center_offset[0] + file_width);
            camera.position[1] = std.math.clamp(camera.position[1], -(canvas_center_offset[1] + file_height), canvas_center_offset[1] + file_height);
        }

        if (imgui.isWindowHovered(.{})) {
            camera.processZoomTooltip();
        }

        // Draw the packed atlas texture
        {
            const width: f32 = @floatFromInt(texture.image.width);
            const height: f32 = @floatFromInt(texture.image.height);

            const center_offset: [2]f32 = .{ -width / 2.0, -height / 2.0 };
            camera.drawTexture(texture.view_handle, texture.image.width, texture.image.height, center_offset, 0xFFFFFFFF);
            camera.drawRect(.{ center_offset[0], center_offset[1], width, height }, 2.0, pixi.state.theme.text_secondary.toU32());
        }
    }
}
