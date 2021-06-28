const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

pub const Camera = @import("../utils/camera.zig").Camera;

const editor = @import("../editor.zig");
const input = @import("../input/input.zig");
const types = @import("../types/types.zig");
const toolbar = @import("../windows/toolbar.zig");
const layers = @import("../windows/layers.zig");
const sprites = @import("../windows/sprites.zig");
const canvas = @import("../windows/canvas.zig");

const File = types.File;
const Layer = types.Layer;
const Animation = types.Animation;

var camera: Camera = .{ .zoom = 4 };
var screen_pos: imgui.ImVec2 = undefined;

pub fn draw() void {
    if (imgui.igBegin("SpriteEdit", 0, imgui.ImGuiWindowFlags_None)) {
        defer imgui.igEnd();

        // setup screen position and size
        screen_pos = imgui.ogGetCursorScreenPos();
        const window_size = imgui.ogGetContentRegionAvail();
        if (window_size.x == 0 or window_size.y == 0) return;

        if (canvas.getActiveFile()) |file| {
            if (sprites.getActiveSprite()) |sprite| {
                var texture_position: imgui.ImVec2 = .{
                    .x = -@intToFloat(f32, file.tileWidth) / 2,
                    .y = -@intToFloat(f32, file.tileHeight) / 2 - 5,
                };

                const tiles_wide = @divExact(file.width, file.tileWidth);
                const tiles_tall = @divExact(file.height, file.tileHeight);

                const column = @mod(@intCast(i32, sprite.index), tiles_wide);
                const row = @divTrunc(@intCast(i32, sprite.index), tiles_wide);

                const src_x = column * file.tileWidth;
                const src_y = row * file.tileHeight;

                var sprite_rect: upaya.math.RectF = .{
                    .width = @intToFloat(f32, file.tileWidth),
                    .height = @intToFloat(f32, file.tileHeight),
                    .x = @intToFloat(f32, src_x),
                    .y = @intToFloat(f32, src_y),
                };

                drawSprite(file.background, texture_position, sprite_rect, 0xFFFFFFFF);

                for(file.layers.items) |layer| {
                    drawSprite(layer.texture, texture_position, sprite_rect, 0xFFFFFFFF);
                }
                

                
            }
        }
    }
}

fn drawSprite(texture: upaya.Texture, position: imgui.ImVec2, rect: upaya.math.RectF, color: u32) void {
    const tl = camera.matrix().transformImVec2(position).add(screen_pos);
    var br = position;
    br.x += rect.width;
    br.y += rect.height;
    br = camera.matrix().transformImVec2(br).add(screen_pos);

    const inv_w = 1.0 / @intToFloat(f32, texture.width);
    const inv_h = 1.0 / @intToFloat(f32, texture.height);

    const uv0 = imgui.ImVec2{ .x = rect.x * inv_w, .y = rect.y * inv_h };
    const uv1 = imgui.ImVec2{ .x = (rect.x + rect.width) * inv_w, .y = (rect.y + rect.height) * inv_h };

    imgui.ogImDrawList_AddImage(
        imgui.igGetWindowDrawList(),
        texture.imTextureID(),
        tl,
        br,
        uv0,
        uv1,
        color,
    );
}
