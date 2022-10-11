const std = @import("std");
const builtin = @import("builtin");
const zgui = @import("zgui");
const pixi = @import("pixi");
const Color = pixi.math.Color;

background: Color = Color.initBytes(30, 31, 39, 255),
foreground: Color = Color.initBytes(42, 44, 54, 255),
text: Color = Color.initBytes(230, 175, 137, 255),
text_secondary: Color = Color.initBytes(138, 138, 147, 255),

highlight_primary: Color = Color.initBytes(47, 179, 135, 255),
hover_primary: Color = Color.initBytes(76, 148, 123, 255),

highlight_secondary: Color = Color.initBytes(76, 48, 67, 255),
hover_secondary: Color = Color.initBytes(105, 50, 68, 255),

pub fn set(self: @This()) void {
    const bg = self.background.toSlice();
    const fg = self.foreground.toSlice();
    const text = self.text.toSlice();
    const highlight_primary = self.highlight_primary.toSlice();
    const hover_primary = self.hover_primary.toSlice();
    const highlight_secondary = self.highlight_secondary.toSlice();
    const hover_secondary = self.hover_secondary.toSlice();

    var style = zgui.getStyle();
    style.window_border_size = 1.0;
    if (builtin.os.tag != .windows) {
        style.window_rounding = 8.0;
        style.popup_rounding = 8.0;
        style.tab_rounding = 8.0;
        style.frame_rounding = 8.0;
        style.grab_rounding = 4.0;
    }
    style.frame_padding = .{ 24.0, 8.0 };
    style.window_padding = .{ 10.0, 10.0 };
    style.item_spacing = .{ 14.0, 8.0 };
    style.item_inner_spacing = .{ 6.0, 4.0 };
    style.window_min_size = .{ 100.0, 100.0 };
    style.window_menu_button_position = .none;
    style.window_title_align = .{ 0.5, 0.5 };
    style.grab_min_size = 6.5 * pixi.state.window.scale[0];
    style.setColor(zgui.StyleCol.window_bg, bg);
    style.setColor(zgui.StyleCol.border, fg);
    style.setColor(zgui.StyleCol.menu_bar_bg, fg);
    style.setColor(zgui.StyleCol.separator, fg);
    style.setColor(zgui.StyleCol.title_bg, bg);
    style.setColor(zgui.StyleCol.title_bg_active, fg);
    style.setColor(zgui.StyleCol.tab, bg);
    style.setColor(zgui.StyleCol.tab_unfocused, bg);
    style.setColor(zgui.StyleCol.tab_unfocused_active, bg);
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
}
