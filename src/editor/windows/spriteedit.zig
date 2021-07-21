const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

pub const Camera = @import("../utils/camera.zig").Camera;

const editor = @import("../editor.zig");
const input = @import("../input/input.zig");
const types = @import("../types/types.zig");
const history = editor.history;
const toolbar = editor.toolbar;
const layers = editor.layers;
const sprites = editor.sprites;
const canvas = editor.canvas;
const animations = editor.animations;

const algorithms = @import("../utils/algorithms.zig");

const File = types.File;
const Layer = types.Layer;
const Animation = types.Animation;

var camera: Camera = .{ .zoom = 4 };
var screen_pos: imgui.ImVec2 = undefined;

var sprite_position: imgui.ImVec2 = undefined;
var sprite_rect: upaya.math.RectF = undefined;

var previous_sprite_position: imgui.ImVec2 = undefined;
var next_sprite_position: imgui.ImVec2 = undefined;

var previous_sprite_rect: upaya.math.RectF = undefined;
var next_sprite_rect: upaya.math.RectF = undefined;

var previous_mouse_position: imgui.ImVec2 = undefined;

pub var preview_opacity: f32 = 50; //default
pub var preview_origin: bool = false;

pub fn draw() void {
    if (imgui.igBegin("SpriteEdit", 0, imgui.ImGuiWindowFlags_None)) {
        defer imgui.igEnd();

        if (imgui.igBeginPopupContextItem("SpriteEdit Settings", imgui.ImGuiMouseButton_Right)) {
            defer imgui.igEndPopup();

            imgui.igText("SpriteEdit Settings");
            imgui.igSeparator();

            _ = imgui.igSliderFloat("Adjacent Opacity", &preview_opacity, 0, 100, "%.0f", 1);
            _ = imgui.igCheckbox("Show Origin", &preview_origin);
        }

        // setup screen position and size
        screen_pos = imgui.ogGetCursorScreenPos();
        const window_size = imgui.ogGetContentRegionAvail();
        if (window_size.x == 0 or window_size.y == 0) return;

        if (canvas.getActiveFile()) |file| {
            if (sprites.getActiveSprite()) |sprite| {
                sprite_position = .{
                    .x = -@intToFloat(f32, file.tileWidth) / 2,
                    .y = -@intToFloat(f32, file.tileHeight) / 2 - 4,
                };

                const tiles_wide = @divExact(file.width, file.tileWidth);

                const column = @mod(@intCast(i32, sprite.index), tiles_wide);
                const row = @divTrunc(@intCast(i32, sprite.index), tiles_wide);

                const src_x = column * file.tileWidth;
                const src_y = row * file.tileHeight;

                sprite_rect = .{
                    .width = @intToFloat(f32, file.tileWidth),
                    .height = @intToFloat(f32, file.tileHeight),
                    .x = @intToFloat(f32, src_x),
                    .y = @intToFloat(f32, src_y),
                };

                // draw transparency background sprite
                drawSprite(file.background, sprite_position, sprite_rect, 0xFFFFFFFF);

                const preview_color = upaya.math.Color.fromRgba(1, 1, 1, preview_opacity / 100);

                if (animations.getActiveAnimation()) |animation| {
                    if (animation.length > 1 and sprite.index >= animation.start and sprite.index < animation.start + animation.length) {
                        const previous_sprite_index = if (sprite.index > animation.start) sprite.index - 1 else sprite.index + animation.length - 1;
                        previous_sprite_position = sprite_position.subtract(.{ .x = @intToFloat(f32, file.tileWidth + 1), .y = 0 });

                        const previous_column = @mod(@intCast(i32, previous_sprite_index), tiles_wide);
                        const previous_row = @divTrunc(@intCast(i32, previous_sprite_index), tiles_wide);

                        const previous_src_x = previous_column * file.tileWidth;
                        const previous_src_y = previous_row * file.tileHeight;

                        previous_sprite_rect = .{
                            .width = @intToFloat(f32, file.tileWidth),
                            .height = @intToFloat(f32, file.tileHeight),
                            .x = @intToFloat(f32, previous_src_x),
                            .y = @intToFloat(f32, previous_src_y),
                        };

                        drawSprite(file.background, previous_sprite_position, previous_sprite_rect, preview_color.value);

                        const next_sprite_index = if (sprite.index < animation.start + animation.length - 1) sprite.index + 1 else animation.start;

                        next_sprite_position = sprite_position.add(.{ .x = @intToFloat(f32, file.tileWidth + 1), .y = 0 });

                        const next_column = @mod(@intCast(i32, next_sprite_index), tiles_wide);
                        const next_row = @divTrunc(@intCast(i32, next_sprite_index), tiles_wide);

                        const next_src_x = next_column * file.tileWidth;
                        const next_src_y = next_row * file.tileHeight;

                        next_sprite_rect = .{
                            .width = @intToFloat(f32, file.tileWidth),
                            .height = @intToFloat(f32, file.tileHeight),
                            .x = @intToFloat(f32, next_src_x),
                            .y = @intToFloat(f32, next_src_y),
                        };

                        drawSprite(file.background, next_sprite_position, next_sprite_rect, preview_color.value);
                    }
                }

                // draw sprite of each layer (reverse order)
                var layer_index: usize = file.layers.items.len;
                while (layer_index > 0) {
                    layer_index -= 1;

                    if (file.layers.items[layer_index].hidden)
                        continue;

                    drawSprite(file.layers.items[layer_index].texture, sprite_position, sprite_rect, 0xFFFFFFFF);

                    if (animations.getActiveAnimation()) |animation| {
                        if (animation.length > 1 and sprite.index >= animation.start and sprite.index < animation.start + animation.length) {
                            drawSprite(file.layers.items[layer_index].texture, previous_sprite_position, previous_sprite_rect, preview_color.value);
                            drawSprite(file.layers.items[layer_index].texture, next_sprite_position, next_sprite_rect, preview_color.value);
                        }
                    }

                    if (layer_index == layers.getActiveIndex()) {
                        drawSprite(file.temporary.texture, sprite_position, sprite_rect, 0xFFFFFFFF);

                        if (animations.getActiveAnimation()) |animation| {
                            if (animation.length > 1 and sprite.index >= animation.start and sprite.index < animation.start + animation.length) {
                                drawSprite(file.temporary.texture, previous_sprite_position, previous_sprite_rect, 0xFFFFFFFF);
                                drawSprite(file.temporary.texture, next_sprite_position, next_sprite_rect, 0xFFFFFFFF);
                            }
                        }
                    }
                }

                if (preview_origin) {
                    var origin: imgui.ImVec2 = .{ .x = sprite.origin_x, .y = sprite.origin_y };
                    origin = origin.add(sprite_position);
                    origin = camera.matrix().transformImVec2(origin).add(screen_pos);

                    const tl = origin.add(.{ .x = -4, .y = -4 });
                    const tr = origin.add(.{ .x = 4, .y = -4 });
                    const bl = origin.add(.{ .x = -4, .y = 4 });
                    const br = origin.add(.{ .x = 4, .y = 4 });

                    imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), tl, br, 0xFF0000FF, 1);
                    imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), bl, tr, 0xFF0000FF, 1);
                }

                // store previous tool and reapply it after to allow quick switching
                var previous_tool = toolbar.selected_tool;
                // handle inputs
                if (imgui.igIsWindowHovered(imgui.ImGuiHoveredFlags_None)) {
                    if (layers.getActiveLayer()) |layer| {
                        const io = imgui.igGetIO();
                        const mouse_position = io.MousePos;

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
                            camera.position.x = @trunc(camera.position.x);
                            camera.position.y = @trunc(camera.position.y);
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

                        if (getPixelCoords(mouse_position)) |pixel_coords| {
                            var pixel_index = getPixelIndexFromCoords(layer.texture, pixel_coords);

                            // color dropper input
                            if (imgui.igGetIO().MouseDown[1] or ((imgui.igGetIO().KeyAlt or imgui.igGetIO().KeySuper) and imgui.igGetIO().MouseDown[0]) or (io.MouseDown[0] and toolbar.selected_tool == .dropper)) {
                                imgui.igBeginTooltip();
                                var coord_text = std.fmt.allocPrintZ(upaya.mem.allocator, "{s} {d},{d}", .{ imgui.icons.eye_dropper, pixel_coords.x + 1, pixel_coords.y + 1 }) catch unreachable;
                                imgui.igText(@ptrCast([*c]const u8, coord_text));
                                upaya.mem.allocator.free(coord_text);
                                imgui.igEndTooltip();

                                if (layer.image.pixels[pixel_index] == 0x00000000) {
                                    if (toolbar.selected_tool != .dropper) {
                                        toolbar.selected_tool = .eraser;
                                        previous_tool = toolbar.selected_tool;
                                    }
                                } else {
                                    if (toolbar.selected_tool != .dropper) {
                                        toolbar.selected_tool = .pencil;
                                        previous_tool = toolbar.selected_tool;
                                    }
                                    toolbar.foreground_color = upaya.math.Color{ .value = layer.image.pixels[pixel_index] };

                                    imgui.igBeginTooltip();
                                    _ = imgui.ogColoredButtonEx(toolbar.foreground_color.value, "###1", .{ .x = 100, .y = 100 });
                                    imgui.igEndTooltip();
                                }
                            }

                            // drawing input
                            if (toolbar.selected_tool == .pencil or toolbar.selected_tool == .eraser) {
                                if (toolbar.selected_tool == .pencil) {
                                    file.temporary.image.pixels[pixel_index] = toolbar.foreground_color.value;
                                    file.temporary.dirty = true;
                                } else {
                                    file.temporary.image.pixels[pixel_index] = 0xFFFFFFFF;
                                    file.temporary.dirty = true;
                                }

                                if (imgui.igIsMouseDragging(imgui.ImGuiMouseButton_Left, 0) and !io.KeyShift) {
                                    if (getPixelCoords(previous_mouse_position)) |prev_pixel_coords| {
                                        var output = algorithms.brezenham(prev_pixel_coords, pixel_coords);

                                        for (output) |coords| {
                                            var index = getPixelIndexFromCoords(layer.texture, coords);

                                            if (toolbar.selected_tool == .pencil and layer.image.pixels[index] != toolbar.foreground_color.value or toolbar.selected_tool == .eraser and layer.image.pixels[index] != 0x00000000) {
                                                canvas.current_stroke_colors.append(layer.image.pixels[index]) catch unreachable;
                                                canvas.current_stroke_indexes.append(index) catch unreachable;
                                                layer.image.pixels[index] = if (toolbar.selected_tool == .pencil) toolbar.foreground_color.value else 0x00000000;
                                            }
                                        }
                                        upaya.mem.allocator.free(output);
                                        layer.dirty = true;
                                    }
                                }

                                if (imgui.igIsMouseDragging(imgui.ImGuiMouseButton_Left, 0) and io.KeyShift) {
                                    if (getPixelCoords(io.MouseClickedPos[0])) |prev_pixel_coords| {
                                        var output = algorithms.brezenham(prev_pixel_coords, pixel_coords);

                                        for (output) |coords| {
                                            var index = getPixelIndexFromCoords(layer.texture, coords);
                                            file.temporary.image.pixels[index] = if (toolbar.selected_tool == .pencil) toolbar.foreground_color.value else 0xFFFFFFFF;
                                        }
                                        upaya.mem.allocator.free(output);
                                        file.temporary.dirty = true;
                                    }
                                }

                                if (imgui.igIsMouseReleased(imgui.ImGuiMouseButton_Left) and io.KeyShift) {
                                    if (getPixelCoords(io.MouseClickedPos[0])) |prev_pixel_coords| {
                                        var output = algorithms.brezenham(prev_pixel_coords, pixel_coords);

                                        for (output) |coords| {
                                            var index = getPixelIndexFromCoords(layer.texture, coords);
                                            canvas.current_stroke_indexes.append(index) catch unreachable;
                                            canvas.current_stroke_colors.append(layer.image.pixels[index]) catch unreachable;
                                            layer.image.pixels[index] = if (toolbar.selected_tool == .pencil) toolbar.foreground_color.value else 0xFFFFFFFF;
                                        }
                                        upaya.mem.allocator.free(output);
                                        layer.dirty = true;
                                    }
                                }

                                //write to history
                                if (imgui.igIsMouseReleased(imgui.ImGuiMouseButton_Left)) {
                                    file.history.push(.{
                                        .tag = .stroke,
                                        .pixel_colors = canvas.current_stroke_colors.toOwnedSlice(),
                                        .pixel_indexes = canvas.current_stroke_indexes.toOwnedSlice(),
                                        .layer_id = layer.id,
                                    });
                                }
                            }

                            //fill
                            if (toolbar.selected_tool == .bucket) {
                                if (imgui.igIsMouseClicked(imgui.ImGuiMouseButton_Left, false)) {
                                    var output = algorithms.floodfill(pixel_coords, layer.image, toolbar.contiguous_fill);

                                    for (output) |index| {
                                        if (layer.image.pixels[index] != toolbar.foreground_color.value) {
                                            canvas.current_stroke_indexes.append(index) catch unreachable;
                                            canvas.current_stroke_colors.append(layer.image.pixels[index]) catch unreachable;
                                            layer.image.pixels[index] = toolbar.foreground_color.value;
                                        }
                                    }
                                    layer.dirty = true;

                                    file.history.push(.{
                                        .tag = .stroke,
                                        .pixel_colors = canvas.current_stroke_colors.toOwnedSlice(),
                                        .pixel_indexes = canvas.current_stroke_indexes.toOwnedSlice(),
                                        .layer_id = layer.id,
                                    });
                                }
                            }
                        }
                        toolbar.selected_tool = previous_tool;
                        previous_mouse_position = mouse_position;
                    }
                }
            }

            if (imgui.igIsWindowFocused(imgui.ImGuiFocusedFlags_None)) {
                if (sprites.getActiveSprite()) |sprite| {

                    // right/down arrow changes sprite
                    if (imgui.ogKeyPressed(upaya.sokol.SAPP_KEYCODE_RIGHT) or imgui.ogKeyPressed(upaya.sokol.SAPP_KEYCODE_DOWN)) {
                        sprites.setActiveSpriteIndex(sprite.index + 1);
                    }

                    // left/up arrow changes sprite
                    if ((imgui.ogKeyPressed(upaya.sokol.SAPP_KEYCODE_LEFT) or imgui.ogKeyPressed(upaya.sokol.SAPP_KEYCODE_UP)) and @intCast(i32, sprite.index) - 1 >= 0) {
                        sprites.setActiveSpriteIndex(sprite.index - 1);
                    }
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

pub fn getPixelCoords(position: imgui.ImVec2) ?imgui.ImVec2 {
    var tl = camera.matrix().transformImVec2(sprite_position).add(screen_pos);
    var br: imgui.ImVec2 = sprite_position;
    br.x += sprite_rect.width;
    br.y += sprite_rect.height;
    br = camera.matrix().transformImVec2(br).add(screen_pos);

    if (position.x > tl.x and position.x < br.x and position.y < br.y and position.y > tl.y) {
        var pixel_pos: imgui.ImVec2 = .{};

        //sprite pixel position
        pixel_pos.x = @divTrunc(position.x - tl.x, camera.zoom);
        pixel_pos.y = @divTrunc(position.y - tl.y, camera.zoom);

        //add src x and y (top left of sprite)
        pixel_pos.x += sprite_rect.x;
        pixel_pos.y += sprite_rect.y;

        return pixel_pos;
    }

    //previous sprite
    tl = camera.matrix().transformImVec2(previous_sprite_position).add(screen_pos);
    br = previous_sprite_position;
    br.x += previous_sprite_rect.width;
    br.y += previous_sprite_rect.height;
    br = camera.matrix().transformImVec2(br).add(screen_pos);

    if (position.x > tl.x and position.x < br.x and position.y < br.y and position.y > tl.y) {
        var pixel_pos: imgui.ImVec2 = .{};

        //sprite pixel position
        pixel_pos.x = @divTrunc(position.x - tl.x, camera.zoom);
        pixel_pos.y = @divTrunc(position.y - tl.y, camera.zoom);

        //add src x and y (top left of sprite)
        pixel_pos.x += previous_sprite_rect.x;
        pixel_pos.y += previous_sprite_rect.y;

        return pixel_pos;
    }

    //next sprite
    tl = camera.matrix().transformImVec2(next_sprite_position).add(screen_pos);
    br = next_sprite_position;
    br.x += next_sprite_rect.width;
    br.y += next_sprite_rect.height;
    br = camera.matrix().transformImVec2(br).add(screen_pos);

    if (position.x > tl.x and position.x < br.x and position.y < br.y and position.y > tl.y) {
        var pixel_pos: imgui.ImVec2 = .{};

        //sprite pixel position
        pixel_pos.x = @divTrunc(position.x - tl.x, camera.zoom);
        pixel_pos.y = @divTrunc(position.y - tl.y, camera.zoom);

        //add src x and y (top left of sprite)
        pixel_pos.x += next_sprite_rect.x;
        pixel_pos.y += next_sprite_rect.y;

        return pixel_pos;
    }

    return null;
}

pub fn getPixelIndexFromCoords(texture: upaya.Texture, coords: imgui.ImVec2) usize {
    return @floatToInt(usize, coords.x + coords.y * @intToFloat(f32, texture.width));
}
