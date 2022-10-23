const storage = @import("storage.zig");

pub const Animation = struct {
    name: []const u8,
    start: usize,
    length: usize,
    fps: usize,
};
