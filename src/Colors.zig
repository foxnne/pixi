const std = @import("std");
const Pixi = @import("Pixi.zig");

const Self = @This();

primary: [4]u8 = .{ 255, 255, 255, 255 },
secondary: [4]u8 = .{ 0, 0, 0, 255 },
height: u8 = 0,
palette: ?Pixi.storage.Internal.Palette = null,
keyframe_palette: ?Pixi.storage.Internal.Palette = null,
