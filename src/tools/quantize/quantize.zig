const std = @import("std");
const median_cut = @import("median-cut.zig");

pub const QuantizerConfig = struct {
    width: usize,
    height: usize,
    use_dithering: bool,
    allocator: std.mem.Allocator,
    ncolors: u16 = 256,
};

/// A single RGB image represented as a list of indices
/// into a color table.
pub const QuantizedImage = struct {
    const Self = @This();
    /// RGBRGBRGB...
    color_table: []u8,
    /// indices into the color table
    image_buffer: []u8,

    pub fn init(color_table: []u8, image_buffer: []u8) Self {
        return .{ .color_table = color_table, .image_buffer = image_buffer };
    }

    pub fn deinit(self: *const Self, allocator: std.mem.Allocator) void {
        allocator.free(self.color_table);
        allocator.free(self.image_buffer);
    }
};

/// A list of frames that are represented as arrays of indices into
/// a common global color table.
pub const QuantizedFrames = struct {
    const Self = @This();
    /// RGBRGBRGB... * 256
    color_table: []u8,
    /// A list of frames where each frame is a
    /// list of indices into the color table.
    frames: [][]u8,

    /// The allocator used to allocate the color table and the frames.
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, table: []u8, frames: [][]u8) !Self {
        return Self{
            .allocator = allocator,
            .color_table = table,
            .frames = frames,
        };
    }

    pub fn deinit(self: *const Self) void {
        self.allocator.free(self.color_table);
        for (self.frames) |frame| {
            self.allocator.free(frame);
        }
        self.allocator.free(self.frames);
    }
};

pub const Quantize = enum { median_cut, kd_tree };

pub fn quantizeBgraFrames(
    allocator: std.mem.Allocator,
    bgra_bufs: []const []const u8,
    width: usize,
    height: usize,
    method: Quantize,
    use_dithering: bool,
) !QuantizedFrames {
    const config = QuantizerConfig{
        .width = width,
        .height = height,
        .use_dithering = use_dithering,
        .allocator = allocator,
    };

    switch (method) {
        Quantize.median_cut => {
            return try median_cut.quantizeBgraFrames(config, bgra_bufs);
        },
        else => std.debug.panic("not implemented!", .{}),
    }
}

pub fn quantizeBgraImage(
    allocator: std.mem.Allocator,
    bgra_buf: []const u8,
    width: usize,
    height: usize,
    method: Quantize,
    use_dithering: bool,
) !QuantizedImage {
    const config = QuantizerConfig{
        .width = width,
        .height = height,
        .use_dithering = use_dithering,
        .allocator = allocator,
    };

    switch (method) {
        Quantize.median_cut => {
            return try median_cut.quantizeBgraImage(config, bgra_buf);
        },
        else => std.debug.panic("not implemented!", .{}),
    }
}

/// Reduce the number of colors in an image down to a specific number.
pub fn reduceColors(
    allocator: std.mem.Allocator,
    bgra_buf: []const u8,
    width: usize,
    height: usize,
    colors: u16,
    dither: bool,
) !QuantizedImage {
    const config = QuantizerConfig{
        .width = width,
        .height = height,
        .use_dithering = dither,
        .allocator = allocator,
        .ncolors = colors,
    };

    return try median_cut.quantizeBgraImage(config, bgra_buf);
}
