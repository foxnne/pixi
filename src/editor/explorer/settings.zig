const builtin = @import("builtin");
const std = @import("std");

const Pixi = @import("../../Pixi.zig");
const Core = @import("mach").Core;
const Editor = Pixi.Editor;

const nfd = @import("nfd");
const imgui = @import("zig-imgui");

pub fn draw(core: *Core, editor: *Editor) !void {
    imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 6.0, .y = 6.0 });
    defer imgui.popStyleVar();
    imgui.pushStyleColorImVec4(imgui.Col_Header, editor.theme.highlight_secondary.toImguiVec4());
    defer imgui.popStyleColor();

    if (imgui.beginChild("SettingsChild", .{
        .x = imgui.getWindowWidth(),
        .y = -1.0,
    }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
        defer imgui.endChild();
        imgui.pushItemWidth(imgui.getWindowWidth() - editor.settings.explorer_grip);

        if (imgui.collapsingHeader(Pixi.fa.mouse ++ "  Input", imgui.TreeNodeFlags_Framed)) {
            imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 3.0, .y = 3.0 });
            imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 4.0, .y = 4.0 });
            defer imgui.popStyleVarEx(2);

            imgui.pushItemWidth(editor.settings.explorer_width * 0.5);
            if (imgui.beginCombo("Scheme", @tagName(editor.settings.input_scheme), imgui.ComboFlags_None)) {
                defer imgui.endCombo();
                if (imgui.selectable("mouse")) {
                    editor.settings.input_scheme = .mouse;
                }
                if (imgui.selectable("trackpad")) {
                    editor.settings.input_scheme = .trackpad;
                }
            }

            if (Pixi.editor.settings.input_scheme == .trackpad) {
                _ = imgui.sliderFloatEx("Pan Sensitivity", &editor.settings.pan_sensitivity, 1.0, 25.0, "%.0f", imgui.SliderFlags_AlwaysClamp);
                _ = imgui.sliderFloatEx("Zoom Sensitivity", &editor.settings.zoom_sensitivity, 1, 200, "%.0f%", imgui.SliderFlags_AlwaysClamp);
            }

            if (builtin.os.tag == .macos) {
                if (imgui.checkbox("Ctrl zoom", &editor.settings.zoom_ctrl)) {
                    Pixi.app.allocator.free(editor.hotkeys.hotkeys);
                    editor.hotkeys = try Pixi.input.Hotkeys.initDefault(Pixi.app.allocator);
                }
            }

            imgui.popItemWidth();
        }

        if (imgui.collapsingHeader(Pixi.fa.th_list ++ "  Layout", imgui.TreeNodeFlags_None)) {
            imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 3.0, .y = 3.0 });
            imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 4.0, .y = 4.0 });
            defer imgui.popStyleVarEx(2);

            imgui.pushItemWidth(editor.settings.explorer_width * 0.5);

            _ = imgui.sliderFloatEx(
                "Info Height",
                &editor.settings.info_bar_height,
                18,
                36,
                "%.0f",
                imgui.SliderFlags_None,
            );

            _ = imgui.sliderFloatEx(
                "Sidebar Width",
                &editor.settings.sidebar_width,
                25,
                75,
                "%.0f",
                imgui.SliderFlags_None,
            );

            _ = imgui.checkbox(
                "Show Rulers",
                &editor.settings.show_rulers,
            );

            _ = imgui.sliderFloatEx(
                "Explorer Title Align",
                &editor.settings.explorer_title_align,
                0.0,
                1.0,
                "%0.1f",
                imgui.SliderFlags_None,
            );

            imgui.popItemWidth();
        }

        if (imgui.collapsingHeader(Pixi.fa.sliders_h ++ "  Configuration", imgui.TreeNodeFlags_None)) {
            imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 3.0, .y = 3.0 });
            imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 4.0, .y = 4.0 });
            defer imgui.popStyleVarEx(2);
            imgui.pushItemWidth(editor.settings.explorer_width * 0.5);

            _ = imgui.checkbox(
                "Dropper Auto-switch",
                &editor.settings.eyedropper_auto_switch_layer,
            );

            imgui.separator();

            imgui.text("Reference Window Opacity");
            _ = imgui.sliderFloatEx("##reference_window_opacity", &editor.settings.reference_window_opacity, 0.0, 100.0, "%.0f", imgui.SliderFlags_AlwaysClamp);

            imgui.separator();

            if (imgui.beginCombo("Compatibility", if (editor.settings.compatibility == .none) "None" else "LDtk", imgui.ComboFlags_None)) {
                defer imgui.endCombo();

                if (imgui.selectable("None")) editor.settings.compatibility = .none;
                if (imgui.selectable("LDtk")) editor.settings.compatibility = .ldtk;
            }

            imgui.popItemWidth();
        }

        if (imgui.collapsingHeader(Pixi.fa.paint_roller ++ "  Style", imgui.TreeNodeFlags_None)) {
            imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 3.0, .y = 3.0 });
            imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 4.0, .y = 4.0 });
            defer imgui.popStyleVarEx(2);

            imgui.pushStyleColorImVec4(imgui.Col_Button, editor.theme.highlight_secondary.toImguiVec4());
            defer imgui.popStyleColor();

            imgui.pushItemWidth(imgui.getWindowWidth() * 0.7);
            if (imgui.beginCombo("Theme", editor.settings.theme, imgui.ComboFlags_None)) {
                defer imgui.endCombo();
                try searchThemes(editor);
            }
            imgui.separator();

            _ = Editor.Theme.styleColorEdit("Background", .{ .col = &editor.theme.background });
            _ = Editor.Theme.styleColorEdit("Foreground", .{ .col = &editor.theme.foreground });
            _ = Editor.Theme.styleColorEdit("Text", .{ .col = &editor.theme.text });
            _ = Editor.Theme.styleColorEdit("Secondary Text", .{ .col = &editor.theme.text_secondary });
            _ = Editor.Theme.styleColorEdit("Background Text", .{ .col = &editor.theme.text_background });
            _ = Editor.Theme.styleColorEdit("Primary Highlight", .{ .col = &editor.theme.highlight_primary });
            _ = Editor.Theme.styleColorEdit("Secondary Highlight", .{ .col = &editor.theme.highlight_secondary });
            _ = Editor.Theme.styleColorEdit("Primary Hover", .{ .col = &editor.theme.hover_primary });
            _ = Editor.Theme.styleColorEdit("Secondary Hover", .{ .col = &editor.theme.hover_secondary });

            imgui.spacing();

            if (imgui.buttonEx("Save As...", .{ .x = imgui.getWindowWidth() - editor.settings.explorer_grip, .y = 0.0 })) {
                editor.popups.file_dialog_request = .{
                    .state = .save,
                    .type = .export_theme,
                    .filter = "json",
                    .initial = Pixi.asset_data.themes,
                };
            }

            if (editor.popups.file_dialog_response) |response| {
                if (response.type == .export_theme) {
                    try editor.theme.save(response.path);
                    Pixi.app.allocator.free(editor.theme.name);
                    editor.theme = try Editor.Theme.loadFromFile(response.path);
                    editor.settings.theme = editor.theme.name;
                }
                nfd.freePath(response.path);
                editor.popups.file_dialog_response = null;
            }

            imgui.popItemWidth();
        }

        imgui.spacing();
        imgui.separator();
        imgui.textColored(editor.theme.text_background.toImguiVec4(), "Framerate: %d", core.frame.rate);

        imgui.popItemWidth();
    }
}

fn searchThemes(editor: *Editor) !void {
    var dir_opt = std.fs.cwd().openDir(Pixi.asset_data.themes, .{ .access_sub_paths = false, .iterate = true }) catch null;
    if (dir_opt) |*dir| {
        defer dir.close();
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file) {
                const ext = std.fs.path.extension(entry.name);
                if (std.mem.eql(u8, ext, ".json")) {
                    const label = try std.fmt.allocPrintZ(Pixi.app.allocator, "{s}", .{entry.name});
                    defer Pixi.app.allocator.free(label);
                    if (imgui.selectable(label)) {
                        const abs_path = try std.fs.path.joinZ(Pixi.app.allocator, &.{ Pixi.asset_data.themes, entry.name });
                        defer Pixi.app.allocator.free(abs_path);
                        Pixi.app.allocator.free(editor.theme.name);
                        editor.theme = try Editor.Theme.loadFromFile(abs_path);
                        editor.settings.theme = editor.theme.name;
                    }
                }
            }
        }
    }
}
