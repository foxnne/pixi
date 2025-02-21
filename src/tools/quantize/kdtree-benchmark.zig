const Kd = @import("kd-tree.zig");
const std = @import("std");
const Timer = @import("timer");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const ncolors = 255;
    var color_table: [ncolors]u8 = undefined;

    var gen = std.rand.DefaultPrng.init(@abs(std.time.milliTimestamp()));
    for (0..color_table.len) |i| {
        color_table[i] = gen.random().int(u8);
    }

    var kdtree = try Kd.KDTree.init(allocator, &color_table);

    var t = Timer{};
    var total_time: i64 = 0;
    const ntimes = 10000;
    for (0..ntimes) |_| {
        const qcolor = [3]u8{
            gen.random().int(u8),
            gen.random().int(u8),
            gen.random().int(u8),
        };

        t.start();
        _ = kdtree.findNearestColor(qcolor);
        total_time += t.end();
    }

    const avg_time = @as(f64, @floatFromInt(total_time)) / ntimes;
    std.debug.print("Average lookup time: {d}ms\n", .{avg_time});
}
