const std = @import("std");
const Pixi = @import("../Pixi.zig");

const PixiFile = @import("PixiFile.zig");

vertices: [4]PixiFile.TransformVertex,
pivot: PixiFile.TransformVertex,
rotation: f32 = 0.0,
id: u32,
sprite_index: usize,
layer_id: u32,
parent_id: ?u32 = null,
visible: bool = true,
tween_id: ?u32 = null,
tween: Pixi.math.Tween = .none,
