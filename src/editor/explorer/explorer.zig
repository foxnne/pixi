const std = @import("std");
const pixi = @import("../../pixi.zig");
const mach = @import("core");
const zgui = @import("zgui").MachImgui(mach);
const nfd = @import("nfd");

pub const files = @import("files.zig");
pub const tools = @import("tools.zig");
pub const layers = @import("layers.zig");
pub const sprites = @import("sprites.zig");
pub const animations = @import("animations.zig");
pub const pack = @import("pack.zig");
pub const settings = @import("settings.zig");

pub fn draw() void {
    zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.window_rounding, .v = 0.0 });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.window_bg, .c = pixi.state.style.foreground.toSlice() });
    defer zgui.popStyleVar(.{ .count = 1 });
    defer zgui.popStyleColor(.{ .count = 1 });
    zgui.setNextWindowPos(.{
        .x = pixi.state.settings.sidebar_width * pixi.content_scale[0],
        .y = 0,
        .cond = .always,
    });
    zgui.setNextWindowSize(.{
        .w = pixi.state.settings.explorer_width * pixi.content_scale[0],
        .h = zgui.getWindowSize()[1] * pixi.content_scale[1],
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
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 4.0 * pixi.content_scale[0], 6.0 * pixi.content_scale[1] } });
        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 0.0, 8.0 * pixi.content_scale[1] } });
        defer zgui.popStyleVar(.{ .count = 2 });

        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.separator, .c = pixi.state.style.background.toSlice() });
        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.header, .c = pixi.state.style.foreground.toSlice() });
        defer zgui.popStyleColor(.{ .count = 2 });

        switch (pixi.state.sidebar) {
            .files => {
                if (zgui.beginMenuBar()) {
                    zgui.text("Explorer", .{});
                    if (pixi.state.hotkeys.hotkey(.{ .sidebar = .files })) |hotkey| {
                        zgui.sameLine(.{});
                        zgui.textColored(pixi.state.style.text_background.toSlice(), "({s})", .{hotkey.shortcut});
                    }
                    zgui.endMenuBar();
                }
                zgui.separator();
                files.draw();
            },
            .tools => {
                if (zgui.beginMenuBar()) {
                    zgui.text("Tools", .{});
                    if (pixi.state.hotkeys.hotkey(.{ .sidebar = .tools })) |hotkey| {
                        zgui.sameLine(.{});
                        zgui.textColored(pixi.state.style.text_background.toSlice(), "({s})", .{hotkey.shortcut});
                    }
                    zgui.endMenuBar();
                }
                zgui.separator();
                tools.draw();
            },
            .layers => {
                if (zgui.beginMenuBar()) {
                    zgui.text("Layers", .{});
                    if (pixi.state.hotkeys.hotkey(.{ .sidebar = .layers })) |hotkey| {
                        zgui.sameLine(.{});
                        zgui.textColored(pixi.state.style.text_background.toSlice(), "({s})", .{hotkey.shortcut});
                    }
                    zgui.endMenuBar();
                }
                zgui.separator();
                layers.draw();
            },
            .sprites => {
                if (zgui.beginMenuBar()) {
                    zgui.text("Sprites", .{});
                    if (pixi.state.hotkeys.hotkey(.{ .sidebar = .sprites })) |hotkey| {
                        zgui.sameLine(.{});
                        zgui.textColored(pixi.state.style.text_background.toSlice(), "({s})", .{hotkey.shortcut});
                    }
                    zgui.endMenuBar();
                }
                zgui.separator();
                sprites.draw();
            },
            .animations => {
                if (zgui.beginMenuBar()) {
                    zgui.text("Animations", .{});
                    if (pixi.state.hotkeys.hotkey(.{ .sidebar = .animations })) |hotkey| {
                        zgui.sameLine(.{});
                        zgui.textColored(pixi.state.style.text_background.toSlice(), "({s})", .{hotkey.shortcut});
                    }
                    zgui.endMenuBar();
                }
                zgui.separator();
                animations.draw();
            },
            .pack => {
                if (zgui.beginMenuBar()) {
                    zgui.text("Pack", .{});
                    if (pixi.state.hotkeys.hotkey(.{ .sidebar = .pack })) |hotkey| {
                        zgui.sameLine(.{});
                        zgui.textColored(pixi.state.style.text_background.toSlice(), "({s})", .{hotkey.shortcut});
                    }
                    zgui.endMenuBar();
                }
                zgui.separator();
                pack.draw();
            },
            .settings => {
                if (zgui.beginMenuBar()) {
                    zgui.text("Settings", .{});
                    if (pixi.state.hotkeys.hotkey(.{ .sidebar = .settings })) |hotkey| {
                        zgui.sameLine(.{});
                        zgui.textColored(pixi.state.style.text_background.toSlice(), "({s})", .{hotkey.shortcut});
                    }
                    zgui.endMenuBar();
                }
                zgui.separator();
                settings.draw();
            },
        }
    }

    zgui.end();
}
