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

const File = types.File;
const Layer = types.Layer;
const Animation = types.Animation;

var camera: Camera = .{ .zoom = 2 };
var screen_pos: imgui.ImVec2 = undefined;

const gridColor: upaya.math.Color = .{ .value = 0xFF999999 };
var logo: ?upaya.Texture = null;

var active_file_index: usize = 0;
var files: std.ArrayList(File) = undefined;

pub fn init() void {
    files = std.ArrayList(File).init(upaya.mem.allocator);
    logo = upaya.Texture.initFromFile("assets/pixi.png", .nearest) catch unreachable;
}

pub fn newFile(file: File) void {
    active_file_index = 0;
    files.insert(0, file) catch unreachable;
}

pub fn getNumberOfFiles() usize {
    return files.items.len;
}

pub fn getActiveFile() ?*File {
    if (files.items.len == 0)
        return null;

    if (active_file_index >= files.items.len)
        active_file_index = files.items.len - 1;

    return &files.items[active_file_index];
}

pub fn draw() void {
    if (!imgui.igBegin("Canvas", null, imgui.ImGuiWindowFlags_None)) return;
    defer imgui.igEnd();

    

    // setup screen position and size
    screen_pos = imgui.ogGetCursorScreenPos();
    const window_size = imgui.ogGetContentRegionAvail();
    if (window_size.x == 0 or window_size.y == 0) return;

    if (files.items.len > 0) {
        var texture_position = .{
            .x = -@intToFloat(f32, files.items[active_file_index].background.width) / 2,
            .y = -@intToFloat(f32, files.items[active_file_index].background.height) / 2,
        };

        // draw background texture
        drawTexture(files.items[active_file_index].background, texture_position, 0xFFFFFFFF);

        // draw layers
        for (files.items[active_file_index].layers.items) |layer, i| {
            if (layer.hidden)
                continue;

            layer.updateTexture();
            drawTexture(layer.texture, texture_position, 0xFFFFFFFF);
        }

        // draw tile grid
        drawGrid(files.items[active_file_index], texture_position);

        // draw selection from sprites list
        drawSelection();

        var cursor_position = imgui.ogGetCursorPos();
        imgui.ogAddRectFilled(imgui.igGetWindowDrawList(), cursor_position, .{ .x = imgui.ogGetWindowSize().x * 2, .y = 40 }, imgui.ogColorConvertFloat4ToU32(editor.background_color));

        // draw open files tabs
        if (imgui.igBeginTabBar("Canvas Tab Bar", imgui.ImGuiTabBarFlags_Reorderable)) {
            defer imgui.igEndTabBar();

            for (files.items) |file, i| {
                var open: bool = true;

                var namePtr = @ptrCast([*c]const u8, file.name);
                if (imgui.igBeginTabItem(namePtr, &open, imgui.ImGuiTabItemFlags_UnsavedDocument)) {
                    defer imgui.igEndTabItem();
                    active_file_index = i;
                }

                if (!open) {
                    // TODO: do i need to deinit all the layers and background?
                    active_file_index = 0;
                    sprites.setActiveSpriteIndex(0);
                    var f = files.swapRemove(i);
                    //f.deinit();
                }
            }
        }
        // store previous tool and reapply it after to allow quick switching
        var previous_tool = toolbar.selected_tool;
        // handle inputs
        if (imgui.igIsWindowHovered(imgui.ImGuiHoveredFlags_None) and files.items.len > 0) {

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
            if (imgui.igGetIO().MouseWheel != 0) {
                input.zoom(&camera);
            }

            // round positions if we are finished changing cameras position
            if (imgui.igIsMouseReleased(imgui.ImGuiMouseButton_Middle) or imgui.ogKeyUp(@intCast(usize, imgui.igGetKeyIndex(imgui.ImGuiKey_Space)))) {
                camera.position.x = @trunc(camera.position.x);
                camera.position.y = @trunc(camera.position.y);
            }

            if (toolbar.selected_tool == .hand and imgui.igIsMouseReleased(imgui.ImGuiMouseButton_Left)){
                camera.position.x = @trunc(camera.position.x);
                camera.position.y = @trunc(camera.position.y);
            }

            if (layers.getActiveLayer()) |layer| {
                if (getPixelCoords(layer.texture, texture_position, imgui.igGetIO().MousePos)) |pixel_coords| {
                    var tiles_wide = @divExact(@intCast(usize, files.items[active_file_index].width), @intCast(usize, files.items[active_file_index].tileWidth));
                    var tiles_tall = @divExact(@intCast(usize, files.items[active_file_index].height), @intCast(usize, files.items[active_file_index].tileHeight));

                    var tile_column = @divTrunc(@floatToInt(usize, pixel_coords.x), @intCast(usize, files.items[active_file_index].tileWidth));
                    var tile_row = @divTrunc(@floatToInt(usize, pixel_coords.y), @intCast(usize, files.items[active_file_index].tileHeight));

                    var tile_index = tile_column + tile_row * tiles_wide;
                    var pixel_index = getPixelIndexFromCoords(layer.texture, pixel_coords);

                    // set active sprite window
                    if (imgui.igGetIO().MouseDown[0] and toolbar.selected_tool != toolbar.Tool.hand)
                        sprites.setActiveSpriteIndex(tile_index);

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
                        if (imgui.igIsMouseDragging(imgui.ImGuiMouseButton_Left, 0))
                            layer.image.pixels[pixel_index] = if (toolbar.selected_tool == .pencil) toolbar.foreground_color.value else 0x00000000;
                    }
                }
            }

            toolbar.selected_tool = previous_tool;
        }
    } else {
        camera.position = .{ .x = 0, .y = 0 };
        camera.zoom = 2;

        var logo_pos = .{ .x = -@intToFloat(f32, logo.?.width) / 2, .y = -@intToFloat(f32, logo.?.height) / 2 };
        // draw background texture
        drawTexture(logo.?, logo_pos, 0x33FFFFFF);

        var text_pos = imgui.ogGetWindowCenter();
        text_pos.y += @intToFloat(f32, logo.?.height);
        text_pos.y += 60;
        text_pos.x -= 60;

        imgui.ogSetCursorPos(text_pos);
        imgui.ogColoredText(0.3, 0.3, 0.3, "New File " ++ imgui.icons.file ++ " (cmd + n)");
    }
}

fn drawGrid(file: File, position: imgui.ImVec2) void {
    var tilesWide = @divExact(file.width, file.tileWidth);
    var tilesTall = @divExact(file.height, file.tileHeight);

    var x: i32 = 0;
    while (x <= tilesWide) : (x += 1) {
        var top = position.add(.{ .x = @intToFloat(f32, x * file.tileWidth), .y = 0 });
        var bottom = position.add(.{ .x = @intToFloat(f32, x * file.tileWidth), .y = @intToFloat(f32, file.height) });

        top = camera.matrix().transformImVec2(top).add(screen_pos);
        bottom = camera.matrix().transformImVec2(bottom).add(screen_pos);

        imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), top, bottom, gridColor.value, 1);
    }

    var y: i32 = 0;
    while (y <= tilesTall) : (y += 1) {
        var left = position.add(.{ .x = 0, .y = @intToFloat(f32, y * file.tileHeight) });
        var right = position.add(.{ .x = @intToFloat(f32, file.width), .y = @intToFloat(f32, y * file.tileHeight) });

        left = camera.matrix().transformImVec2(left).add(screen_pos);
        right = camera.matrix().transformImVec2(right).add(screen_pos);

        imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), left, right, gridColor.value, 1);
    }
}

fn drawSelection() void {

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

fn getPixelCoords(texture: upaya.Texture, texture_position: imgui.ImVec2, position: imgui.ImVec2) ?imgui.ImVec2 {
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

fn getPixelIndexFromCoords(texture: upaya.Texture, coords: imgui.ImVec2) usize {
    return @floatToInt(usize, coords.x + coords.y * @intToFloat(f32, texture.width));
}

// helper for getting texture pixel index from screen position
fn getPixelIndex(texture: upaya.Texture, texture_position: imgui.ImVec2, position: imgui.ImVec2) ?usize {
    if (getPixelCoords(texture, texture_position, position)) |coords| {
        return getPixelIndexFromCoords(texture, coords);
    } else return null;
}

pub fn close() void {
    logo.?.deinit();
    for (files.items) |file, i| {
        files.items[i].deinit();
    }
}
