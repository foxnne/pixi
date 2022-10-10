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
