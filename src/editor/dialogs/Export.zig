const std = @import("std");
const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");
const zigimg = @import("zigimg");

pub var mode: enum(usize) {
    single,
    animation,
    layer,
    all,
} = .single;

pub var scale: f32 = 1.0;

pub const max_size: [2]u32 = .{ 4096, 4096 };
pub const min_size: [2]u32 = .{ 1, 1 };

pub const max_scale: u32 = 16;
pub const min_scale: u32 = 1;

pub fn dialog(id: dvui.Id) anyerror!bool {
    var outer_box = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both });
    defer outer_box.deinit();

    var valid: bool = true;

    { // Mode selector

        var horizontal_box = dvui.box(@src(), .{ .dir = .horizontal, .equal_space = true }, .{ .expand = .none, .gravity_x = 0.5, .margin = .all(4) });
        defer horizontal_box.deinit();

        const field_names = std.meta.fieldNames(@TypeOf(mode));

        for (field_names, 0..) |tag, i| {
            const corner_radius: dvui.Rect = if (i == 0) .{
                .x = 100000,
                .h = 100000,
            } else if (i == field_names.len - 1) .{
                .y = 100000,
                .w = 100000,
            } else .all(0);

            var name = dvui.currentWindow().arena().dupe(u8, tag) catch {
                dvui.log.err("Failed to dupe tag {s}", .{tag});
                return false;
            };
            @memcpy(name.ptr, tag);
            name[0] = std.ascii.toUpper(name[0]);

            var button: dvui.ButtonWidget = undefined;
            button.init(@src(), .{}, .{
                .corner_radius = corner_radius,
                .id_extra = i,
                .margin = .{ .y = 2, .h = 4 },
                .padding = .all(6),
                .expand = .horizontal,
                .color_fill = if (mode == @as(@TypeOf(mode), @enumFromInt(i))) dvui.themeGet().color(.window, .fill).lighten(-4) else dvui.themeGet().color(.control, .fill),
                .box_shadow = if (i != @intFromEnum(mode)) .{
                    .color = .black,
                    .offset = .{ .x = 0.0, .y = 2 },
                    .fade = 7.0,
                    .alpha = 0.2,
                    .corner_radius = corner_radius,
                    .shrink = 0,
                } else null,
            });
            defer button.deinit();
            if (i != @intFromEnum(mode)) {
                button.processEvents();
            }

            var clip_rect = button.data().rectScale().r;

            clip_rect.y -= 10000;
            clip_rect.h += 20000;

            if (i == 0) {
                clip_rect.x -= 10000;
                clip_rect.w += 10000;
            } else if (i == field_names.len - 1) {
                clip_rect.w += 10000;
            }

            const clip = dvui.clip(clip_rect);
            defer dvui.clipSet(clip);

            button.drawFocus();
            button.drawBackground();

            dvui.labelNoFmt(@src(), name, .{}, .{
                .gravity_x = 0.5,
                .gravity_y = 0.5,
                .color_text = if (mode == @as(@TypeOf(mode), @enumFromInt(i))) dvui.themeGet().color(.window, .text) else dvui.themeGet().color(.control, .text),
                .margin = .all(0),
                .padding = .all(0),
            });

            if (button.clicked()) {
                mode = @enumFromInt(i);
            }
        }
    }

    valid = switch (mode) {
        .single => singleDialog(id) catch false,
        .animation => animationDialog(id) catch false,
        .layer => layerDialog(id) catch false,
        .all => allDialog(id) catch false,
    };

    valid = pixi.editor.activeFile() != null;

    return valid;
}

pub fn singleDialog(_: dvui.Id) anyerror!bool {
    _ = dvui.sliderEntry(@src(), "Scale: {d}", .{ .value = &scale, .min = 1, .max = 16, .interval = 1 }, .{
        .expand = .horizontal,
        .box_shadow = .{
            .color = .black,
            .offset = .{ .x = 0.0, .y = 3 },
            .fade = 5.0,
            .alpha = 0.2,
            .corner_radius = .all(100000),
        },
        .color_fill = dvui.themeGet().color(.window, .fill).lighten(-4),
        .color_fill_hover = dvui.themeGet().color(.window, .fill).lighten(2),
        .corner_radius = .all(100000),
        .margin = .all(6),
    });
    return true;
}

pub fn animationDialog(_: dvui.Id) anyerror!bool {
    _ = dvui.sliderEntry(@src(), "Scale: {d}", .{ .value = &scale, .min = 1, .max = 16, .interval = 1 }, .{
        .expand = .horizontal,
        .box_shadow = .{
            .color = .black,
            .offset = .{ .x = 0.0, .y = 3 },
            .fade = 5.0,
            .alpha = 0.2,
            .corner_radius = .all(100000),
        },
        .corner_radius = .all(100000),
        .margin = .all(6),
    });

    return true;
}

pub fn layerDialog(_: dvui.Id) anyerror!bool {
    return true;
}

pub fn allDialog(_: dvui.Id) anyerror!bool {
    return true;
}

/// Returns a physical rect that the dialog should animate into after closing, or null if the dialog should be removed without animation
pub fn callAfter(_: dvui.Id, response: dvui.enums.DialogResponse) anyerror!void {
    switch (response) {
        .ok => {
            if (mode == .animation) {
                if (pixi.editor.activeFile()) |file| {
                    if (file.animations.len > 0) {
                        if (file.selected_animation_index) |animation_index| {
                            const anim: pixi.Internal.Animation = file.animations.get(animation_index);

                            var image = zigimg.Image.create(pixi.app.allocator, file.column_width, file.row_height, .rgb24) catch {
                                dvui.log.err("Failed to create image", .{});
                                return error.FailedToCreateImage;
                            };
                            defer image.deinit(pixi.app.allocator);

                            for (anim.frames) |sprite_index| {
                                const sprite_rect = file.spriteRect(sprite_index);

                                var layer_index: usize = file.layers.len - 1;
                                while (layer_index > 0) {
                                    layer_index -= 1;
                                    var layer = file.layers.get(layer_index);
                                    if (layer.visible) {
                                        break;
                                    }

                                    if (layer.pixelsFromRect(pixi.app.allocator, sprite_rect)) |pixels| {
                                        _ = pixels;
                                    }
                                    // Now we need to copy these pixels into the image
                                }
                            }
                        }
                    }
                }
            }
        },
        .cancel => {},
        else => {},
    }
}
