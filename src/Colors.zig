const std = @import("std");
const pixi = @import("Pixi.zig");

const Self = @This();

primary: [4]u8 = .{ 255, 255, 255, 255 },
secondary: [4]u8 = .{ 0, 0, 0, 255 },
height: u8 = 0,
palette: ?pixi.storage.Internal.Palette = null,
keyframe_palette: ?pixi.storage.Internal.Palette = null,
