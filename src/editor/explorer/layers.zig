const std = @import("std");
const pixi = @import("../../pixi.zig");
const core = @import("mach-core");
const imgui = @import("zig-imgui");
const History = pixi.storage.Internal.Pixi.History;

pub fn draw() void {
    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
        imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0 * pixi.content_scale[0], .y = 5.0 * pixi.content_scale[1] });
        defer imgui.popStyleVar();

        imgui.pushStyleColorImVec4(imgui.Col_Button, pixi.state.theme.foreground.toImguiVec4());
        imgui.pushStyleColorImVec4(imgui.Col_ButtonActive, pixi.state.theme.foreground.toImguiVec4());
        imgui.pushStyleColorImVec4(imgui.Col_ButtonHovered, pixi.state.theme.foreground.toImguiVec4());
        defer imgui.popStyleColorEx(3);

        imgui.pushFont(pixi.state.fonts.fa_small_regular);
        imgui.pushFont(pixi.state.fonts.fa_small_solid);
        defer {
            imgui.popFont();
            imgui.popFont();
        }

        if (file.heightmap.layer != null) {
            imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 6.0 * pixi.content_scale[0], .y = 5.0 * pixi.content_scale[1] });
            defer imgui.popStyleVar();
            imgui.pushStyleColorImVec4(imgui.Col_Button, pixi.state.theme.highlight_secondary.toImguiVec4());
            imgui.pushStyleColorImVec4(imgui.Col_ButtonActive, pixi.state.theme.highlight_secondary.toImguiVec4());
            imgui.pushStyleColorImVec4(imgui.Col_ButtonHovered, pixi.state.theme.hover_secondary.toImguiVec4());
            defer imgui.popStyleColorEx(3);
            if (imgui.checkbox("Edit Heightmap Layer", &file.heightmap.visible)) {}
            if (imgui.button("Delete Heightmap Layer")) {
                file.deleted_heightmap_layers.append(file.heightmap.layer.?) catch unreachable;
                file.heightmap.layer = null;
                file.history.append(.{ .heightmap_restore_delete = .{ .action = .restore } }) catch unreachable;
                if (pixi.state.tools.current == .heightmap)
                    pixi.state.tools.current = .pointer;
            }
        }

        imgui.spacing();
        if (imgui.smallButton(pixi.fa.plus)) {
            pixi.state.popups.layer_setup_name = [_:0]u8{0} ** 128;
            std.mem.copyForwards(u8, &pixi.state.popups.layer_setup_name, "New Layer");
            pixi.state.popups.layer_setup_state = .none;
            pixi.state.popups.layer_setup = true;
        }
        imgui.separator();
        imgui.spacing();

        if (imgui.beginChild("LayersChild", .{
            .x = imgui.getWindowWidth(),
            .y = 0.0,
        }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
            defer imgui.endChild();

            var i: usize = file.layers.items.len;
            while (i > 0) {
                i -= 1;
                const layer = file.layers.items[i];

                imgui.pushStyleColorImVec4(imgui.Col_Text, if (i == file.selected_layer_index) pixi.state.theme.text.toImguiVec4() else pixi.state.theme.text_secondary.toImguiVec4());
                defer imgui.popStyleColor();

                imgui.pushID(layer.name);
                if (imgui.smallButton(if (layer.visible) pixi.fa.eye else pixi.fa.eye_slash)) {
                    file.layers.items[i].visible = !file.layers.items[i].visible;
                }
                imgui.popID();

                imgui.pushStyleVar(imgui.StyleVar_IndentSpacing, 30.0);
                defer imgui.popStyleVar();

                imgui.sameLine();
                imgui.indent();
                defer imgui.unindent();

                if (imgui.selectableEx(layer.name, i == file.selected_layer_index, imgui.SelectableFlags_None, .{ .x = 0.0, .y = 0.0 })) {
                    file.selected_layer_index = i;
                }

                imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0 * pixi.content_scale[0], .y = 2.0 * pixi.content_scale[1] });
                imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0 * pixi.content_scale[0], .y = 6.0 * pixi.content_scale[1] });
                imgui.pushStyleVar(imgui.StyleVar_IndentSpacing, 16.0 * pixi.content_scale[0]);
                imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0 * pixi.content_scale[0], .y = 10.0 * pixi.content_scale[1] });
                defer imgui.popStyleVarEx(4);

                if (imgui.beginPopupContextItem()) {
                    defer imgui.endPopup();

                    if (imgui.menuItem("Rename...")) {
                        pixi.state.popups.layer_setup_name = [_:0]u8{0} ** 128;
                        @memcpy(pixi.state.popups.layer_setup_name[0..layer.name.len], layer.name);
                        pixi.state.popups.layer_setup_index = i;
                        pixi.state.popups.layer_setup_state = .rename;
                        pixi.state.popups.layer_setup = true;
                    }

                    if (imgui.menuItem("Duplicate...")) {
                        const new_name = std.fmt.allocPrint(pixi.state.allocator, "{s}_copy", .{layer.name}) catch unreachable;
                        defer pixi.state.allocator.free(new_name);
                        pixi.state.popups.layer_setup_name = [_:0]u8{0} ** 128;
                        @memcpy(pixi.state.popups.layer_setup_name[0..new_name.len], new_name);
                        pixi.state.popups.layer_setup_index = i;
                        pixi.state.popups.layer_setup_state = .duplicate;
                        pixi.state.popups.layer_setup = true;
                    }
                    imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_red.toImguiVec4());
                    imgui.pushStyleColorImVec4(imgui.Col_Separator, pixi.state.theme.foreground.toImguiVec4());
                    defer imgui.popStyleColorEx(2);

                    imgui.separator();
                    if (imgui.menuItem("Delete")) {
                        file.deleteLayer(i) catch unreachable;
                    }
                }

                if (imgui.isItemActive() and !imgui.isItemHovered(imgui.HoveredFlags_None) and imgui.isAnyItemHovered()) {
                    const i_next = @as(usize, @intCast(std.math.clamp(@as(i32, @intCast(i)) + (if (imgui.getMouseDragDelta(imgui.MouseButton_Left, 0.0).y < 0.0) @as(i32, 1) else @as(i32, -1)), 0, std.math.maxInt(i32))));
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
                    imgui.resetMouseDragDeltaEx(imgui.MouseButton_Left);
                }
            }
        }
    } else {
        imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_background.toImguiVec4());
        imgui.textWrapped("Open a file to begin editing.");
        imgui.popStyleColor();
    }
}
