const builtin = @import("builtin");
const pixi = @import("root");
const std = @import("std");

pub const settings_filename = "pixi-settings.json";

//get the path to the settings file
fn getSettingsPath(a: std.mem.Allocator) ![]const u8 {

    //get the cwd
    const cwd = try std.fs.selfExeDirPathAlloc(a);
    defer a.free(cwd);
    const path = try std.fmt.allocPrint(a, "{s}/{s}", .{ cwd, settings_filename });
    return path;
}

///Reads in default settings or reads from the settings file
pub fn init(a: std.mem.Allocator) !@This() {
    const path = try getSettingsPath(a);
    defer a.free(path);

    //attempt to read the file
    const max_bytes = 10000; //maximum bytes in settings file
    const settings_string = std.fs.cwd().readFileAlloc(a, path, max_bytes) catch null;

    //check if the file was read, and if so, parse it
    if (settings_string) |str| {
        defer a.free(settings_string.?);

        const parsed_settings = std.json.parseFromSlice(@This(), a, str, .{}) catch null;
        if (parsed_settings) |settings| {
            return settings.value;
        }
    }

    //return default if parsing failed or file does not exist
    return @This(){};
}

///saves the current settings to a file and deinitializes the memory
pub fn deinit(self: *@This(), a: std.mem.Allocator) void {
    //NOTE, this doesn't actually free any memory for the settings struct.
    //
    //This is because we need to maintain a copy of std.json.parsed(@This()) in order to properly
    //Deinitialize the memory via `parsed.deinit()`
    //
    //attempting to do `a.free(self)` will result in an error
    //
    //Alternatively, we could use an arena allocator to initialize the memory in the Init() method, which will allow use to more easily free it
    //
    //Either way, properly freeing this memory will involve changing things outside of the settings file which I will leave the best course of action
    //a decision for the core maintainers

    const path = getSettingsPath(a) catch {
        std.debug.print("memory allocation error when saving settings", .{});
        return;
    };
    defer a.free(path);
    const stringified = std.json.stringifyAlloc(a, self, .{}) catch {
        std.debug.print("failed to stringify settings", .{});
        return;
    };
    defer a.free(stringified);
    var file = std.fs.createFileAbsolute(path, .{}) catch {
        std.debug.print("failed to open settings file", .{});
        return;
    };
    file.writeAll(stringified) catch {
        std.debug.print("failed to save settings", .{});
        return;
    };
}

/// Width of the explorer bar.
explorer_width: f32 = 200.0,

/// Width of the explorer grip.
explorer_grip: f32 = 18.0,

/// Height of the flipbook window.
flipbook_height: f32 = 0.3,

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

pub const InputScheme = enum { mouse, trackpad };
