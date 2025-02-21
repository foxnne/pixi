const std = @import("std");

pub fn FixedStack(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();

        data: [capacity]T = undefined,
        ptr: usize = 0,

        pub inline fn push(self: *Self, value: T) void {
            std.debug.assert(self.ptr < capacity);
            self.data[self.ptr] = value;
            self.ptr += 1;
        }

        pub inline fn isEmpty(self: *const Self) bool {
            return self.ptr == 0;
        }

        pub inline fn pop(self: *Self) T {
            std.debug.assert(self.ptr >= 0);
            self.ptr -= 1;
            return self.data[self.ptr];
        }

        pub inline fn top(self: *Self) T {
            std.debug.assert(self.ptr >= 0);
            return self.data[self.ptr - 1];
        }
    };
}
