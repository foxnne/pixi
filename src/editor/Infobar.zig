const std = @import("std");
const pixi = @import("../pixi.zig");
const dvui = @import("dvui");
const icons = @import("icons");
const App = pixi.App;
const Editor = pixi.Editor;

pub const Infobar = @This();

pub fn init() !Infobar {
    return .{};
}

pub fn deinit() void {
    // TODO: Free memory
}

pub fn draw(_: Infobar) !void {
    var scrollarea = dvui.scrollArea(@src(), .{}, .{
        .expand = .horizontal,
        .background = true,
        .color_fill = dvui.themeGet().color(.control, .fill),
        .gravity_y = 1.0,
        .padding = .all(0),
        .margin = .all(0),
    });
    defer scrollarea.deinit();
    var infobox = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .background = false,
        .gravity_y = 1.0,
        .padding = .all(0),
        .margin = .all(0),
    });
    defer infobox.deinit();

    {
        var highlight_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .vertical,
            .background = true,
            .color_fill = dvui.themeGet().color(.highlight, .fill),
            .padding = .all(0),
            .margin = .all(0),
        });
        defer highlight_box.deinit();

        _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 8 } });
        dvui.icon(
            @src(),
            "Info Bar",
            icons.tvg.lucide.info,
            .{ .stroke_color = dvui.themeGet().color(.window, .fill) },
            .{
                .gravity_y = 0.5,
                .expand = .vertical,
            },
        );
        _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 8 } });
    }
}
