const std = @import("std");
const pixi = @import("pixi");

pub const Style = @import("style.zig");

pub const menu = @import("panes/menu.zig");
pub const sidebar = @import("panes/sidebar.zig");
pub const explorer = @import("panes/explorer.zig");
pub const artboard = @import("panes/artboard.zig");

pub fn draw() void {
    sidebar.draw();
    explorer.draw();
    artboard.draw();
}

pub fn setProjectFolder(path: [*:0]const u8) void {
    pixi.state.project_folder = path[0..std.mem.len(path) :0];
}
