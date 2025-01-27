const std = @import("std");
const pixi = @import("../pixi.zig");

/// A frame is the necessary data to create a transformation frame control around a sprite
/// and move/scale/rotate it within the editor.
///
/// The vertices correspond to each corner where a stretch control exists,
/// and a pivot, which is moveable and changes the rotation control pivot.
const Frame = @This();

const File = @import("File.zig");

vertices: [4]File.TransformVertex,
pivot: File.TransformVertex,
rotation: f32 = 0.0,
id: u32,
sprite_index: usize,
layer_id: u32,
parent_id: ?u32 = null,
visible: bool = true,
tween_id: ?u32 = null,
tween: pixi.math.Tween = .none,
