const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

pub const Camera = @import("../utils/camera.zig").Camera;

const editor = @import("../editor.zig");
const input = editor.input;
const types = editor.types;
const history = editor.history;
const toolbar = editor.toolbar;
const layers = editor.layers;
const sprites = editor.sprites;
const animations = editor.animations;

const algorithms = @import("../utils/algorithms.zig");

const File = types.File;
const Layer = types.Layer;
const Animation = types.Animation;

var camera: Camera = .{ .zoom = 2 };
var screen_pos: imgui.ImVec2 = undefined;
var texture_position: imgui.ImVec2 = undefined;

var logo: ?upaya.Texture = null;

var active_file_index: usize = 0;
var files: std.ArrayList(File) = undefined;

var previous_mouse_position: imgui.ImVec2 = undefined;

pub var current_stroke_colors: std.ArrayList(u32) = undefined;
pub var current_stroke_indexes: std.ArrayList(usize) = undefined;

pub fn init() void {
    files = std.ArrayList(File).init(upaya.mem.allocator);
    current_stroke_colors = std.ArrayList(u32).init(upaya.mem.allocator);
    current_stroke_indexes = std.ArrayList(usize).init(upaya.mem.allocator);
    var logo_pixels = [_]u32{
        0x00000000, 0xFF89AFEF, 0xFF89AFEF, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
        0xFF7391D8, 0xFF201a19, 0xFF7391D8, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
        0xFF5C6DC2, 0xFF5C6DC2, 0xFF5C6DC2, 0xFF89AFEF, 0xFF89AFEF, 0xFF89AFEF, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
        0x8C5058FF, 0xFF201a19, 0xFF201a19, 0xFF201a19, 0xFF7391D8, 0xFF201a19, 0xFF89E6C5, 0x00000000, 0xFF89E6C5, 0x00000000, 0x00000000, 0x00000000,
        0xFF201a19, 0x00000000, 0x00000000, 0xFF5C6DC2, 0xFF5C6DC2, 0xFF5C6DC2, 0xFF201a19, 0xFF7BC167, 0xFF201a19, 0xFFC5E689, 0xFFC5E689, 0xFFC5E689,
        0x00000000, 0x00000000, 0x00000000, 0xFF201a19, 0xFF201a19, 0xFF201a19, 0xFF678540, 0xFF201a19, 0xFF678540, 0xFF201a19, 0xFFA78F4A, 0xFF201a19,
        0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0xFF201a19, 0xFF201a19, 0xFF201a19, 0xFF844531, 0xFF844531, 0xFF844531,
        0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0xFF201a19, 0xFF201a19, 0xFF201a19,
    };

    logo = upaya.Texture.initWithColorData(&logo_pixels, 12, 8, .nearest, .clamp);

    upaya.sokol.sapp_set_icon(&.{ .sokol_default = true, .images = undefined });
}

pub fn addFile(file: File) void {
    active_file_index = 0;
    files.insert(0, file) catch unreachable;
}

pub fn getNumberOfFiles() usize {
    return files.items.len;
}

pub fn getActiveFile() ?*File {
    if (files.items.len == 0)
        return null;

    // this is trash but i cant see a way i can
    // get around it without having to track state of
    // the canvas tabs outside of the loop...
    if (active_file_index >= files.items.len)
        active_file_index = files.items.len - 1;

    return &files.items[active_file_index];
}

pub fn getFile(index: usize) ?*File {
    if (index < files.items.len)
        return &files.items[index];

    return null;
}

pub fn draw() void {
    if (!imgui.igBegin("Canvas", null, imgui.ImGuiWindowFlags_None)) return;
    defer imgui.igEnd();

    // setup screen position and size
    screen_pos = imgui.ogGetCursorScreenPos();
    const window_size = imgui.ogGetContentRegionAvail();
    if (window_size.x == 0 or window_size.y == 0) return;

    if (getActiveFile()) |file| {
        texture_position = .{
            .x = -@intToFloat(f32, file.background.width) / 2,
            .y = -@intToFloat(f32, file.background.height) / 2,
        };

        // draw background texture
        drawTexture(file.background, texture_position, 0xFFFFFFFF);

        // draw layers (reverse order)
        var layer_index: usize = file.layers.items.len;
        while (layer_index > 0) {
            layer_index -= 1;

            if (file.layers.items[layer_index].hidden)
                continue;

            file.layers.items[layer_index].updateTexture();
            drawTexture(file.layers.items[layer_index].texture, texture_position, 0xFFFFFFFF);

            // draw temporary texture over active layer
            if (layer_index == layers.getActiveIndex()) {
                file.temporary.updateTexture();
                drawTexture(file.temporary.texture, texture_position, 0xFFFFFFFF);
            }
        }

        // blank out image for next frame
        file.temporary.image.fillRect(.{
            .x = 0,
            .y = 0,
            .width = file.width,
            .height = file.height,
        }, upaya.math.Color.transparent);
        file.temporary.dirty = true;

        // draw tile grid
        drawGrid(file, texture_position);

        // draw fill to hide canvas behind transparent tab bar
        var cursor_position = imgui.ogGetCursorPos();
        imgui.ogAddRectFilled(imgui.igGetWindowDrawList(), cursor_position, .{ .x = imgui.ogGetWindowSize().x * 2, .y = 40 }, imgui.ogColorConvertFloat4ToU32(editor.background_color));

        // draw open files tabs
        if (imgui.igBeginTabBar("Canvas Tab Bar", imgui.ImGuiTabBarFlags_Reorderable | imgui.ImGuiTabBarFlags_AutoSelectNewTabs)) {
            defer imgui.igEndTabBar();

            for (files.items) |f, i| {
                var open: bool = true;

                var name_z = upaya.mem.allocator.dupeZ(u8, f.name) catch unreachable;
                defer upaya.mem.allocator.free(name_z);
                imgui.igPushIDInt(@intCast(c_int, i));
                var dirty_flag = if (files.items[i].dirty) imgui.ImGuiTabItemFlags_UnsavedDocument else imgui.ImGuiTabItemFlags_None;
                if (imgui.igBeginTabItem(@ptrCast([*c]const u8, name_z), &open, dirty_flag)) {
                    defer imgui.igEndTabItem();
                    active_file_index = i;
                }
                imgui.igPopID();

                if (!open) {
                    // TODO: do i need to deinit all the layers and background?
                    active_file_index = 0;
                    sprites.setActiveSpriteIndex(0);
                    _ = files.swapRemove(i);
                    //f.deinit();
                }
            }
        }
        // store previous tool and reapply it after to allow quick switching
        var previous_tool = toolbar.selected_tool;
        // handle inputs
        if (imgui.igIsWindowHovered(imgui.ImGuiHoveredFlags_None)) {
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

            if (layers.getActiveLayer()) |layer| {
                if (getPixelCoords(layer.texture, mouse_position)) |pixel_coords| {
                    var tiles_wide = @divExact(@intCast(usize, file.width), @intCast(usize, file.tileWidth));

                    var tile_column = @divTrunc(@floatToInt(usize, pixel_coords.x), @intCast(usize, file.tileWidth));
                    var tile_row = @divTrunc(@floatToInt(usize, pixel_coords.y), @intCast(usize, file.tileHeight));

                    var tile_index = tile_column + tile_row * tiles_wide;
                    var pixel_index = getPixelIndexFromCoords(layer.texture, pixel_coords);

                    // set active sprite window
                    if (io.MouseDown[0] and toolbar.selected_tool != toolbar.Tool.hand and animations.animation_state != .play) {
                        sprites.setActiveSpriteIndex(tile_index);

                        if (toolbar.selected_tool == toolbar.Tool.arrow) {
                            imgui.igBeginTooltip();
                            var index_text = std.fmt.allocPrintZ(upaya.mem.tmp_allocator, "Index: {d}", .{tile_index}) catch unreachable;
                            imgui.igText(@ptrCast([*c]const u8, index_text));
                            imgui.igEndTooltip();
                        }
                    }

                    // color dropper input
                    if (io.MouseDown[1] or ((io.KeyAlt or io.KeySuper) and io.MouseDown[0]) or (io.MouseDown[0] and toolbar.selected_tool == .dropper)) {
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
                        } else file.temporary.image.pixels[pixel_index] = 0xFFFFFFFF;

                        file.temporary.dirty = true;

                        if (imgui.igIsMouseDragging(imgui.ImGuiMouseButton_Left, 0) and !io.KeyShift) {
                            if (getPixelCoords(layer.texture, previous_mouse_position)) |prev_pixel_coords| {
                                var output = algorithms.brezenham(prev_pixel_coords, pixel_coords);

                                for (output) |coords| {
                                    var index = getPixelIndexFromCoords(layer.texture, coords);

                                    if (toolbar.selected_tool == .pencil and layer.image.pixels[index] != toolbar.foreground_color.value or toolbar.selected_tool == .eraser and layer.image.pixels[index] != 0x00000000) {
                                        current_stroke_colors.append(layer.image.pixels[index]) catch unreachable;
                                        current_stroke_indexes.append(index) catch unreachable;
                                        layer.image.pixels[index] = if (toolbar.selected_tool == .pencil) toolbar.foreground_color.value else 0x00000000;
                                    }
                                }
                                upaya.mem.allocator.free(output);
                                layer.dirty = true;
                            }
                        }

                        if (imgui.igIsMouseDragging(imgui.ImGuiMouseButton_Left, 0) and io.KeyShift) {
                            if (getPixelCoords(layer.texture, io.MouseClickedPos[0])) |prev_pixel_coords| {
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
                            if (getPixelCoords(layer.texture, io.MouseClickedPos[0])) |prev_pixel_coords| {
                                var output = algorithms.brezenham(prev_pixel_coords, pixel_coords);

                                for (output) |coords| {
                                    var index = getPixelIndexFromCoords(layer.texture, coords);
                                    current_stroke_indexes.append(index) catch unreachable;
                                    current_stroke_colors.append(layer.image.pixels[index]) catch unreachable;
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
                                .pixel_colors = current_stroke_colors.toOwnedSlice(),
                                .pixel_indexes = current_stroke_indexes.toOwnedSlice(),
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
                                    current_stroke_indexes.append(index) catch unreachable;
                                    current_stroke_colors.append(layer.image.pixels[index]) catch unreachable;
                                    layer.image.pixels[index] = toolbar.foreground_color.value;
                                }
                            }
                            layer.dirty = true;

                            file.history.push(.{
                                .tag = .stroke,
                                .pixel_colors = current_stroke_colors.toOwnedSlice(),
                                .pixel_indexes = current_stroke_indexes.toOwnedSlice(),
                                .layer_id = layer.id,
                            });
                        }
                    }

                    // set animation
                    if (toolbar.selected_tool == .animation) {
                        if (io.MouseClicked[0] and !imgui.ogKeyDown(upaya.sokol.SAPP_KEYCODE_SPACE)) {
                            if (animations.getActiveAnimation()) |animation| {
                                animation.start = tile_index;
                                sprites.resetNames();
                            }
                        }

                        if (imgui.igIsMouseDragging(imgui.ImGuiMouseButton_Left, 0)) {
                            if (animations.getActiveAnimation()) |animation| {
                                if (@intCast(i32, tile_index) - @intCast(i32, animation.start) + 1 >= 0)
                                    animation.length = tile_index - animation.start + 1;
                                sprites.resetNames();
                            }
                        }
                    }
                }
            }

            toolbar.selected_tool = previous_tool;
            previous_mouse_position = mouse_position;
        }
    } else {
        camera.position = .{ .x = 0, .y = 0 };
        camera.zoom = 28;

        var logo_pos = .{ .x = -@intToFloat(f32, logo.?.width) / 2, .y = -@intToFloat(f32, logo.?.height) / 2 };
        // draw background texture
        drawTexture(logo.?, logo_pos, 0x33FFFFFF);

        var text_pos = imgui.ogGetWindowCenter();
        text_pos.y += @intToFloat(f32, logo.?.height);
        text_pos.y += 175;
        text_pos.x -= 60;

        imgui.ogSetCursorPos(text_pos);
        const mod_name = if(std.builtin.os.tag == .windows) "ctrl" else if (std.builtin.os.tag == .linux) "super" else "cmd";
        imgui.ogColoredText(0.3, 0.3, 0.3, "New File " ++ imgui.icons.file ++ " (" ++ mod_name ++ "+n)");
    }
}

fn drawGrid(file: *File, position: imgui.ImVec2) void {
    var tilesWide = @divExact(file.width, file.tileWidth);
    var tilesTall = @divExact(file.height, file.tileHeight);

    var x: i32 = 0;
    while (x <= tilesWide) : (x += 1) {
        var top = position.add(.{ .x = @intToFloat(f32, x * file.tileWidth), .y = 0 });
        var bottom = position.add(.{ .x = @intToFloat(f32, x * file.tileWidth), .y = @intToFloat(f32, file.height) });

        top = camera.matrix().transformImVec2(top).add(screen_pos);
        bottom = camera.matrix().transformImVec2(bottom).add(screen_pos);

        imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), top, bottom, editor.gridColor.value, 1);
    }

    var y: i32 = 0;
    while (y <= tilesTall) : (y += 1) {
        var left = position.add(.{ .x = 0, .y = @intToFloat(f32, y * file.tileHeight) });
        var right = position.add(.{ .x = @intToFloat(f32, file.width), .y = @intToFloat(f32, y * file.tileHeight) });

        left = camera.matrix().transformImVec2(left).add(screen_pos);
        right = camera.matrix().transformImVec2(right).add(screen_pos);

        imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), left, right, editor.gridColor.value, 1);
    }

    if (sprites.getActiveSprite()) |sprite| {
        var column = @mod(@intCast(i32, sprite.index), tilesWide);
        var row = @divTrunc(@intCast(i32, sprite.index), tilesWide);

        var tl: imgui.ImVec2 = position.add(.{ .x = @intToFloat(f32, column * file.tileWidth), .y = @intToFloat(f32, row * file.tileHeight) });
        tl = camera.matrix().transformImVec2(tl).add(screen_pos);
        var size: imgui.ImVec2 = .{ .x = @intToFloat(f32, file.tileWidth), .y = @intToFloat(f32, file.tileHeight) };
        size = size.scale(camera.zoom);

        imgui.ogAddRect(imgui.igGetWindowDrawList(), tl, size, imgui.ogColorConvertFloat4ToU32(editor.highlight_color_green), 2);
    }

    if (animations.getActiveAnimation()) |animation| {
        const start_column = @mod(@intCast(i32, animation.start), tilesWide);
        const start_row = @divTrunc(@intCast(i32, animation.start), tilesWide);

        var start_tl: imgui.ImVec2 = position.add(.{ .x = @intToFloat(f32, start_column * file.tileWidth), .y = @intToFloat(f32, start_row * file.tileHeight) });
        var start_bl: imgui.ImVec2 = start_tl.add(.{ .x = 0, .y = @intToFloat(f32, file.tileHeight) });
        var start_tm: imgui.ImVec2 = start_tl.add(.{ .x = @intToFloat(f32, @divTrunc(file.tileWidth, 2)) });
        var start_bm: imgui.ImVec2 = start_bl.add(.{ .x = @intToFloat(f32, @divTrunc(file.tileWidth, 2)) });
        start_tl = camera.matrix().transformImVec2(start_tl).add(screen_pos);
        start_bl = camera.matrix().transformImVec2(start_bl).add(screen_pos);

        start_tm = camera.matrix().transformImVec2(start_tm).add(screen_pos);
        start_bm = camera.matrix().transformImVec2(start_bm).add(screen_pos);
        imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), start_tl, start_bl, 0xFFFFAA00, 2);
        imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), start_tl, start_tm, 0xFFFFAA00, 2);
        imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), start_bl, start_bm, 0xFFFFAA00, 2);

        const end_column = @mod(@intCast(i32, animation.start + animation.length - 1), tilesWide);
        const end_row = @divTrunc(@intCast(i32, animation.start + animation.length - 1), tilesWide);

        var end_tr: imgui.ImVec2 = position.add(.{ .x = @intToFloat(f32, end_column * file.tileWidth + file.tileWidth), .y = @intToFloat(f32, end_row * file.tileHeight) });
        var end_br: imgui.ImVec2 = end_tr.add(.{ .x = 0, .y = @intToFloat(f32, file.tileHeight) });
        var end_tm: imgui.ImVec2 = end_tr.subtract(.{ .x = @intToFloat(f32, @divTrunc(file.tileWidth, 2)) });
        var end_bm: imgui.ImVec2 = end_br.subtract(.{ .x = @intToFloat(f32, @divTrunc(file.tileWidth, 2)) });
        end_tr = camera.matrix().transformImVec2(end_tr).add(screen_pos);
        end_br = camera.matrix().transformImVec2(end_br).add(screen_pos);

        end_tm = camera.matrix().transformImVec2(end_tm).add(screen_pos);
        end_bm = camera.matrix().transformImVec2(end_bm).add(screen_pos);
        imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), end_tr, end_br, 0xFFAA00FF, 2);
        imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), end_tr, end_tm, 0xFFAA00FF, 2);
        imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), end_br, end_bm, 0xFFAA00FF, 2);
    }
}

fn drawTexture(texture: upaya.Texture, position: imgui.ImVec2, color: u32) void {
    const tl = camera.matrix().transformImVec2(position).add(screen_pos);
    var br = position;
    br.x += @intToFloat(f32, texture.width);
    br.y += @intToFloat(f32, texture.height);
    br = camera.matrix().transformImVec2(br).add(screen_pos);

    imgui.ogImDrawList_AddImage(
        imgui.igGetWindowDrawList(),
        texture.imTextureID(),
        tl,
        br,
        .{},
        .{ .x = 1, .y = 1 },
        color,
    );
}

pub fn getPixelCoords(texture: upaya.Texture, position: imgui.ImVec2) ?imgui.ImVec2 {
    var tl = camera.matrix().transformImVec2(texture_position).add(screen_pos);
    var br: imgui.ImVec2 = texture_position;
    br.x += @intToFloat(f32, texture.width);
    br.y += @intToFloat(f32, texture.height);
    br = camera.matrix().transformImVec2(br).add(screen_pos);

    if (position.x > tl.x and position.x < br.x and position.y < br.y and position.y > tl.y) {
        var pixel_pos: imgui.ImVec2 = .{};

        pixel_pos.x = @divTrunc(position.x - tl.x, camera.zoom);
        pixel_pos.y = @divTrunc(position.y - tl.y, camera.zoom);

        return pixel_pos;
    } else return null;
}

pub fn getPixelIndexFromCoords(texture: upaya.Texture, coords: imgui.ImVec2) usize {
    return @floatToInt(usize, coords.x + coords.y * @intToFloat(f32, texture.width));
}

pub fn close() void {
    logo.?.deinit();
    for (files.items) |_, i| {
        files.items[i].deinit();
    }
}
