const std = @import("std");
const cgif = @cImport(@cInclude("cgif.h"));
const quant = @import("quantize/quantize.zig");
const zstbi = @import("zstbi");

const Allocator = std.mem.Allocator;

const GifError = error{
    gif_make_failed,
    gif_open_failed,
    gif_close_failed,
    malloc_failed,
    gif_write_failed,
    invalid_index,
    cgif_pending,
    cgif_unknown_error,

    gif_uninitialized,

    unknown_error_pls_report_bug,
};

pub const GifFrame = struct {
    bgra_buf: []const u8,
    duration_ms: u64,
};

pub const GifConfig = struct {
    transparent: bool = false,
    use_dithering: bool = true,
    use_local_palette: bool = true,
    path: [:0]const u8,
    width: usize,
    height: usize,
};

pub const Gif = struct {
    const Self = @This();

    allocator: Allocator,

    cgif_config: *cgif.CGIF_Config,
    cgif_frame_config: *cgif.CGIF_FrameConfig,
    gif: ?*cgif.CGIF,
    path: [:0]const u8,

    config: GifConfig,

    pub fn init(allocator: Allocator, config: GifConfig) !Self {
        // Configure CGIF's config object
        const cgif_config = try allocator.create(cgif.CGIF_Config);
        initCGifConfig(cgif_config, config.path, config.width, config.height);
        cgif_config.attrFlags = cgif.CGIF_ATTR_IS_ANIMATED;
        if (config.transparent)
            cgif_config.attrFlags |= cgif.CGIF_ATTR_HAS_TRANSPARENCY;

        const cgif_frame_config = try allocator.create(cgif.CGIF_FrameConfig);
        initFrameConfig(cgif_frame_config);

        cgif_frame_config.transIndex = 0;
        cgif_frame_config.genFlags = cgif.CGIF_FRAME_GEN_USE_DIFF_WINDOW;

        if (config.transparent)
            cgif_frame_config.genFlags |= cgif.CGIF_FRAME_GEN_USE_TRANSPARENCY;

        var gif: ?*cgif.CGIF = null;
        if (config.use_local_palette) {
            cgif_config.attrFlags |= @intCast(cgif.CGIF_ATTR_NO_GLOBAL_TABLE);
            cgif_frame_config.attrFlags |= @intCast(cgif.CGIF_FRAME_ATTR_USE_LOCAL_TABLE);

            // If we're using a local palette, we can create a GIF object right away.
            // For global palettes, we need to wait for the frames first.
            // We cannot create a palette object for CGIF before seeing all the frames.
            gif = cgif.cgif_newgif(cgif_config) orelse {
                return GifError.gif_make_failed;
            };
        }

        return .{
            .allocator = allocator,
            .cgif_config = cgif_config,
            .cgif_frame_config = cgif_frame_config,
            .gif = gif,
            .path = config.path,
            .config = config,
        };
    }

    pub fn addFrames(self: *Self, frames: []zstbi.Image, fps: u32) !void {
        for (frames) |frame| {
            const duration: u64 = @as(u64, @intFromFloat((1.0 / @as(f32, @floatFromInt(fps))) * 1000.0));
            try self.addFrame(frame, duration);
        }
    }

    pub fn addFrame(self: *Self, frame: zstbi.Image, duration_ms: u64) !void {
        if (!self.config.use_local_palette) {
            std.debug.panic("Unimplemented!", .{});
        }

        const gif = self.gif orelse return GifError.gif_uninitialized;

        const quantized = try quant.quantizeBgraImage(
            self.allocator,
            frame.data,
            self.config.width,
            self.config.height,
            quant.Quantize.median_cut,
            self.config.use_dithering,
        );

        // CGIF uses units of 0.01s for frame delay.
        const duration = @as(f64, @floatFromInt(duration_ms)) / 10.0;
        const duration_int: u64 = @intFromFloat(@round(duration));

        self.cgif_frame_config.delay = @truncate(duration_int);
        self.cgif_frame_config.pImageData = quantized.image_buffer.ptr;
        self.cgif_frame_config.pLocalPalette = quantized.color_table.ptr;
        self.cgif_frame_config.numLocalPaletteEntries = @intCast(quantized.color_table.len / 3);

        const err_code = cgif.cgif_addframe(gif, self.cgif_frame_config);
        if (err_code != 0) {
            return cgifError(err_code);
        }
    }

    pub fn close(self: *Self) GifError!void {
        if (self.gif == null) {
            return GifError.gif_uninitialized;
        }

        const err_code = cgif.cgif_close(self.gif);
        self.gif = null;
        if (err_code != 0) {
            return cgifError(err_code);
        }
    }

    /// Convert a CGIF error to a GifError.
    fn cgifError(err_code: c_int) GifError {
        return switch (err_code) {
            cgif.CGIF_ERROR => GifError.cgif_unknown_error,
            cgif.CGIF_EOPEN => GifError.gif_open_failed,
            cgif.CGIF_EWRITE => GifError.gif_write_failed,
            cgif.CGIF_ECLOSE => GifError.gif_close_failed,
            cgif.CGIF_EALLOC => GifError.malloc_failed,
            cgif.CGIF_EINDEX => GifError.invalid_index,
            else => GifError.unknown_error_pls_report_bug,
        };
    }

    pub fn deinit(self: *const Self) void {
        self.allocator.destroy(self.cgif_config);
        self.allocator.destroy(self.cgif_frame_config);
    }
};

/// Intialize a cgif gif config struct.
fn initCGifConfig(
    gif_config: *cgif.CGIF_Config,
    path: [:0]const u8,
    width: usize,
    height: usize,
) void {
    // in a c program, this would be a memset(gif_config, 0), but we can't do that in Zig
    gif_config.pGlobalPalette = null;
    gif_config.pContext = null;
    gif_config.pWriteFn = null;
    gif_config.attrFlags = 0;
    gif_config.genFlags = 0;
    gif_config.numGlobalPaletteEntries = 0;
    gif_config.numLoops = 0;

    gif_config.path = path.ptr;
    gif_config.width = @intCast(width);
    gif_config.height = @intCast(height);
}

/// Intialize a cgif frame config struct.
pub fn initFrameConfig(conf: *cgif.CGIF_FrameConfig) void {
    conf.pLocalPalette = null;
    conf.pImageData = null;

    conf.numLocalPaletteEntries = 0;
    conf.attrFlags = 0;
    conf.genFlags = 0;
    conf.transIndex = 0;

    conf.delay = 0;
}
