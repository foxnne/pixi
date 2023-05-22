const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("root");

pub fn draw() void {
    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 2.0 * pixi.state.window.scale[0], 5.0 * pixi.state.window.scale[1] } });
        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button, .c = pixi.state.style.highlight_secondary.toSlice() });
        defer zgui.popStyleColor(.{ .count = 1 });
        defer zgui.popStyleVar(.{ .count = 1 });

        zgui.spacing();
        zgui.text("Edit Layer", .{});
        zgui.separator();
        zgui.spacing();
        if (zgui.beginChild("LayerChild", .{
            .h = pixi.state.settings.sprite_edit_height * pixi.state.window.scale[1],
        })) {
            defer zgui.endChild();
            if (zgui.button("New Layer", .{ .w = -1.0 })) {}
        }

        zgui.spacing();
        zgui.text("Layers", .{});
        zgui.separator();
        zgui.spacing();

        if (zgui.beginChild("LayersChild", .{})) {
            defer zgui.endChild();

            var i: usize = file.layers.items.len;
            while (i > 0) {
                i -= 1;
                const layer = file.layers.items[i];

                if (i == file.selected_layer_index) {
                    zgui.bullet();
                    zgui.sameLine(.{});
                }

                zgui.pushStyleColor4f(.{
                    .idx = zgui.StyleCol.text,
                    .c = if (i == file.selected_layer_index) pixi.state.style.text.toSlice() else pixi.state.style.text_secondary.toSlice(),
                });
                defer zgui.popStyleColor(.{ .count = 1 });

                zgui.indent(.{});
                defer zgui.unindent(.{});
                if (zgui.selectable(zgui.formatZ("{s}", .{layer.name}), .{ .selected = i == file.selected_layer_index })) {
                    file.selected_layer_index = i;
                }

                if (zgui.beginPopupContextItem()) {
                    defer zgui.endPopup();

                    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button, .c = pixi.state.style.background.toSlice() });
                    defer zgui.popStyleColor(.{ .count = 1 });

                    if (zgui.button(if (layer.visible) pixi.fa.eye else pixi.fa.eye_slash, .{})) {
                        file.layers.items[i].visible = !file.layers.items[i].visible;
                    }
                    zgui.sameLine(.{});

                    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text_red.toSlice() });
                    defer zgui.popStyleColor(.{ .count = 1 });

                    if (zgui.button(pixi.fa.trash, .{})) {}
                }

                if (zgui.isItemActive() and !zgui.isItemHovered(.{}) and zgui.isAnyItemHovered()) {
                    const i_next = @intCast(usize, std.math.clamp(@intCast(i32, i) + (if (zgui.getMouseDragDelta(.left, .{})[1] < 0.0) @as(i32, 1) else @as(i32, -1)), 0, std.math.maxInt(i32)));
                    if (i_next >= 0.0 and i_next < file.layers.items.len) {
                        file.layers.items[i] = file.layers.items[i_next];
                        file.layers.items[i_next] = layer;
                        file.selected_layer_index = i_next;
                    }
                    zgui.resetMouseDragDelta(.left);
                }
            }
        }
    }
}
