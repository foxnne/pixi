const std = @import("std");
const pixi = @import("../pixi.zig");

pub const layer_name_max_length = 128;
pub const animation_name_max_length = 128;
pub const file_name_max_length = std.fs.max_path_bytes;
