const std = @import("std");
const game = @import("game");

pub const Counter = struct {
    var value: u64 = 0;

    pub fn count(self: Counter) u64 {
        _ = self;
        if (value == std.math.maxInt(u64)) {
            value = 0;
            std.log.debug("[{s}] Counter rolled over to 0, errors to be expected.", .{game.name});
        }
        value += 1;
        return value;
    }
};
