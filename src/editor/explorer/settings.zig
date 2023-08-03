const std = @import("std");
const pixi = @import("../../pixi.zig");
const mach = @import("core");
const zgui = @import("zgui").MachImgui(mach);

pub fn draw() void {
    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 8.0 * pixi.content_scale[1], 8.0 * pixi.content_scale[1] } });
    defer zgui.popStyleVar(.{ .count = 1 });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.header, .c = pixi.state.theme.highlight_secondary.toSlice() });
    defer zgui.popStyleColor(.{ .count = 1 });

    if (zgui.collapsingHeader(zgui.formatZ("{s}  {s}", .{ pixi.fa.mouse, "Input" }), .{})) {
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 3.0 * pixi.content_scale[0], 3.0 * pixi.content_scale[1] } });
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 4.0 * pixi.content_scale[1], 4.0 * pixi.content_scale[1] } });
        defer zgui.popStyleVar(.{ .count = 2 });

        zgui.setNextItemWidth(pixi.state.settings.explorer_width * pixi.content_scale[0] * 0.5);
        if (zgui.beginCombo("Scheme", .{ .preview_value = @tagName(pixi.state.settings.input_scheme) })) {
            defer zgui.endCombo();
            if (zgui.selectable("mouse", .{})) {
                pixi.state.settings.input_scheme = .mouse;
            }
            if (zgui.selectable("trackpad", .{})) {
                pixi.state.settings.input_scheme = .trackpad;
            }
        }

        zgui.setNextItemWidth(pixi.state.settings.explorer_width * pixi.content_scale[0] * 0.3);
        _ = zgui.sliderFloat("Pan Sensitivity", .{
            .v = &pixi.state.settings.pan_sensitivity,
            .min = 1.0,
            .max = 25.0,
            .cfmt = "%.0f",
        });
    }

    if (zgui.collapsingHeader(zgui.formatZ("{s}  {s}", .{ pixi.fa.th_list, "Layout" }), .{})) {
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 3.0 * pixi.content_scale[0], 3.0 * pixi.content_scale[1] } });
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 4.0 * pixi.content_scale[1], 4.0 * pixi.content_scale[1] } });
        defer zgui.popStyleVar(.{ .count = 2 });

        zgui.setNextItemWidth(pixi.state.settings.explorer_width * pixi.content_scale[0] * 0.5);
        _ = zgui.sliderFloat("Explorer Width", .{
            .v = &pixi.state.settings.explorer_width,
            .min = 100,
            .max = 400,
            .cfmt = "%.0f",
        });

        zgui.setNextItemWidth(pixi.state.settings.explorer_width * pixi.content_scale[0] * 0.5);
        _ = zgui.sliderFloat("Info Height", .{
            .v = &pixi.state.settings.info_bar_height,
            .min = 18,
            .max = 36,
            .cfmt = "%.0f",
        });

        zgui.setNextItemWidth(pixi.state.settings.explorer_width * pixi.content_scale[0] * 0.5);
        _ = zgui.sliderFloat("Sidebar Width", .{
            .v = &pixi.state.settings.sidebar_width,
            .min = 25,
            .max = 75,
            .cfmt = "%.0f",
        });

        _ = zgui.checkbox("Show Rulers", .{
            .v = &pixi.state.settings.show_rulers,
        });
    }

    if (zgui.collapsingHeader(zgui.formatZ("{s}  {s}", .{ pixi.fa.paint_roller, "Style" }), .{})) {
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 3.0 * pixi.content_scale[0], 3.0 * pixi.content_scale[1] } });
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 4.0 * pixi.content_scale[1], 4.0 * pixi.content_scale[1] } });
        defer zgui.popStyleVar(.{ .count = 2 });

        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button, .c = pixi.state.theme.highlight_secondary.toSlice() });
        defer zgui.popStyleColor(.{ .count = 1 });

        if (zgui.beginCombo("Theme", .{ .preview_value = pixi.state.theme.name })) {
            defer zgui.endCombo();
            for (pixi.state.themes.themes.items) |theme| {
                if (zgui.selectable(theme.name, .{})) {
                    pixi.state.theme = theme;
                }
            }
        }
        zgui.separator();

        zgui.pushItemWidth(pixi.state.settings.explorer_width * pixi.content_scale[0] * 0.5);
        _ = pixi.editor.Theme.styleColorEdit("Background", .{ .col = &pixi.state.theme.background });
        _ = pixi.editor.Theme.styleColorEdit("Foreground", .{ .col = &pixi.state.theme.foreground });
        _ = pixi.editor.Theme.styleColorEdit("Text", .{ .col = &pixi.state.theme.text });
        _ = pixi.editor.Theme.styleColorEdit("Secondary Text", .{ .col = &pixi.state.theme.text_secondary });
        _ = pixi.editor.Theme.styleColorEdit("Background Text", .{ .col = &pixi.state.theme.text_background });
        _ = pixi.editor.Theme.styleColorEdit("Primary Highlight", .{ .col = &pixi.state.theme.highlight_primary });
        _ = pixi.editor.Theme.styleColorEdit("Secondary Highlight", .{ .col = &pixi.state.theme.highlight_secondary });
        _ = pixi.editor.Theme.styleColorEdit("Primary Hover", .{ .col = &pixi.state.theme.hover_primary });
        _ = pixi.editor.Theme.styleColorEdit("Secondary Hover", .{ .col = &pixi.state.theme.hover_secondary });

        zgui.separator();
        if (zgui.button("Save", .{})) {
            pixi.state.theme.save() catch unreachable;
            pixi.state.themes.deinit();
            pixi.state.themes = pixi.Themes.load() catch unreachable;
        }
        zgui.sameLine(.{});
        if (zgui.button("Save As...", .{})) {}

        zgui.popItemWidth();
    }
}
