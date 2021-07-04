const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

pub const Camera = @import("../utils/camera.zig").Camera;

const editor = @import("../editor.zig");
const input = @import("../input/input.zig");
const types = @import("../types/types.zig");
const toolbar = editor.toolbar;
const layers = editor.layers;
const sprites = editor.sprites;
const canvas = editor.canvas;
const animations = editor.animations;


const File = types.File;
const Layer = types.Layer;
const Animation = types.Animation;

var camera: Camera = .{ .zoom = 4 };
var screen_pos: imgui.ImVec2 = undefined;

var zoom_time: usize = 0;

pub fn draw() void {
    if (imgui.igBegin("SpriteEdit", 0, imgui.ImGuiWindowFlags_None)) {
        defer imgui.igEnd();

        // setup screen position and size
        screen_pos = imgui.ogGetCursorScreenPos();
        const window_size = imgui.ogGetContentRegionAvail();
        if (window_size.x == 0 or window_size.y == 0) return;

        if (canvas.getActiveFile()) |file| {

            if (sprites.getActiveSprite()) |sprite| {
                var sprite_position: imgui.ImVec2 = .{
                    .x = -@intToFloat(f32, file.tileWidth) / 2,
                    .y = -@intToFloat(f32, file.tileHeight) / 2 - 4,
                };

                const tiles_wide = @divExact(file.width, file.tileWidth);

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

                // draw transparency background sprite
                drawSprite(file.background, sprite_position, sprite_rect, 0xFFFFFFFF);

                // draw sprite of each layer
                for (file.layers.items) |layer| {
                    drawSprite(layer.texture, sprite_position, sprite_rect, 0xFFFFFFFF);
                }

                // store previous tool and reapply it after to allow quick switching
                var previous_tool = toolbar.selected_tool;
                // handle inputs
                if (imgui.igIsWindowHovered(imgui.ImGuiHoveredFlags_None)) {
                    if (layers.getActiveLayer()) |layer| {

                        const io = imgui.igGetIO();
                        //const mouse_position = io.MousePos;

                        //pan
                        if (toolbar.selected_tool == .hand and imgui.igIsMouseDragging(imgui.ImGuiMouseButton_Left, 0)) {
                            input.pan(&camera, imgui.ImGuiMouseButton_Left);
                        }

                        if (imgui.igIsMouseDragging(imgui.ImGuiMouseButton_Middle, 0)) {
                            input.pan(&camera, imgui.ImGuiMouseButton_Middle);
                        }

                        if (imgui.igIsMouseDragging(imgui.ImGuiMouseButton_Left, 0) and imgui.ogKeyDown(@intCast(usize, imgui.igGetKeyIndex(imgui.ImGuiKey_Space)))) {
                            toolbar.selected_tool = .hand;
                            input.pan(&camera, imgui.ImGuiMouseButton_Left);
                        }

                        // zoom
                        if (io.MouseWheel != 0) {
                            input.zoom(&camera);
                            zoom_time = 20;
                        }

                        if (zoom_time > 0) {

                            //TODO: make tooltip remain for a second or so after stop scrolling
                            imgui.igBeginTooltip();
                            var zoom_text = std.fmt.allocPrintZ(upaya.mem.tmp_allocator, "{s} {d}", .{ imgui.icons.search, camera.zoom }) catch unreachable;
                            imgui.igText(@ptrCast([*c]const u8, zoom_text));
                            imgui.igEndTooltip();

                            zoom_time -= 1;
                        }

                        // round positions if we are finished changing cameras position
                        if (imgui.igIsMouseReleased(imgui.ImGuiMouseButton_Middle) or imgui.ogKeyUp(@intCast(usize, imgui.igGetKeyIndex(imgui.ImGuiKey_Space)))) {
                            camera.position.x = @trunc(camera.position.x);
                            camera.position.y = @trunc(camera.position.y);
                        }

                        if (toolbar.selected_tool == .hand and imgui.igIsMouseReleased(imgui.ImGuiMouseButton_Left)) {
                            camera.position.x = @trunc(camera.position.x);
                            camera.position.y = @trunc(camera.position.y);
                        }

                        if (getPixelCoords(sprite_position, sprite_rect, imgui.igGetIO().MousePos)) |pixel_coords| {
                            var pixel_index = getPixelIndexFromCoords(layer.texture, pixel_coords);

                            // color dropper input
                            if (imgui.igGetIO().MouseDown[1] or ((imgui.igGetIO().KeyAlt or imgui.igGetIO().KeySuper) and imgui.igGetIO().MouseDown[0])) {
                                imgui.igBeginTooltip();
                                var coord_text = std.fmt.allocPrint(upaya.mem.allocator, "{s} {d},{d}\u{0}", .{ imgui.icons.eye_dropper, pixel_coords.x + 1, pixel_coords.y + 1 }) catch unreachable;
                                imgui.igText(@ptrCast([*c]const u8, coord_text));
                                upaya.mem.allocator.free(coord_text);
                                imgui.igEndTooltip();

                                if (layer.image.pixels[pixel_index] == 0x00000000) {
                                    toolbar.selected_tool = .eraser;
                                    previous_tool = toolbar.selected_tool;
                                } else {
                                    toolbar.selected_tool = .pencil;
                                    previous_tool = toolbar.selected_tool;
                                    toolbar.foreground_color = upaya.math.Color{ .value = layer.image.pixels[pixel_index] };

                                    imgui.igBeginTooltip();
                                    _ = imgui.ogColoredButtonEx(toolbar.foreground_color.value, "###1", .{ .x = 100, .y = 100 });
                                    imgui.igEndTooltip();
                                }
                            }

                            // drawing input
                            if (toolbar.selected_tool == .pencil or toolbar.selected_tool == .eraser) {
                                if (imgui.igIsMouseDragging(imgui.ImGuiMouseButton_Left, 0)) {
                                    layer.image.pixels[pixel_index] = if (toolbar.selected_tool == .pencil) toolbar.foreground_color.value else 0x00000000;
                                    layer.*.dirty = true;
                                }
                            }
                        }
                    }

                    toolbar.selected_tool = previous_tool;
                }
            }
        }
    }
}

//TODO fix this....
fn fitToWindow(position: imgui.ImVec2, rect: upaya.math.RectF) void {
    const tl = camera.matrix().transformImVec2(position).add(screen_pos);
    var br = position;
    br.x += rect.width;
    br.y += rect.height;
    br = camera.matrix().transformImVec2(br).add(screen_pos);

    var window_size = imgui.ogGetWindowContentRegionMax();
    var sprite_size: imgui.ImVec2 = .{ .x = br.x - tl.x, .y = br.y - tl.y };
    var current_zoom_index: usize = 0;
    for (input.zoom_steps) |z, i| {
        if (z == camera.zoom)
            current_zoom_index = i;
    }

    if (window_size.y > sprite_size.y) {
        if (current_zoom_index < input.zoom_steps.len - 1) {
            var next_sprite_height = sprite_size.y * (input.zoom_steps[current_zoom_index + 1] - camera.zoom);

            if (next_sprite_height <= window_size.y) {
                camera.zoom = input.zoom_steps[current_zoom_index + 1];
            }
        }
    }

    if (window_size.y <= sprite_size.y) {
        if (current_zoom_index > 0) {
            camera.zoom = input.zoom_steps[current_zoom_index - 1];
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

fn getPixelCoords( sprite_position: imgui.ImVec2, rect: upaya.math.RectF, position: imgui.ImVec2) ?imgui.ImVec2 {
    var tl = camera.matrix().transformImVec2(sprite_position).add(screen_pos);
    var br: imgui.ImVec2 = sprite_position;
    br.x += rect.width;
    br.y += rect.height;
    br = camera.matrix().transformImVec2(br).add(screen_pos);

    if (position.x > tl.x and position.x < br.x and position.y < br.y and position.y > tl.y) {
        var pixel_pos: imgui.ImVec2 = .{};

        //sprite pixel position
        pixel_pos.x = @divTrunc(position.x - tl.x, camera.zoom);
        pixel_pos.y = @divTrunc(position.y - tl.y, camera.zoom);

        //add src x and y (top left of sprite)
        pixel_pos.x += rect.x;
        pixel_pos.y += rect.y;

        return pixel_pos;
    } else return null;
}

fn getPixelIndexFromCoords(texture: upaya.Texture, coords: imgui.ImVec2) usize {
    return @floatToInt(usize, coords.x + coords.y * @intToFloat(f32, texture.width));
}
