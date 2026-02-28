const builtin = @import("builtin");
const std = @import("std");

const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");
// const Core = @import("mach").Core;
const Editor = pixi.Editor;

const nfd = @import("nfd");
// const imgui = @import("zig-imgui");

pub fn draw() !void {
    var vbox = dvui.box(@src(), .{ .dir = .vertical }, .{});
    defer vbox.deinit();

    if (dvui.Theme.picker(@src(), pixi.editor.themes.items, .{})) {}

    if (true) {
        if (dvui.sliderEntry(@src(), "Window Opacity: {d:0.01}", .{
            .value = &pixi.editor.settings.window_opacity,
            .interval = 0.01,
            .max = 1.0,
            .min = 0.0,
        }, .{
            .expand = .none,
        })) {
            pixi.backend.setTitlebarColor(dvui.currentWindow(), dvui.themeGet().color(.content, .fill).opacity(pixi.editor.settings.window_opacity));
            dvui.refresh(null, @src(), vbox.data().id);
        }

        if (dvui.sliderEntry(@src(), "Content Opacity: {d:0.01}", .{
            .value = &pixi.editor.settings.content_opacity,
            .interval = 0.01,
            .max = 1.0,
            .min = 0.0,
        }, .{
            .expand = .none,
        })) {
            pixi.backend.setTitlebarColor(dvui.currentWindow(), dvui.themeGet().color(.content, .fill).opacity(pixi.editor.settings.content_opacity));
            dvui.refresh(null, @src(), vbox.data().id);
        }
    }

    dvui.label(@src(), "{d:0>3.0} fps", .{dvui.FPS()}, .{});
}
