const std = @import("std");
const pixi = @import("../pixi.zig");
const dvui = @import("dvui");
const App = pixi.App;
const Editor = pixi.Editor;

const Pane = @import("explorer/Explorer.zig").Pane;

pub const Sidebar = @This();

pub fn init() !Sidebar {
    return .{};
}

pub fn deinit() void {
    // TODO: Free memory
}

pub fn draw(_: Sidebar) !dvui.App.Result {
    const vbox = dvui.box(@src(), .vertical, .{
        .expand = .vertical,
        .background = false,
        .min_size_content = .{ .w = 40, .h = 100 },
    });
    defer vbox.deinit();

    const options = [_]struct { pane: Pane, icon: []const u8 }{
        .{ .pane = .files, .icon = dvui.entypo.folder },
        .{ .pane = .tools, .icon = dvui.entypo.pencil },
        .{ .pane = .sprites, .icon = dvui.entypo.grid },
        .{ .pane = .animations, .icon = dvui.entypo.controller_play },
        .{ .pane = .keyframe_animations, .icon = dvui.entypo.key },
        .{ .pane = .project, .icon = dvui.entypo.box },
        .{ .pane = .settings, .icon = dvui.entypo.cog },
    };

    for (options) |option| {
        try drawOption(option.pane, option.icon, 20);
    }

    return .ok;
}

fn drawOption(option: Pane, icon: []const u8, size: f32) !void {
    const selected = option == pixi.editor.explorer.pane;

    const theme = dvui.themeGet();

    var bw = dvui.ButtonWidget.init(@src(), .{}, .{
        .id_extra = @intFromEnum(option),
        .min_size_content = .{ .h = size },
        .color_fill_hover = .fill_window,
    });
    defer bw.deinit();
    bw.install();
    bw.processEvents();
    //try bw.drawBackground();

    const color: dvui.Color = if (selected) theme.color_accent else if (bw.hovered()) theme.color_text else theme.color_fill_hover;

    dvui.icon(
        @src(),
        @tagName(option),
        icon,
        .{ .fill_color = color },
        .{
            .min_size_content = .{ .h = size },
        },
    );

    if (bw.clicked()) {
        pixi.editor.explorer.pane = option;
    }

    if (selected) return;

    var tooltip: dvui.FloatingTooltipWidget = .init(@src(), .{
        .active_rect = bw.data().rectScale().r,
    }, .{
        .id_extra = @intFromEnum(option),
        .color_fill = .fill_window,
        .border = dvui.Rect.all(0),
        .box_shadow = .{
            .color = .{ .color = .black },
            .shrink = 0,
            .corner_radius = dvui.Rect.all(8),
            .offset = .{ .x = 0, .y = 2 },
            .fade = 8,
            .alpha = 0.2,
        },
    });
    defer tooltip.deinit();

    if (tooltip.shown()) {
        var animator = dvui.animate(@src(), .{
            .kind = .alpha,
            .duration = 350_000,
        }, .{
            .expand = .both,
        });
        defer animator.deinit();

        var vbox2 = dvui.box(@src(), .vertical, dvui.FloatingTooltipWidget.defaults.override(.{
            .background = false,
            .expand = .both,
            .border = dvui.Rect.all(0),
        }));
        defer vbox2.deinit();

        var tl2 = dvui.textLayout(@src(), .{}, .{
            .background = false,
            .padding = dvui.Rect.all(4),
        });
        tl2.format("{s}", .{pixi.Editor.Explorer.title(option, false)}, .{
            .font_style = .caption,
        });
        tl2.deinit();
    }
}
