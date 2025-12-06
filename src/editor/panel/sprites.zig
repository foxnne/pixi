const std = @import("std");
const icons = @import("icons");
const dvui = @import("dvui");
const pixi = @import("../../pixi.zig");
const Editor = pixi.Editor;

const Sprites = @This();

pub fn draw(_: *Sprites) !void {
    if (pixi.editor.activeFile()) |file| {
        if (dvui.buttonIcon(@src(), "Play", if (file.editor.playing) icons.tvg.lucide.pause else icons.tvg.lucide.play, .{}, .{}, .{
            .expand = .none,
            .corner_radius = dvui.Rect.all(1000),
            .gravity_x = 0.01,
            .gravity_y = 0.01,
            .box_shadow = .{
                .color = .black,
                .offset = .{ .x = -2.0, .y = 2.0 },
                .fade = 6.0,
                .alpha = 0.15,
                .corner_radius = dvui.Rect.all(1000),
            },
            .color_fill = dvui.themeGet().color(.control, .fill),
        })) {
            file.editor.playing = !file.editor.playing;
        }

        var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .none,
            .gravity_x = 0.5,
            .gravity_y = 0.5,
            .border = .all(1),
            .color_border = dvui.themeGet().color(.control, .text),
        });
        defer hbox.deinit();

        if (file.selected_animation_index) |index| {
            const animation = file.animations.get(index);

            var frame_index = file.selected_animation_frame_index;

            if (frame_index >= animation.frames.len) {
                frame_index = 0;
            }
            const frame = animation.frames[frame_index];

            const src_rect = file.spriteRect(frame);

            _ = pixi.dvui.sprite(@src(), .{
                .source = file.layers.items(.source)[file.selected_layer_index],
                .file = file,
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
                    // var found = false;
                    // var i: usize = 0;
                    // while (i > steps.len) {
                    //     const scale = steps[i];
                    //     if ((sprite_h * scale) > target_h) {
                    //         chosen_scale = if (i == 0) 1.0 else steps[i - 1];
                    //         found = true;
                    //         break;
                    //     }
                    //     i += 1;
                    // }
                    // if (!found) {
                    //     chosen_scale = steps[0];
                    // }

                    for (steps, 0..) |zoom, i| {
                        if ((sprite_h * zoom) > target_h) {
                            if (i > 0) {
                                chosen_scale = steps[i - 1];
                                break;
                            }
                            chosen_scale = steps[i];
                            break;
                        }
                    }
                    break :blk chosen_scale;
                },
                // Compute a normalized depth in [-1.0, 1.0] where 0.0 is the center of the viewport
                // .depth = blk: {
                //     const viewport = pixi.editor.panel.scroll_info.viewport;
                //     const cx = viewport.x + viewport.w / 2.0;
                //     const px = hbox.data().rectScale().r.center().x;
                //     break :blk (px - cx) / (viewport.w / 2.0);
                // },
                //.overlap = 0.8,
                .reflection = true,
            }, .{
                .id_extra = index,
                .margin = .all(0),
                .padding = .all(0),
                //.border = .all(1),
                //.color_border = dvui.themeGet().color(.control, .text),
            });
        }
    }

    //     if (file.editor.selected_sprites.count() > 0) {
    //         var iterator = file.editor.selected_sprites.iterator(.{ .kind = .set, .direction = .forward });
    //         while (iterator.next()) |index| {
    //             const src_rect = file.spriteRect(index);

    //             _ = pixi.dvui.sprite(@src(), .{
    //                 .source = file.layers.items(.source)[file.selected_layer_index],
    //                 .alpha_source = file.editor.checkerboard_tile,
    //                 .sprite = .{
    //                     .source = .{
    //                         @intFromFloat(src_rect.x),
    //                         @intFromFloat(src_rect.y),
    //                         @intFromFloat(src_rect.w),
    //                         @intFromFloat(src_rect.h),
    //                     },
    //                     .origin = .{
    //                         0,
    //                         0,
    //                     },
    //                 },
    //                 .scale = blk: {
    //                     const steps = pixi.editor.settings.zoom_steps;
    //                     const target_h = pixi.editor.panel.scroll_info.viewport.h;
    //                     const sprite_h = src_rect.h;
    //                     var chosen_scale: f32 = 1.0;
    //                     var found = false;
    //                     var i: usize = steps.len;
    //                     while (i > 0) : (i -= 1) {
    //                         const scale = steps[i - 1];
    //                         if (sprite_h * scale <= target_h) {
    //                             chosen_scale = scale;
    //                             found = true;
    //                             break;
    //                         }
    //                     }
    //                     if (!found) {
    //                         chosen_scale = steps[0];
    //                     }
    //                     break :blk chosen_scale;
    //                 },
    //                 // Compute a normalized depth in [-1.0, 1.0] where 0.0 is the center of the viewport
    //                 .depth = blk: {
    //                     const viewport = pixi.editor.panel.scroll_info.viewport;
    //                     const cx = viewport.x + viewport.w / 2.0;
    //                     const px = hbox.data().rectScale().r.center().x;
    //                     break :blk (px - cx) / (viewport.w / 2.0);
    //                 },
    //                 .overlap = 0.8,
    //                 .reflection = true,
    //             }, .{
    //                 .id_extra = index,
    //                 .margin = .all(0),
    //                 .padding = .all(0),
    //                 //.border = .all(1),
    //                 //.color_border = dvui.themeGet().color(.control, .text),
    //             });
    //         }
    //     } else {
    //         var index: usize = 0;
    //         while (index < file.spriteCount()) : (index += 1) {
    //             const src_rect = file.spriteRect(index);

    //             _ = pixi.dvui.sprite(@src(), .{
    //                 .source = file.layers.items(.source)[file.selected_layer_index],
    //                 .sprite = .{
    //                     .source = .{
    //                         @intFromFloat(src_rect.x),
    //                         @intFromFloat(src_rect.y),
    //                         @intFromFloat(src_rect.w),
    //                         @intFromFloat(src_rect.h),
    //                     },
    //                     .origin = .{
    //                         0,
    //                         0,
    //                     },
    //                 },
    //                 .scale = blk: {
    //                     const steps = pixi.editor.settings.zoom_steps;
    //                     const target_h = pixi.editor.panel.scroll_info.viewport.h;
    //                     const sprite_h = src_rect.h;
    //                     var chosen_scale: f32 = 1.0;
    //                     var found = false;
    //                     var i: usize = steps.len;
    //                     while (i > 0) : (i -= 1) {
    //                         const scale = steps[i - 1];
    //                         if (sprite_h * scale <= target_h) {
    //                             chosen_scale = scale;
    //                             found = true;
    //                             break;
    //                         }
    //                     }
    //                     if (!found) {
    //                         chosen_scale = steps[0];
    //                     }
    //                     break :blk chosen_scale;
    //                 },
    //                 .depth = 0.25,
    //             }, .{
    //                 .id_extra = index,
    //                 .padding = .all(0),
    //                 .margin = .all(0),
    //             });
    //         }
    //     }
    // }
}
