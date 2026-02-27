const std = @import("std");
const builtin = @import("builtin");

const dvui = @import("dvui");
const pixi = @import("../../pixi.zig");

const Core = @import("mach").Core;
const App = pixi.App;
const Editor = pixi.Editor;
const Packer = pixi.Packer;

pub const Panel = @This();

pub const Sprites = @import("sprites.zig");

sprites: Sprites = .{},
pane: Pane = .sprites,
paned: *pixi.dvui.PanedWidget = undefined,
scroll_info: dvui.ScrollInfo = .{
    .horizontal = .auto,
},

pub const Pane = enum(u32) {
    sprites,
};

pub fn init() Panel {
    return .{};
}

pub fn deinit(_: *Panel) void {}

pub fn draw(panel: *Panel) !dvui.App.Result {
    // var scroll_area = dvui.scrollArea(@src(), .{ .scroll_info = &panel.scroll_info }, .{
    //     .expand = .both,
    // });
    // defer scroll_area.deinit();

    var vbox = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .both,
        .background = true,
        .color_fill = dvui.themeGet().color(.window, .fill),
    });
    defer vbox.deinit();

    switch (panel.pane) {
        .sprites => try panel.sprites.draw(),
    }

    return .ok;
}
