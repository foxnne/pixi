const std = @import("std");
const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");
const zigimg = @import("zigimg");
const msf_gif = @import("msf_gif");
const sdl3 = @import("backend").c;
const zstbi = @import("zstbi");

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
pub fn callAfter(id: dvui.Id, response: dvui.enums.DialogResponse) anyerror!void {
    switch (response) {
        .ok => {
            switch (mode) {
                .animation => {
                    const default = blk: {
                        const file = pixi.editor.activeFile() orelse {
                            break :blk "animation.gif";
                        };

                        const default_filename: [:0]const u8 = std.fmt.allocPrintSentinel(pixi.app.allocator, "{s}.gif", .{
                            if (file.selected_animation_index) |animation_index| file.animations.items(.name)[animation_index] else "animation",
                        }, 0) catch {
                            dvui.log.err("Failed to allocate filename", .{});
                            return;
                        };

                        break :blk default_filename;
                    };

                    if (dvui.dialogNativeFileSave(pixi.app.allocator, .{ .title = "Save Animation", .path = default }) catch null) |path| {
                        createAnimationGif(path) catch {
                            dvui.log.err("Failed to save animation", .{});
                            return;
                        };
                    }
                },
                else => {},
            }
        },
        .cancel => {},
        else => {},
    }

    // We always want to remove the dialog, this will likely be hidden behind the save file dialog
    dvui.dialogRemove(id);
}

// This is for use with the SDL dialogs, but currently the SDL dialogs dont support sending the default path
// on macOS, so we are going to use the native dialogs instead.
pub fn saveAnimationCallback(paths: ?[][:0]const u8) void {
    if (paths) |paths_| {
        for (paths_) |path| {
            createAnimationGif(path);
        }
    }
}

pub fn createAnimationGif(path: []const u8) anyerror!void {
    const ext = std.fs.path.extension(path);
    const is_gif = std.mem.eql(u8, ext, ".gif");

    if (!is_gif) {
        dvui.log.err("Export: File must end with .gif extension, got {s}", .{ext});
        return error.InvalidExtension;
    }

    var file = pixi.editor.activeFile() orelse {
        dvui.log.err("Export: No active file", .{});
        return error.NoActiveFile;
    };

    if (file.animations.len == 0) {
        dvui.log.err("Export: No animations in file", .{});
        return error.NoAnimations;
    }

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

        // Anything less than this number will be considered transparent
        // When resizing, sometimes we see a small outline of the pixels?
        // Only see in some gif readers, but not all.
        msf_gif.msf_gif_alpha_threshold = 240;

        for (anim.frames) |sprite_index| {
            const sprite_rect = file.spriteRect(sprite_index);

            var layer_index = file.layers.len - 1;
            const pixels = file.layers.get(layer_index).pixelsFromRect(pixi.app.allocator, sprite_rect) orelse continue;
            defer pixi.app.allocator.free(pixels);

            if (file.layers.len > 1) {
                layer_index -= 1;

                while (layer_index > 0) {
                    const layer = file.layers.get(layer_index);
                    if (!layer.visible) {
                        break;
                    }

                    if (layer.pixelsFromRect(pixi.app.allocator, sprite_rect)) |layer_pixels| {
                        pixi.image.blitData(pixels, @intFromFloat(sprite_rect.w), @intFromFloat(sprite_rect.h), layer_pixels, sprite_rect.justSize(), true);
                        pixi.app.allocator.free(layer_pixels);
                    }

                    layer_index -= 1;
                }
            }

            { // msf_gif will error if there are only transparent pixels
                const valid = blk: {
                    for (pixels) |pixel| {
                        if (pixel[3] > msf_gif.msf_gif_alpha_threshold) {
                            break :blk true;
                        }
                    }

                    break :blk false;
                };

                if (!valid) {
                    dvui.log.debug("Export: No valid pixels, skipping animation frame", .{});
                    continue;
                }
            }

            if (scale != 1.0) {
                const resized_pixels = pixi.app.allocator.alloc([4]u8, export_width * export_height) catch {
                    dvui.log.err("Failed to allocate resized pixels", .{});
                    continue;
                };
                defer pixi.app.allocator.free(resized_pixels);

                _ = zstbi.resize(
                    pixels,
                    file.column_width,
                    file.row_height,
                    resized_pixels,
                    export_width,
                    export_height,
                );

                _ = msf_gif.frame(&handle, @ptrCast(resized_pixels.ptr), @intFromFloat(anim.fps / 100));
            } else {
                _ = msf_gif.frame(&handle, @ptrCast(pixels.ptr), @intFromFloat(anim.fps / 100));
            }
        }

        const result = msf_gif.end(&handle);
        defer msf_gif.free(result);

        // // Now write to file using the new Writer interface
        var output_file = std.fs.cwd().createFile(path, .{}) catch {
            dvui.log.err("Failed to create file {s}", .{path});
            return;
        };
        defer output_file.close();

        if (result.data) |data| {
            output_file.writeAll(data[0..result.dataSize]) catch {
                dvui.log.err("Failed to write to file {s}", .{path});
                return;
            };
        }
    }

    return error.NoSelectedAnimation;
}
