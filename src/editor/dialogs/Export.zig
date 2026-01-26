const std = @import("std");
const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");
const zigimg = @import("zigimg");
const msf_gif = @import("msf_gif");

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
                if (dvui.native_dialogs.Native.save(
                    dvui.currentWindow().arena(),
                    .{ .title = "Export Animation", .path = "untitled.gif" },
                ) catch null) |path| {
                    if (pixi.editor.activeFile()) |file| {
                        if (file.animations.len > 0) {
                            if (file.selected_animation_index) |animation_index| {
                                const anim: pixi.Internal.Animation = file.animations.get(animation_index);

                                var export_width = file.column_width;
                                var export_height = file.row_height;

                                if (scale != 1.0) {
                                    export_width = @intFromFloat(@as(f32, @floatFromInt(file.column_width)) * scale);
                                    export_height = @intFromFloat(@as(f32, @floatFromInt(file.row_height)) * scale);
                                }

                                var handle: msf_gif.MSFGifState = undefined;
                                _ = msf_gif.begin(&handle, export_width, export_height);

                                msf_gif.msf_gif_alpha_threshold = 10;

                                for (anim.frames) |sprite_index| {
                                    const sprite_rect = file.spriteRect(sprite_index);
                                    const layer = file.layers.get(0);

                                    const pixels = layer.pixelsFromRect(dvui.currentWindow().arena(), sprite_rect) orelse continue;

                                    if (scale != 1.0) {
                                        const triangles = dvui.Path.fillConvexTriangles(.{
                                            .points = &[_]dvui.Point.Physical{
                                                .{ .x = 0, .y = 0 },
                                                .{ .x = @as(f32, @floatFromInt(file.column_width)) * scale, .y = 0 },
                                                .{ .x = @as(f32, @floatFromInt(file.column_width)) * scale, .y = @as(f32, @floatFromInt(file.row_height)) * scale },
                                                .{ .x = 0, .y = @as(f32, @floatFromInt(file.row_height)) * scale },
                                            },
                                        }, dvui.currentWindow().arena(), .{
                                            .color = .white,
                                            .fade = 0.0,
                                        }) catch {
                                            dvui.log.err("Failed to fill convex triangles", .{});
                                            continue;
                                        };

                                        // Here pass in the data rect, since we will be rendering directly to the low-res texture
                                        const target_texture = dvui.textureCreateTarget(export_width, export_height, .nearest) catch {
                                            std.log.err("Failed to create target texture", .{});
                                            return;
                                        };

                                        defer {
                                            const texture: ?dvui.Texture = dvui.textureFromTarget(target_texture) catch null;
                                            if (texture) |t| {
                                                dvui.textureDestroyLater(t);
                                            }
                                        }

                                        // This is the previous target, we will be setting this back
                                        const previous_target = dvui.renderTarget(.{ .texture = target_texture, .offset = .{ .x = 0, .y = 0 } });

                                        // Make sure we clip to the image rect, if we don't  and the texture overlaps the canvas,
                                        // the rendering will be clipped incorrectly
                                        // Use clipSet instead of clip, clip unions with current clip
                                        const clip_rect: dvui.Rect.Physical = .{ .x = 0, .y = 0, .w = @as(f32, @floatFromInt(export_width)), .h = @as(f32, @floatFromInt(export_height)) };
                                        const prev_clip = dvui.clipGet();
                                        dvui.clipSet(clip_rect);

                                        // Set UVs, there are 5 vertexes, or 1 more than the number of triangles, and is at the center

                                        triangles.vertexes[0].uv = .{ 0.0, 0.0 }; // TL
                                        triangles.vertexes[1].uv = .{ 1.0, 0.0 }; // TR
                                        triangles.vertexes[2].uv = .{ 1.0, 1.0 }; // BR
                                        triangles.vertexes[3].uv = .{ 0.0, 1.0 }; // BL

                                        const new_texture_source = pixi.image.fromPixelsPMA(@as([*]dvui.Color.PMA, @ptrCast(pixels.ptr))[0..@intCast(pixels.len)], file.column_width, file.row_height, .ptr) catch {
                                            std.log.err("Failed to create new texture", .{});
                                            return;
                                        };

                                        // Render the triangles to the target texture
                                        dvui.renderTriangles(triangles, new_texture_source.getTexture() catch null) catch {
                                            std.log.err("Failed to render triangles", .{});
                                        };

                                        // Restore the previous clip
                                        dvui.clipSet(prev_clip);
                                        // Set the target back
                                        _ = dvui.renderTarget(previous_target);

                                        // Read the target texture and copy it to the selection layer
                                        if (dvui.textureReadTarget(dvui.currentWindow().arena(), target_texture) catch null) |image_data| {
                                            _ = msf_gif.frame(&handle, @ptrCast(image_data.ptr), @intFromFloat(anim.fps / 100));
                                        } else {
                                            std.log.err("Failed to read target", .{});
                                        }
                                    } else {
                                        _ = msf_gif.frame(&handle, @ptrCast(pixels.ptr), @intFromFloat(anim.fps / 100));
                                    }
                                }

                                const result = msf_gif.end(&handle);
                                defer msf_gif.free(result);

                                // // Now write to file using the new Writer interface
                                var output_file = try std.fs.cwd().createFile(path, .{});
                                defer output_file.close();

                                if (result.data) |data| {
                                    try output_file.writeAll(data[0..result.dataSize]);
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
