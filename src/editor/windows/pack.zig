const std = @import("std");
const upaya = @import("upaya");
const stb = @import("stb");
const imgui = @import("imgui");

const Camera = @import("../utils/camera.zig").Camera;

const editor = @import("../editor.zig");
const input = editor.input;
const canvas = editor.canvas;
const menubar = editor.menubar;
const sprites = editor.sprites;

const types = @import("../types/types.zig");
const File = types.File;
const Layer = types.Layer;
const Sprite = types.Sprite;

var camera: Camera = .{ .zoom = 0.5 };
var screen_position: imgui.ImVec2 = undefined;
var texture_position: imgui.ImVec2 = undefined;

var packed_image: ?upaya.Image = null;
var packed_texture: ?upaya.Texture = null;

var background: ?upaya.Texture = null;
var atlas: ?upaya.TexturePacker.Atlas = null;

pub fn draw() void {
    if (canvas.getActiveFile()) |_| {
        const width = 1024;
        const height = 768;
        const center = imgui.ogGetWindowCenter();
        imgui.ogSetNextWindowSize(.{ .x = width, .y = height }, imgui.ImGuiCond_Appearing);
        imgui.ogSetNextWindowPos(.{ .x = center.x - width / 2, .y = center.y - height / 2 }, imgui.ImGuiCond_Appearing, .{});
        if (imgui.igBeginPopupModal("Pack", &menubar.pack_popup, imgui.ImGuiWindowFlags_NoResize | imgui.ImGuiWindowFlags_MenuBar)) {
            defer imgui.igEndPopup();

            screen_position = imgui.ogGetCursorScreenPos();

            // menu
            if (imgui.igBeginMenuBar()) {
                defer imgui.igEndMenuBar();

                if (imgui.igBeginMenu("File", true)) {
                    defer imgui.igEndMenu();

                    if (imgui.igMenuItemBool("Export", 0, false, true)) {}
                }
            }

            if (packed_texture) |texture| {
                texture_position = .{
                    .x = -@intToFloat(f32, texture.width) / 2,
                    .y = -@intToFloat(f32, texture.height) / 2,
                };

                const tl = camera.matrix().transformImVec2(texture_position).add(screen_position);
                var br = texture_position;
                br.x += @intToFloat(f32, texture.width);
                br.y += @intToFloat(f32, texture.height);
                br = camera.matrix().transformImVec2(br).add(screen_position);

                imgui.ogImDrawList_AddImage(imgui.igGetWindowDrawList(), background.?.imTextureID(), tl, br, .{}, .{ .x = 1, .y = 1 }, 0xFFFFFFFF);

                imgui.ogImDrawList_AddImage(imgui.igGetWindowDrawList(), texture.imTextureID(), tl, br, .{}, .{ .x = 1, .y = 1 }, 0xFFFFFFFF);
            }

            if (imgui.igIsWindowHovered(imgui.ImGuiHoveredFlags_None)) {
                const io = imgui.igGetIO();

                //pan
                if (imgui.igIsMouseDragging(imgui.ImGuiMouseButton_Middle, 0)) {
                    input.pan(&camera, imgui.ImGuiMouseButton_Middle);
                }

                if (imgui.igIsMouseDragging(imgui.ImGuiMouseButton_Left, 0) and imgui.ogKeyDown(@intCast(usize, imgui.igGetKeyIndex(imgui.ImGuiKey_Space)))) {
                    input.pan(&camera, imgui.ImGuiMouseButton_Left);
                }

                // zoom
                if (io.MouseWheel != 0) {
                    input.zoom(&camera);
                    camera.position.x = @trunc(camera.position.x);
                    camera.position.y = @trunc(camera.position.y);
                }

                // round positions if we are finished changing cameras position
                if (imgui.igIsMouseReleased(imgui.ImGuiMouseButton_Middle) or imgui.ogKeyUp(@intCast(usize, imgui.igGetKeyIndex(imgui.ImGuiKey_Space)))) {
                    camera.position.x = @trunc(camera.position.x);
                    camera.position.y = @trunc(camera.position.y);
                }
            }
        }
    }
}

pub fn pack() void {
    if (canvas.getActiveFile()) |file| {
        var images = std.ArrayList(upaya.Image).init(upaya.mem.allocator);
        var frames = std.ArrayList(upaya.stb.stbrp_rect).init(upaya.mem.allocator);
        var names = std.ArrayList([]const u8).init(upaya.mem.allocator);
        var origins = std.ArrayList(upaya.math.Point).init(upaya.mem.allocator);

        for (file.layers.items) |layer| {
            for (file.sprites.items) |sprite| {
                const tiles_wide = @divExact(file.width, file.tileWidth);

                const column = @mod(@intCast(i32, sprite.index), tiles_wide);
                const row = @divTrunc(@intCast(i32, sprite.index), tiles_wide);

                const src_x = @intCast(usize, column * file.tileWidth);
                const src_y = @intCast(usize, row * file.tileHeight);

                var sprite_image = upaya.Image.init(@intCast(usize, file.tileWidth), @intCast(usize, file.tileHeight));
                var sprite_origin: upaya.math.Point = .{ .x = @floatToInt(i32, sprite.origin_x), .y = @floatToInt(i32, sprite.origin_y) };

                var y: usize = @intCast(usize, src_y);
                var dst_y: usize = 0;
                var yy: usize = y;
                var data = sprite_image.pixels[dst_y * sprite_image.w ..];

                while (y < src_y + @intCast(usize, file.tileHeight)) : (y += 1) {
                    const texture_width = @intCast(usize, layer.texture.width);
                    var src_row = layer.image.pixels[src_x + (yy * texture_width) .. (src_x + (yy * texture_width)) + sprite_image.w];

                    std.mem.copy(u32, data, src_row);
                    yy += 1;
                    dst_y += 1;
                    data = sprite_image.pixels[dst_y * sprite_image.w ..];
                }

                var containsColor: bool = false;
                for (sprite_image.pixels) |p| {
                    if (p & 0xFF000000 != 0) {
                        containsColor = true;
                        break;
                    }
                }

                if (containsColor) {
                    const offset = sprite_image.crop();
                    const sprite_rect: stb.stbrp_rect = .{ .id = @intCast(c_int, sprite.index), .w = @intCast(c_ushort, sprite_image.w), .h = @intCast(c_ushort, sprite_image.h) };

                    sprite_origin = .{ .x = sprite_origin.x - offset.x, .y = sprite_origin.y - offset.y};

                    images.append(sprite_image) catch unreachable;
                    names.append(sprite.name) catch unreachable;
                    frames.append(sprite_rect) catch unreachable;
                    origins.append(sprite_origin) catch unreachable;
                } else {
                    sprite_image.deinit();
                }
            }
        }

        if (upaya.TexturePacker.runRectPacker(frames.items)) |size| {
            atlas = upaya.TexturePacker.Atlas.initImages(frames.toOwnedSlice(), origins.toOwnedSlice(), names.toOwnedSlice(), images.toOwnedSlice(), size);
            background = upaya.Texture.initChecker(atlas.?.width, atlas.?.height, editor.checkerColor1, editor.checkerColor2);
            packed_texture = atlas.?.image.asTexture(.nearest);
        }
    }
}
