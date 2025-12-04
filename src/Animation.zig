const std = @import("std");
const Animation = @This();

name: []const u8,
frames: []usize,
fps: f32,

pub const OldAnimation = struct {
    name: []const u8,
    start: usize,
    length: usize,
    fps: f32,
};

pub fn init(allocator: std.mem.Allocator, name: []const u8, frames: []usize, fps: f32) !Animation {
    return .{
        .name = try allocator.dupe(u8, name),
        .frames = try allocator.dupe(usize, frames),
        .fps = fps,
    };
}

pub fn deinit(self: *Animation, allocator: std.mem.Allocator) void {
    allocator.free(self.name);
    allocator.free(self.frames);
}
