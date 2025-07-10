const std = @import("std");
const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");

pub fn draw() !void {
    const hbox = dvui.box(@src(), .horizontal, .{ .expand = .both, .background = false });
    defer hbox.deinit();
}
