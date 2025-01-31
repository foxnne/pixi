const builtin = @import("builtin");
const pixi = @import("../pixi.zig");
const std = @import("std");

const Settings = @This();

pub var parsed: ?std.json.Parsed(Settings) = null;

pub const InputScheme = enum { mouse, trackpad };
pub const FlipbookView = enum { sequential, grid };
pub const Compatibility = enum { none, ldtk };

/// Width of the explorer bar.
explorer_width: f32 = 200.0,

/// Width of the explorer grip.
explorer_grip: f32 = 18.0,

/// Whether or not the artboard is split
split_artboard: bool = false,

/// The horizontal ratio of the artboard split
split_artboard_ratio: f32 = 0.5,

/// Alignment of explorer separator titles
explorer_title_align: f32 = 0.0,

/// Height of the flipbook window.
flipbook_height: f32 = 0.3,

/// Flipbook view, sequential or grid
flipbook_view: FlipbookView = .sequential,

/// Font size set when loading the editor.
font_size: f32 = 13.0,

/// Height of the infobar.
info_bar_height: f32 = 24.0,

/// When a new window is opened, describes the height of the window.
initial_window_height: u32 = 720,

/// When a new window is opened, describes the width of the window.
initial_window_width: u32 = 1280,

/// Which control scheme to use for zooming and panning.
/// TODO: Remove builtin check and offer a setup menu if settings.json doesn't exist.
input_scheme: InputScheme = if (builtin.os.tag == .macos) .trackpad else .mouse,

/// Sensitivity when panning via scrolling with trackpad.
pan_sensitivity: f32 = 15.0,

/// Whether or not to show rulers on the canvas.
show_rulers: bool = true,

/// Width of the sidebar.
sidebar_width: f32 = 50,

/// Height of the sprite edit panel
sprite_edit_height: f32 = 100,

/// Height of the animation edit panel
animation_edit_height: f32 = 100,

/// Maximum zoom sensitivity applied at last zoom steps.
zoom_max_sensitivity: f32 = 1.0,

/// Minimum zoom sensitivity applied at first zoom steps.
zoom_min_sensitivity: f32 = 0.1,

/// Setting to control overall zoom sensitivity
zoom_sensitivity: f32 = 100.0,

/// Predetermined zoom steps, each is pixel perfect.
zoom_steps: [21]f32 = [_]f32{ 0.125, 0.167, 0.2, 0.25, 0.333, 0.5, 1, 2, 3, 4, 5, 6, 8, 12, 18, 28, 38, 50, 70, 90, 128 },

/// Amount of time it takes for the zoom correction.
zoom_time: f32 = 0.2,

/// Amount of time after zooming that the tooltip hangs around.
zoom_tooltip_time: f32 = 0.6,

/// Amount of time before zoom is corrected, increase if fighting while zooming slowly.
zoom_wait_time: f32 = 0.1,

/// Maximum file size
max_file_size: [2]i32 = .{ 4096, 4096 },

/// Maximum number of recents before removing oldest
max_recents: usize = 10,

/// Automatically switch layers when using eyedropper tool
eyedropper_auto_switch_layer: bool = true,

/// Width and height of the eyedropper preview
eyedropper_preview_size: f32 = 64.0,

/// Drop shadow opacity (shows between artboard and flipbook)
shadow_opacity: f32 = 0.1,

/// Drop shadow length (shows between artboard and flipbook)
shadow_length: f32 = 14.0,

/// Stroke max size
stroke_max_size: i32 = 64,

/// Hue shift for suggested
suggested_hue_shift: f32 = 0.25,

/// Saturation shift for suggested colors
suggested_sat_shift: f32 = 0.65,

/// Lightness shift for suggested colors
suggested_lit_shift: f32 = 0.75,

/// Opacity of the reference window background
reference_window_opacity: f32 = 50.0,

/// Currently applied theme name
theme: [:0]const u8,

/// Temporary switch to allow ctrl on macos for zoom
zoom_ctrl: bool = false,

/// Setting to generate a compatiblity layer between pixi and level editors
compatibility: Compatibility = .none,

/// Radius of the color chips in palettes and suggested colors
color_chip_radius: f32 = 12.0,

/// Loads settings or if fails, returns default settings
pub fn loadOrDefault(allocator: std.mem.Allocator) !Settings {
    const data = try pixi.fs.read(allocator, "settings.json");
    defer allocator.free(data);

    const options = std.json.ParseOptions{ .duplicate_field_behavior = .use_first, .ignore_unknown_fields = true };
    if (std.json.parseFromSlice(Settings, allocator, data, options) catch null) |p| {
        parsed = p;
        return p.value;
    }

    return .{
        .theme = try allocator.dupeZ(u8, "pixi_dark.json"),
    };
}

pub fn save(settings: *Settings, allocator: std.mem.Allocator) !void {
    const str = try std.json.stringifyAlloc(allocator, settings, .{});
    defer allocator.free(str);

    var file = try std.fs.cwd().createFile("settings.json", .{});
    defer file.close();

    try file.writeAll(str);
}

pub fn deinit(settings: *Settings, allocator: std.mem.Allocator) void {
    defer parsed = null;
    if (parsed) |p| p.deinit() else allocator.free(settings.theme);
}
