const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

const canvas = @import("canvas.zig");

var active_layer_index: usize = 0;

pub fn draw() void {
    if (imgui.igBegin("Layers", 0, imgui.ImGuiWindowFlags_NoResize)) {
        defer imgui.igEnd();

        var file = canvas.getActiveFile();

        if (file) |f| {
            if (imgui.ogColoredButton(0x00000000, imgui.icons.plus_circle)) {
                f.layers.insert(0, .{
                    .name = std.fmt.allocPrint(upaya.mem.allocator, "Layer {d}\u{0}", .{f.layers.items.len}) catch unreachable,
                    .texture = upaya.Texture.initTransparent(f.width, f.height),
                }) catch unreachable;
                active_layer_index += 1;
            }
            imgui.igSeparator();

            for (f.layers.items) |layer, i| {

                var eye = if (!layer.hidden) imgui.icons.eye else imgui.icons.eye_slash;
                
                imgui.igPushIDInt(@intCast(i32, i));
                if (imgui.ogColoredButton(0x00000000, eye)){
                    f.layers.items[i].hidden = !layer.hidden;
                }
                
                imgui.igSameLine(0, 5);
                var selected = i == active_layer_index;
                if(imgui.ogSelectableBool(@ptrCast([*c]const u8, layer.name), selected , imgui.ImGuiSelectableFlags_None, .{}))
                    active_layer_index = i;
                imgui.igPopID();
                
                if (imgui.igIsItemActive() and !imgui.igIsItemHovered(imgui.ImGuiHoveredFlags_None)) {
                    var i_next = @intCast(i32, i) + if (imgui.ogGetMouseDragDelta(imgui.ImGuiMouseButton_Left, 0).y < 0) @as(i32, -1) else @as(i32, 1);
                    if (i_next >= 0 and i_next < f.layers.items.len){

                        //var l = f.layers.orderedRemove(i);
                        //f.layers.insert(@intCast(usize, i_next), l) catch unreachable;
                        f.layers.items[i] = f.layers.items[@intCast(usize,i_next)];
                        f.layers.items[@intCast(usize,i_next)] = layer;
                        active_layer_index = @intCast(usize, i_next);
                        imgui.igResetMouseDragDelta(imgui.ImGuiMouseButton_Left);
                        
                    }
                }
            }
        }
    }
}
