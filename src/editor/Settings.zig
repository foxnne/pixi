const builtin = @import("builtin");
const pixi = @import("../pixi.zig");
const std = @import("std");

const Settings = @This();

pub var parsed: ?std.json.Parsed(Settings) = null;

pub const InputScheme = enum { mouse, trackpad };
pub const FlipbookView = enum { sequential, grid };
pub const Compatibility = enum { none, ldtk };

/// The ratio of the explorer to the artboard.
explorer_ratio: f32 = 0.35,

/// Height of the flipbook window.
panel_ratio: f32 = 0.25,

min_window_size: [2]f32 = .{ 640, 480 },

initial_window_size: [2]f32 = .{ 1280, 720 },

/// Minimum FPS for animations.
min_animation_fps: f32 = 0.001,

/// Maximum FPS for animations.
max_animation_fps: f32 = 240.0,

/// Which control scheme to use for zooming and panning.
/// TODO: Remove builtin check and offer a setup menu if settings.json doesn't exist.
input_scheme: InputScheme = if (builtin.os.tag == .macos) .trackpad else .mouse,

/// Whether or not to show rulers on each canvas.
show_rulers: bool = true,

/// Padding to include in the size of the ruler outside of the font height.
ruler_padding: f32 = 4.0,

/// Setting to control overall zoom sensitivity
/// 0 - 1
zoom_sensitivity: f32 = 1.0,

/// Predetermined zoom steps, each is pixel perfect.
zoom_steps: [23]f32 = [_]f32{ 0.125, 0.167, 0.2, 0.25, 0.333, 0.5, 1, 2, 3, 4, 5, 6, 8, 12, 18, 28, 38, 50, 70, 90, 128, 256, 512 },

/// Maximum file size
max_file_size: [2]i32 = .{ 4096, 4096 },

/// Maximum number of recents before removing oldest
max_recents: usize = 10,

/// Currently applied theme name
theme: []const u8,

/// Color for the even squares of the checkerboard pattern
checker_color_even: [4]u8 = .{ 255, 255, 255, 255 },
/// Color for the odd squares of the checkerboard pattern
checker_color_odd: [4]u8 = .{ 175, 175, 175, 255 },

/// Opacity of the background window
/// CURRENTLY ONLY SUPPORTED ON MACOS
window_opacity: f32 = 0.95,

/// Loads settings or if fails, returns default settings
pub fn load(allocator: std.mem.Allocator, path: []const u8) !Settings {
    if (pixi.fs.read(allocator, path) catch null) |data| {
        defer allocator.free(data);

        const options = std.json.ParseOptions{
            .duplicate_field_behavior = .use_first,
            .ignore_unknown_fields = true,
        };
        if (std.json.parseFromSlice(Settings, allocator, data, options) catch null) |p| {
            parsed = p;
            return p.value;
        }
    }

    return .{
        .theme = try allocator.dupe(u8, "pixi_dark.json"),
    };
}

pub fn save(settings: *Settings, allocator: std.mem.Allocator, path: []const u8) !void {
    const str = try std.json.Stringify.valueAlloc(allocator, settings, .{});
    defer allocator.free(str);

    var file = try std.fs.createFileAbsolute(path, .{});
    defer file.close();

    try file.writeAll(str);
}

pub fn deinit(settings: *Settings, allocator: std.mem.Allocator) void {
    defer parsed = null;
    if (parsed) |p| p.deinit() else allocator.free(settings.theme);
}
