const std = @import("std");
const builtin = @import("builtin");
const upaya = @import("upaya");
const imgui = @import("imgui");

pub const Camera = @import("../utils/camera.zig").Camera;

const editor = @import("../editor.zig");
const input = editor.input;
const types = editor.types;
const history = editor.history;
const menubar = editor.menubar;
const toolbar = editor.toolbar;
const layers = editor.layers;
const sprites = editor.sprites;
const animations = editor.animations;

const algorithms = @import("../utils/algorithms.zig");

const File = types.File;
const Layer = types.Layer;
const Animation = types.Animation;

const SelectionMode = enum { rect, pixel };

var camera: Camera = .{ .zoom = 2 };
var screen_position: imgui.ImVec2 = undefined;
pub var texture_position: imgui.ImVec2 = undefined;
pub var background_opacity: f32 = 80; //default

var logo: ?upaya.Texture = null;

var active_file_index: usize = 0;
var files: std.ArrayList(File) = undefined;

var previous_mouse_position: imgui.ImVec2 = undefined;

pub var current_stroke_colors: std.ArrayList(u32) = undefined;
pub var current_stroke_indexes: std.ArrayList(usize) = undefined;

pub var clipboard_layer: ?Layer = null;
pub var clipboard_position: imgui.ImVec2 = .{};
pub var clipboard_size: imgui.ImVec2 = .{};

pub var current_selection_colors: std.ArrayList(u32) = undefined;
pub var current_selection_indexes: std.ArrayList(usize) = undefined;
pub var current_selection_mode: SelectionMode = .rect;
pub var current_selection_layer: ?Layer = null;
pub var current_selection_position: imgui.ImVec2 = .{};
pub var current_selection_size: imgui.ImVec2 = .{};

pub fn init() void {
    files = std.ArrayList(File).init(upaya.mem.allocator);

    current_stroke_colors = std.ArrayList(u32).init(upaya.mem.allocator);
    current_stroke_indexes = std.ArrayList(usize).init(upaya.mem.allocator);

    current_selection_colors = std.ArrayList(u32).init(upaya.mem.allocator);
    current_selection_indexes = std.ArrayList(usize).init(upaya.mem.allocator);

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

}

pub fn addFile(file: File) void {
    active_file_index = 0;
    files.insert(0, file) catch unreachable;
}

pub fn closeFile(index: usize) void {
    active_file_index = 0;
    sprites.setActiveSpriteIndex(0);
    _ = files.swapRemove(index);
    // TODO: clear memory??
}

pub fn getNumberOfFiles() usize {
    return files.items.len;
}

pub fn getActiveFileIndex() usize {
    return active_file_index;
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

pub fn setActiveFile(index: usize) void {
    if (index < files.items.len and active_file_index != index) {
        active_file_index = index;
    }
}

pub fn draw() void {
    if (!imgui.igBegin("Canvas", null, imgui.ImGuiWindowFlags_None)) return;
    defer imgui.igEnd();

    if (imgui.igBeginPopupContextItem("Canvas Settings", imgui.ImGuiMouseButton_Right)) {
        defer imgui.igEndPopup();

        imgui.igText("Canvas Settings");
        imgui.igSeparator();

        _ = imgui.igSliderFloat("Background Opacity", &background_opacity, 0, 100, "%.0f", 1);
    }

    const background_color = upaya.math.Color.fromRgba(1, 1, 1, background_opacity / 100);

    // setup screen position and size
    screen_position = imgui.ogGetCursorScreenPos();
    const window_size = imgui.ogGetContentRegionAvail();
    if (window_size.x == 0 or window_size.y == 0) return;

    if (getActiveFile()) |file| {
        texture_position = .{
            .x = -@intToFloat(f32, file.background.width) / 2,
            .y = -@intToFloat(f32, file.background.height) / 2,
        };

        // draw background texture
        drawTexture(file.background, texture_position, background_color.value);

        // draw layers (reverse order)
        var layer_index: usize = file.layers.items.len;
        while (layer_index > 0) {
            layer_index -= 1;

            if (file.layers.items[layer_index].hidden)
                continue;

            file.layers.items[layer_index].updateTexture();

            switch (toolbar.selected_mode) {
                .diffuse => drawTexture(file.layers.items[layer_index].texture, texture_position, 0xFFFFFFFF),
                .height => {
                    drawTexture(file.layers.items[layer_index].texture, texture_position, 0x55FFFFFF);
                    drawTexture(file.layers.items[layer_index].heightmap_texture, texture_position, 0xFFFFFFFF);
                },
            }

            // draw temporary texture over active layer
            if (layer_index == layers.getActiveIndex()) {
                file.temporary.updateTexture();

                switch (toolbar.selected_mode) {
                    .diffuse => drawTexture(file.temporary.texture, texture_position, 0xFFFFFFFF),
                    .height => drawTexture(file.temporary.heightmap_texture, texture_position, 0xFFFFFFFF),
                }
            }
        }

        // blank out images for next frame
        file.temporary.image.fillRect(.{
            .x = 0,
            .y = 0,
            .width = file.width,
            .height = file.height,
        }, upaya.math.Color.transparent);

        file.temporary.heightmap_image.fillRect(.{
            .x = 0,
            .y = 0,
            .width = file.width,
            .height = file.height,
        }, upaya.math.Color.transparent);
        file.temporary.dirty = true;

        // draw tile grid
        drawGrid(file, texture_position);

        // draw selection layer
        if (current_selection_layer) |*selection_layer| {
            selection_layer.updateTexture();

            switch (toolbar.selected_mode) {
                .diffuse => drawTexture(selection_layer.*.texture, current_selection_position, 0xFFFFFFFF),
                .height => drawTexture(selection_layer.*.heightmap_texture, current_selection_position, 0xFFFFFFFF),
            }

            const tl = camera.matrix().transformImVec2(current_selection_position).add(screen_position);
            var br = current_selection_position;
            br.x += @intToFloat(f32, selection_layer.texture.width);
            br.y += @intToFloat(f32, selection_layer.texture.height);
            br = camera.matrix().transformImVec2(br).add(screen_position);

            var size = br.subtract(tl);

            imgui.ogAddRect(imgui.igGetWindowDrawList(), tl, size, editor.selection_color.value, 2);
        }

        // draw current selection feedback
        if (current_selection_indexes.items.len > 1 and current_selection_colors.items.len == current_selection_indexes.items.len) {
            if (layers.getActiveLayer()) |layer| {
                switch (current_selection_mode) {
                    .rect => {
                        const start_index = current_selection_indexes.items[0];
                        const end_index = current_selection_indexes.items[current_selection_indexes.items.len - 1];

                        const start_position = getPixelCoordsFromIndex(layer.texture, start_index);
                        const end_position = getPixelCoordsFromIndex(layer.texture, end_index);

                        const size = end_position.subtract(start_position).add(.{ .x = 1, .y = 1 }).scale(camera.zoom);

                        const tl = camera.matrix().transformImVec2(start_position.add(texture_position)).add(screen_position);

                        imgui.ogAddRect(imgui.igGetWindowDrawList(), tl, size, editor.selection_color.value, 2);
                    },
                    .pixel => {
                        for (current_selection_indexes.items) |index| {
                            file.temporary.image.pixels[index] = editor.selection_color.value;
                        }
                    },
                }
            }
        }

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
                var dirty_flag = if (f.dirty) imgui.ImGuiTabItemFlags_UnsavedDocument else imgui.ImGuiTabItemFlags_None;
                if (imgui.igBeginTabItem(@ptrCast([*c]const u8, name_z), &open, dirty_flag)) {
                    defer imgui.igEndTabItem();

                    if (imgui.igBeginPopupContextItem("File Settings", imgui.ImGuiMouseButton_Right)) {
                        defer imgui.igEndPopup();

                        imgui.igText("File Settings");
                        imgui.igSeparator();

                    
                    }

                    setActiveFile(i);
                }
                imgui.igPopID();

                if (!open) {
                    if (f.dirty) {
                        menubar.close_file_popup = true;
                    } else {
                        closeFile(i);
                        // TODO: do i need to deinit all the layers and background?
                        // active_file_index = 0;
                        // sprites.setActiveSpriteIndex(0);
                        // _ = files.swapRemove(i);
                        //f.deinit(); this crashes
                    }
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

                // clear selection on escape
                if (imgui.igIsKeyPressed(upaya.sokol.SAPP_KEYCODE_ESCAPE, false)) {
                    if (current_selection_indexes.items.len > 0) {
                        current_selection_indexes.clearAndFree();
                    }
                    if (current_selection_colors.items.len > 0) {
                        current_selection_colors.clearAndFree();
                    }
                }

                // delete selection if present
                if (imgui.igIsKeyPressed(upaya.sokol.SAPP_KEYCODE_DELETE, false) or imgui.igIsKeyPressed(upaya.sokol.SAPP_KEYCODE_BACKSPACE, false)) {
                    if (current_selection_indexes.items.len > 0) {
                        for (current_selection_indexes.items) |index| {
                            const color = switch (toolbar.selected_mode) {
                                .diffuse => layer.image.pixels[index],
                                .height => layer.heightmap_image.pixels[index],
                            };
                            current_stroke_colors.append(color) catch unreachable;
                            current_stroke_indexes.append(index) catch unreachable;

                            switch (toolbar.selected_mode) {
                                .diffuse => layer.image.pixels[index] = 0x00000000,
                                .height => layer.heightmap_image.pixels[index] = 0x00000000,
                            }
                        }

                        file.history.push(.{
                            .tag = .stroke,
                            .pixel_colors = current_stroke_colors.toOwnedSlice(),
                            .pixel_indexes = current_stroke_indexes.toOwnedSlice(),
                            .layer_id = layer.id,
                            .layer_mode = toolbar.selected_mode,
                        });

                        current_selection_indexes.clearAndFree();
                        current_selection_colors.clearAndFree();
                    }
                    layer.dirty = true;
                }

                // move selection if present
                if (current_selection_layer) |_| {
                    if (imgui.igIsKeyPressed(upaya.sokol.SAPP_KEYCODE_DOWN, true))
                        current_selection_position.y += 1;
                    if (imgui.igIsKeyPressed(upaya.sokol.SAPP_KEYCODE_UP, true))
                        current_selection_position.y -= 1;
                    if (imgui.igIsKeyPressed(upaya.sokol.SAPP_KEYCODE_LEFT, true))
                        current_selection_position.x -= 1;
                    if (imgui.igIsKeyPressed(upaya.sokol.SAPP_KEYCODE_RIGHT, true))
                        current_selection_position.x += 1;
                }

                // move the selection if present with mouse
                if (imgui.igIsMouseDragging(imgui.ImGuiMouseButton_Left, 0) and isOverSelectionImage(io.MousePos)) {
                    current_selection_position = current_selection_position.add(io.MouseDelta.scale(1 / camera.zoom));
                    imgui.igResetMouseDragDelta(imgui.ImGuiMouseButton_Left);
                }

                // round the position of the selection image if done moving
                if (imgui.igIsMouseReleased(imgui.ImGuiMouseButton_Left) and current_selection_layer != null) {
                    current_selection_position.x = @round(current_selection_position.x);
                    current_selection_position.y = @round(current_selection_position.y);
                }

                // mouse is hovering over the artboard
                if (getPixelCoords(layer.texture, mouse_position)) |mouse_pixel_coords| {
                    var tiles_wide = @divExact(@intCast(usize, file.width), @intCast(usize, file.tileWidth));

                    var tile_column = @divTrunc(@floatToInt(usize, mouse_pixel_coords.x), @intCast(usize, file.tileWidth));
                    var tile_row = @divTrunc(@floatToInt(usize, mouse_pixel_coords.y), @intCast(usize, file.tileHeight));

                    var tile_index = tile_column + tile_row * tiles_wide;
                    var pixel_index = getPixelIndexFromCoords(layer.texture, mouse_pixel_coords);

                    // set active sprite window
                    if (io.MouseDown[0] and toolbar.selected_tool != .hand and toolbar.selected_tool != .selection and toolbar.selected_tool != .wand and animations.animation_state != .play) {
                        sprites.setActiveSpriteIndex(tile_index);

                        if (toolbar.selected_tool == .arrow) {
                            imgui.igBeginTooltip();
                            var index_text = std.fmt.allocPrintZ(upaya.mem.allocator, "Index: {d}", .{tile_index}) catch unreachable;
                            defer upaya.mem.allocator.free(index_text);
                            imgui.igText(@ptrCast([*c]const u8, index_text));
                            imgui.igEndTooltip();
                        }
                    }

                    // color dropper input
                    if (io.MouseDown[1] or (io.MouseDown[0] and toolbar.selected_tool == .dropper)) {
                        imgui.igBeginTooltip();
                        var coord_text = std.fmt.allocPrintZ(upaya.mem.allocator, "{s} {d},{d}", .{ imgui.icons.eye_dropper, mouse_pixel_coords.x + 1, mouse_pixel_coords.y + 1 }) catch unreachable;
                        var color = switch(toolbar.selected_mode) {
                            .diffuse => upaya.math.Color{ .value = layer.image.pixels[pixel_index]},
                            .height => upaya.math.Color{ .value = layer.heightmap_image.pixels[pixel_index]},
                        };
                        var color_text = std.fmt.allocPrintZ(upaya.mem.allocator, "R: {d}, G: {d}, B: {d}, A: {d}", .{color.r_val(), color.g_val(), color.b_val(), color.a_val()}) catch unreachable;
                        imgui.igText(@ptrCast([*c]const u8, coord_text));
                        imgui.igText(@ptrCast([*c]const u8, color_text));
                        upaya.mem.allocator.free(coord_text);
                        upaya.mem.allocator.free(color_text);
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

                            toolbar.foreground_color = switch (toolbar.selected_mode) {
                                .diffuse => upaya.math.Color{ .value = layer.image.pixels[pixel_index] },
                                .height => upaya.math.Color{ .value = layer.heightmap_image.pixels[pixel_index] },
                            };

                            imgui.igBeginTooltip();
                            _ = imgui.ogColoredButtonEx(toolbar.foreground_color.value, "###1", .{ .x = 100, .y = 100 });
                            imgui.igEndTooltip();
                        }
                    }

                    // drawing input
                    if (toolbar.selected_tool == .pencil or toolbar.selected_tool == .eraser) {
                        if (toolbar.selected_tool == .pencil) {
                            switch (toolbar.selected_mode) {
                                .diffuse => file.temporary.image.pixels[pixel_index] = toolbar.foreground_color.value,
                                .height => file.temporary.heightmap_image.pixels[pixel_index] = toolbar.foreground_color.value,
                            }
                        } else {
                            switch (toolbar.selected_mode) {
                                .diffuse => file.temporary.image.pixels[pixel_index] = 0xFFFFFFFF,
                                .height => file.temporary.heightmap_image.pixels[pixel_index] = 0xFFFFFFFF,
                            }
                        }

                        file.temporary.dirty = true;

                        if (imgui.igIsMouseDragging(imgui.ImGuiMouseButton_Left, 0) and !io.KeyShift) {
                            if (getPixelCoords(layer.texture, previous_mouse_position)) |prev_mouse_pixel_coords| {
                                var output = algorithms.brezenham(prev_mouse_pixel_coords, mouse_pixel_coords);

                                for (output) |coords| {
                                    const index = getPixelIndexFromCoords(layer.texture, coords);
                                    const color = switch (toolbar.selected_mode) {
                                        .diffuse => layer.image.pixels[index],
                                        .height => layer.heightmap_image.pixels[index],
                                    };

                                    if (toolbar.selected_tool == .pencil and color != toolbar.foreground_color.value or toolbar.selected_tool == .eraser and color != 0x00000000) {
                                        current_stroke_colors.append(color) catch unreachable;
                                        current_stroke_indexes.append(index) catch unreachable;

                                        switch (toolbar.selected_mode) {
                                            .diffuse => layer.image.pixels[index] = if (toolbar.selected_tool == .pencil) toolbar.foreground_color.value else 0x00000000,
                                            .height => layer.heightmap_image.pixels[index] = if (toolbar.selected_tool == .pencil) toolbar.foreground_color.value else 0x00000000,
                                        }
                                    }
                                }
                                upaya.mem.allocator.free(output);
                                layer.dirty = true;
                            }
                        }

                        if (imgui.igIsMouseDragging(imgui.ImGuiMouseButton_Left, 0) and io.KeyShift) {
                            if (getPixelCoords(layer.texture, io.MouseClickedPos[0])) |prev_mouse_pixel_coords| {
                                var output = algorithms.brezenham(prev_mouse_pixel_coords, mouse_pixel_coords);

                                for (output) |coords| {
                                    var index = getPixelIndexFromCoords(layer.texture, coords);

                                    switch (toolbar.selected_mode) {
                                        .diffuse => file.temporary.image.pixels[index] = if (toolbar.selected_tool == .pencil) toolbar.foreground_color.value else 0xFFFFFFFF,
                                        .height => file.temporary.heightmap_image.pixels[index] = if (toolbar.selected_tool == .pencil) toolbar.foreground_color.value else 0xFFFFFFFF,
                                    }
                                }
                                upaya.mem.allocator.free(output);
                                file.temporary.dirty = true;
                            }
                        }

                        if (imgui.igIsMouseReleased(imgui.ImGuiMouseButton_Left) and io.KeyShift) {
                            if (getPixelCoords(layer.texture, io.MouseClickedPos[0])) |prev_mouse_pixel_coords| {
                                var output = algorithms.brezenham(prev_mouse_pixel_coords, mouse_pixel_coords);

                                for (output) |coords| {
                                    var index = getPixelIndexFromCoords(layer.texture, coords);
                                    current_stroke_indexes.append(index) catch unreachable;
                                    current_stroke_colors.append(layer.image.pixels[index]) catch unreachable;
                                    switch (toolbar.selected_mode) {
                                        .diffuse => layer.image.pixels[index] = if (toolbar.selected_tool == .pencil) toolbar.foreground_color.value else 0xFFFFFFFF,
                                        .height => layer.heightmap_image.pixels[index] = if (toolbar.selected_tool == .pencil) toolbar.foreground_color.value else 0xFFFFFFFF,
                                    }
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
                                .layer_mode = toolbar.selected_mode,
                            });
                        }
                    }

                    //fill
                    if (toolbar.selected_tool == .bucket) {
                        if (imgui.igIsMouseClicked(imgui.ImGuiMouseButton_Left, false)) {
                            var output = algorithms.floodfill(mouse_pixel_coords, layer.image, toolbar.contiguous_fill);

                            for (output) |index| {
                                const color = switch (toolbar.selected_mode) {
                                    .diffuse => layer.image.pixels[index],
                                    .height => layer.heightmap_image.pixels[index],
                                };
                                if (color != toolbar.foreground_color.value) {
                                    current_stroke_indexes.append(index) catch unreachable;
                                    current_stroke_colors.append(color) catch unreachable;

                                    switch (toolbar.selected_mode) {
                                        .diffuse => layer.image.pixels[index] = toolbar.foreground_color.value,
                                        .height => layer.heightmap_image.pixels[index] = toolbar.foreground_color.value,
                                    }
                                }
                            }
                            layer.dirty = true;

                            file.history.push(.{
                                .tag = .stroke,
                                .pixel_colors = current_stroke_colors.toOwnedSlice(),
                                .pixel_indexes = current_stroke_indexes.toOwnedSlice(),
                                .layer_id = layer.id,
                                .layer_mode = toolbar.selected_mode,
                            });
                        }
                    }

                    //selections
                    if (toolbar.selected_tool == .selection) {
                        // feedback
                        if (imgui.igIsMouseDragging(imgui.ImGuiMouseButton_Left, 0) and !editor.isModKeyDown() and current_selection_layer == null) {
                            if (getPixelCoords(layer.texture, io.MouseClickedPos[0])) |mouse_clicked_position| {
                                if (getPixelCoords(layer.texture, io.MousePos)) |mouse_current_position| {
                                    var tl = texture_position.add(mouse_clicked_position);
                                    tl = camera.matrix().transformImVec2(tl).add(screen_position);
                                    const size = mouse_current_position.subtract(mouse_clicked_position).scale(camera.zoom);

                                    imgui.ogAddRect(imgui.igGetWindowDrawList(), tl, size, editor.selection_feedback_color.value, 1);
                                }
                            }
                        }

                        // shortcut for selecting an entire tile
                        if (imgui.igIsMouseDoubleClicked(imgui.ImGuiMouseButton_Left) and current_selection_layer == null) {
                            if (getPixelCoords(layer.texture, io.MousePos)) |_| {
                                const tl_x = tile_column * @intCast(usize, file.tileWidth);
                                const tl_y = tile_row * @intCast(usize, file.tileHeight);
                                const start_index = tl_x + tl_y * @intCast(usize, file.width);

                                const size: imgui.ImVec2 = .{ .x = @intToFloat(f32, file.tileWidth), .y = @intToFloat(f32, file.tileHeight) };

                                if (current_selection_indexes.items.len > 0) {
                                    current_selection_indexes.clearAndFree();
                                    current_selection_colors.clearAndFree();
                                }

                                const selection_width = @floatToInt(usize, size.x);
                                const selection_height = @floatToInt(usize, size.y);

                                var y: usize = 0;
                                while (y < selection_height) : (y += 1) {
                                    const color_slice = switch (toolbar.selected_mode) {
                                        .diffuse => layer.image.pixels[start_index + (y * layer.image.w) .. start_index + (y * layer.image.w) + selection_width],
                                        .height => layer.heightmap_image.pixels[start_index + (y * layer.heightmap_image.w) .. start_index + (y * layer.heightmap_image.w) + selection_width],
                                    };
                                    current_selection_colors.appendSlice(color_slice) catch unreachable;

                                    var x: usize = start_index + (y * layer.image.w);
                                    while (x < start_index + (y * layer.image.w) + selection_width) : (x += 1) {
                                        current_selection_indexes.append(x) catch unreachable;
                                    }
                                }
                            }
                        }

                        // actual selection storing
                        if (imgui.igIsMouseReleased(imgui.ImGuiMouseButton_Left) and !editor.isMouseDoubleClickReleased() and current_selection_layer == null) {
                            if (getPixelCoords(layer.texture, io.MouseClickedPos[0])) |mouse_clicked_position| {
                                if (getPixelCoords(layer.texture, io.MousePos)) |mouse_current_position| {
                                    var start_index: usize = 0;
                                    var selection_size: imgui.ImVec2 = .{};

                                    // allow dragging in any direction
                                    if (mouse_current_position.x < mouse_clicked_position.x and mouse_current_position.y < mouse_clicked_position.y) {
                                        start_index = getPixelIndexFromCoords(layer.texture, mouse_current_position);
                                        selection_size = mouse_clicked_position.subtract(mouse_current_position);
                                    } else if (mouse_current_position.x < mouse_clicked_position.x and mouse_current_position.y > mouse_clicked_position.y) {
                                        const tl = .{ .x = mouse_current_position.x, .y = mouse_clicked_position.y };
                                        const br = .{ .x = mouse_clicked_position.x, .y = mouse_current_position.y };
                                        start_index = getPixelIndexFromCoords(layer.texture, tl);
                                        selection_size = imgui.ImVec2.subtract(br, tl);
                                    } else if (mouse_current_position.x > mouse_clicked_position.x and mouse_current_position.y > mouse_clicked_position.y) {
                                        start_index = getPixelIndexFromCoords(layer.texture, mouse_clicked_position);
                                        selection_size = mouse_current_position.subtract(mouse_clicked_position);
                                    } else if (mouse_current_position.x > mouse_clicked_position.x and mouse_current_position.y < mouse_clicked_position.y) {
                                        const tl = .{ .x = mouse_clicked_position.x, .y = mouse_current_position.y };
                                        const br = .{ .x = mouse_current_position.x, .y = mouse_clicked_position.y };
                                        start_index = getPixelIndexFromCoords(layer.texture, tl);
                                        selection_size = imgui.ImVec2.subtract(br, tl);
                                    }

                                    const selection_width = @floatToInt(usize, selection_size.x);
                                    const selection_height = @floatToInt(usize, selection_size.y);

                                    if (current_selection_colors.items.len > 0)
                                        current_selection_colors.clearAndFree();

                                    if (current_selection_indexes.items.len > 0)
                                        current_selection_indexes.clearAndFree();

                                    var y: usize = 0;
                                    while (y < selection_height) : (y += 1) {
                                        const color_slice = switch (toolbar.selected_mode) {
                                            .diffuse => layer.image.pixels[start_index + (y * layer.image.w) .. start_index + (y * layer.image.w) + selection_width],
                                            .height => layer.heightmap_image.pixels[start_index + (y * layer.heightmap_image.w) .. start_index + (y * layer.heightmap_image.w) + selection_width],
                                        };
                                        current_selection_colors.appendSlice(color_slice) catch unreachable;

                                        var x: usize = start_index + (y * layer.image.w);
                                        while (x < start_index + (y * layer.image.w) + selection_width) : (x += 1) {
                                            current_selection_indexes.append(x) catch unreachable;
                                        }
                                    }

                                    current_selection_mode = .rect;
                                }
                            }
                        }

                        // turn selection into a temporary layer and clear the pixels in the current layer image
                        if (imgui.igIsMouseClicked(imgui.ImGuiMouseButton_Left, false) and editor.isModKeyDown() and current_selection_indexes.items.len > 0 and isOverSelection(mouse_position)) {
                            var tl = getPixelCoordsFromIndex(layer.texture, current_selection_indexes.items[0]);
                            var br = getPixelCoordsFromIndex(layer.texture, current_selection_indexes.items[current_selection_indexes.items.len - 1]).add(.{ .x = 1, .y = 1 });
                            var size = br.subtract(tl);

                            current_selection_position = texture_position.add(tl);
                            current_selection_size = size;

                            var image = upaya.Image.init(@floatToInt(usize, size.x), @floatToInt(usize, size.y));
                            std.mem.copy(u32, image.pixels, current_selection_colors.items);

                            var heightmap_image = upaya.Image.init(@floatToInt(usize, size.x), @floatToInt(usize, size.y));
                            std.mem.copy(u32, heightmap_image.pixels, current_selection_colors.items);

                            current_selection_layer = .{
                                .name = "Selection",
                                .texture = image.asTexture(.nearest),
                                .image = image,
                                .heightmap_image = heightmap_image,
                                .heightmap_texture = heightmap_image.asTexture(.nearest),
                                .id = layers.getNewID(),
                            };

                            if (!io.KeyShift) {
                                for (current_selection_indexes.items) |index| {
                                    const color = switch (toolbar.selected_mode) {
                                        .diffuse => layer.image.pixels[index],
                                        .height => layer.heightmap_image.pixels[index],
                                    };
                                    //store for history state
                                    current_stroke_indexes.append(index) catch unreachable;
                                    current_stroke_colors.append(color) catch unreachable;

                                    switch (toolbar.selected_mode) {
                                        .diffuse => layer.image.pixels[index] = 0x00000000,
                                        .height => layer.heightmap_image.pixels[index] = 0x00000000,
                                    }

                                    layer.dirty = true;
                                }
                                file.history.push(.{
                                    .tag = .stroke,
                                    .pixel_colors = current_stroke_colors.toOwnedSlice(),
                                    .pixel_indexes = current_stroke_indexes.toOwnedSlice(),
                                    .layer_id = layer.id,
                                    .layer_mode = toolbar.selected_mode,
                                });
                            }

                            // clear selection
                            current_selection_indexes.clearAndFree();
                            current_selection_colors.clearAndFree();
                        }
                    }

                    // blit the selection image
                    if (imgui.igIsMouseClicked(imgui.ImGuiMouseButton_Left, false) and !isOverSelectionImage(mouse_position)) {
                        if (current_selection_layer) |selection_layer| {
                            const selection_position = current_selection_position.subtract(texture_position);
                            const x = @floatToInt(i32, selection_position.x);
                            const y = @floatToInt(i32, selection_position.y);

                            //TODO: crop the layer.image if its not within the artboard bounds
                            // or completely remove if it doesnt overlap

                            for (selection_layer.image.pixels) |_, i| {
                                var pix_coord_x = @intToFloat(f32, x + @mod(@intCast(i32, i), selection_layer.texture.width));
                                var pix_coord_y = @intToFloat(f32, y + @divTrunc(@intCast(i32, i), selection_layer.texture.width));
                                var test_index = getPixelIndexFromCoordsUnsafe(layer.texture, .{ .x = pix_coord_x, .y = pix_coord_y });

                                if (test_index) |index| {
                                    const color = switch (toolbar.selected_mode) {
                                        .diffuse => layer.image.pixels[index],
                                        .height => layer.heightmap_image.pixels[index],
                                    };
                                    // store current colors for history state
                                    if (index < layer.image.pixels.len) {
                                        current_stroke_indexes.append(index) catch unreachable;
                                        current_stroke_colors.append(color) catch unreachable;
                                    }
                                }
                            }

                            file.history.push(.{
                                .tag = .stroke,
                                .pixel_colors = current_stroke_colors.toOwnedSlice(),
                                .pixel_indexes = current_stroke_indexes.toOwnedSlice(),
                                .layer_id = layer.id,
                                .layer_mode = toolbar.selected_mode,
                            });

                            switch (toolbar.selected_mode) {
                                .diffuse => layer.image.blitWithoutTransparent(selection_layer.image, x, y),
                                .height => layer.heightmap_image.blitWithoutTransparent(selection_layer.heightmap_image, x, y),
                            }
                            layer.dirty = true;

                            //TODO: this breaks pasting, crashes on second paste
                            //selection_layer.image.deinit();
                            //selection_layer.heightmap_image.deinit();
                            current_selection_layer = null;
                        }
                    }

                    if (toolbar.selected_tool == .wand) {
                        if (imgui.igIsMouseClicked(imgui.ImGuiMouseButton_Left, false) and !editor.isModKeyDown()) {
                            current_selection_indexes.clearAndFree();
                            current_selection_colors.clearAndFree();

                            var selection = algorithms.floodfill(
                                mouse_pixel_coords,
                                switch (toolbar.selected_mode) {
                                    .diffuse => layer.image,
                                    .height => layer.heightmap_image,
                                },
                                false,
                            );
                            current_selection_indexes.appendSlice(selection) catch unreachable;

                            for (current_selection_indexes.items) |index| {
                                current_selection_colors.append(layer.image.pixels[index]) catch unreachable;
                            }
                            current_selection_mode = .pixel;
                        }
                    }

                    // set animation
                    if (toolbar.selected_tool == .animation) {
                        if (io.MouseClicked[0] and !imgui.ogKeyDown(upaya.sokol.SAPP_KEYCODE_SPACE)) {
                            if (animations.getActiveAnimation()) |animation| {
                                animation.length = 1;
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
                } else { //mouse is not over the art board


                    // TODO: This is duplicated code from above, lets try to make this a function and reuse?

                    if (imgui.igIsMouseClicked(imgui.ImGuiMouseButton_Left, false) and current_selection_layer != null) {

                        if (current_selection_layer) |selection_layer| {
                            const selection_position = current_selection_position.subtract(texture_position);
                            const x = @floatToInt(i32, selection_position.x);
                            const y = @floatToInt(i32, selection_position.y);

                            //TODO: crop the layer.image if its not within the artboard bounds
                            // or completely remove if it doesnt overlap

                            for (selection_layer.image.pixels) |_, i| {
                                var pix_coord_x = @intToFloat(f32, x + @mod(@intCast(i32, i), selection_layer.texture.width));
                                var pix_coord_y = @intToFloat(f32, y + @divTrunc(@intCast(i32, i), selection_layer.texture.width));
                                var test_index = getPixelIndexFromCoordsUnsafe(layer.texture, .{ .x = pix_coord_x, .y = pix_coord_y });

                                if (test_index) |index| {
                                    const color = switch (toolbar.selected_mode) {
                                        .diffuse => layer.image.pixels[index],
                                        .height => layer.heightmap_image.pixels[index],
                                    };
                                    // store current colors for history state
                                    if (index < layer.image.pixels.len) {
                                        current_stroke_indexes.append(index) catch unreachable;
                                        current_stroke_colors.append(color) catch unreachable;
                                    }
                                }
                            }

                            file.history.push(.{
                                .tag = .stroke,
                                .pixel_colors = current_stroke_colors.toOwnedSlice(),
                                .pixel_indexes = current_stroke_indexes.toOwnedSlice(),
                                .layer_id = layer.id,
                                .layer_mode = toolbar.selected_mode,
                            });

                            switch (toolbar.selected_mode) {
                                .diffuse => layer.image.blitWithoutTransparent(selection_layer.image, x, y),
                                .height => layer.heightmap_image.blitWithoutTransparent(selection_layer.heightmap_image, x, y),
                            }
                            layer.dirty = true;

                            //TODO: this breaks pasting, crashes on second paste
                            //selection_layer.image.deinit();
                            //selection_layer.heightmap_image.deinit();
                            current_selection_layer = null;
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
        const mod_name = if (builtin.os.tag == .windows) "ctrl" else if (builtin.os.tag == .linux) "super" else "cmd";
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

        top = camera.matrix().transformImVec2(top).add(screen_position);
        bottom = camera.matrix().transformImVec2(bottom).add(screen_position);

        imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), top, bottom, editor.grid_color.value, 1);
    }

    var y: i32 = 0;
    while (y <= tilesTall) : (y += 1) {
        var left = position.add(.{ .x = 0, .y = @intToFloat(f32, y * file.tileHeight) });
        var right = position.add(.{ .x = @intToFloat(f32, file.width), .y = @intToFloat(f32, y * file.tileHeight) });

        left = camera.matrix().transformImVec2(left).add(screen_position);
        right = camera.matrix().transformImVec2(right).add(screen_position);

        imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), left, right, editor.grid_color.value, 1);
    }

    if (sprites.getActiveSprite()) |sprite| {
        var column = @mod(@intCast(i32, sprite.index), tilesWide);
        var row = @divTrunc(@intCast(i32, sprite.index), tilesWide);

        var tl: imgui.ImVec2 = position.add(.{ .x = @intToFloat(f32, column * file.tileWidth), .y = @intToFloat(f32, row * file.tileHeight) });
        tl = camera.matrix().transformImVec2(tl).add(screen_position);
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
        start_tl = camera.matrix().transformImVec2(start_tl).add(screen_position);
        start_bl = camera.matrix().transformImVec2(start_bl).add(screen_position);

        start_tm = camera.matrix().transformImVec2(start_tm).add(screen_position);
        start_bm = camera.matrix().transformImVec2(start_bm).add(screen_position);
        imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), start_tl, start_bl, 0xFFFFAA00, 2);
        imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), start_tl, start_tm, 0xFFFFAA00, 2);
        imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), start_bl, start_bm, 0xFFFFAA00, 2);

        const end_column = @mod(@intCast(i32, animation.start + animation.length - 1), tilesWide);
        const end_row = @divTrunc(@intCast(i32, animation.start + animation.length - 1), tilesWide);

        var end_tr: imgui.ImVec2 = position.add(.{ .x = @intToFloat(f32, end_column * file.tileWidth + file.tileWidth), .y = @intToFloat(f32, end_row * file.tileHeight) });
        var end_br: imgui.ImVec2 = end_tr.add(.{ .x = 0, .y = @intToFloat(f32, file.tileHeight) });
        var end_tm: imgui.ImVec2 = end_tr.subtract(.{ .x = @intToFloat(f32, @divTrunc(file.tileWidth, 2)) });
        var end_bm: imgui.ImVec2 = end_br.subtract(.{ .x = @intToFloat(f32, @divTrunc(file.tileWidth, 2)) });
        end_tr = camera.matrix().transformImVec2(end_tr).add(screen_position);
        end_br = camera.matrix().transformImVec2(end_br).add(screen_position);

        end_tm = camera.matrix().transformImVec2(end_tm).add(screen_position);
        end_bm = camera.matrix().transformImVec2(end_bm).add(screen_position);
        imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), end_tr, end_br, 0xFFAA00FF, 2);
        imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), end_tr, end_tm, 0xFFAA00FF, 2);
        imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), end_br, end_bm, 0xFFAA00FF, 2);
    }
}

fn drawTexture(texture: upaya.Texture, position: imgui.ImVec2, color: u32) void {
    const tl = camera.matrix().transformImVec2(position).add(screen_position);
    var br = position;
    br.x += @intToFloat(f32, texture.width);
    br.y += @intToFloat(f32, texture.height);
    br = camera.matrix().transformImVec2(br).add(screen_position);

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
    var tl = camera.matrix().transformImVec2(texture_position).add(screen_position);
    var br: imgui.ImVec2 = texture_position;
    br.x += @intToFloat(f32, texture.width);
    br.y += @intToFloat(f32, texture.height);
    br = camera.matrix().transformImVec2(br).add(screen_position);

    if (position.x > tl.x and position.x < br.x and position.y < br.y and position.y > tl.y) {
        var pixel_pos: imgui.ImVec2 = .{};

        pixel_pos.x = @divTrunc(position.x - tl.x, camera.zoom);
        pixel_pos.y = @divTrunc(position.y - tl.y, camera.zoom);

        return pixel_pos;
    } else return null;
}

pub fn isOverSelectionImage(position: imgui.ImVec2) bool {
    if (current_selection_layer) |_| {
        const tl = camera.matrix().transformImVec2(current_selection_position).add(screen_position);
        const br = camera.matrix().transformImVec2(current_selection_position.add(current_selection_size)).add(screen_position);

        if (position.x > tl.x and position.x < br.x and position.y < br.y and position.y > tl.y) {
            return true;
        }
    }
    return false;
}

pub fn isOverSelection(position: imgui.ImVec2) bool {
    switch (current_selection_mode) {
        .rect => {
            if (layers.getActiveLayer()) |layer| {
                if (getPixelCoords(layer.texture, position)) |coords| {
                    const index = getPixelIndexFromCoords(layer.texture, coords);

                    for (current_selection_indexes.items) |i| {
                        if (i == index)
                            return true;
                    }
                }
            }
        },
        .pixel => {
            //TODO: handle wand selections here, find bounding pixels and check as rect
            // or during selection, fill with transparent pixels between?
        },
    }

    return false;
}

pub fn getPixelIndexFromCoords(texture: upaya.Texture, coords: imgui.ImVec2) usize {
    return @floatToInt(usize, coords.x + coords.y * @intToFloat(f32, texture.width));
}

pub fn getPixelIndexFromCoordsUnsafe(texture: upaya.Texture, coords: imgui.ImVec2) ?usize {
    if (coords.x < 0 or coords.x > @intToFloat(f32, texture.width) or coords.y < 0 or coords.y > @intToFloat(f32, texture.height))
        return null;
    return @floatToInt(usize, coords.x + coords.y * @intToFloat(f32, texture.width));
}

pub fn getPixelCoordsFromIndex(texture: upaya.Texture, index: usize) imgui.ImVec2 {
    const x = @intToFloat(f32, @mod(@intCast(i32, index), texture.width));
    const y = @intToFloat(f32, @divTrunc(@intCast(i32, index), texture.width));

    return .{ .x = x, .y = y };
}

pub fn copy() void {
    if (getActiveFile()) |_| {
        if (layers.getActiveLayer()) |layer| {
            if (current_selection_indexes.items.len > 0) {
                var tl = getPixelCoordsFromIndex(layer.texture, current_selection_indexes.items[0]);
                var br = getPixelCoordsFromIndex(layer.texture, current_selection_indexes.items[current_selection_indexes.items.len - 1]).add(.{ .x = 1, .y = 1 });
                var size = br.subtract(tl);

                clipboard_position = texture_position.add(tl);
                clipboard_size = size;

                var image = upaya.Image.init(@floatToInt(usize, size.x), @floatToInt(usize, size.y));
                std.mem.copy(u32, image.pixels, current_selection_colors.items);

                var heightmap_image = upaya.Image.init(@floatToInt(usize, size.x), @floatToInt(usize, size.y));
                std.mem.copy(u32, heightmap_image.pixels, current_selection_colors.items);

                clipboard_layer = .{
                    .name = "Clipboard",
                    .texture = image.asTexture(.nearest),
                    .image = image,
                    .heightmap_image = heightmap_image,
                    .heightmap_texture = heightmap_image.asTexture(.nearest),
                    .id = layers.getNewID(),
                };
            }
        }
    }
}

pub fn cut() void {
    if (getActiveFile()) |file| {
        if (layers.getActiveLayer()) |layer| {
            var tl = getPixelCoordsFromIndex(layer.texture, current_selection_indexes.items[0]);
            var br = getPixelCoordsFromIndex(layer.texture, current_selection_indexes.items[current_selection_indexes.items.len - 1]).add(.{ .x = 1, .y = 1 });
            var size = br.subtract(tl);

            clipboard_position = texture_position.add(tl);
            clipboard_size = size;

            var image = upaya.Image.init(@floatToInt(usize, size.x), @floatToInt(usize, size.y));
            std.mem.copy(u32, image.pixels, current_selection_colors.items);

            var heightmap_image = upaya.Image.init(@floatToInt(usize, size.x), @floatToInt(usize, size.y));
            std.mem.copy(u32, heightmap_image.pixels, current_selection_colors.items);

            clipboard_layer = .{
                .name = "Clipboard",
                .texture = image.asTexture(.nearest),
                .image = image,
                .heightmap_image = heightmap_image,
                .heightmap_texture = heightmap_image.asTexture(.nearest),
                .id = layers.getNewID(),
            };

            for (current_selection_indexes.items) |index| {
                var color = layer.image.pixels[index];
                current_stroke_indexes.append(index) catch unreachable;
                current_stroke_colors.append(color) catch unreachable;
                layer.image.pixels[index] = 0x00000000;
            }

            layer.dirty = true;

            file.history.push(.{
                .tag = .stroke,
                .pixel_colors = current_stroke_colors.toOwnedSlice(),
                .pixel_indexes = current_stroke_indexes.toOwnedSlice(),
                .layer_id = layer.id,
                .layer_mode = toolbar.selected_mode,
            });
        }
    }
}

pub fn paste() void {
    if (getActiveFile()) |_| {
        if (clipboard_layer) |clipboard| {
            current_selection_position = clipboard_position;
            current_selection_size = clipboard_size;
            current_selection_layer = .{
                .name = "Selection",
                .texture = clipboard.texture,
                .image = clipboard.image,
                .heightmap_image = clipboard.heightmap_image,
                .heightmap_texture = clipboard.heightmap_texture,
                .id = layers.getNewID(),
            };
        }
    }
}

pub fn close() void {
    logo.?.deinit();
    for (files.items) |_, i| {
        files.items[i].deinit();
    }
}
