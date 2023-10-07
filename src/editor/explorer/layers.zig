const std = @import("std");
const pixi = @import("../../pixi.zig");
const core = @import("mach-core");
const zgui = @import("zgui").MachImgui(core);
const History = pixi.storage.Internal.Pixi.History;

pub fn draw() void {
    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 2.0 * pixi.content_scale[0], 5.0 * pixi.content_scale[1] } });
        defer zgui.popStyleVar(.{ .count = 1 });

        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button, .c = pixi.state.theme.foreground.toSlice() });
        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button_active, .c = pixi.state.theme.foreground.toSlice() });
        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button_hovered, .c = pixi.state.theme.foreground.toSlice() });
        defer zgui.popStyleColor(.{ .count = 3 });

        zgui.pushFont(pixi.state.fonts.fa_small_regular);
        zgui.pushFont(pixi.state.fonts.fa_small_solid);
        defer {
            zgui.popFont();
            zgui.popFont();
        }

        if (file.heightmap_layer != null) {
            zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 6.0 * pixi.content_scale[0], 5.0 * pixi.content_scale[1] } });
            defer zgui.popStyleVar(.{ .count = 1 });
            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button, .c = pixi.state.theme.highlight_secondary.toSlice() });
            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button_active, .c = pixi.state.theme.highlight_secondary.toSlice() });
            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button_hovered, .c = pixi.state.theme.hover_secondary.toSlice() });
            defer zgui.popStyleColor(.{ .count = 3 });
            if (zgui.button("Delete Heightmap Layer", .{})) {
                file.deleted_heightmap_layers.append(file.heightmap_layer.?) catch unreachable;
                file.heightmap_layer = null;
                file.history.append(.{ .heightmap_restore_delete = .{ .action = .restore } }) catch unreachable;
                if (pixi.state.tools.current == .heightmap)
                    pixi.state.tools.current = .pointer;
            }
        }

        zgui.spacing();
        if (zgui.smallButton(pixi.fa.plus)) {
            pixi.state.popups.layer_setup_name = [_:0]u8{0} ** 128;
            std.mem.copyForwards(u8, &pixi.state.popups.layer_setup_name, "New Layer");
            pixi.state.popups.layer_setup_state = .none;
            pixi.state.popups.layer_setup = true;
        }
        zgui.separator();
        zgui.spacing();

        if (zgui.beginChild("LayersChild", .{ .w = zgui.getWindowWidth() - pixi.state.settings.explorer_grip * pixi.content_scale[0] })) {
            defer zgui.endChild();

            var i: usize = file.layers.items.len;
            while (i > 0) {
                i -= 1;
                const layer = file.layers.items[i];

                zgui.pushStyleColor4f(.{
                    .idx = zgui.StyleCol.text,
                    .c = if (i == file.selected_layer_index) pixi.state.theme.text.toSlice() else pixi.state.theme.text_secondary.toSlice(),
                });
                defer zgui.popStyleColor(.{ .count = 1 });

                zgui.pushStrId(layer.name);
                if (zgui.smallButton(if (layer.visible) pixi.fa.eye else pixi.fa.eye_slash)) {
                    file.layers.items[i].visible = !file.layers.items[i].visible;
                }
                zgui.popId();

                zgui.sameLine(.{});
                zgui.indent(.{});
                defer zgui.unindent(.{});
                if (zgui.selectable(zgui.formatZ(" {s}", .{layer.name}), .{ .selected = i == file.selected_layer_index })) {
                    file.selected_layer_index = i;
                }

                zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 2.0 * pixi.content_scale[0], 2.0 * pixi.content_scale[1] } });
                zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 4.0 * pixi.content_scale[0], 6.0 * pixi.content_scale[1] } });
                zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.indent_spacing, .v = 16.0 * pixi.content_scale[0] });
                zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.window_padding, .v = .{ 10.0 * pixi.content_scale[0], 10.0 * pixi.content_scale[1] } });
                defer zgui.popStyleVar(.{ .count = 4 });

                if (zgui.beginPopupContextItem()) {
                    defer zgui.endPopup();

                    if (zgui.menuItem("Rename...", .{})) {
                        pixi.state.popups.layer_setup_name = [_:0]u8{0} ** 128;
                        @memcpy(pixi.state.popups.layer_setup_name[0..layer.name.len], layer.name);
                        pixi.state.popups.layer_setup_index = i;
                        pixi.state.popups.layer_setup_state = .rename;
                        pixi.state.popups.layer_setup = true;
                    }

                    if (zgui.menuItem("Duplicate...", .{})) {
                        const new_name = zgui.format("{s}_copy", .{layer.name});
                        pixi.state.popups.layer_setup_name = [_:0]u8{0} ** 128;
                        @memcpy(pixi.state.popups.layer_setup_name[0..new_name.len], new_name);
                        pixi.state.popups.layer_setup_index = i;
                        pixi.state.popups.layer_setup_state = .duplicate;
                        pixi.state.popups.layer_setup = true;
                    }
                    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.theme.text_red.toSlice() });
                    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.separator, .c = pixi.state.theme.foreground.toSlice() });
                    defer zgui.popStyleColor(.{ .count = 2 });

                    zgui.separator();
                    if (zgui.menuItem("Delete", .{})) {
                        file.deleteLayer(i) catch unreachable;
                    }
                }

                if (zgui.isItemActive() and !zgui.isItemHovered(.{}) and zgui.isAnyItemHovered()) {
                    const i_next = @as(usize, @intCast(std.math.clamp(@as(i32, @intCast(i)) + (if (zgui.getMouseDragDelta(.left, .{})[1] < 0.0) @as(i32, 1) else @as(i32, -1)), 0, std.math.maxInt(i32))));
                    if (i_next >= 0.0 and i_next < file.layers.items.len) {
                        var change = History.Change.create(pixi.state.allocator, .layers_order, file.layers.items.len) catch unreachable;
                        for (file.layers.items, 0..) |l, layer_i| {
                            change.layers_order.order[layer_i] = l.id;
                            if (file.selected_layer_index == layer_i) {
                                change.layers_order.selected = l.id;
                            }
                        }
                        file.history.append(change) catch unreachable;

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
