const builtin = @import("builtin");
const Pixi = @import("../Pixi.zig");
const std = @import("std");

const Settings = @This();

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

/// Drop shadow opacity
shadow_opacity: f32 = 0.1,

/// Shadow length
shadow_length: f32 = 14.0,

/// Stroke
stroke_max_size: i32 = 64,

/// Suggested colors settings
suggested_hue_shift: f32 = 0.25,
suggested_sat_shift: f32 = 0.65,
suggested_lit_shift: f32 = 0.75,

/// Opacity of the reference window background
reference_window_opacity: f32 = 50.0,

/// Currently applied theme name
theme: [:0]const u8,

/// Temporary switch to allow ctrl on macos for zoom
zoom_ctrl: bool = false,

/// Setting to generate a compatiblity layer between pixi and level editors
compatibility: Compatibility = .none,

///Reads in default settings or reads from the settings file
pub fn load(allocator: std.mem.Allocator) !Settings {
    const path = "settings.json";

    // Attempt to read the file
    const max_bytes = 10000; //maximum bytes in settings file
    const settings_string = std.fs.cwd().readFileAlloc(allocator, path, max_bytes) catch null;

    // Check if the file was read, and if so, parse it
    if (settings_string) |str| {
        defer allocator.free(settings_string.?);

        const parsed_settings = std.json.parseFromSlice(@This(), allocator, str, .{}) catch null;
        if (parsed_settings) |settings| {
            // TODO: Fix this, we shouldnt have to allocate the theme name just because we need to free all later
            var s: Settings = settings.value;
            s.theme = try allocator.dupeZ(u8, s.theme);
            return s;
        }
    }
    // Return default if parsing failed or file does not exist
    return @This(){
        .theme = try allocator.dupeZ(u8, "pixi_dark.json"),
    };
}

pub fn save(self: *@This(), allocator: std.mem.Allocator) void {
    const path = "settings.json";
    const stringified = std.json.stringifyAlloc(allocator, self, .{}) catch {
        std.debug.print("ERROR: Failed to stringify settings\n", .{});
        return;
    };
    defer allocator.free(stringified);
    var file = std.fs.cwd().createFile(path, .{}) catch {
        std.debug.print("ERROR: Failed to open settings file \"{s}\"\n", .{path});
        return;
    };
    file.writeAll(stringified) catch {
        std.debug.print("ERROR: Failed to write settings to file \"{s}\"\n", .{path});
        return;
    };
}

pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
    allocator.free(self.theme);
}
