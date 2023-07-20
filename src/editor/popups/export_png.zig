const std = @import("std");
const pixi = @import("../../pixi.zig");
const mach = @import("core");
const zgui = @import("zgui").MachImgui(mach);
const nfd = @import("nfd");
const zstbi = @import("zstbi");

pub fn draw() void {
    if (pixi.state.popups.export_to_png) {
        zgui.openPopup("Export to .png...", .{});
    } else return;

    const popup_width = 350 * pixi.content_scale[0];
    const popup_height = 300 * pixi.content_scale[1];

    var window_size = zgui.getWindowSize();
    window_size[0] *= pixi.content_scale[0];
    window_size[1] *= pixi.content_scale[1];
    const window_center: [2]f32 = .{ window_size[0] / 2.0, window_size[1] / 2.0 };

    zgui.setNextWindowPos(.{
        .x = window_center[0] - popup_width / 2.0,
        .y = window_center[1] - popup_height / 2.0,
    });
    zgui.setNextWindowSize(.{
        .w = popup_width,
        .h = 0.0,
    });

    if (zgui.beginPopupModal("Export to .png...", .{
        .popen = &pixi.state.popups.export_to_png,
        .flags = .{
            .no_resize = true,
            .no_collapse = true,
        },
    })) {
        defer zgui.endPopup();

        const style = zgui.getStyle();
        const spacing = style.item_spacing[0];
        const content = zgui.getContentRegionAvail();
        const half_width = (popup_width - (style.frame_padding[0] * 2.0 * pixi.content_scale[0]) - spacing) / 2.0;

        // if (zgui.radioButton("Selected Sprite", .{ .active = pixi.state.popups.export_to_png_state == .selected_sprite })) {
        //     pixi.state.popups.export_to_png_state = .selected_sprite;
        // }
        // var disabled = true;
        // if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
        //     if (file.animations.items.len > 0)
        //         disabled = false;
        // }
        // if (disabled) zgui.beginDisabled(.{});
        // if (zgui.radioButton("Selected Animation", .{ .active = pixi.state.popups.export_to_png_state == .selected_animation })) {
        //     pixi.state.popups.export_to_png_state = .selected_animation;
        // }
        // if (disabled) zgui.endDisabled();
        // if (zgui.radioButton("Selected Layer", .{ .active = pixi.state.popups.export_to_png_state == .selected_layer })) {
        //     pixi.state.popups.export_to_png_state = .selected_layer;
        // }
        // if (zgui.radioButton("All Layers", .{ .active = pixi.state.popups.export_to_png_state == .all_layers })) {
        //     pixi.state.popups.export_to_png_state = .all_layers;
        // }
        // if (zgui.radioButton("Full Image", .{ .active = pixi.state.popups.export_to_png_state == .full_image })) {
        //     pixi.state.popups.export_to_png_state = .full_image;
        // }

        const plot_name = switch (pixi.state.popups.export_to_png_state) {
            .selected_sprite => "Selected Sprite",
            .selected_animation => "Selected Animation",
            .selected_layer => "Selected Layer",
            .all_layers => "All Layers Individually",
            .full_image => "Full Flattened Image",
        };

        zgui.pushItemWidth(content[0]);

        zgui.text("Select an export area:", .{});

        if (zgui.beginCombo("Plot", .{ .preview_value = plot_name })) {
            defer zgui.endCombo();
            var i: usize = 0;
            while (i < 5) : (i += 1) {
                const current = @as(pixi.Popups.ExportToPngState, @enumFromInt(i));
                const current_plot_name = switch (current) {
                    .selected_sprite => "Selected Sprite",
                    .selected_animation => "Selected Animation",
                    .selected_layer => "Selected Layer",
                    .all_layers => "All Layers Individually",
                    .full_image => "Full Flattened Image",
                };
                if (zgui.selectable(current_plot_name, .{ .selected = current == pixi.state.popups.export_to_png_state })) {
                    pixi.state.popups.export_to_png_state = current;
                }
            }
        }

        zgui.separator();
        zgui.spacing();

        var image_scale: i32 = 1;

        switch (pixi.state.popups.export_to_png_state) {
            .selected_sprite, .selected_animation => {
                image_scale = @as(i32, @intCast(pixi.state.popups.export_to_png_scale));

                zgui.text("Select an export scale:", .{});
                if (zgui.sliderInt("Image Scale", .{
                    .v = &image_scale,
                    .min = 1,
                    .max = 16,
                })) {
                    pixi.state.popups.export_to_png_scale = @as(u32, @intCast(image_scale));
                }
            },
            else => {
                zgui.spacing();
            },
        }
        zgui.spacing();

        switch (pixi.state.popups.export_to_png_state) {
            .selected_sprite,
            .selected_animation,
            .selected_layer,
            .all_layers,
            => {
                _ = zgui.checkbox("Preserve names", .{ .v = &pixi.state.popups.export_to_png_preserve_names });
                zgui.spacing();
            },
            else => {
                zgui.spacing();
            },
        }

        zgui.popItemWidth();

        if (zgui.button("Cancel", .{ .w = half_width })) {
            pixi.state.popups.export_to_png = false;
        }
        zgui.sameLine(.{});
        if (zgui.button("Export", .{ .w = half_width })) {
            switch (pixi.state.popups.export_to_png_state) {
                .selected_sprite => {
                    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
                        const path_opt = if (pixi.state.popups.export_to_png_preserve_names)
                            nfd.openFolderDialog(null) catch unreachable
                        else
                            nfd.saveFileDialog("png", null) catch unreachable;

                        if (path_opt) |path| {
                            const ext = std.fs.path.extension(path);
                            var full_path: [:0]const u8 = undefined;
                            if (std.mem.eql(u8, ext, ".png")) {
                                full_path = path;
                            } else {
                                const name = file.sprites.items[file.selected_sprite_index].name;
                                full_path = zgui.formatZ("{s}{c}{s}.png", .{ path, std.fs.path.sep, name });
                            }

                            var sprite_image = file.spriteToImage(file.selected_sprite_index) catch unreachable;
                            defer sprite_image.deinit();

                            if (pixi.state.popups.export_to_png_scale > 1) {
                                var scaled_image = sprite_image.resize(file.tile_width * pixi.state.popups.export_to_png_scale, file.tile_height * pixi.state.popups.export_to_png_scale);
                                defer scaled_image.deinit();
                                scaled_image.writeToFile(full_path, .png) catch unreachable;
                            } else {
                                sprite_image.writeToFile(full_path, .png) catch unreachable;
                            }
                            pixi.state.popups.export_to_png = false;
                        }
                    }
                },
                .selected_animation => {
                    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
                        const path_opt = if (pixi.state.popups.export_to_png_preserve_names)
                            nfd.openFolderDialog(null) catch unreachable
                        else
                            nfd.saveFileDialog("png", null) catch unreachable;

                        if (path_opt) |path| {
                            const animation = file.animations.items[file.selected_animation_index];

                            var i: usize = animation.start;
                            while (i < animation.start + animation.length) : (i += 1) {
                                if (pixi.state.popups.export_to_png_preserve_names) {
                                    const folder = path;
                                    const name = file.sprites.items[i].name;
                                    const full_path = zgui.formatZ("{s}{c}{s}.png", .{ folder, std.fs.path.sep, name });

                                    var sprite_image = file.spriteToImage(i) catch unreachable;
                                    defer sprite_image.deinit();

                                    if (pixi.state.popups.export_to_png_scale > 1) {
                                        var scaled_image = sprite_image.resize(file.tile_width * pixi.state.popups.export_to_png_scale, file.tile_height * pixi.state.popups.export_to_png_scale);
                                        defer scaled_image.deinit();
                                        scaled_image.writeToFile(full_path, .png) catch unreachable;
                                    } else {
                                        sprite_image.writeToFile(full_path, .png) catch unreachable;
                                    }
                                    pixi.state.popups.export_to_png = false;
                                } else {
                                    const base_name = std.fs.path.basename(path);
                                    if (std.mem.indexOf(u8, path, base_name)) |folder_index| {
                                        const folder = path[0..folder_index];
                                        const ext = std.fs.path.extension(base_name);

                                        if (std.mem.eql(u8, ext, ".png")) {
                                            if (std.mem.indexOf(u8, base_name, ext)) |ext_index| {
                                                const name = base_name[0..ext_index];
                                                const full_path = zgui.formatZ("{s}{s}_{d}.png", .{ folder, name, i });

                                                var sprite_image = file.spriteToImage(i) catch unreachable;
                                                defer sprite_image.deinit();

                                                if (pixi.state.popups.export_to_png_scale > 1) {
                                                    var scaled_image = sprite_image.resize(file.tile_width * pixi.state.popups.export_to_png_scale, file.tile_height * pixi.state.popups.export_to_png_scale);
                                                    defer scaled_image.deinit();
                                                    scaled_image.writeToFile(full_path, .png) catch unreachable;
                                                } else {
                                                    sprite_image.writeToFile(full_path, .png) catch unreachable;
                                                }
                                                pixi.state.popups.export_to_png = false;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                },
                .selected_layer => {
                    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
                        const path_opt = if (pixi.state.popups.export_to_png_preserve_names)
                            nfd.openFolderDialog(null) catch unreachable
                        else
                            nfd.saveFileDialog("png", null) catch unreachable;

                        if (path_opt) |path| {
                            const ext = std.fs.path.extension(path);
                            var full_path: [:0]const u8 = undefined;
                            if (std.mem.eql(u8, ext, ".png")) {
                                full_path = path;
                            } else {
                                const name = file.layers.items[file.selected_layer_index].name;
                                full_path = zgui.formatZ("{s}{c}{s}.png", .{ path, std.fs.path.sep, name });
                            }

                            file.layers.items[file.selected_layer_index].texture.image.writeToFile(full_path, .png) catch unreachable;
                            pixi.state.popups.export_to_png = false;
                        }
                    }
                },
                .all_layers => {
                    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
                        const path_opt = if (pixi.state.popups.export_to_png_preserve_names)
                            nfd.openFolderDialog(null) catch unreachable
                        else
                            nfd.saveFileDialog("png", null) catch unreachable;

                        if (path_opt) |path| {
                            var i: usize = 0;
                            while (i < file.layers.items.len) : (i += 1) {
                                if (pixi.state.popups.export_to_png_preserve_names) {
                                    const folder = path;
                                    const name = file.layers.items[i].name;
                                    const full_path = zgui.formatZ("{s}{c}{s}.png", .{ folder, std.fs.path.sep, name });
                                    file.layers.items[i].texture.image.writeToFile(full_path, .png) catch unreachable;
                                    pixi.state.popups.export_to_png = false;
                                } else {
                                    const base_name = std.fs.path.basename(path);
                                    if (std.mem.indexOf(u8, path, base_name)) |folder_index| {
                                        const folder = path[0..folder_index];
                                        const ext = std.fs.path.extension(base_name);

                                        if (std.mem.eql(u8, ext, ".png")) {
                                            if (std.mem.indexOf(u8, base_name, ext)) |ext_index| {
                                                const name = base_name[0..ext_index];
                                                const full_path = zgui.formatZ("{s}{s}_{d}.png", .{ folder, name, i });

                                                file.layers.items[i].texture.image.writeToFile(full_path, .png) catch unreachable;
                                                pixi.state.popups.export_to_png = false;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                },
                .full_image => {
                    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
                        if (nfd.saveFileDialog("png", null) catch unreachable) |path| {
                            var dest_image = zstbi.Image.createEmpty(file.width, file.height, 4, .{}) catch unreachable;
                            defer dest_image.deinit();
                            var dest_pixels = @as([*][4]u8, @ptrCast(dest_image.data.ptr))[0 .. dest_image.data.len / 4];

                            var i: usize = file.layers.items.len;
                            while (i > 0) {
                                i -= 1;
                                const src_image = file.layers.items[i].texture.image;
                                const src_pixels = @as([*][4]u8, @ptrCast(src_image.data.ptr))[0 .. src_image.data.len / 4];
                                for (src_pixels, 0..) |src, j| {
                                    if (src[3] != 0) dest_pixels[j] = src;
                                }
                            }
                            dest_image.writeToFile(path, .png) catch unreachable;
                        }
                    }
                    pixi.state.popups.export_to_png = false;
                },
            }
        }
    }
}
