const std = @import("std");
const zm = @import("zmath");

/// The design texture width for render-textures.
pub const design_width: u32 = 1280;

/// The design texture height for render-textures.
pub const design_height: u32 = 720;

/// The design texture size for render-textures as an f32x4.
pub const design_size = zm.f32x4(@intToFloat(f32, design_width), @intToFloat(f32, design_height), 0, 0);

/// The font size used by zgui elements.
pub const zgui_font_size = 13;

pub const sidebar_width = 50;
pub const explorer_width = 200;
pub const info_bar_height = 24;

pub var show_rulers: bool = true;
pub const canvas_buffer: f32 = 100.0;
pub const zoom_min_sensitivity: f32 = 0.1;
pub const zoom_max_sensitivity: f32 = 1.0;
pub const zoom_substeps: f32 = 4.0;
pub const zoom_time: f32 = 0.2;
pub const zoom_tooltip_time: f32 = 0.6;
pub const zoom_steps = [_]f32{ 0.125, 0.167, 0.2, 0.25, 0.333, 0.5, 1, 2, 3, 4, 5, 6, 8, 12, 18, 28, 38, 50, 70, 90, 128 };
