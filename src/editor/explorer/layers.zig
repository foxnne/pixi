const std = @import("std");
const Pixi = @import("../../Pixi.zig");
const imgui = @import("zig-imgui");
const History = Pixi.storage.Internal.PixiFile.History;

pub fn draw() void {
    if (Pixi.Editor.getFile(Pixi.state.open_file_index)) |file| {
        imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0, .y = 5.0 });
        defer imgui.popStyleVar();

        imgui.pushStyleColorImVec4(imgui.Col_Button, Pixi.editor.theme.foreground.toImguiVec4());
        imgui.pushStyleColorImVec4(imgui.Col_ButtonActive, Pixi.editor.theme.foreground.toImguiVec4());
        imgui.pushStyleColorImVec4(imgui.Col_ButtonHovered, Pixi.editor.theme.foreground.toImguiVec4());
        defer imgui.popStyleColorEx(3);

        imgui.pushFont(Pixi.state.fonts.fa_small_regular);
        imgui.pushFont(Pixi.state.fonts.fa_small_solid);
        defer {
            imgui.popFont();
            imgui.popFont();
        }

        if (file.heightmap.layer != null) {
            imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 6.0, .y = 5.0 });
            defer imgui.popStyleVar();
            imgui.pushStyleColorImVec4(imgui.Col_Button, Pixi.editor.theme.highlight_secondary.toImguiVec4());
            imgui.pushStyleColorImVec4(imgui.Col_ButtonActive, Pixi.editor.theme.highlight_secondary.toImguiVec4());
            imgui.pushStyleColorImVec4(imgui.Col_ButtonHovered, Pixi.editor.theme.hover_secondary.toImguiVec4());
            defer imgui.popStyleColorEx(3);

            if (imgui.checkbox("Edit Heightmap Layer", &file.heightmap.visible)) {}
            if (imgui.button("Delete Heightmap Layer")) {
                file.deleted_heightmap_layers.append(file.heightmap.layer.?) catch unreachable;
                file.heightmap.layer = null;
                file.history.append(.{ .heightmap_restore_delete = .{ .action = .restore } }) catch unreachable;
                if (Pixi.state.tools.current == .heightmap)
                    Pixi.state.tools.current = .pointer;
            }
        }

        imgui.spacing();
        if (imgui.smallButton(Pixi.fa.plus)) {
            Pixi.state.popups.layer_setup_name = [_:0]u8{0} ** 128;
            std.mem.copyForwards(u8, &Pixi.state.popups.layer_setup_name, "New Layer");
            Pixi.state.popups.layer_setup_state = .none;
            Pixi.state.popups.layer_setup = true;
        }
        imgui.sameLine();

        const file_name = std.fmt.allocPrintZ(Pixi.state.allocator, "{s}", .{std.fs.path.basename(file.path)}) catch unreachable;
        defer Pixi.state.allocator.free(file_name);

        imgui.text(file_name);

        imgui.separator();
        imgui.spacing();

        imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 5.0, .y = 10.0 });
        defer imgui.popStyleVar();

        const line_height: f32 = imgui.getTextLineHeightWithSpacing();
        const layers_min_height: f32 = line_height * 10.0;
        const min_lines_height: f32 = line_height * @as(f32, @floatFromInt(file.layers.items.len));

        if (imgui.beginChild("LayersChild", .{
            .x = -1.0,
            .y = @min(min_lines_height, layers_min_height),
        }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
            defer imgui.endChild();

            var i: usize = file.layers.items.len;
            while (i > 0) {
                i -= 1;
                const layer = file.layers.items[i];

                imgui.pushStyleColorImVec4(imgui.Col_Text, if (i == file.selected_layer_index) Pixi.editor.theme.text.toImguiVec4() else Pixi.editor.theme.text_secondary.toImguiVec4());
                imgui.pushStyleColorImVec4(imgui.Col_Header, if (i == file.selected_layer_index) Pixi.editor.theme.highlight_secondary.toImguiVec4() else Pixi.editor.theme.foreground.toImguiVec4());
                imgui.pushStyleColorImVec4(imgui.Col_HeaderHovered, Pixi.editor.theme.background.toImguiVec4());
                defer imgui.popStyleColorEx(3);

                imgui.pushID(layer.name);
                if (imgui.smallButton(if (layer.visible) Pixi.fa.eye else Pixi.fa.eye_slash)) {
                    const change: History.Change = .{ .layer_settings = .{
                        .collapse = file.layers.items[i].collapse,
                        .visible = file.layers.items[i].visible,
                        .index = i,
                    } };

                    file.layers.items[i].visible = !file.layers.items[i].visible;

                    file.history.append(change) catch unreachable;
                }
                imgui.sameLineEx(0.0, 0.0);

                const collapse_true = Pixi.fa.arrow_up;
                const collapse_false = Pixi.fa.box_open;
                if (imgui.smallButton(if (layer.collapse) collapse_true else collapse_false)) {
                    const change: History.Change = .{ .layer_settings = .{
                        .collapse = file.layers.items[i].collapse,
                        .visible = file.layers.items[i].visible,
                        .index = i,
                    } };

                    file.layers.items[i].collapse = !file.layers.items[i].collapse;
                    file.history.append(change) catch unreachable;
                }
                if (imgui.beginItemTooltip()) {
                    defer imgui.endTooltip();
                    imgui.text("Collapse");
                    imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_background.toImguiVec4());
                    defer imgui.popStyleColor();
                    imgui.text("If " ++ collapse_true ++ ", layer will be drawn onto the layer above it (lower in the layer stack) prior to packing.");
                    imgui.text("If " ++ collapse_false ++ ", layer will remain independent and will be packed separately.");
                }
                imgui.popID();

                imgui.pushStyleVar(imgui.StyleVar_IndentSpacing, 30.0);
                defer imgui.popStyleVar();

                imgui.sameLine();
                imgui.indentEx(64.0);
                defer imgui.unindentEx(64.0);

                if (imgui.selectableEx(layer.name, i == file.selected_layer_index, imgui.SelectableFlags_None, .{ .x = 0.0, .y = 0.0 })) {
                    file.selected_layer_index = i;
                }

                imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0, .y = 2.0 });
                imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0, .y = 6.0 });
                imgui.pushStyleVar(imgui.StyleVar_IndentSpacing, 16.0);
                imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0, .y = 10.0 });
                defer imgui.popStyleVarEx(4);

                if (imgui.beginPopupContextItem()) {
                    defer imgui.endPopup();

                    if (imgui.menuItem("Rename...")) {
                        Pixi.state.popups.layer_setup_name = [_:0]u8{0} ** 128;
                        @memcpy(Pixi.state.popups.layer_setup_name[0..layer.name.len], layer.name);
                        Pixi.state.popups.layer_setup_index = i;
                        Pixi.state.popups.layer_setup_state = .rename;
                        Pixi.state.popups.layer_setup = true;
                    }

                    if (imgui.menuItem("Duplicate...")) {
                        const new_name = std.fmt.allocPrint(Pixi.state.allocator, "{s}_copy", .{layer.name}) catch unreachable;
                        defer Pixi.state.allocator.free(new_name);
                        Pixi.state.popups.layer_setup_name = [_:0]u8{0} ** 128;
                        @memcpy(Pixi.state.popups.layer_setup_name[0..new_name.len], new_name);
                        Pixi.state.popups.layer_setup_index = i;
                        Pixi.state.popups.layer_setup_state = .duplicate;
                        Pixi.state.popups.layer_setup = true;
                    }
                    imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_red.toImguiVec4());
                    imgui.pushStyleColorImVec4(imgui.Col_Separator, Pixi.editor.theme.foreground.toImguiVec4());
                    defer imgui.popStyleColorEx(2);

                    imgui.separator();
                    if (imgui.menuItem("Delete")) {
                        file.deleteLayer(i) catch unreachable;
                    }
                }

                if (imgui.isItemActive() and !imgui.isItemHovered(imgui.HoveredFlags_None) and imgui.isAnyItemHovered()) {
                    const i_next = @as(usize, @intCast(std.math.clamp(@as(i32, @intCast(i)) + (if (imgui.getMouseDragDelta(imgui.MouseButton_Left, 0.0).y < 0.0) @as(i32, 1) else @as(i32, -1)), 0, std.math.maxInt(i32))));
                    if (i_next >= 0.0 and i_next < file.layers.items.len) {
                        var change = History.Change.create(Pixi.state.allocator, .layers_order, file.layers.items.len) catch unreachable;
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
    }
}
