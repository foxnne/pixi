const std = @import("std");
const pixi = @import("../pixi.zig");
const dvui = @import("dvui");

pub const Brushes = @This();

pub const Brush = struct {
    name: []const u8,
    source: dvui.ImageSource,
    origin: dvui.Point,
};

brushes: std.ArrayList(Brush) = undefined,
selected_brush_index: usize = 0,

pub fn init() !Brushes {
    return .{
        .brushes = std.ArrayList(Brush).init(pixi.app.allocator),
    };
}

pub fn deinit(self: *Brushes) void {
    self.brushes.deinit();
}
