const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("pixi");
const nfd = @import("nfd");

pub const files = @import("files.zig");
pub const sprites = @import("sprites.zig");
pub const settings = @import("settings.zig");

pub fn draw() void {
    zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.window_rounding, .v = 0.0 });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.window_bg, .c = pixi.state.style.foreground.toSlice() });
    defer zgui.popStyleVar(.{ .count = 1 });
    defer zgui.popStyleColor(.{ .count = 1 });
    zgui.setNextWindowPos(.{
        .x = pixi.state.settings.sidebar_width * pixi.state.window.scale[0],
        .y = 0,
        .cond = .always,
    });
    zgui.setNextWindowSize(.{
        .w = pixi.state.settings.explorer_width * pixi.state.window.scale[0],
        .h = pixi.state.window.size[1] * pixi.state.window.scale[1],
    });

    if (zgui.begin("Explorer", .{
        .flags = .{
            .no_title_bar = true,
            .no_resize = true,
            .no_move = true,
            .no_collapse = true,
            .horizontal_scrollbar = true,
            .menu_bar = true,
        },
    })) {
        // Push explorer style changes.
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 4.0 * pixi.state.window.scale[0], 6.0 * pixi.state.window.scale[1] } });
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 0.0, 8.0 * pixi.state.window.scale[1] } });
        defer zgui.popStyleVar(.{ .count = 2 });

        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.separator, .c = pixi.state.style.background.toSlice() });
        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.header, .c = pixi.state.style.foreground.toSlice() });
        defer zgui.popStyleColor(.{ .count = 2 });

        switch (pixi.state.sidebar) {
            .files => {
                if (zgui.beginMenuBar()) {
                    zgui.text("Explorer", .{});
                    zgui.endMenuBar();
                }
                files.draw();
            },
            .tools => {
                if (zgui.beginMenuBar()) {
                    zgui.text("Tools", .{});
                    zgui.endMenuBar();
                }
            },
            .layers => {
                if (zgui.beginMenuBar()) {
                    zgui.text("Layers", .{});
                    zgui.endMenuBar();
                }
                if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
                    for (file.layers.items) |layer| {
                        zgui.bulletText("{s}", .{layer.name});
                    }
                }
            },
            .sprites => {
                if (zgui.beginMenuBar()) {
                    zgui.text("Sprites & Animations", .{});
                    zgui.endMenuBar();
                }
                sprites.draw();
            },
            .settings => {
                if (zgui.beginMenuBar()) {
                    zgui.text("Settings", .{});
                    zgui.endMenuBar();
                }
                settings.draw();
            },
        }
    }

    zgui.end();
}
