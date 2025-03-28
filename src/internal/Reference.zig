const std = @import("std");
const pixi = @import("../pixi.zig");
const imgui = @import("zig-imgui");

const File = @import("File.zig");

const Reference = @This();

path: [:0]const u8,
texture: pixi.gfx.Texture,
camera: pixi.gfx.Camera = .{},
opacity: f32 = 100.0,

pub fn deinit(reference: *Reference) void {
    reference.texture.deinit();
    pixi.app.allocator.free(reference.path);
}

pub fn canvasCenterOffset(reference: *Reference) [2]f32 {
    const width: f32 = @floatFromInt(reference.texture.width);
    const height: f32 = @floatFromInt(reference.texture.height);

    return .{ -width / 2.0, -height / 2.0 };
}

pub fn getPixelIndex(reference: Reference, pixel: [2]usize) usize {
    return pixel[0] + pixel[1] * @as(usize, @intCast(reference.texture.width));
}

pub fn getPixel(self: Reference, pixel: [2]usize) [4]u8 {
    const index = self.getPixelIndex(pixel);
    const pixels = @as([*][4]u8, @ptrCast(self.texture.pixels.ptr))[0 .. self.texture.pixels.len / 4];
    return pixels[index];
}

pub fn processSampleTool(reference: *Reference) void {
    const sample_key = if (pixi.editor.hotkeys.hotkey(.{ .proc = .sample })) |hotkey| hotkey.down() else false;
    const sample_button = if (pixi.editor.mouse.button(.sample)) |sample| sample.down() else false;

    if (!sample_key and !sample_button) return;

    imgui.setMouseCursor(imgui.MouseCursor_None);
    reference.camera.drawCursor(pixi.atlas.sprites.dropper_default, 0xFFFFFFFF);

    const mouse_position = pixi.editor.mouse.position;
    var camera = reference.camera;

    const pixel_coord_opt = camera.pixelCoordinates(.{
        .texture_position = canvasCenterOffset(reference),
        .position = mouse_position,
        .width = reference.texture.width,
        .height = reference.texture.height,
    });

    if (pixel_coord_opt) |pixel_coord| {
        const pixel = .{ @as(usize, @intFromFloat(pixel_coord[0])), @as(usize, @intFromFloat(pixel_coord[1])) };

        const color = reference.getPixel(pixel);

        try camera.drawColorTooltip(color);

        if (color[3] != 0)
            pixi.editor.colors.primary = color;
    }
}
