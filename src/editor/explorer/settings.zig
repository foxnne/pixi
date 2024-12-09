const builtin = @import("builtin");
const std = @import("std");
const pixi = @import("../../pixi.zig");
const Core = @import("mach").Core;
const nfd = @import("nfd");
const imgui = @import("zig-imgui");

pub fn draw(core: *Core) void {
    imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 6.0 * pixi.content_scale[1], .y = 6.0 * pixi.content_scale[1] });
    defer imgui.popStyleVar();
    imgui.pushStyleColorImVec4(imgui.Col_Header, pixi.state.theme.highlight_secondary.toImguiVec4());
    defer imgui.popStyleColor();

    if (imgui.beginChild("SettingsChild", .{
        .x = imgui.getWindowWidth(),
        .y = -1.0,
    }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
        defer imgui.endChild();
        imgui.pushItemWidth(imgui.getWindowWidth() - pixi.state.settings.explorer_grip * pixi.content_scale[0]);

        if (imgui.collapsingHeader(pixi.fa.mouse ++ "  Input", imgui.TreeNodeFlags_Framed)) {
            imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 3.0 * pixi.content_scale[0], .y = 3.0 * pixi.content_scale[1] });
            imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 4.0 * pixi.content_scale[1], .y = 4.0 * pixi.content_scale[1] });
            defer imgui.popStyleVarEx(2);

            imgui.pushItemWidth(pixi.state.settings.explorer_width * pixi.content_scale[0] * 0.5);
            if (imgui.beginCombo("Scheme", @tagName(pixi.state.settings.input_scheme), imgui.ComboFlags_None)) {
                defer imgui.endCombo();
                if (imgui.selectable("mouse")) {
                    pixi.state.settings.input_scheme = .mouse;
                }
                if (imgui.selectable("trackpad")) {
                    pixi.state.settings.input_scheme = .trackpad;
                }
            }

            if (pixi.state.settings.input_scheme == .trackpad) {
                _ = imgui.sliderFloatEx("Pan Sensitivity", &pixi.state.settings.pan_sensitivity, 1.0, 25.0, "%.0f", imgui.SliderFlags_AlwaysClamp);
                _ = imgui.sliderFloatEx("Zoom Sensitivity", &pixi.state.settings.zoom_sensitivity, 1, 200, "%.0f%", imgui.SliderFlags_AlwaysClamp);
            }

            if (builtin.os.tag == .macos) {
                if (imgui.checkbox("Ctrl zoom", &pixi.state.settings.zoom_ctrl)) {
                    pixi.state.allocator.free(pixi.state.hotkeys.hotkeys);
                    pixi.state.hotkeys = pixi.input.Hotkeys.initDefault(pixi.state.allocator) catch unreachable;
                }
            }

            imgui.popItemWidth();
        }

        if (imgui.collapsingHeader(pixi.fa.th_list ++ "  Layout", imgui.TreeNodeFlags_None)) {
            imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 3.0 * pixi.content_scale[0], .y = 3.0 * pixi.content_scale[1] });
            imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 4.0 * pixi.content_scale[1], .y = 4.0 * pixi.content_scale[1] });
            defer imgui.popStyleVarEx(2);

            imgui.pushItemWidth(pixi.state.settings.explorer_width * pixi.content_scale[0] * 0.5);

            _ = imgui.sliderFloatEx(
                "Info Height",
                &pixi.state.settings.info_bar_height,
                18,
                36,
                "%.0f",
                imgui.SliderFlags_None,
            );

            _ = imgui.sliderFloatEx(
                "Sidebar Width",
                &pixi.state.settings.sidebar_width,
                25,
                75,
                "%.0f",
                imgui.SliderFlags_None,
            );

            _ = imgui.checkbox(
                "Show Rulers",
                &pixi.state.settings.show_rulers,
            );

            _ = imgui.sliderFloatEx(
                "Explorer Title Align",
                &pixi.state.settings.explorer_title_align,
                0.0,
                1.0,
                "%0.1f",
                imgui.SliderFlags_None,
            );

            imgui.popItemWidth();
        }

        if (imgui.collapsingHeader(pixi.fa.sliders_h ++ "  Configuration", imgui.TreeNodeFlags_None)) {
            imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 3.0 * pixi.content_scale[0], .y = 3.0 * pixi.content_scale[1] });
            imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 4.0 * pixi.content_scale[1], .y = 4.0 * pixi.content_scale[1] });
            defer imgui.popStyleVarEx(2);
            imgui.pushItemWidth(pixi.state.settings.explorer_width * pixi.content_scale[0] * 0.5);

            _ = imgui.checkbox(
                "Dropper Auto-switch",
                &pixi.state.settings.eyedropper_auto_switch_layer,
            );

            imgui.separator();

            imgui.text("Reference Window Opacity");
            _ = imgui.sliderFloatEx("##reference_window_opacity", &pixi.state.settings.reference_window_opacity, 0.0, 100.0, "%.0f", imgui.SliderFlags_AlwaysClamp);

            imgui.separator();

            if (imgui.beginCombo("Compatibility", if (pixi.state.settings.compatibility == .none) "None" else "LDtk", imgui.ComboFlags_None)) {
                defer imgui.endCombo();

                if (imgui.selectable("None")) pixi.state.settings.compatibility = .none;
                if (imgui.selectable("LDtk")) pixi.state.settings.compatibility = .ldtk;
            }

            imgui.popItemWidth();
        }

        if (imgui.collapsingHeader(pixi.fa.paint_roller ++ "  Style", imgui.TreeNodeFlags_None)) {
            imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 3.0 * pixi.content_scale[0], .y = 3.0 * pixi.content_scale[1] });
            imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 4.0 * pixi.content_scale[1], .y = 4.0 * pixi.content_scale[1] });
            defer imgui.popStyleVarEx(2);

            imgui.pushStyleColorImVec4(imgui.Col_Button, pixi.state.theme.highlight_secondary.toImguiVec4());
            defer imgui.popStyleColor();

            imgui.pushItemWidth(imgui.getWindowWidth() * 0.7);
            if (imgui.beginCombo("Theme", pixi.state.settings.theme, imgui.ComboFlags_None)) {
                defer imgui.endCombo();
                searchThemes() catch unreachable;
            }
            imgui.separator();

            _ = pixi.editor.Theme.styleColorEdit("Background", .{ .col = &pixi.state.theme.background });
            _ = pixi.editor.Theme.styleColorEdit("Foreground", .{ .col = &pixi.state.theme.foreground });
            _ = pixi.editor.Theme.styleColorEdit("Text", .{ .col = &pixi.state.theme.text });
            _ = pixi.editor.Theme.styleColorEdit("Secondary Text", .{ .col = &pixi.state.theme.text_secondary });
            _ = pixi.editor.Theme.styleColorEdit("Background Text", .{ .col = &pixi.state.theme.text_background });
            _ = pixi.editor.Theme.styleColorEdit("Primary Highlight", .{ .col = &pixi.state.theme.highlight_primary });
            _ = pixi.editor.Theme.styleColorEdit("Secondary Highlight", .{ .col = &pixi.state.theme.highlight_secondary });
            _ = pixi.editor.Theme.styleColorEdit("Primary Hover", .{ .col = &pixi.state.theme.hover_primary });
            _ = pixi.editor.Theme.styleColorEdit("Secondary Hover", .{ .col = &pixi.state.theme.hover_secondary });

            imgui.spacing();

            if (imgui.buttonEx("Save As...", .{ .x = imgui.getWindowWidth() - pixi.state.settings.explorer_grip * pixi.content_scale[0], .y = 0.0 })) {
                pixi.state.popups.file_dialog_request = .{
                    .state = .save,
                    .type = .export_theme,
                    .filter = "json",
                    .initial = pixi.assets.themes,
                };
            }

            if (pixi.state.popups.file_dialog_response) |response| {
                if (response.type == .export_theme) {
                    pixi.state.theme.save(response.path) catch unreachable;
                    pixi.state.allocator.free(pixi.state.theme.name);
                    pixi.state.theme = pixi.editor.Theme.loadFromFile(response.path) catch unreachable;
                    pixi.state.settings.theme = pixi.state.theme.name;
                }
                nfd.freePath(response.path);
                pixi.state.popups.file_dialog_response = null;
            }

            imgui.popItemWidth();
        }

        imgui.spacing();
        imgui.separator();
        imgui.textColored(pixi.state.theme.text_background.toImguiVec4(), "Framerate: %d", core.frame.rate);

        imgui.popItemWidth();
    }
}

fn searchThemes() !void {
    var dir_opt = std.fs.cwd().openDir(pixi.assets.themes, .{ .access_sub_paths = false, .iterate = true }) catch null;
    if (dir_opt) |*dir| {
        defer dir.close();
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file) {
                const ext = std.fs.path.extension(entry.name);
                if (std.mem.eql(u8, ext, ".json")) {
                    const label = try std.fmt.allocPrintZ(pixi.state.allocator, "{s}", .{entry.name});
                    defer pixi.state.allocator.free(label);
                    if (imgui.selectable(label)) {
                        const abs_path = try std.fs.path.joinZ(pixi.state.allocator, &.{ pixi.assets.themes, entry.name });
                        defer pixi.state.allocator.free(abs_path);
                        pixi.state.allocator.free(pixi.state.theme.name);
                        pixi.state.theme = try pixi.editor.Theme.loadFromFile(abs_path);
                        pixi.state.settings.theme = pixi.state.theme.name;
                    }
                }
            }
        }
    }
}
