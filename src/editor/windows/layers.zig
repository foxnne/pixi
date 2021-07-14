const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

const types = @import("../types/types.zig");
const editor = @import("../editor.zig");
const canvas = editor.canvas;
const history = editor.history;

const Layer = types.Layer;

var layer_name_buffer: [128]u8 = [_]u8{0} ** 128;

var current_id: usize = 0;
var active_layer_index: usize = 0;

pub fn getActiveLayer() ?*Layer {
    if (canvas.getActiveFile()) |file| {
        return &file.layers.items[active_layer_index];
    } else return null;
}

pub fn getActiveIndex() usize {
    return active_layer_index;
}

pub fn getLayer(id: usize) ?*Layer {
    if (canvas.getActiveFile()) |file| {
        for (file.layers.items) |layer, i| {
            if (layer.id == id)
                return &file.layers.items[i];
        }
    }
    return null;
}

//find a better way to get a unique id per layer?
pub fn getNewID() usize {
    var id = current_id;
    current_id += 1;

    if (canvas.getActiveFile()) |file| {
        for (file.layers.items) |layer| {
            if (layer.id == id)
                current_id += 1;
        }
    }
    return id;
}

pub fn draw() void {
    if (imgui.igBegin("Layers", 0, imgui.ImGuiWindowFlags_NoResize)) {
        defer imgui.igEnd();

        if (canvas.getActiveFile()) |file| {

            // create
            if (imgui.ogColoredButton(0x00000000, imgui.icons.plus_circle)) {
                var image = upaya.Image.init(@intCast(usize, file.width), @intCast(usize, file.height));
                image.fillRect(.{ .x = 0, .y = 0, .width = file.width, .height = file.height }, upaya.math.Color.transparent);

                var name = std.fmt.allocPrint(upaya.mem.allocator, "Layer {d}", .{file.layers.items.len}) catch unreachable;
                defer upaya.mem.allocator.free(name);

                var new_layer: Layer = .{
                    .name = upaya.mem.allocator.dupe(u8, name) catch unreachable,
                    .id = getNewID(),
                    .image = image,
                    .texture = image.asTexture(.nearest),
                };

                file.layers.insert(0, new_layer) catch unreachable;
                active_layer_index = 0;

                file.history.push(.{
                    .tag = .new_layer,
                    .layer_id = new_layer.id,
                });
            }
            imgui.igSameLine(0, 5);
            // delete
            if (imgui.ogColoredButton(0x00000000, imgui.icons.minus_circle)) {
                if (file.layers.items.len > 1) {
                    var old_index = active_layer_index;
                    active_layer_index = 0;
                    var layer = file.layers.orderedRemove(old_index);
                    file.history.push(.{
                        .tag = .delete_layer,
                        .layer_id = layer.id,
                        .layer_state = layer,
                    });
                }
            }

            imgui.igSameLine(0, 5);
            //merge down
            if (imgui.ogColoredButton(0x00000000, imgui.icons.download)) {}

            imgui.igSameLine(0, 5);
            //merge up
            if (imgui.ogColoredButton(0x00000000, imgui.icons.upload)) {}

            imgui.igSeparator();

            for (file.layers.items) |layer, i| {
                imgui.igPushIDInt(@intCast(i32, layer.id));
                imgui.igBeginGroup();

                var eye = if (!layer.hidden) imgui.icons.eye else imgui.icons.eye_slash;
                if (imgui.ogColoredButton(0x00000000, eye)) {
                    file.layers.items[i].hidden = !layer.hidden;
                }

                imgui.igSameLine(0, 5);

                var layer_name_z = upaya.mem.allocator.dupeZ(u8, layer.name) catch unreachable;
                defer upaya.mem.allocator.free(layer_name_z);
                if (imgui.ogSelectableBool(@ptrCast([*c]const u8, layer_name_z), i == active_layer_index, imgui.ImGuiSelectableFlags_DrawHoveredWhenHeld, .{}))
                    active_layer_index = i;

                imgui.igEndGroup();

                if (imgui.igBeginPopupContextItem("Layer Settings", imgui.ImGuiMouseButton_Right)) {
                    defer imgui.igEndPopup();

                    imgui.igText("Layer Settings");
                    imgui.igSeparator();

                    for (layer_name_buffer) |_, j|
                        layer_name_buffer[j] = if (j < layer.name.len) layer.name[j] else 0;

                    if (imgui.ogInputTextEnter("Name", &layer_name_buffer, layer_name_buffer.len)) {
                        var end = std.mem.indexOf(u8, layer_name_buffer[0..], "\u{0}");

                        if (end) |e| {
                            if (!std.mem.eql(u8, file.layers.items[i].name, layer_name_buffer[0..e]) and !std.mem.eql(u8, layer_name_buffer[0..e], "")) {
                                file.history.push(.{
                                    .tag = .rename_layer,
                                    .layer_name = upaya.mem.allocator.dupe(u8, file.layers.items[i].name) catch unreachable,
                                    .layer_id = file.layers.items[i].id,
                                });

                                file.layers.items[i].name = upaya.mem.allocator.dupe(u8, layer_name_buffer[0..e]) catch unreachable;
                            }
                        }
                    }
                }

                imgui.igPopID();

                if (imgui.igIsItemActive() and !imgui.igIsItemHovered(imgui.ImGuiHoveredFlags_RectOnly)) {
                    var i_next = @intCast(i32, i) + if (imgui.ogGetMouseDragDelta(imgui.ImGuiMouseButton_Left, 0).y < 0) @as(i32, -1) else @as(i32, 1);
                    if (i_next >= 0 and i_next < file.layers.items.len) {
                        std.mem.swap(Layer, &file.layers.items[i], &file.layers.items[@intCast(usize, i_next)]);
                        active_layer_index = @intCast(usize, i_next);
                        imgui.igResetMouseDragDelta(imgui.ImGuiMouseButton_Left);
                    }
                }
            }

            if (imgui.igIsWindowFocused(imgui.ImGuiFocusedFlags_None)) {
                // down arrow changes layer
                if (imgui.ogKeyPressed(upaya.sokol.SAPP_KEYCODE_DOWN)) {
                    if (imgui.igGetIO().KeySuper) {
                        if (active_layer_index < file.layers.items.len - 1) {
                            std.mem.swap(Layer, &file.layers.items[active_layer_index], &file.layers.items[active_layer_index + 1]);
                            active_layer_index += 1;
                        }
                    } else {
                        if (active_layer_index < file.layers.items.len - 1)
                            active_layer_index += 1;
                    }
                }

                // up arrow changes layer
                if (imgui.ogKeyPressed(upaya.sokol.SAPP_KEYCODE_UP)) {
                    if (imgui.igGetIO().KeySuper) {
                        if (active_layer_index > 0) {
                            std.mem.swap(Layer, &file.layers.items[active_layer_index], &file.layers.items[active_layer_index - 1]);
                            active_layer_index -= 1;
                        }
                    } else {
                        if (active_layer_index > 0)
                            active_layer_index -= 1;
                    }
                }
            }
        }
    }
}
