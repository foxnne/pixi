const std = @import("std");

const pixi = @import("../pixi.zig");

const Frame = @import("Frame.zig");

const Keyframe = @This();

frames: std.ArrayList(Frame),
time: f32 = 0.0,
id: u32,
active_frame_id: u32,

pub fn frame(self: Keyframe, id: u32) ?*Frame {
    for (self.frames.items) |*fr| {
        if (fr.id == id)
            return fr;
    }
    return null;
}

pub fn frameIndex(self: Keyframe, id: u32) ?usize {
    for (self.frames.items, 0..) |*fr, i| {
        if (fr.id == id)
            return i;
    }
    return null;
}
