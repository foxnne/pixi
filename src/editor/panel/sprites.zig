const std = @import("std");
const icons = @import("icons");
const dvui = @import("dvui");
const pixi = @import("../../pixi.zig");
const Editor = pixi.Editor;

const Sprites = @This();

var prev_scale: f32 = 1.0;
var current_scale: f32 = 1.0;

pub fn draw(self: *Sprites) !void {
    if (pixi.editor.activeFile()) |file| {
        self.drawAnimationControlsDialog();

        // Since not all panel screens will likely want shadows, which should be reserved for canvases?
        // Text editors, consoles, etc would likely want flat panels or to handle shadows themselves.
        defer {
            pixi.dvui.drawEdgeShadow(dvui.parentGet().data().rectScale(), .top, .{ .opacity = 0.15 });
            pixi.dvui.drawEdgeShadow(dvui.parentGet().data().rectScale(), .bottom, .{ .opacity = 0.15 });
            pixi.dvui.drawEdgeShadow(dvui.parentGet().data().rectScale(), .left, .{ .opacity = 0.15 });
            pixi.dvui.drawEdgeShadow(dvui.parentGet().data().rectScale(), .right, .{ .opacity = 0.15 });
        }

        const mouse_data_point = file.editor.canvas.dataFromScreenPoint(dvui.currentWindow().mouse_pt);

        const parent = dvui.parentGet().data().rect;
        const parent_height = parent.h;

        var index: usize = 0;
        var src_rect = file.spriteRect(index); // Default to the first sprite

        if (file.editor.playing or file.editor.canvas.hovered() == null) {
            if (file.selected_animation_index) |i| {
                index = i;
                const animation = file.animations.get(index);
                const frame_index = file.selected_animation_frame_index;

                if (frame_index < animation.frames.len) {
                    const sprite_index = animation.frames[frame_index];
                    src_rect = file.spriteRect(sprite_index);
                }
            }
        } else if (file.spriteIndex(mouse_data_point)) |sprite_index| {
            src_rect = file.spriteRect(sprite_index);
            index = sprite_index;
        }

        const scale = blk: {
            const steps = pixi.editor.settings.zoom_steps;
            const target_size = @min(parent.h, parent.w);
            const sprite_size = @max(src_rect.h, src_rect.w);
            var target_scale: f32 = 1.0;
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
                if ((sprite_size * 1.2 * zoom) >= target_size) {
                    if (i > 0) {
                        target_scale = steps[i - 1];
                        break;
                    }
                    target_scale = steps[i];
                    break;
                }
            }

            if (target_scale != current_scale) {
                if (dvui.animationGet(dvui.parentGet().data().id, "scale")) |a| {
                    if (a.done()) {
                        current_scale = target_scale;
                        prev_scale = current_scale;
                    } else {
                        if (a.end_val != target_scale) {
                            _ = dvui.currentWindow().animations.remove(dvui.parentGet().data().id.update("scale"));
                            dvui.animation(dvui.parentGet().data().id, "scale", .{
                                .end_time = 600_000,
                                .easing = dvui.easing.outBack,
                                .start_val = a.value(),
                                .end_val = target_scale,
                            });
                        } else {
                            current_scale = a.value();
                        }
                    }
                } else {
                    prev_scale = current_scale;
                    dvui.animation(dvui.parentGet().data().id, "scale", .{
                        .end_time = 600_000,
                        .easing = dvui.easing.outBack,
                        .start_val = prev_scale,
                        .end_val = target_scale,
                    });
                }
            }

            break :blk current_scale;
        };

        var rect = dvui.Rect{
            .x = parent.center().x,
            .y = parent.center().y,
            .w = @as(f32, @floatFromInt(file.tile_width)) * scale,
            .h = @as(f32, @floatFromInt(file.tile_height)) * scale,
        };

        rect.x -= rect.w / 2.0;
        rect.y -= rect.h / 2.0;

        var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .none,
            .rect = rect,
            .border = .all(0),
            .color_border = dvui.themeGet().color(.control, .text),
            .box_shadow = .{
                .color = .black,
                .offset = .{ .x = 0.0, .y = 8.0 },
                .fade = 12.0,
                .alpha = 0.25,
                .corner_radius = dvui.Rect.all(parent_height / 32.0),
            },
        });
        defer hbox.deinit();

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
            .scale = scale,
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

pub fn drawAnimationControlsDialog(_: *Sprites) void {
    if (pixi.editor.activeFile()) |file| {
        if (file.selected_animation_index) |_| {
            var rect = dvui.parentGet().data().rectScale().r;

            if (dvui.parentGet().data().rect.h < 48.0) {
                return;
            }

            var fw: dvui.FloatingWidget = undefined;
            fw.init(@src(), .{}, .{
                .rect = .{ .x = rect.toNatural().x + 10, .y = rect.toNatural().y + 10, .w = 0, .h = 0 },
                .expand = .none,
                .background = true,
                .color_fill = dvui.themeGet().color(.control, .fill),
                .corner_radius = dvui.Rect.all(8),
                .box_shadow = .{
                    .color = .black,
                    .alpha = 0.2,
                    .fade = 8,
                    .corner_radius = dvui.Rect.all(8),
                },
            });
            defer fw.deinit();

            var anim = dvui.animate(@src(), .{ .kind = .vertical, .duration = 450_000, .easing = dvui.easing.outBack }, .{});
            defer anim.deinit();

            var anim_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .expand = .both,
                .background = false,
            });
            defer anim_box.deinit();

            {
                if (dvui.buttonIcon(@src(), "Play", if (file.editor.playing) icons.tvg.entypo.pause else icons.tvg.entypo.play, .{}, .{}, .{
                    .expand = .ratio,
                    .corner_radius = dvui.Rect.all(1000),
                    .box_shadow = .{
                        .color = .black,
                        .offset = .{ .x = -2.0, .y = 2.0 },
                        .fade = 6.0,
                        .alpha = 0.15,
                        .corner_radius = dvui.Rect.all(1000),
                    },
                    .color_fill = dvui.themeGet().color(.control, .fill),
                    .min_size_content = .{ .w = 0.0, .h = 12.0 },
                })) {
                    file.editor.playing = !file.editor.playing;
                }
            }

            // dvui.labelNoFmt(@src(), "TRANSFORM", .{ .align_x = 0.5 }, .{
            //     .padding = dvui.Rect.all(4),
            //     .expand = .horizontal,
            //     .font_style = .title_4,
            // });
            // _ = dvui.separator(@src(), .{ .expand = .horizontal });

            // _ = dvui.spacer(@src(), .{ .expand = .horizontal });

            // var degrees: f32 = std.math.radiansToDegrees(transform.rotation);

            // var slider_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
            //     .expand = .horizontal,
            //     .background = false,
            // });

            // if (dvui.sliderEntry(@src(), "{d:0.0}°", .{
            //     .value = &degrees,
            //     .min = 0,
            //     .max = 360,
            //     .interval = 1,
            // }, .{ .expand = .horizontal, .color_fill = dvui.themeGet().color(.window, .fill) })) {
            //     transform.rotation = std.math.degreesToRadians(degrees);
            // }
            // slider_box.deinit();

            // if (transform.ortho) {
            //     var box = dvui.box(@src(), .{ .dir = .horizontal, .equal_space = true }, .{
            //         .expand = .horizontal,
            //         .background = false,
            //     });
            //     defer box.deinit();
            //     dvui.label(@src(), "Width: {d:0.0}", .{transform.point(.bottom_left).diff(transform.point(.bottom_right).*).length()}, .{ .expand = .horizontal, .font_style = .heading });
            //     dvui.label(@src(), "Height: {d:0.0}", .{transform.point(.top_left).diff(transform.point(.bottom_left).*).length()}, .{ .expand = .horizontal, .font_style = .heading });
            // }

            // {
            //     var box = dvui.box(@src(), .{ .dir = .horizontal, .equal_space = true }, .{
            //         .expand = .horizontal,
            //         .background = false,
            //     });
            //     defer box.deinit();
            //     if (dvui.buttonIcon(@src(), "transform_cancel", icons.tvg.lucide.@"trash-2", .{}, .{ .stroke_color = dvui.themeGet().color(.window, .fill) }, .{ .style = .err, .expand = .horizontal })) {
            //         transform.cancel();
            //     }
            //     if (dvui.buttonIcon(@src(), "transform_accept", icons.tvg.lucide.check, .{}, .{ .stroke_color = dvui.themeGet().color(.window, .fill) }, .{ .style = .highlight, .expand = .horizontal })) {
            //         transform.accept();
            //     }
            // }
        }
    }
}
