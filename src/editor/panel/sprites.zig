const std = @import("std");

const dvui = @import("dvui");
const pixi = @import("../../pixi.zig");
const Editor = pixi.Editor;

const sprites = @This();

pub fn draw() !void {
    if (pixi.editor.activeFile()) |file| {
        var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .none,
            .gravity_x = 0.5,
            .gravity_y = 0.5,
            .border = .all(1),
            .color_border = dvui.themeGet().color(.control, .text),
        });
        defer hbox.deinit();

        if (file.editor.selected_sprites.count() > 0) {
            var iterator = file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
            while (iterator.next()) |index| {
                const src_rect = file.spriteRect(index);

                _ = pixi.dvui.sprite(@src(), .{
                    .source = file.layers.items(.source)[file.selected_layer_index],
                    .alpha_source = file.editor.checkerboard_tile,
                    .sprite = .{
                        .source = .{
                            @intFromFloat(src_rect.x),
                            @intFromFloat(src_rect.y),
                            @intFromFloat(src_rect.w),
                            @intFromFloat(src_rect.h),
                        },
                        .origin = .{
                            0,
                            0,
                        },
                    },
                    .scale = blk: {
                        const steps = pixi.editor.settings.zoom_steps;
                        const target_h = pixi.editor.panel.scroll_info.viewport.h;
                        const sprite_h = src_rect.h;
                        var chosen_scale: f32 = 1.0;
                        var found = false;
                        var i: usize = steps.len;
                        while (i > 0) : (i -= 1) {
                            const scale = steps[i - 1];
                            if (sprite_h * scale <= target_h) {
                                chosen_scale = scale;
                                found = true;
                                break;
                            }
                        }
                        if (!found) {
                            chosen_scale = steps[0];
                        }
                        break :blk chosen_scale;
                    },
                    // Compute a normalized depth in [-1.0, 1.0] where 0.0 is the center of the viewport
                    .depth = blk: {
                        const viewport = pixi.editor.panel.scroll_info.viewport;
                        const cx = viewport.x + viewport.w / 2.0;
                        const px = hbox.data().rectScale().r.center().x;
                        break :blk (px - cx) / (viewport.w / 2.0);
                    },
                    .overlap = 0.8,
                    .reflection = true,
                }, .{
                    .id_extra = index,
                    .margin = .all(0),
                    .padding = .all(0),
                    //.border = .all(1),
                    //.color_border = dvui.themeGet().color(.control, .text),
                });
            }
        } else {
            var index: usize = 0;
            while (index < file.spriteCount()) : (index += 1) {
                const src_rect = file.spriteRect(index);

                _ = pixi.dvui.sprite(@src(), .{
                    .source = file.layers.items(.source)[file.selected_layer_index],
                    .sprite = .{
                        .source = .{
                            @intFromFloat(src_rect.x),
                            @intFromFloat(src_rect.y),
                            @intFromFloat(src_rect.w),
                            @intFromFloat(src_rect.h),
                        },
                        .origin = .{
                            0,
                            0,
                        },
                    },
                    .scale = blk: {
                        const steps = pixi.editor.settings.zoom_steps;
                        const target_h = pixi.editor.panel.scroll_info.viewport.h;
                        const sprite_h = src_rect.h;
                        var chosen_scale: f32 = 1.0;
                        var found = false;
                        var i: usize = steps.len;
                        while (i > 0) : (i -= 1) {
                            const scale = steps[i - 1];
                            if (sprite_h * scale <= target_h) {
                                chosen_scale = scale;
                                found = true;
                                break;
                            }
                        }
                        if (!found) {
                            chosen_scale = steps[0];
                        }
                        break :blk chosen_scale;
                    },
                    .depth = 0.25,
                }, .{
                    .id_extra = index,
                    .padding = .all(0),
                    .margin = .all(0),
                });
            }
        }
    }
}
