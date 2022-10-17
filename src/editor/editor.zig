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

pub fn openFile(path: [:0]const u8) !bool {
    // TODO: Load files
    const file: pixi.storage.File = .{
        .path = path,
        .width = 0,
        .height = 0,
    };

    try pixi.state.open_files.insert(0, file);
    pixi.state.open_file_index = 0;
    return true;
}

pub fn closeFile(index: usize) !void {
    pixi.state.open_file_index = 0;
    var file = pixi.state.open_files.swapRemove(index);
    pixi.state.allocator.free(file.path);
}
