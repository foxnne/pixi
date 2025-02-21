// A simple timer utility for benchmarking.
const std = @import("std");

const Self = @This();
start_time: i64 = -1,
done: bool = false,

pub fn start(self: *Self) void {
    self.start_time = std.time.milliTimestamp();
    self.done = false;
}

pub fn end(self: *Self) i64 {
    if (self.start_time == -1 or self.done) {
        std.debug.panic("Timer already ended", .{});
        return -1;
    }
    self.done = true;

    const end_time = std.time.milliTimestamp();
    const elapsed = end_time - self.start_time;
    return elapsed;
}
