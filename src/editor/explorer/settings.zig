const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("root");

pub fn draw() void {
    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 8.0 * pixi.state.window.scale[1], 8.0 * pixi.state.window.scale[1] } });
    defer zgui.popStyleVar(.{ .count = 1 });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.header, .c = pixi.state.style.highlight_secondary.toSlice() });
    defer zgui.popStyleColor(.{ .count = 1 });

    if (zgui.collapsingHeader(zgui.formatZ("{s}  {s}", .{ pixi.fa.mouse, "Input" }), .{})) {
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 3.0 * pixi.state.window.scale[0], 3.0 * pixi.state.window.scale[1] } });
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 4.0 * pixi.state.window.scale[1], 4.0 * pixi.state.window.scale[1] } });
        defer zgui.popStyleVar(.{ .count = 2 });

        zgui.setNextItemWidth(pixi.state.settings.explorer_width * pixi.state.window.scale[0] * 0.5);
        if (zgui.beginCombo("Scheme", .{ .preview_value = @tagName(pixi.state.settings.input_scheme) })) {
            inline for (@typeInfo(pixi.Settings.InputScheme).Enum.fields, 0..) |f, i| {
                if (zgui.selectable(f.name[0.. :0], .{})) {
                    pixi.state.settings.input_scheme = @intToEnum(pixi.Settings.InputScheme, i);
                    // TODO: Mark settings as dirty to save on close
                }
            }
            zgui.endCombo();
        }

        zgui.setNextItemWidth(pixi.state.settings.explorer_width * pixi.state.window.scale[0] * 0.3);
        _ = zgui.sliderFloat("Pan Sensitivity", .{
            .v = &pixi.state.settings.pan_sensitivity,
            .min = 1.0,
            .max = 25.0,
            .cfmt = "%.0f",
        });
    }

    if (zgui.collapsingHeader(zgui.formatZ("{s}  {s}", .{ pixi.fa.th_list, "Layout" }), .{})) {
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 3.0 * pixi.state.window.scale[0], 3.0 * pixi.state.window.scale[1] } });
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 4.0 * pixi.state.window.scale[1], 4.0 * pixi.state.window.scale[1] } });
        defer zgui.popStyleVar(.{ .count = 2 });

        zgui.setNextItemWidth(pixi.state.settings.explorer_width * pixi.state.window.scale[0] * 0.5);
        _ = zgui.sliderFloat("Explorer Width", .{
            .v = &pixi.state.settings.explorer_width,
            .min = 100,
            .max = 400,
            .cfmt = "%.0f",
        });

        zgui.setNextItemWidth(pixi.state.settings.explorer_width * pixi.state.window.scale[0] * 0.5);
        _ = zgui.sliderFloat("Info Height", .{
            .v = &pixi.state.settings.info_bar_height,
            .min = 18,
            .max = 36,
            .cfmt = "%.0f",
        });

        zgui.setNextItemWidth(pixi.state.settings.explorer_width * pixi.state.window.scale[0] * 0.5);
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
}
