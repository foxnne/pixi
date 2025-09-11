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

    {
        var button = dvui.ButtonWidget.init(@src(), .{}, .{ .gravity_y = 0.5, .margin = .all(0), .padding = .all(0) });
        button.install();
        button.processEvents();
        button.drawBackground();
        defer button.deinit();

        var box = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal, .margin = .all(0), .padding = .all(0) });
        defer box.deinit();

        dvui.icon(
            @src(),
            "info_icon",
            icons.tvg.entypo.@"info-circled",
            .{ .fill_color = dvui.themeGet().color(.window, .text) },
            .{ .gravity_y = 0.5, .padding = .{
                .x = 4,
            } },
        );
        dvui.label(@src(), "Pixi", .{}, .{ .font_style = .caption_heading, .gravity_y = 0.5, .margin = .all(0) });
    }

    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 12 } });

    if (pixi.editor.folder) |folder| {
        dvui.icon(
            @src(),
            "project_icon",
            icons.tvg.lucide.book,
            .{ .stroke_color = dvui.themeGet().color(.window, .text) },
            .{ .gravity_y = 0.5 },
        );
        dvui.label(@src(), "{s}", .{std.fs.path.basename(folder)}, .{ .font_style = .caption_heading, .gravity_y = 0.5 });
    }

    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 12 } });

    if (pixi.editor.activeFile()) |file| {
        dvui.icon(
            @src(),
            "file_icon",
            icons.tvg.lucide.file,
            .{ .stroke_color = dvui.themeGet().color(.window, .text) },
            .{ .gravity_y = 0.5 },
        );
        dvui.label(@src(), "{s}", .{std.fs.path.basename(file.path)}, .{ .font_style = .caption_heading, .gravity_y = 0.5 });

        _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 12 } });

        dvui.icon(
            @src(),
            "width_icon",
            icons.tvg.lucide.@"ruler-dimension-line",
            .{ .stroke_color = dvui.themeGet().color(.window, .text) },
            .{ .gravity_y = 0.5 },
        );
        dvui.label(@src(), "{d}x{d} - {d}x{d}", .{ file.width, file.height, file.tile_width, file.tile_height }, .{ .font_style = .caption_heading, .gravity_y = 0.5 });

        _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 12 } });

        dvui.icon(
            @src(),
            "mouse_icon",
            icons.tvg.lucide.@"mouse-pointer",
            .{ .stroke_color = dvui.themeGet().color(.window, .text) },
            .{ .gravity_y = 0.5 },
        );

        const mouse_pt = dvui.currentWindow().mouse_pt;
        const data_pt = file.editor.canvas.dataFromScreenPoint(mouse_pt);
        const sprite_pt = file.spritePoint(data_pt);
        dvui.label(@src(), "{d:0.0},{d:0.0} - {d:0.0},{d:0.0}", .{ @floor(data_pt.x), @floor(data_pt.y), @floor(sprite_pt.x / @as(f32, @floatFromInt(file.tile_width))), @floor(sprite_pt.y / @as(f32, @floatFromInt(file.tile_height))) }, .{ .font_style = .caption_heading, .gravity_y = 0.5 });
    }
}
