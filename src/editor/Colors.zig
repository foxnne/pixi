const std = @import("std");
const pixi = @import("../pixi.zig");

const Self = @This();

primary: [4]u8 = .{ 255, 255, 255, 255 },
secondary: [4]u8 = .{ 0, 0, 0, 255 },
height: u8 = 0,
palette: ?pixi.Internal.Palette = null,
file_tree_palette: ?pixi.Internal.Palette = null,
