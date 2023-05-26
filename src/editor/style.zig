const std = @import("std");
const builtin = @import("builtin");
const zgui = @import("zgui");
const pixi = @import("root");
const Color = pixi.math.Color;

background: Color = Color.initBytes(30, 31, 39, 255),
foreground: Color = Color.initBytes(42, 44, 54, 255),
text: Color = Color.initBytes(230, 175, 137, 255),
text_secondary: Color = Color.initBytes(138, 138, 147, 255),
text_background: Color = Color.initFloats(0.3, 0.3, 0.35, 1.0),

text_blue: Color = Color.initBytes(110, 150, 200, 255),
text_orange: Color = Color.initBytes(183, 113, 96, 255),
text_yellow: Color = Color.initBytes(214, 199, 130, 255),
text_red: Color = Color.initBytes(206, 120, 105, 255),

highlight_primary: Color = Color.initBytes(47, 179, 135, 255),
hover_primary: Color = Color.initBytes(76, 148, 123, 255),

highlight_secondary: Color = Color.initBytes(76, 48, 67, 255),
hover_secondary: Color = Color.initBytes(105, 50, 68, 255),

checkerboard_primary: Color = Color.initBytes(150, 150, 150, 255),
checkerboard_secondary: Color = Color.initBytes(55, 55, 55, 255),

modal_dim: Color = Color.initBytes(0, 0, 0, 48),

pub fn set(self: @This()) void {
    const bg = self.background.toSlice();
    const fg = self.foreground.toSlice();
    const text = self.text.toSlice();
    const highlight_primary = self.highlight_primary.toSlice();
    const hover_primary = self.hover_primary.toSlice();
    const highlight_secondary = self.highlight_secondary.toSlice();
    const hover_secondary = self.hover_secondary.toSlice();
    const modal_dim = self.modal_dim.toSlice();

    var style = zgui.getStyle();
    style.window_border_size = 1.0;
    style.window_rounding = 8.0;
    style.popup_rounding = 8.0;
    style.tab_rounding = 8.0;
    style.frame_rounding = 8.0;
    style.grab_rounding = 4.0;
    style.frame_padding = .{ 12.0, 4.0 };
    style.window_padding = .{ 5.0, 5.0 };
    style.item_spacing = .{ 7.0, 4.0 };
    style.item_inner_spacing = .{ 3.0, 3.0 };
    style.window_menu_button_position = .none;
    style.window_title_align = .{ 0.5, 0.5 };
    style.grab_min_size = 6.5;
    style.scrollbar_size = 12;
    style.frame_padding = .{ 4.0, 4.0 };
    style.frame_border_size = 1.0;
    style.scaleAllSizes(std.math.max(pixi.state.window.scale[0], pixi.state.window.scale[1]));
    style.setColor(zgui.StyleCol.window_bg, bg);
    style.setColor(zgui.StyleCol.border, fg);
    style.setColor(zgui.StyleCol.menu_bar_bg, fg);
    style.setColor(zgui.StyleCol.separator, fg);
    style.setColor(zgui.StyleCol.title_bg, fg);
    style.setColor(zgui.StyleCol.title_bg_active, fg);
    style.setColor(zgui.StyleCol.tab, bg);
    style.setColor(zgui.StyleCol.tab_unfocused, bg);
    style.setColor(zgui.StyleCol.tab_unfocused_active, fg);
    style.setColor(zgui.StyleCol.tab_active, fg);
    style.setColor(zgui.StyleCol.tab_hovered, fg);
    style.setColor(zgui.StyleCol.popup_bg, bg);
    style.setColor(zgui.StyleCol.text, text);
    style.setColor(zgui.StyleCol.resize_grip, highlight_primary);
    style.setColor(zgui.StyleCol.scrollbar_grab_active, highlight_primary);
    style.setColor(zgui.StyleCol.scrollbar_grab_hovered, hover_primary);
    style.setColor(zgui.StyleCol.scrollbar_bg, bg);
    style.setColor(zgui.StyleCol.scrollbar_grab, fg);
    style.setColor(zgui.StyleCol.header, highlight_secondary);
    style.setColor(zgui.StyleCol.header_hovered, hover_secondary);
    style.setColor(zgui.StyleCol.header_active, highlight_secondary);
    style.setColor(zgui.StyleCol.button, fg);
    style.setColor(zgui.StyleCol.button_hovered, hover_secondary);
    style.setColor(zgui.StyleCol.button_active, highlight_secondary);
    style.setColor(zgui.StyleCol.modal_window_dim_bg, modal_dim);
}
