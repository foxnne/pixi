const std = @import("std");
const builtin = @import("builtin");
const core = @import("mach-core");
const pixi = @import("../pixi.zig");
const Color = pixi.math.Color;

const imgui = @import("zig-imgui");

const Self = @This();

name: [:0]const u8,

background: Color = Color.initBytes(34, 35, 42, 255),
foreground: Color = Color.initBytes(42, 44, 54, 255),
text: Color = Color.initBytes(230, 175, 137, 255),
text_secondary: Color = Color.initBytes(159, 159, 176, 255),
text_background: Color = Color.initBytes(97, 97, 106, 255),

text_blue: Color = Color.initBytes(110, 150, 200, 255),
text_orange: Color = Color.initBytes(183, 113, 96, 255),
text_yellow: Color = Color.initBytes(214, 199, 130, 255),
text_red: Color = Color.initBytes(206, 120, 105, 255),

highlight_primary: Color = Color.initBytes(47, 179, 135, 255),
hover_primary: Color = Color.initBytes(76, 148, 123, 255),

highlight_secondary: Color = Color.initBytes(76, 48, 67, 255),
hover_secondary: Color = Color.initBytes(105, 50, 68, 255),

checkerboard_primary: Color = Color.initBytes(150, 150, 150, 255),
checkerboard_secondary: Color = Color.initBytes(100, 100, 100, 255),

modal_dim: Color = Color.initBytes(0, 0, 0, 48),

pub fn init(self: Self) void {
    var style = imgui.getStyle();
    style.window_border_size = 1.0;
    style.window_rounding = 8.0;
    style.popup_rounding = 8.0;
    style.tab_rounding = 8.0;
    style.frame_rounding = 8.0;
    style.grab_rounding = 4.0;
    style.frame_padding = .{ .x = 12.0, .y = 8.0 };
    style.window_padding = .{ .x = 5.0, .y = 5.0 };
    style.item_spacing = .{ .x = 4.0, .y = 4.0 };
    style.item_inner_spacing = .{ .x = 3.0, .y = 3.0 };
    style.window_menu_button_position = 0;
    style.window_title_align = .{ .x = 0.5, .y = 0.5 };
    style.grab_min_size = 6.5;
    style.scrollbar_size = 12;
    style.frame_padding = .{ .x = 4.0, .y = 4.0 };
    style.frame_border_size = 1.0;
    style.hover_stationary_delay = 0.35;
    style.hover_delay_normal = 0.5;
    style.hover_delay_short = 0.25;
    style.popup_rounding = 8.0;
    style.separator_text_align = .{ .x = pixi.state.settings.explorer_title_align, .y = 0.5 };
    style.separator_text_border_size = 1.0;
    style.separator_text_padding = .{ .x = 20.0, .y = 10.0 };

    const bg = self.background.toImguiVec4();
    const fg = self.foreground.toImguiVec4();
    const text = self.text.toImguiVec4();
    const bg_text = self.text_background.toImguiVec4();
    const highlight_primary = self.highlight_primary.toImguiVec4();
    const hover_primary = self.hover_primary.toImguiVec4();
    const highlight_secondary = self.highlight_secondary.toImguiVec4();
    const hover_secondary = self.hover_secondary.toImguiVec4();
    const modal_dim = self.modal_dim.toImguiVec4();

    style.colors[imgui.Col_WindowBg] = bg;
    style.colors[imgui.Col_Border] = fg;
    style.colors[imgui.Col_MenuBarBg] = fg;
    style.colors[imgui.Col_Separator] = bg_text;
    style.colors[imgui.Col_TitleBg] = fg;
    style.colors[imgui.Col_TitleBgActive] = fg;
    style.colors[imgui.Col_Tab] = fg;
    style.colors[imgui.Col_TabUnfocused] = fg;
    style.colors[imgui.Col_TabUnfocusedActive] = fg;
    style.colors[imgui.Col_TabActive] = fg;
    style.colors[imgui.Col_TabHovered] = fg;
    style.colors[imgui.Col_PopupBg] = bg;
    style.colors[imgui.Col_FrameBg] = bg;
    style.colors[imgui.Col_FrameBgHovered] = bg;
    style.colors[imgui.Col_Text] = text;
    style.colors[imgui.Col_ResizeGrip] = highlight_primary;
    style.colors[imgui.Col_ScrollbarGrabActive] = highlight_primary;
    style.colors[imgui.Col_ScrollbarGrabHovered] = hover_primary;
    style.colors[imgui.Col_ScrollbarBg] = bg;
    style.colors[imgui.Col_ScrollbarGrab] = fg;
    style.colors[imgui.Col_Header] = highlight_secondary;
    style.colors[imgui.Col_HeaderHovered] = hover_secondary;
    style.colors[imgui.Col_HeaderActive] = highlight_secondary;
    style.colors[imgui.Col_Button] = fg;
    style.colors[imgui.Col_ButtonHovered] = hover_secondary;
    style.colors[imgui.Col_ButtonActive] = highlight_secondary;
    style.colors[imgui.Col_ModalWindowDimBg] = modal_dim;
}

pub fn set(self: *Self) void {
    const bg = self.background.toImguiVec4();
    const fg = self.foreground.toImguiVec4();
    const text = self.text.toImguiVec4();
    const bg_text = self.text_background.toImguiVec4();
    const highlight_primary = self.highlight_primary.toImguiVec4();
    const hover_primary = self.hover_primary.toImguiVec4();
    const highlight_secondary = self.highlight_secondary.toImguiVec4();
    const hover_secondary = self.hover_secondary.toImguiVec4();
    const modal_dim = self.modal_dim.toImguiVec4();

    imgui.pushStyleColorImVec4(imgui.Col_WindowBg, bg);
    imgui.pushStyleColorImVec4(imgui.Col_Border, fg);
    imgui.pushStyleColorImVec4(imgui.Col_MenuBarBg, fg);
    imgui.pushStyleColorImVec4(imgui.Col_Separator, bg_text);
    imgui.pushStyleColorImVec4(imgui.Col_TitleBg, fg);
    imgui.pushStyleColorImVec4(imgui.Col_TitleBgActive, fg);
    imgui.pushStyleColorImVec4(imgui.Col_Tab, bg);
    imgui.pushStyleColorImVec4(imgui.Col_TabUnfocused, bg);
    imgui.pushStyleColorImVec4(imgui.Col_TabUnfocusedActive, fg);
    imgui.pushStyleColorImVec4(imgui.Col_TabActive, fg);
    imgui.pushStyleColorImVec4(imgui.Col_TabHovered, fg);
    imgui.pushStyleColorImVec4(imgui.Col_PopupBg, bg);
    imgui.pushStyleColorImVec4(imgui.Col_FrameBg, bg);
    imgui.pushStyleColorImVec4(imgui.Col_FrameBgHovered, bg);
    imgui.pushStyleColorImVec4(imgui.Col_Text, text);
    imgui.pushStyleColorImVec4(imgui.Col_ResizeGrip, highlight_primary);
    imgui.pushStyleColorImVec4(imgui.Col_ScrollbarGrabActive, highlight_primary);
    imgui.pushStyleColorImVec4(imgui.Col_ScrollbarGrabHovered, hover_primary);
    imgui.pushStyleColorImVec4(imgui.Col_ScrollbarBg, bg);
    imgui.pushStyleColorImVec4(imgui.Col_ScrollbarGrab, fg);
    imgui.pushStyleColorImVec4(imgui.Col_Header, highlight_secondary);
    imgui.pushStyleColorImVec4(imgui.Col_HeaderHovered, hover_secondary);
    imgui.pushStyleColorImVec4(imgui.Col_HeaderActive, highlight_secondary);
    imgui.pushStyleColorImVec4(imgui.Col_Button, fg);
    imgui.pushStyleColorImVec4(imgui.Col_ButtonHovered, hover_secondary);
    imgui.pushStyleColorImVec4(imgui.Col_ButtonActive, highlight_secondary);
    imgui.pushStyleColorImVec4(imgui.Col_ModalWindowDimBg, modal_dim);
}

pub fn loadFromFile(file: [:0]const u8) !Self {
    const base_name = std.fs.path.basename(file);
    const ext = std.fs.path.extension(file);

    if (std.mem.eql(u8, ext, ".json")) {
        var read_opt: ?[]const u8 = pixi.fs.read(pixi.state.allocator, file) catch null;
        if (read_opt) |read| {
            defer pixi.state.allocator.free(read);

            const options = std.json.ParseOptions{ .duplicate_field_behavior = .use_first, .ignore_unknown_fields = true };
            const parsed = try std.json.parseFromSlice(Self, pixi.state.allocator, read, options);
            defer parsed.deinit();

            var out = parsed.value;
            out.name = try pixi.state.allocator.dupeZ(u8, base_name);
            return out;
        }
    }
    return Self{
        .name = try pixi.state.allocator.dupeZ(u8, "pixi_dark.json"),
    };
}

pub fn save(self: Self, path: [:0]const u8) !void {
    var handle = try std.fs.cwd().createFile(path, .{});
    defer handle.close();

    const out_stream = handle.writer();
    const options = std.json.StringifyOptions{};

    try std.json.stringify(self, options, out_stream);
}

pub fn unset(self: Self) void {
    _ = self;
    imgui.popStyleColorEx(27);
}

pub const StyleColorButton = struct {
    col: *Color,
    flags: imgui.ColorEditFlags = 0,
    w: f32 = 0.0,
    h: f32 = 0.0,
};

pub fn styleColorEdit(desc_id: [:0]const u8, args: StyleColorButton) bool {
    var c = args.col.toImguiVec4();
    var c_slice = args.col.toSlice();
    if (imgui.colorButton(
        desc_id,
        c,
        imgui.ColorEditFlags_None,
    )) {
        return true;
    }
    if (imgui.beginPopupContextItem()) {
        defer imgui.endPopup();
        imgui.pushStyleColorImVec4(imgui.Col_Text, .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 });
        if (imgui.colorPicker4(desc_id, &c_slice, imgui.ColorEditFlags_None, null)) {
            args.col.value[0] = c_slice[0];
            args.col.value[1] = c_slice[1];
            args.col.value[2] = c_slice[2];
            args.col.value[3] = c_slice[3];
        }
        imgui.popStyleColorEx(1);
    }
    imgui.sameLine();
    imgui.text(desc_id);
    return false;
}
