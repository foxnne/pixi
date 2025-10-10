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
        });
        defer hbox.deinit();

        if (file.editor.selected_sprites.count() > 0) {
            var iterator = file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
            while (iterator.next()) |index| {
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
                    //.margin = .all(6),
                    .padding = .all(0),
                    //.border = .all(1),
                    //.color_border = dvui.themeGet().color(.control, .text),
                });
            }
        } else {
            var index: usize = 0;
            while (index < file.spriteCount()) : (index += 1) {
                const src_rect = file.spriteRect(index);

                var center_rect = dvui.Rect.fromSize(.{ .w = src_rect.w, .h = src_rect.h });
                center_rect.x = (pixi.editor.panel.scroll_info.viewport.w / 2 - center_rect.w / 2) + pixi.editor.panel.scroll_info.offset(.horizontal);
                center_rect.y = pixi.editor.panel.scroll_info.viewport.h / 2 - center_rect.h / 2;

                const center_screen: dvui.Rect.Physical = hbox.data().rectScale().rectToPhysical(center_rect);
                center_screen.stroke(dvui.Rect.Physical.all(0), .{
                    .thickness = 1,
                    .color = dvui.themeGet().color(.highlight, .fill),
                });

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
                }, .{
                    .id_extra = index,
                    .padding = .all(0),
                    .margin = .all(6),
                    .border = .all(1),
                    .color_border = dvui.themeGet().color(.control, .text),
                });
            }
        }
    }
}
