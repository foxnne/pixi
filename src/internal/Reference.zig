const std = @import("std");
const Pixi = @import("../Pixi.zig");
const imgui = @import("zig-imgui");

const PixiFile = @import("PixiFile.zig");

const Reference = @This();

path: [:0]const u8,
texture: Pixi.gfx.Texture,
camera: Pixi.gfx.Camera = .{},
opacity: f32 = 100.0,

pub fn deinit(reference: *Reference) void {
    reference.texture.deinit();
    Pixi.app.allocator.free(reference.path);
}

pub fn canvasCenterOffset(reference: *Reference) [2]f32 {
    const width: f32 = @floatFromInt(reference.texture.image.width);
    const height: f32 = @floatFromInt(reference.texture.image.height);

    return .{ -width / 2.0, -height / 2.0 };
}

pub fn getPixelIndex(reference: Reference, pixel: [2]usize) usize {
    return pixel[0] + pixel[1] * @as(usize, @intCast(reference.texture.image.width));
}

pub fn getPixel(self: Reference, pixel: [2]usize) [4]u8 {
    const index = self.getPixelIndex(pixel);
    const pixels = @as([*][4]u8, @ptrCast(self.texture.image.data.ptr))[0 .. self.texture.image.data.len / 4];
    return pixels[index];
}

pub fn processSampleTool(reference: *Reference) void {
    const sample_key = if (Pixi.editor.hotkeys.hotkey(.{ .proc = .sample })) |hotkey| hotkey.down() else false;
    const sample_button = if (Pixi.app.mouse.button(.sample)) |sample| sample.down() else false;

    if (!sample_key and !sample_button) return;

    imgui.setMouseCursor(imgui.MouseCursor_None);
    reference.camera.drawCursor(Pixi.atlas.dropper_0_default, 0xFFFFFFFF);

    const mouse_position = Pixi.app.mouse.position;
    var camera = reference.camera;

    const pixel_coord_opt = camera.pixelCoordinates(.{
        .texture_position = canvasCenterOffset(reference),
        .position = mouse_position,
        .width = reference.texture.image.width,
        .height = reference.texture.image.height,
    });

    if (pixel_coord_opt) |pixel_coord| {
        const pixel = .{ @as(usize, @intFromFloat(pixel_coord[0])), @as(usize, @intFromFloat(pixel_coord[1])) };

        const color = reference.getPixel(pixel);

        try camera.drawColorTooltip(color);

        if (color[3] != 0)
            Pixi.editor.colors.primary = color;
    }
}
