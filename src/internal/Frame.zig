const std = @import("std");
const Pixi = @import("../Pixi.zig");

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
tween: Pixi.math.Tween = .none,
