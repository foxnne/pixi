const builtin = @import("builtin");
const std = @import("std");
const Pixi = @import("../../Pixi.zig");
const Core = @import("mach").Core;
const nfd = @import("nfd");
const imgui = @import("zig-imgui");

pub fn draw(core: *Core) !void {
    imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 6.0 * Pixi.state.content_scale[1], .y = 6.0 * Pixi.state.content_scale[1] });
    defer imgui.popStyleVar();
    imgui.pushStyleColorImVec4(imgui.Col_Header, Pixi.editor.theme.highlight_secondary.toImguiVec4());
    defer imgui.popStyleColor();

    if (imgui.beginChild("SettingsChild", .{
        .x = imgui.getWindowWidth(),
        .y = -1.0,
    }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
        defer imgui.endChild();
        imgui.pushItemWidth(imgui.getWindowWidth() - Pixi.state.settings.explorer_grip * Pixi.state.content_scale[0]);

        if (imgui.collapsingHeader(Pixi.fa.mouse ++ "  Input", imgui.TreeNodeFlags_Framed)) {
            imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 3.0 * Pixi.state.content_scale[0], .y = 3.0 * Pixi.state.content_scale[1] });
            imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 4.0 * Pixi.state.content_scale[1], .y = 4.0 * Pixi.state.content_scale[1] });
            defer imgui.popStyleVarEx(2);

            imgui.pushItemWidth(Pixi.state.settings.explorer_width * Pixi.state.content_scale[0] * 0.5);
            if (imgui.beginCombo("Scheme", @tagName(Pixi.state.settings.input_scheme), imgui.ComboFlags_None)) {
                defer imgui.endCombo();
                if (imgui.selectable("mouse")) {
                    Pixi.state.settings.input_scheme = .mouse;
                }
                if (imgui.selectable("trackpad")) {
                    Pixi.state.settings.input_scheme = .trackpad;
                }
            }

            if (Pixi.state.settings.input_scheme == .trackpad) {
                _ = imgui.sliderFloatEx("Pan Sensitivity", &Pixi.state.settings.pan_sensitivity, 1.0, 25.0, "%.0f", imgui.SliderFlags_AlwaysClamp);
                _ = imgui.sliderFloatEx("Zoom Sensitivity", &Pixi.state.settings.zoom_sensitivity, 1, 200, "%.0f%", imgui.SliderFlags_AlwaysClamp);
            }

            if (builtin.os.tag == .macos) {
                if (imgui.checkbox("Ctrl zoom", &Pixi.state.settings.zoom_ctrl)) {
                    Pixi.state.allocator.free(Pixi.state.hotkeys.hotkeys);
                    Pixi.state.hotkeys = try Pixi.input.Hotkeys.initDefault(Pixi.state.allocator);
                }
            }

            imgui.popItemWidth();
        }

        if (imgui.collapsingHeader(Pixi.fa.th_list ++ "  Layout", imgui.TreeNodeFlags_None)) {
            imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 3.0 * Pixi.state.content_scale[0], .y = 3.0 * Pixi.state.content_scale[1] });
            imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 4.0 * Pixi.state.content_scale[1], .y = 4.0 * Pixi.state.content_scale[1] });
            defer imgui.popStyleVarEx(2);

            imgui.pushItemWidth(Pixi.state.settings.explorer_width * Pixi.state.content_scale[0] * 0.5);

            _ = imgui.sliderFloatEx(
                "Info Height",
                &Pixi.state.settings.info_bar_height,
                18,
                36,
                "%.0f",
                imgui.SliderFlags_None,
            );

            _ = imgui.sliderFloatEx(
                "Sidebar Width",
                &Pixi.state.settings.sidebar_width,
                25,
                75,
                "%.0f",
                imgui.SliderFlags_None,
            );

            _ = imgui.checkbox(
                "Show Rulers",
                &Pixi.state.settings.show_rulers,
            );

            _ = imgui.sliderFloatEx(
                "Explorer Title Align",
                &Pixi.state.settings.explorer_title_align,
                0.0,
                1.0,
                "%0.1f",
                imgui.SliderFlags_None,
            );

            imgui.popItemWidth();
        }

        if (imgui.collapsingHeader(Pixi.fa.sliders_h ++ "  Configuration", imgui.TreeNodeFlags_None)) {
            imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 3.0 * Pixi.state.content_scale[0], .y = 3.0 * Pixi.state.content_scale[1] });
            imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 4.0 * Pixi.state.content_scale[1], .y = 4.0 * Pixi.state.content_scale[1] });
            defer imgui.popStyleVarEx(2);
            imgui.pushItemWidth(Pixi.state.settings.explorer_width * Pixi.state.content_scale[0] * 0.5);

            _ = imgui.checkbox(
                "Dropper Auto-switch",
                &Pixi.state.settings.eyedropper_auto_switch_layer,
            );

            imgui.separator();

            imgui.text("Reference Window Opacity");
            _ = imgui.sliderFloatEx("##reference_window_opacity", &Pixi.state.settings.reference_window_opacity, 0.0, 100.0, "%.0f", imgui.SliderFlags_AlwaysClamp);

            imgui.separator();

            if (imgui.beginCombo("Compatibility", if (Pixi.state.settings.compatibility == .none) "None" else "LDtk", imgui.ComboFlags_None)) {
                defer imgui.endCombo();

                if (imgui.selectable("None")) Pixi.state.settings.compatibility = .none;
                if (imgui.selectable("LDtk")) Pixi.state.settings.compatibility = .ldtk;
            }

            imgui.popItemWidth();
        }

        if (imgui.collapsingHeader(Pixi.fa.paint_roller ++ "  Style", imgui.TreeNodeFlags_None)) {
            imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 3.0 * Pixi.state.content_scale[0], .y = 3.0 * Pixi.state.content_scale[1] });
            imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 4.0 * Pixi.state.content_scale[1], .y = 4.0 * Pixi.state.content_scale[1] });
            defer imgui.popStyleVarEx(2);

            imgui.pushStyleColorImVec4(imgui.Col_Button, Pixi.editor.theme.highlight_secondary.toImguiVec4());
            defer imgui.popStyleColor();

            imgui.pushItemWidth(imgui.getWindowWidth() * 0.7);
            if (imgui.beginCombo("Theme", Pixi.state.settings.theme, imgui.ComboFlags_None)) {
                defer imgui.endCombo();
                try searchThemes();
            }
            imgui.separator();

            _ = Pixi.Editor.Theme.styleColorEdit("Background", .{ .col = &Pixi.editor.theme.background });
            _ = Pixi.Editor.Theme.styleColorEdit("Foreground", .{ .col = &Pixi.editor.theme.foreground });
            _ = Pixi.Editor.Theme.styleColorEdit("Text", .{ .col = &Pixi.editor.theme.text });
            _ = Pixi.Editor.Theme.styleColorEdit("Secondary Text", .{ .col = &Pixi.editor.theme.text_secondary });
            _ = Pixi.Editor.Theme.styleColorEdit("Background Text", .{ .col = &Pixi.editor.theme.text_background });
            _ = Pixi.Editor.Theme.styleColorEdit("Primary Highlight", .{ .col = &Pixi.editor.theme.highlight_primary });
            _ = Pixi.Editor.Theme.styleColorEdit("Secondary Highlight", .{ .col = &Pixi.editor.theme.highlight_secondary });
            _ = Pixi.Editor.Theme.styleColorEdit("Primary Hover", .{ .col = &Pixi.editor.theme.hover_primary });
            _ = Pixi.Editor.Theme.styleColorEdit("Secondary Hover", .{ .col = &Pixi.editor.theme.hover_secondary });

            imgui.spacing();

            if (imgui.buttonEx("Save As...", .{ .x = imgui.getWindowWidth() - Pixi.state.settings.explorer_grip * Pixi.state.content_scale[0], .y = 0.0 })) {
                Pixi.state.popups.file_dialog_request = .{
                    .state = .save,
                    .type = .export_theme,
                    .filter = "json",
                    .initial = Pixi.assets.themes,
                };
            }

            if (Pixi.state.popups.file_dialog_response) |response| {
                if (response.type == .export_theme) {
                    try Pixi.editor.theme.save(response.path);
                    Pixi.state.allocator.free(Pixi.editor.theme.name);
                    Pixi.editor.theme = try Pixi.Editor.Theme.loadFromFile(response.path);
                    Pixi.state.settings.theme = Pixi.editor.theme.name;
                }
                nfd.freePath(response.path);
                Pixi.state.popups.file_dialog_response = null;
            }

            imgui.popItemWidth();
        }

        imgui.spacing();
        imgui.separator();
        imgui.textColored(Pixi.editor.theme.text_background.toImguiVec4(), "Framerate: %d", core.frame.rate);

        imgui.popItemWidth();
    }
}

fn searchThemes() !void {
    var dir_opt = std.fs.cwd().openDir(Pixi.assets.themes, .{ .access_sub_paths = false, .iterate = true }) catch null;
    if (dir_opt) |*dir| {
        defer dir.close();
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file) {
                const ext = std.fs.path.extension(entry.name);
                if (std.mem.eql(u8, ext, ".json")) {
                    const label = try std.fmt.allocPrintZ(Pixi.state.allocator, "{s}", .{entry.name});
                    defer Pixi.state.allocator.free(label);
                    if (imgui.selectable(label)) {
                        const abs_path = try std.fs.path.joinZ(Pixi.state.allocator, &.{ Pixi.assets.themes, entry.name });
                        defer Pixi.state.allocator.free(abs_path);
                        Pixi.state.allocator.free(Pixi.editor.theme.name);
                        Pixi.editor.theme = try Pixi.Editor.Theme.loadFromFile(abs_path);
                        Pixi.state.settings.theme = Pixi.editor.theme.name;
                    }
                }
            }
        }
    }
}
