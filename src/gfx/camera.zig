const std = @import("std");
const zm = @import("zmath");
const zgpu = @import("zgpu");
const zglfw = @import("zglfw");
const pixi = @import("pixi");

pub const Camera = struct {
    design_size: zm.F32x4,
    window_size: zm.F32x4,
    zoom: f32 = 1.0,
    zoom_step: f32 = 1.0,
    zoom_step_next: f32 = 1.0,
    zoom_progress: f32 = -1.0,
    position: zm.F32x4 = zm.f32x4s(0),

    pub fn init(design_size: zm.F32x4, window_size: struct { w: i32, h: i32 }, position: zm.F32x4) Camera {
        const w_size = zm.f32x4(@intToFloat(f32, window_size.w), @intToFloat(f32, window_size.h), 0, 0);
        const zooms = zm.ceil(w_size / design_size);
        const zoom = std.math.max(zooms[0], zooms[1]) + 1.0; // Initially set the zoom to be 1 step greater than minimum.

        return .{
            .design_size = design_size,
            .window_size = w_size,
            .zoom = zoom,
            .position = position,
        };
    }

    /// Sets window size from the window, call this everytime the window changes.
    pub fn setWindow(camera: *Camera, window: zglfw.Window) void {
        const window_size = window.getSize();
        camera.window_size = zm.f32x4(@intToFloat(f32, window_size[0]), @intToFloat(f32, window_size[1]), 0, 0);
        const min_zoom = camera.minZoom();
        const max_zoom = camera.maxZoom();
        if (camera.zoom < min_zoom) camera.zoom = min_zoom;
        if (camera.zoom > max_zoom) camera.zoom = max_zoom;
    }

    /// Use this matrix when drawing to the framebuffer.
    pub fn frameBufferMatrix(camera: Camera) zm.Mat {
        const fb_ortho = zm.orthographicLh(camera.window_size[0], camera.window_size[1], -100, 100);
        const fb_scaling = zm.scaling(camera.zoom, camera.zoom, 1);
        const fb_translation = zm.translation(-camera.design_size[0] / 2 * camera.zoom, -camera.design_size[1] / 2 * camera.zoom, 1);

        return zm.mul(fb_scaling, zm.mul(fb_translation, fb_ortho));
    }

    /// Use this matrix when drawing to an off-screen render texture.
    pub fn renderTextureMatrix(camera: Camera) zm.Mat {
        const rt_ortho = zm.orthographicLh(camera.design_size[0], camera.design_size[1], -100, 100);
        const rt_translation = zm.translation(-camera.position[0], -camera.position[1], 0);

        return zm.mul(rt_translation, rt_ortho);
    }

    /// Transforms a position from screen-space to world-space.
    /// Remember that in screen-space positive Y is down, and positive Y is up in world-space.
    pub fn screenToWorld(camera: Camera, position: zm.F32x4, fb_mat: zm.Mat) zm.F32x4 {
        const ndc = zm.mul(fb_mat, zm.f32x4(position[0], -position[1], 1, 1)) / zm.f32x4(camera.zoom * 2, camera.zoom * 2, 1, 1) + zm.f32x4(-0.5, 0.5, 1, 1);
        const world = ndc * zm.f32x4(camera.window_size[0] / camera.zoom, camera.window_size[1] / camera.zoom, 1, 1) - zm.f32x4(-camera.position[0], -camera.position[1], 1, 1);

        return zm.f32x4(world[0], world[1], 0, 0);
    }

    /// Transforms a position from world-space to screen-space.
    /// Remember that in screen-space positive Y is down, and positive Y is up in world-space.
    pub fn worldToScreen(camera: Camera, position: zm.F32x4) zm.F32x4 {
        const cs = pixi.state.gctx.window.getContentScale();
        const screen = (camera.position - position) * zm.f32x4(camera.zoom * cs[0], camera.zoom * cs[1], 0, 0) - zm.f32x4((camera.window_size[0] / 2) * cs[0], (-camera.window_size[1] / 2) * cs[1], 0, 0);

        return zm.f32x4(-screen[0], screen[1], 0, 0);
    }

    /// Returns the minimum zoom needed to render to the window without black bars.
    pub fn minZoom(camera: Camera) f32 {
        const zoom = zm.ceil(camera.window_size / camera.design_size);
        return std.math.max(zoom[0], zoom[1]);
    }

    /// Returns the maximum zoom allowed for the current window size.
    pub fn maxZoom(camera: Camera) f32 {
        const min = camera.minZoom();
        return min + pixi.settings.max_zoom_offset;
    }
};
