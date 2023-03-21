const builtin = @import("builtin");
const pixi = @import("pixi");

/// Width of the explorer bar.
explorer_width: f32 = 200,

/// Height of the flipbook window.
flipbook_height: f32 = 0.3,

/// Font size set when loading the editor.
font_size: f32 = 13,

/// Height of the infobar.
info_bar_height: f32 = 24,

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

/// Maximum zoom sensitivity applied at last zoom steps.
zoom_max_sensitivity: f32 = 1.0,

/// Minimum zoom sensitivity applied at first zoom steps.
zoom_min_sensitivity: f32 = 0.1,

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

pub const InputScheme = enum { mouse, trackpad };
