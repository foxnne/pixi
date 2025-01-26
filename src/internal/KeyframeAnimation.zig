const std = @import("std");
const Pixi = @import("../Pixi.zig");

const Keyframe = @import("Keyframe.zig");
const Frame = @import("Frame.zig");

const KeyframeAnimation = @This();

name: [:0]const u8,
id: u32,
keyframes: std.ArrayList(Keyframe),
elapsed_time: f32 = 0.0,
active_keyframe_id: u32,

pub fn keyframe(self: KeyframeAnimation, id: u32) ?*Keyframe {
    for (self.keyframes.items) |*fr| {
        if (fr.id == id)
            return fr;
    }
    return null;
}

pub fn keyframeIndex(self: KeyframeAnimation, id: u32) ?usize {
    for (self.keyframes.items, 0..) |fr, i| {
        if (fr.id == id)
            return i;
    }
    return null;
}

pub fn getKeyframeMilliseconds(self: KeyframeAnimation, ms: usize) ?*Keyframe {
    for (self.keyframes.items) |*kf| {
        const kf_ms: usize = @intFromFloat(kf.time * 1000.0);
        if (ms == kf_ms)
            return kf;
    }

    return null;
}

pub fn getKeyframeFromFrame(self: KeyframeAnimation, frame_id: u32) ?*Keyframe {
    for (self.keyframes.items) |*kf| {
        if (kf.frame(frame_id) != null) {
            return kf;
        }
    }

    return null;
}

pub fn getFrameNodeColor(self: KeyframeAnimation, frame_id: u32) u32 {
    var color_index: usize = @mod(frame_id * 2, 35);

    if (self.getTweenStartFrame(frame_id)) |tween_start_frame| {
        var last_frame = tween_start_frame;
        while (true) {
            if (self.getTweenStartFrame(last_frame.id)) |fr| {
                last_frame = fr;
            } else {
                break;
            }
        }

        color_index = @mod(last_frame.id * 2, 35);
    }

    return if (Pixi.editor.colors.keyframe_palette) |palette| Pixi.math.Color.initBytes(
        palette.colors[color_index][0],
        palette.colors[color_index][1],
        palette.colors[color_index][2],
        palette.colors[color_index][3],
    ).toU32() else Pixi.editor.theme.text.toU32();
}

pub fn getTweenStartFrame(self: KeyframeAnimation, frame_id: u32) ?*Frame {
    for (self.keyframes.items) |kf| {
        for (kf.frames.items) |*fr| {
            if (fr.tween_id) |tween_id| {
                if (tween_id == frame_id) {
                    return fr;
                }
            }
        }
    }
    return null;
}

/// Returns the length of the animation in seconds
pub fn length(self: KeyframeAnimation) f32 {
    var len: f32 = 0.0;
    for (self.keyframes.items) |kf| {
        if (kf.time > len)
            len = kf.time;
    }
    return len;
}

/// Returns the number of frames in the largest keyframe
pub fn maxNodes(self: KeyframeAnimation) usize {
    var nodes: usize = 0;
    for (self.keyframes.items) |kf| {
        if (kf.frames.items.len > nodes)
            nodes = kf.frames.items.len;
    }
    return nodes;
}
