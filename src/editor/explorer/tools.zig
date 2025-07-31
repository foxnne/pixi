const std = @import("std");
const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");

pub fn draw() !void {
    const toolbox = dvui.flexbox(@src(), .{}, .{
        .expand = .horizontal,
        .max_size_content = .{ .w = pixi.editor.explorer.scroll_info.viewport.w - 10, .h = std.math.floatMax(f32) },
        .gravity_x = 0.5,
    });
    defer toolbox.deinit();

    drawTools() catch {};
}

pub fn drawTools() !void {
    for (0..std.meta.fields(pixi.Editor.Tools.Tool).len) |i| {
        const tool: pixi.Editor.Tools.Tool = @enumFromInt(i);
        const id_extra = i;

        var color = dvui.themeGet().color_fill_hover;
        if (pixi.editor.colors.file_tree_palette) |*palette| {
            color = palette.getDVUIColor(i);
        }

        const sprite = switch (tool) {
            .pointer => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.dropper_default],
            .pencil => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.pencil_default],
            .eraser => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.eraser_default],
            .bucket => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.bucket_default],
            .selection => pixi.editor.atlas.data.sprites[pixi.atlas.sprites.selection_default],
        };
        var button = dvui.ButtonWidget.init(@src(), .{}, .{
            .expand = .none,
            .min_size_content = .{ .w = 32, .h = 32 },
            .id_extra = id_extra,
            .background = true,
            .corner_radius = dvui.Rect.all(1000),
            .color_fill = if (pixi.editor.tools.current == tool) .fill_hover else .fill_window,
            .color_fill_hover = .fill,
            .color_fill_press = .fill_hover,
            .box_shadow = if (pixi.editor.tools.current == tool) null else .{
                .color = .black,
                .offset = .{ .x = 0, .y = 0 },
                .fade = 8.0,
                .alpha = 0.15,
            },
            .border = dvui.Rect.all(1.0),
            .color_border = .{ .color = color },
        });
        defer button.deinit();

        const size: dvui.Size = dvui.imageSize(pixi.editor.atlas.source) catch .{ .w = 0, .h = 0 };

        const uv = dvui.Rect{
            .x = @as(f32, @floatFromInt(sprite.source[0])) / size.w,
            .y = @as(f32, @floatFromInt(sprite.source[1])) / size.h,
            .w = @as(f32, @floatFromInt(sprite.source[2])) / size.w,
            .h = @as(f32, @floatFromInt(sprite.source[3])) / size.h,
        };

        button.install();
        button.processEvents();
        button.drawBackground();

        var rs = button.data().contentRectScale();

        const width = @as(f32, @floatFromInt(sprite.source[2])) * rs.s;
        const height = @as(f32, @floatFromInt(sprite.source[3])) * rs.s;

        rs.r.x += (rs.r.w - width) / 2.0;
        rs.r.y += (rs.r.h - height) / 2.0;
        rs.r.w = width;
        rs.r.h = height;

        dvui.renderImage(pixi.editor.atlas.source, rs, .{
            .uv = uv,
        }) catch {
            std.log.err("Failed to render image", .{});
        };

        if (button.clicked()) {
            pixi.editor.tools.set(tool);
        }
    }
}
