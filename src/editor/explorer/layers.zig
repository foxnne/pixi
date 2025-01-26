const std = @import("std");

const Pixi = @import("../../Pixi.zig");
const Editor = Pixi.Editor;
const History = Pixi.Internal.PixiFile.History;

const imgui = @import("zig-imgui");

pub fn draw(editor: *Editor) !void {
    if (editor.getFile(editor.open_file_index)) |file| {
        imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 2.0, .y = 5.0 });
        defer imgui.popStyleVar();

        imgui.pushStyleColorImVec4(imgui.Col_Button, editor.theme.foreground.toImguiVec4());
        imgui.pushStyleColorImVec4(imgui.Col_ButtonActive, editor.theme.foreground.toImguiVec4());
        imgui.pushStyleColorImVec4(imgui.Col_ButtonHovered, editor.theme.foreground.toImguiVec4());
        defer imgui.popStyleColorEx(3);

        if (file.heightmap.layer != null) {
            imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 6.0, .y = 5.0 });
            defer imgui.popStyleVar();
            imgui.pushStyleColorImVec4(imgui.Col_Button, editor.theme.highlight_secondary.toImguiVec4());
            imgui.pushStyleColorImVec4(imgui.Col_ButtonActive, editor.theme.highlight_secondary.toImguiVec4());
            imgui.pushStyleColorImVec4(imgui.Col_ButtonHovered, editor.theme.hover_secondary.toImguiVec4());
            defer imgui.popStyleColorEx(3);

            if (imgui.checkbox("Edit Heightmap Layer", &file.heightmap.visible)) {}
            if (imgui.button("Delete Heightmap Layer")) {
                try file.deleted_heightmap_layers.append(Pixi.app.allocator, file.heightmap.layer.?);
                file.heightmap.layer = null;
                try file.history.append(.{ .heightmap_restore_delete = .{ .action = .restore } });
                if (editor.tools.current == .heightmap)
                    editor.tools.current = .pointer;
            }
        }

        imgui.spacing();
        if (imgui.smallButton(Pixi.fa.plus)) {
            editor.popups.layer_setup_name = [_:0]u8{0} ** 128;
            std.mem.copyForwards(u8, &editor.popups.layer_setup_name, "New Layer");
            editor.popups.layer_setup_state = .none;
            editor.popups.layer_setup = true;
        }
        imgui.sameLine();

        const file_name = try std.fmt.allocPrintZ(Pixi.app.allocator, "{s}", .{std.fs.path.basename(file.path)});
        defer Pixi.app.allocator.free(file_name);

        imgui.text(file_name);

        imgui.separator();
        imgui.spacing();

        imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 5.0, .y = 10.0 });
        defer imgui.popStyleVar();

        const line_height: f32 = imgui.getTextLineHeightWithSpacing();
        const layers_min_height: f32 = line_height * 10.0;
        const min_lines_height: f32 = line_height * @as(f32, @floatFromInt(file.layers.slice().len));

        if (imgui.beginChild("LayersChild", .{
            .x = -1.0,
            .y = @min(min_lines_height, layers_min_height),
        }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
            defer imgui.endChild();

            var i: usize = file.layers.slice().len;
            while (i > 0) {
                i -= 1;
                var layer = file.layers.slice().get(i);

                imgui.pushStyleColorImVec4(imgui.Col_Text, if (i == file.selected_layer_index) editor.theme.text.toImguiVec4() else editor.theme.text_secondary.toImguiVec4());
                imgui.pushStyleColorImVec4(imgui.Col_Header, if (i == file.selected_layer_index) editor.theme.highlight_secondary.toImguiVec4() else editor.theme.foreground.toImguiVec4());
                imgui.pushStyleColorImVec4(imgui.Col_HeaderHovered, editor.theme.background.toImguiVec4());
                defer imgui.popStyleColorEx(3);

                imgui.pushID(layer.name);
                if (imgui.smallButton(if (layer.visible) Pixi.fa.eye else Pixi.fa.eye_slash)) {
                    const change: History.Change = .{ .layer_settings = .{
                        .collapse = layer.collapse,
                        .visible = layer.visible,
                        .index = i,
                    } };

                    layer.visible = !layer.visible;

                    file.layers.set(i, layer);

                    try file.history.append(change);
                }
                imgui.sameLineEx(0.0, 0.0);

                const collapse_true = Pixi.fa.arrow_up;
                const collapse_false = Pixi.fa.box_open;
                if (imgui.smallButton(if (layer.collapse) collapse_true else collapse_false)) {
                    const change: History.Change = .{ .layer_settings = .{
                        .collapse = layer.collapse,
                        .visible = layer.visible,
                        .index = i,
                    } };

                    layer.collapse = !layer.collapse;
                    file.layers.set(i, layer);
                    try file.history.append(change);
                }
                if (imgui.beginItemTooltip()) {
                    defer imgui.endTooltip();
                    imgui.text("Collapse");
                    imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text_background.toImguiVec4());
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
                        editor.popups.layer_setup_name = [_:0]u8{0} ** 128;
                        @memcpy(editor.popups.layer_setup_name[0..layer.name.len], layer.name);
                        editor.popups.layer_setup_index = i;
                        editor.popups.layer_setup_state = .rename;
                        editor.popups.layer_setup = true;
                    }

                    if (imgui.menuItem("Duplicate...")) {
                        const new_name = try std.fmt.allocPrint(Pixi.app.allocator, "{s}_copy", .{layer.name});
                        defer Pixi.app.allocator.free(new_name);
                        editor.popups.layer_setup_name = [_:0]u8{0} ** 128;
                        @memcpy(editor.popups.layer_setup_name[0..new_name.len], new_name);
                        editor.popups.layer_setup_index = i;
                        editor.popups.layer_setup_state = .duplicate;
                        editor.popups.layer_setup = true;
                    }
                    imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text_red.toImguiVec4());
                    imgui.pushStyleColorImVec4(imgui.Col_Separator, editor.theme.foreground.toImguiVec4());
                    defer imgui.popStyleColorEx(2);

                    imgui.separator();
                    if (imgui.menuItem("Delete")) {
                        try file.deleteLayer(i);
                    }
                }

                if (imgui.isItemActive() and !imgui.isItemHovered(imgui.HoveredFlags_None) and imgui.isAnyItemHovered()) {
                    const i_next = @as(usize, @intCast(std.math.clamp(@as(i32, @intCast(i)) + (if (imgui.getMouseDragDelta(imgui.MouseButton_Left, 0.0).y < 0.0) @as(i32, 1) else @as(i32, -1)), 0, std.math.maxInt(i32))));
                    if (i_next >= 0.0 and i_next < file.layers.slice().len) {
                        var change = try History.Change.create(Pixi.app.allocator, .layers_order, file.layers.slice().len);
                        var index: usize = 0;
                        while (index < file.layers.slice().len) : (index += 1) {
                            const l = file.layers.slice().get(index);
                            change.layers_order.order[index] = l.id;
                            if (file.selected_layer_index == index) {
                                change.layers_order.selected = l.id;
                            }
                        }
                        try file.history.append(change);

                        file.layers.set(i, file.layers.slice().get(i_next));
                        file.layers.set(i_next, layer);
                        file.selected_layer_index = i_next;
                    }
                    imgui.resetMouseDragDeltaEx(imgui.MouseButton_Left);
                }
            }
        }
    }
}
