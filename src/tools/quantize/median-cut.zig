const std = @import("std");
const Dither = @import("dither.zig");

const q = @import("quantize.zig");
const QuantizedImage = q.QuantizedImage;
const QuantizedFrames = q.QuantizedFrames;
const QuantizerConfig = q.QuantizerConfig;

const KDTree = @import("kd-tree.zig").KDTree;

// Implements the color quantization algorithm described here:
// https://dl.acm.org/doi/pdf/10.1145/965145.801294
// Color Image Quantization for frame buffer display.
// Paul Heckbert, Computer Graphics lab, New York Institute of Technology.
//
// Used this as reference: https://github.com/mirrorer/giflib/blob/master/lib/quantize.c

// The color array maps a color index to a "Color" object that contains:
// the RGB value of the color and its frequency in the original image.
// We use 5 bits per color channel, so we can represent 32 levels of each color.
pub const color_array_size: comptime_int = 32768; // (2 ^ 5) ^ 3

pub const QuantizedColor = struct {
    /// RGB color values reduced to 5 bit space.
    /// R = RGB[0] << 3.
    RGB: [3]u8,
    /// Frequency of the color in the original image.
    frequency: usize,
    /// Index into color table. Will point to the closest RGB value present
    /// in a color table with at most 256 entries.
    index_in_color_table: u8,
    /// Next color in the linked list.
    next: ?*QuantizedColor,
};

/// A subdivison of the color space produced by the median cut algorithm.
const ColorSpace = struct {
    const Self = @This();

    /// The color channel in this partition with the highest range
    widest_channel: Channel,
    // width of the widest channel in this partition.
    max_rgb_width: i32,
    // length of the partition across each axis (R/G/B).
    rgb_len: [3]i32,
    /// The minimum values of the respective RGB channels in this partition.
    rgb_min: [3]i32,
    /// The maximum values of the respective RGB channels in this partition.
    rgb_max: [3]i32,
    /// linked list of colors in this partition.
    colors: *QuantizedColor,
    /// number of colors in the linked list
    num_colors: usize,
    /// Number of pixels that this partition accounts for.
    num_pixels: usize,

    /// Volume of the partition
    pub inline fn volume(self: *Self) usize {
        return @intCast(self.rgb_len[0] * self.rgb_len[1] * self.rgb_len[2]);
    }
};

const Channel = enum(u5) { Red = 0, Blue = 1, Green = 2 };

/// A function that compares two pixels based on a color channel.
fn colorLessThan(channel: Channel, a: *QuantizedColor, b: *QuantizedColor) bool {
    const sort_channel: usize = @intFromEnum(channel);

    const a_hash = @as(usize, a.RGB[sort_channel]) * 256 * 256 +
        @as(usize, a.RGB[(sort_channel + 1) % 3]) * 256 +
        @as(usize, a.RGB[(sort_channel + 2) % 3]);

    const b_hash = @as(usize, b.RGB[sort_channel]) * 256 * 256 +
        @as(usize, b.RGB[(sort_channel + 1) % 3]) * 256 +
        @as(usize, b.RGB[(sort_channel + 2) % 3]);

    return a_hash < b_hash;
}

test "pixel comparison function" {
    var a: QuantizedColor = undefined;
    var b: QuantizedColor = undefined;

    a.RGB = [3]u8{ 0, 1, 1 };
    b.RGB = [3]u8{ 1, 1, 0 };

    try std.testing.expectEqual(true, colorLessThan(Channel.Red, &a, &b));
    try std.testing.expectEqual(false, colorLessThan(Channel.Green, &a, &b));
    try std.testing.expectEqual(false, colorLessThan(Channel.Blue, &a, &b));
}

fn colorFromRGB(r: u8, g: u8, b: u8) QuantizedColor {
    return QuantizedColor{
        .RGB = [3]u8{ r, g, b },
        .frequency = 0,
        .index_in_color_table = 0,
        .next = null,
    };
}

test "sorting pixels by color channel" {
    var a = colorFromRGB(15, 50, 20);
    var b = colorFromRGB(19, 40, 40);
    var c = colorFromRGB(13, 30, 50);
    var d = colorFromRGB(200, 100, 60);
    var e = colorFromRGB(5, 20, 10);

    var input = [_]*QuantizedColor{ &a, &b, &c, &d, &e };
    const want = [_]*QuantizedColor{ &e, &c, &a, &b, &d };

    std.sort.heap(*QuantizedColor, &input, Channel.Red, colorLessThan);
    for (0..input.len) |i| {
        try std.testing.expectEqual(want[i], input[i]);
    }
}

const bits_per_prim_color = 5; // 5 bits per color channel.
const max_prim_color = 0b11111;
const shift = 8 - bits_per_prim_color;

/// Given an 8-bit RGB color,
/// returns a pointer to the nearest matching color present in the global color array.
pub inline fn getGlobalColor(
    all_colors: *[color_array_size]QuantizedColor,
    r: usize,
    g: usize,
    b: usize,
) *QuantizedColor {
    const r_mask = (r >> shift) << (2 * bits_per_prim_color);
    const g_mask = (g >> shift) << bits_per_prim_color;
    const b_mask = b >> shift;
    return &all_colors[r_mask | g_mask | b_mask];
}

/// Quantize a list of raw BGRA frames such that all frames share the same global color table.
pub fn quantizeBgraFrames(config: QuantizerConfig, bgra_bufs: []const []const u8) !QuantizedFrames {
    // Initialize the color array table with all possible colors in the R5G5B5 space.
    var all_colors: [color_array_size]QuantizedColor = undefined;

    for (0.., &all_colors) |i, *color| {
        color.frequency = 0;
        color.index_in_color_table = 0;
        // The RGB values are packed in the lower 15 bits of its index
        // 0x--(RRRRR)(GGGGG)(BBBBB)
        color.RGB[0] = @truncate(i >> (2 * bits_per_prim_color)); // R: upper 5 bits
        color.RGB[1] = @truncate((i >> bits_per_prim_color) & max_prim_color); // G: middle 5 bits
        color.RGB[2] = @truncate(i & max_prim_color); // B: lower 5 bits.
    }

    // 1. Prepare a frequency histogram of all colors in the clip.
    for (bgra_bufs) |buf| {
        const npixels = buf.len / 4;
        for (0..npixels) |i| {
            const base = i * 4;
            const b = buf[base];
            const g = buf[base + 1];
            const r = buf[base + 2];

            const color = getGlobalColor(&all_colors, r, g, b);
            color.frequency += 1;
        }
    }

    const allocator = config.allocator;

    // 2. Quantize the histogram to 256 colors.
    const total_px_count = bgra_bufs.len * bgra_bufs[0].len / 4;
    const color_table = try quantizeHistogram(allocator, &all_colors, total_px_count);

    // 3. Go over each frame in the input, and replace every pixel with an index into
    // the color table.
    const quantized_frames = try allocator.alloc([]u8, bgra_bufs.len);
    var ditherer = try Dither.init(allocator, &all_colors, color_table);
    for (0.., bgra_bufs) |i, bgra_frame| {
        const npixels = bgra_frame.len / 4;
        const quantized_frame = try allocator.alloc(u8, npixels);

        for (0..npixels) |j| {
            const b = bgra_frame[j * 4];
            const g = bgra_frame[j * 4 + 1];
            const r = bgra_frame[j * 4 + 2];

            const color = getGlobalColor(&all_colors, r, g, b);
            quantized_frame[j] = color.index_in_color_table;
        }

        if (config.use_dithering) {
            try ditherer.ditherBgraImage(
                bgra_frame,
                .{ .quantized_buf = quantized_frame, .color_table = color_table },
                config.width,
                config.height,
            );
        }

        quantized_frames[i] = quantized_frame;
    }

    return QuantizedFrames.init(allocator, color_table, quantized_frames);
}

/// Given a buffer of RGB pixels, quantize the colors in the image to 256 colors.
pub fn quantizeBgraImage(config: QuantizerConfig, image: []const u8) !QuantizedImage {
    const n_pixels = image.len / 4;
    std.debug.assert(image.len % 4 == 0);

    // Initialize the global color array with all possible colors in the R5G5B5 space.
    var all_colors: [color_array_size]QuantizedColor = undefined;
    for (0.., &all_colors) |i, *color| {
        color.frequency = 0;
        color.index_in_color_table = 0;
        // The RGB values are packed in the lower 15 bits of its index
        // 0x--(RRRRR)(GGGGG)(BBBBB)
        color.RGB[0] = @truncate(i >> (2 * bits_per_prim_color)); // R: upper 5 bits
        color.RGB[1] = @truncate((i >> bits_per_prim_color) & max_prim_color); // G: middle 5 bits
        color.RGB[2] = @truncate(i & max_prim_color); // B: lower 5 bits.
    }

    // Sample all colors in the image, and count their frequency.
    for (0..n_pixels) |i| {
        const base = i * 4;

        const b = image[base];
        const g = image[base + 1];
        const r = image[base + 2];

        const r_mask = @as(usize, r >> shift) << (2 * bits_per_prim_color);
        const g_mask = @as(usize, g >> shift) << bits_per_prim_color;
        const b_mask = @as(usize, b >> shift);

        const index = r_mask | g_mask | b_mask;
        all_colors[index].frequency += 1;
    }

    const allocator = config.allocator;
    const color_table = try quantizeHistogram(
        allocator,
        &all_colors,
        n_pixels,
        config.ncolors,
    );

    // Now go over the input image, and replace each pixel with the index of the partition
    var image_buf = try allocator.alloc(u8, n_pixels);
    for (0..n_pixels) |i| {
        const b = image[i * 4];
        const g = image[i * 4 + 1];
        const r = image[i * 4 + 2];

        const nearest_color = getGlobalColor(&all_colors, r, g, b);
        image_buf[i] = nearest_color.index_in_color_table;
    }

    if (config.use_dithering) {
        var ditherer = try Dither.init(allocator, &all_colors, color_table);
        try ditherer.ditherBgraImage(
            image,
            .{ .quantized_buf = image_buf, .color_table = color_table },
            config.width,
            config.height,
        );
    }

    return QuantizedImage.init(color_table, image_buf);
}

/// Given a list of colors with their respective frequencies,
/// produce a color table with 256 colors that best represent the histogram.
fn quantizeHistogram(
    allocator: std.mem.Allocator,
    all_colors: *[color_array_size]QuantizedColor,
    n_pixels: usize,
    n_colors: u16,
) ![]u8 {
    // Find all colors in the color table that are used at least once, and chain them.
    var head: *QuantizedColor = undefined;
    for (all_colors) |*color| {
        if (color.frequency > 0) {
            head = color;
            break;
        }
    }

    var qcolor = head;
    var color_count: usize = 1;
    for (all_colors) |*color| {
        if (color != head and color.frequency > 0) {
            qcolor.next = color;
            qcolor = color;
            color_count += 1;
        }
    }
    qcolor.next = null;

    var first_partition = try allocator.create(ColorSpace);
    first_partition.colors = head;
    first_partition.num_colors = color_count;
    first_partition.num_pixels = n_pixels;

    std.debug.assert(n_pixels == countPixels(first_partition));

    findWidestChannel(first_partition);

    const partitions = try medianCut(allocator, first_partition, n_colors);

    defer {
        for (partitions) |p| {
            allocator.destroy(p);
        }
        allocator.free(partitions);
    }

    const color_table = try allocator.alloc(u8, partitions.len * 3);
    for (0.., partitions) |i, partition| {
        if (partition.num_colors == 0) continue;

        // This loop does two things:
        // 1. Find the average color of this partition.
        // 2. Point all colors in this partition to the index of this partition.
        var color = partition.colors;
        var rgb_sum: @Vector(3, usize) = .{ 0, 0, 0 };
        for (0..partition.num_colors) |j| {
            color.index_in_color_table = @truncate(i);

            rgb_sum += color.RGB;

            if (color.next) |next| {
                color = next;
            } else {
                std.debug.assert(j == partition.num_colors - 1);
                break;
            }
        }

        color_table[i * 3] = @intCast((rgb_sum[0] << shift) / partition.num_colors);
        color_table[i * 3 + 1] = @intCast((rgb_sum[1] << shift) / partition.num_colors);
        color_table[i * 3 + 2] = @intCast((rgb_sum[2] << shift) / partition.num_colors);
    }

    var kdtree = try KDTree.init(allocator, color_table);
    defer kdtree.deinit();

    for (all_colors) |*color| {
        const r: u8 = color.RGB[0] << shift;
        const g: u8 = color.RGB[1] << shift;
        const b: u8 = color.RGB[2] << shift;

        if (color.index_in_color_table != 0) continue;

        const nearest = kdtree.findNearestColor([3]u8{ r, g, b }).color_table_index;
        color.index_in_color_table = nearest;
    }

    return color_table;
}

/// Find the color channel with the largest range in the given parition.
/// Mutates `rgb_min`, `rgb_max`, `rgb_len`, ` max_rgb_width`, and `widest_channel`.
fn findWidestChannel(partition: *ColorSpace) void {
    var min = [3]i32{ 255, 255, 255 };
    var max = [3]i32{ 0, 0, 0 };

    var color: ?*QuantizedColor = partition.colors;
    for (0..partition.num_colors) |_| {
        std.debug.assert(color != null);
        const color_ptr = color orelse unreachable;
        for (0..3) |i| {
            min[i] = @min(color_ptr.RGB[i] << shift, min[i]);
            max[i] = @max(color_ptr.RGB[i] << shift, max[i]);
        }
        color = color_ptr.next;
    }

    partition.rgb_min = min;
    partition.rgb_max = max;

    const rgb_widths = [3]i32{ max[0] - min[0], max[1] - min[1], max[2] - min[2] };
    partition.rgb_len = rgb_widths;

    if (rgb_widths[0] > rgb_widths[1] and rgb_widths[0] > rgb_widths[2]) {
        partition.widest_channel = Channel.Red;
        partition.max_rgb_width = rgb_widths[0];
        return;
    }

    if (rgb_widths[1] > rgb_widths[0] and rgb_widths[1] > rgb_widths[2]) {
        partition.max_rgb_width = rgb_widths[1];
        partition.widest_channel = Channel.Green;
        return;
    }

    partition.max_rgb_width = rgb_widths[2];
    partition.widest_channel = Channel.Blue;
}

test "findWidestChannel" {
    var yellow = QuantizedColor{
        .RGB = [3]u8{ 25, 24, 0 },
        .frequency = 0,
        .index_in_color_table = 0,
        .next = null,
    };

    var purple = QuantizedColor{
        .RGB = [3]u8{ 25, 0, 25 },
        .frequency = 0,
        .index_in_color_table = 0,
        .next = &yellow,
    };

    var colorspace = ColorSpace{
        .widest_channel = undefined,
        .max_rgb_width = undefined,
        .rgb_len = undefined,
        .rgb_min = undefined,
        .rgb_max = undefined,
        .colors = &purple,
        .num_colors = 2,
        .num_pixels = 0,
    };
    findWidestChannel(&colorspace);
    try std.testing.expect(std.mem.eql(i32, &colorspace.rgb_min, &[3]i32{ 25 << 3, 0, 0 }));
    try std.testing.expect(std.mem.eql(i32, &colorspace.rgb_max, &[3]i32{ 25 << 3, 24 << 3, 25 << 3 }));
    try std.testing.expectEqual(.Blue, colorspace.widest_channel);
}

/// Copy all the colors in a partition into an array,
/// then sort that array along the widest channel of the partition, and return it.
/// The array contains pointers to the original colors in the partition.
/// The array is owned by the caller, and must be kept alive at least as long as the partition itself.
fn sortPartition(allocator: std.mem.Allocator, partition: *const ColorSpace) ![]*QuantizedColor {
    var sorted_colors = try allocator.alloc(*QuantizedColor, partition.num_colors);
    var color = partition.colors;
    for (0..partition.num_colors) |i| {
        std.debug.assert(@as(?*QuantizedColor, color) != null);
        sorted_colors[i] = color;
        if (color.next) |next| {
            color = next;
        } else {
            std.debug.assert(i == partition.num_colors - 1);
            break;
        }
    }

    std.sort.heap(
        *QuantizedColor,
        sorted_colors,
        partition.widest_channel,
        colorLessThan,
    );

    for (0..sorted_colors.len - 1) |i| {
        sorted_colors[i].next = sorted_colors[i + 1];
    }
    sorted_colors[sorted_colors.len - 1].next = null;
    return sorted_colors;
}

/// Find the index of the partition to split during median cut.
fn findPartitionToSplit(partitions: []*ColorSpace, use_volume: bool) ?usize {
    var max_val: usize = 0;
    var split_index: ?usize = null;

    for (0..partitions.len) |i| {
        const partition = partitions[i];
        if (partition.num_colors <= 1) continue;

        const val = if (use_volume)
            partition.num_pixels * partition.volume()
        else
            partition.num_pixels;

        if (val > max_val) {
            max_val = val;
            split_index = i;
        }
    }

    return split_index;
}

fn splitPartition(allocator: std.mem.Allocator, partition: *ColorSpace) !*ColorSpace {
    std.debug.assert(partition.num_colors > 1);

    const half_population: usize = partition.num_pixels / 2;

    // Color that divides the population of pixels in this partition
    // into two (roughly) equal halves.
    var median_color: *QuantizedColor = partition.colors;
    var ncolors_left: usize = 1; // # colors on the left side
    var npixels_left = median_color.frequency; // # pixels on the left side

    // min, max, and widest color (in the widest channel) on the left side of the median.
    var min_rgb_left: @Vector(3, i32) = .{ 255, 255, 255 };
    var max_rgb_left: @Vector(3, i32) = .{ 0, 0, 0 };

    const shift_vec: @Vector(3, i32) = .{ shift, shift, shift };
    while (true) {
        const next = median_color.next orelse break;
        const reached_half_population =
            npixels_left >= half_population or
            next.next == null;

        // check if we've reached the color that divides the population in half.
        if (reached_half_population) {
            break;
        }

        const rgb = @as(@Vector(3, i32), median_color.RGB) << shift_vec;
        min_rgb_left = @min(min_rgb_left, rgb);
        max_rgb_left = @max(max_rgb_left, rgb);

        median_color = next;
        npixels_left += median_color.frequency;
        ncolors_left += 1;
    }

    const new_partition = try allocator.create(ColorSpace);
    new_partition.colors = partition.colors;
    new_partition.num_colors = ncolors_left;
    new_partition.num_pixels = npixels_left;
    new_partition.rgb_min = min_rgb_left;
    new_partition.rgb_max = max_rgb_left;

    // set the new partition's widest channel.
    var widest_channel = Channel.Red;
    var maxdiff: i32 = 0;
    for (0..3) |i| {
        const diff = max_rgb_left[i] - min_rgb_left[i];
        if (diff >= maxdiff) {
            maxdiff = diff;
            widest_channel = @enumFromInt(i);
        }
    }

    new_partition.widest_channel = widest_channel;

    const first_of_right_partition = median_color.next orelse
        @panic("encountered a bug, please report!");
    median_color.next = null; // unlink the two partitions.
    partition.colors = first_of_right_partition;
    partition.num_colors = partition.num_colors - ncolors_left;
    partition.num_pixels = partition.num_pixels - npixels_left;
    findWidestChannel(partition);

    return new_partition;
}

/// An "improved" partition split algorithm taken from this paper:
/// http://leptonica.org/papers/mediancut.pdf
fn splitPartitionImproved(allocator: std.mem.Allocator, partition: *ColorSpace) !*ColorSpace {
    std.debug.assert(partition.num_colors > 1);

    const half_population: usize = partition.num_pixels / 2;

    // Color that divides the population of pixels in this partition
    // into two (roughly) equal halves.
    var median_color: *QuantizedColor = partition.colors;
    var npixels_left = median_color.frequency; // # pixels on the left side

    const widest_channel = @intFromEnum(partition.widest_channel);

    // min, max, and widest color (in the widest channel) on the left side of the median.
    var min_color_left = median_color.RGB[widest_channel] << shift;
    var max_color_left = median_color.RGB[widest_channel] << shift;

    // Width of the color channel on the left side of the color
    // that divides the pixel population in half (a.k.a `median_color`).
    var color_width_left: i32 = 0;

    while (true) {
        // check if we've reached the color that divides the population in half.
        const reached_half_population =
            npixels_left >= half_population or
            median_color.next == null or
            median_color.next.?.next == null;

        if (reached_half_population) {
            // Now, `median_color` points to the color
            // that divides the population in this partition into two
            // roughly equal halves.
            //
            // We want to take the longer side (left), find its midpoint
            // and use that to split the old partition into two new ones.
            // Instead of allocating two new partitions, we'll reuse the old one.
            // and allocate just one new partition for the new left side.

            var new_partition = try allocator.create(ColorSpace);
            const midpoint = min_color_left + @divTrunc(color_width_left, 2);

            // At the end of the iteration, `temp_color` will
            // point to the first color in the old partition.
            var temp_color: *QuantizedColor = partition.colors;

            var new_rgbmin: @Vector(3, i32) = temp_color.RGB;
            var new_rgbmax: @Vector(3, i32) = temp_color.RGB;

            const shift_vec: @Vector(3, i32) = [_]i32{shift} ** 3;
            new_rgbmin <<= shift_vec;
            new_rgbmax <<= shift_vec;

            var new_num_pixels: usize = temp_color.frequency;
            var new_num_colors: usize = 1;
            while (true) {
                const prev = temp_color;
                temp_color = temp_color.next orelse @panic("bug encountered. please report.");
                if ((temp_color.RGB[widest_channel] << shift) >= midpoint) {
                    // unlink the colors in two partitions.
                    prev.next = null;
                    break;
                }

                var rgb: @Vector(3, i32) = temp_color.RGB;
                rgb <<= shift_vec;
                new_rgbmin = @min(new_rgbmin, rgb);
                new_rgbmax = @max(new_rgbmax, rgb);

                new_num_colors += 1;
                new_num_pixels += temp_color.frequency;
            }

            new_partition.colors = partition.colors;
            new_partition.num_colors = new_num_colors;
            new_partition.num_pixels = new_num_pixels;
            new_partition.rgb_min = new_rgbmin;
            new_partition.rgb_max = new_rgbmax;

            // set the new partition's widest channel.
            var new_rgbwidth = [3]i32{ 0, 0, 0 };
            var maxdiff: i32 = 0;
            for (0..3) |i| {
                new_rgbwidth[i] = new_rgbmax[i] - new_rgbmin[i];
                if (new_rgbwidth[i] >= maxdiff) {
                    maxdiff = new_rgbwidth[i];
                    new_partition.widest_channel = @enumFromInt(i);
                }
            }

            new_partition.rgb_len = new_rgbwidth;
            new_partition.max_rgb_width = maxdiff;

            partition.colors = temp_color;
            partition.num_colors = partition.num_colors - new_num_colors;
            partition.num_pixels = partition.num_pixels - new_num_pixels;
            findWidestChannel(partition);

            return new_partition;
        }

        const next = median_color.next orelse unreachable;

        median_color = next;
        npixels_left += median_color.frequency;

        // compare the value of this color in the widest
        // axis to the min and max values found so far.
        const color_value = median_color.RGB[widest_channel] << shift;
        if (color_value < min_color_left) {
            min_color_left = color_value;
            color_width_left = max_color_left - min_color_left;
        } else if (color_value > max_color_left) {
            max_color_left = color_value;
            color_width_left = max_color_left - min_color_left;
        }
    }
}

test "splitPartition" {
    // TODO
}

/// Recursively split the colorspace into smaller partitions until `total_partitions` partitions are created.
fn medianCut(allocator: std.mem.Allocator, first_partition: *ColorSpace, total_partitions: u16) ![]*ColorSpace {
    var parts = try allocator.alloc(*ColorSpace, total_partitions);
    parts[0] = first_partition;

    var n_partitions: usize = 1; // we're starting with 1 large partition.
    while (n_partitions < total_partitions) : (n_partitions += 1) {

        // For the 50% of the partitions,
        // we divide them based on pixel population.
        // We divide the other 50% based on the product of population
        // and volume.
        const split_index_ = findPartitionToSplit(
            parts[0..n_partitions],
            n_partitions >= total_partitions / 2,
        );

        const split_index = split_index_ orelse break;

        // We found the partition that varies the most in either of the 3 color channels.
        const partition_to_split = parts[split_index];
        // sort the colors in that partition along the widest channel.
        const sorted_colors = try sortPartition(allocator, partition_to_split);
        defer allocator.free(sorted_colors);

        // Now the colors in the partition are sorted along the widest channel.
        partition_to_split.colors = sorted_colors[0]; // reset the head pointer of the linked list.

        const new_partition = try splitPartitionImproved(allocator, partition_to_split);
        parts[n_partitions] = new_partition;

        std.debug.assert(partition_to_split.num_pixels == countPixels(partition_to_split));
        std.debug.assert(new_partition.num_pixels == countPixels(new_partition));
    }

    if (n_partitions != total_partitions) {
        return try allocator.realloc(parts, n_partitions);
    }

    return parts;
}

/// Returns the sum of frequencies of all colors in the partition.
fn countPixels(partition: *ColorSpace) usize {
    var color = partition.colors;
    var count: usize = 0;
    const ncolors = partition.num_colors;
    for (0..ncolors) |i| {
        count += color.frequency;
        if (color.next) |next| {
            color = next;
        } else {
            if (ncolors != i + 1) {
                std.debug.panic(
                    "expected {} colors, got {}\n",
                    .{ ncolors, i + 1 },
                );
            }
            break;
        }
    }

    std.debug.assert(color.next == null);
    return count;
}
