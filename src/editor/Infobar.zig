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
        .padding = .all(0),
        .margin = .all(0),
    });
    defer infobox.deinit();

    if (dvui.buttonIcon(
        @src(),
        "info_icon",
        icons.tvg.lucide.info,
        .{},
        .{ .stroke_color = dvui.themeGet().color(.window, .text) },
        .{
            .gravity_y = 0.5,
            .margin = .all(0),
        },
    )) {}
    dvui.label(@src(), "Pixi", .{}, .{ .font_style = .caption, .gravity_y = 0.5, .padding = .all(0), .margin = .all(0) });

    if (pixi.editor.folder) |folder| {
        dvui.icon(
            @src(),
            "Info Bar",
            icons.tvg.lucide.book,
            .{ .stroke_color = dvui.themeGet().color(.window, .text) },
            .{ .gravity_y = 0.5 },
        );
        dvui.label(@src(), "{s}", .{std.fs.path.basename(folder)}, .{ .font_style = .caption, .gravity_y = 0.5 });
    }
}
