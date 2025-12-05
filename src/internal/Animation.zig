const std = @import("std");
const dvui = @import("dvui");
const Animation = @This();

// TODO: make the same type as external without id
id: u64,
name: []const u8,
frames: []usize,
fps: f32,

pub const OldAnimation = struct {
    name: []const u8,
    start: usize,
    length: usize,
    fps: f32,
};

pub fn init(allocator: std.mem.Allocator, id: u64, name: []const u8, frames: []usize, fps: f32) !Animation {
    return .{
        .id = id,
        .name = try allocator.dupe(u8, name),
        .frames = try allocator.dupe(usize, frames),
        .fps = fps,
    };
}

pub fn appendFrame(self: *Animation, allocator: std.mem.Allocator, frame: usize) !void {
    var new_frames = std.array_list.Managed(usize).init(allocator);
    new_frames.appendSlice(self.frames) catch |err| {
        dvui.log.err("Failed to append frames", .{});
        return err;
    };
    new_frames.append(frame) catch |err| {
        dvui.log.err("Failed to append frame", .{});
        return err;
    };

    allocator.free(self.frames);

    self.frames = new_frames.toOwnedSlice() catch |err| {
        dvui.log.err("Failed to free frames", .{});
        return err;
    };
}

pub fn appendFrames(self: *Animation, allocator: std.mem.Allocator, frames: []usize) !void {
    var new_frames = std.array_list.Managed(usize).init(allocator);
    new_frames.appendSlice(self.frames) catch |err| {
        dvui.log.err("Failed to append frames", .{});
        return err;
    };
    new_frames.appendSlice(frames) catch |err| {
        dvui.log.err("Failed to append frames", .{});
        return err;
    };

    allocator.free(self.frames);
    self.frames = new_frames.toOwnedSlice() catch |err| {
        dvui.log.err("Failed to free frames", .{});
        return err;
    };
}

pub fn insertFrame(self: *Animation, allocator: std.mem.Allocator, index: usize, frame: usize) !void {
    var new_frames = std.array_list.Managed(usize).init(allocator);
    new_frames.appendSlice(self.frames) catch |err| {
        dvui.log.err("Failed to append frames", .{});
        return err;
    };
    new_frames.insert(index, frame) catch |err| {
        dvui.log.err("Failed to insert frame", .{});
        return err;
    };

    allocator.free(self.frames);

    self.frames = new_frames.toOwnedSlice() catch |err| {
        dvui.log.err("Failed to free frames", .{});
        return err;
    };
}

pub fn removeFrame(self: *Animation, allocator: std.mem.Allocator, index: usize) void {
    var new_frames = std.array_list.Managed(usize).init(allocator);
    new_frames.appendSlice(self.frames) catch {
        dvui.log.err("Failed to append frames", .{});
        return;
    };
    _ = new_frames.orderedRemove(index);

    allocator.free(self.frames);

    self.frames = new_frames.toOwnedSlice() catch {
        dvui.log.err("Failed to free frames", .{});
        return;
    };
}

pub fn deinit(self: *Animation, allocator: std.mem.Allocator) void {
    allocator.free(self.name);
    allocator.free(self.frames);
}
