const std = @import("std");

const pixi = @import("../../pixi.zig");
const Editor = pixi.Editor;
const imgui = @import("zig-imgui");
const nfd = @import("nfd");
const zstbi = @import("zstbi");
const gif = @import("zgif");

pub fn draw(editor: *Editor) !void {
    if (editor.popups.print) {
        imgui.openPopup("Export...", imgui.PopupFlags_None);
    } else return;

    const popup_width = 350;
    const popup_height = 300;

    const window_size = pixi.app.window_size;
    const window_center: [2]f32 = .{ window_size[0] / 2.0, window_size[1] / 2.0 };

    imgui.setNextWindowPos(.{
        .x = window_center[0] - popup_width / 2.0,
        .y = window_center[1] - popup_height / 2.0,
    }, imgui.Cond_None);
    imgui.setNextWindowSize(.{
        .x = popup_width,
        .y = 0.0,
    }, imgui.Cond_None);

    var modal_flags: imgui.WindowFlags = 0;
    modal_flags |= imgui.WindowFlags_NoResize;
    modal_flags |= imgui.WindowFlags_NoCollapse;

    if (imgui.beginPopupModal(
        "Export...",
        &editor.popups.print,
        modal_flags,
    )) {
        defer imgui.endPopup();

        const style = imgui.getStyle();
        const spacing = style.item_spacing.x;
        const content = imgui.getContentRegionAvail();
        const half_width = (popup_width - (style.frame_padding.x * 2.0) - spacing) / 2.0;

        const plot_name = switch (editor.popups.print_state) {
            .selected_sprite => "Selected Sprite",
            .selected_animation => "Selected Animation",
            .selected_layer => "Selected Layer",
            .all_layers => "All Layers Individually",
            .full_image => "Full Flattened Image",
        };

        imgui.pushItemWidth(content.x);

        imgui.text("Select an export area:");

        if (imgui.beginCombo("Plot", plot_name, imgui.ComboFlags_None)) {
            defer imgui.endCombo();
            var i: usize = 0;
            while (i < 5) : (i += 1) {
                const current = @as(Editor.Popups.PrintState, @enumFromInt(i));
                const current_plot_name = switch (current) {
                    .selected_sprite => "Selected Sprite",
                    .selected_animation => "Selected Animation",
                    .selected_layer => "Selected Layer",
                    .all_layers => "All Layers Individually",
                    .full_image => "Full Flattened Image",
                };
                if (imgui.selectableEx(
                    current_plot_name,
                    current == editor.popups.print_state,
                    imgui.SelectableFlags_None,
                    .{ .x = 0.0, .y = 0.0 },
                )) {
                    editor.popups.print_state = current;
                }
            }
        }

        imgui.separator();
        imgui.spacing();

        var image_scale: i32 = 1;

        switch (editor.popups.print_state) {
            .selected_sprite, .selected_animation => {
                image_scale = @as(i32, @intCast(editor.popups.print_scale));

                imgui.text("Select an export scale:");
                if (imgui.sliderInt(
                    "Image Scale",
                    &image_scale,
                    1,
                    16,
                )) {
                    editor.popups.print_scale = @as(u32, @intCast(image_scale));
                }
            },
            else => {
                imgui.spacing();
            },
        }
        imgui.spacing();

        switch (editor.popups.print_state) {
            .selected_animation => {
                _ = imgui.checkbox("Export as GIF", &editor.popups.print_animation_gif);
            },
            else => {},
        }

        switch (editor.popups.print_state) {
            .selected_sprite,
            .selected_layer,
            .all_layers,
            => {
                _ = imgui.checkbox("Preserve names", &editor.popups.print_preserve_names);
                imgui.spacing();
            },
            .selected_animation,
            => {
                if (!editor.popups.print_animation_gif)
                    _ = imgui.checkbox("Preserve names", &editor.popups.print_preserve_names);
                imgui.spacing();
            },
            else => {
                imgui.spacing();
            },
        }

        imgui.popItemWidth();

        if (imgui.buttonEx("Cancel", .{ .x = half_width, .y = 0.0 })) {
            editor.popups.print = false;
        }
        imgui.sameLine();
        if (imgui.buttonEx("Export", .{ .x = half_width, .y = 0.0 })) {
            switch (editor.popups.print_state) {
                .selected_sprite => {
                    if (editor.popups.print_preserve_names) {
                        editor.popups.file_dialog_request = .{
                            .state = .folder,
                            .type = .export_sprite,
                        };
                    } else {
                        editor.popups.file_dialog_request = .{
                            .state = .save,
                            .type = .export_sprite,
                            .filter = "png",
                        };
                    }
                },
                .selected_animation => {
                    if (editor.popups.print_preserve_names and !editor.popups.print_animation_gif) {
                        editor.popups.file_dialog_request = .{
                            .state = .folder,
                            .type = .export_animation,
                        };
                    } else if (editor.popups.print_animation_gif) {
                        editor.popups.file_dialog_request = .{
                            .state = .save,
                            .type = .export_animation,
                            .filter = "gif",
                        };
                    } else {
                        editor.popups.file_dialog_request = .{
                            .state = .save,
                            .type = .export_animation,
                            .filter = "png",
                        };
                    }
                },
                .selected_layer => {
                    if (editor.popups.print_preserve_names) {
                        editor.popups.file_dialog_request = .{
                            .state = .folder,
                            .type = .export_layer,
                        };
                    } else {
                        editor.popups.file_dialog_request = .{
                            .state = .save,
                            .type = .export_layer,
                            .filter = "png",
                        };
                    }
                },
                .all_layers => {
                    if (editor.popups.print_preserve_names) {
                        editor.popups.file_dialog_request = .{
                            .state = .folder,
                            .type = .export_all_layers,
                        };
                    } else {
                        editor.popups.file_dialog_request = .{
                            .state = .save,
                            .type = .export_all_layers,
                            .filter = "png",
                        };
                    }
                },
                .full_image => {
                    editor.popups.file_dialog_request = .{
                        .state = .save,
                        .type = .export_full_image,
                        .filter = "png",
                    };
                },
            }
        }

        if (editor.getFile(editor.open_file_index)) |file| {
            if (editor.popups.file_dialog_response) |response| {
                switch (response.type) {
                    .export_sprite => {
                        const ext = std.fs.path.extension(response.path);
                        var full_path: [:0]const u8 = undefined;
                        if (std.mem.eql(u8, ext, ".png")) {
                            full_path = response.path;
                        } else {
                            const name = try file.calculateSpriteName(editor.arena.allocator(), file.selected_sprite_index);
                            full_path = try std.fmt.allocPrintZ(editor.arena.allocator(), "{s}{c}{s}.png", .{ response.path, std.fs.path.sep, name });
                        }

                        var sprite_image = try file.spriteToImage(file.selected_sprite_index, true);
                        defer sprite_image.deinit();

                        if (editor.popups.print_scale > 1) {
                            var scaled_image = sprite_image.resize(file.tile_width * editor.popups.print_scale, file.tile_height * editor.popups.print_scale);
                            defer scaled_image.deinit();
                            try scaled_image.writeToFile(full_path, .png);
                        } else {
                            try sprite_image.writeToFile(full_path, .png);
                        }
                        editor.popups.print = false;
                    },

                    .export_animation => {
                        const animation = file.animations.slice().get(file.selected_animation_index);

                        var i: usize = animation.start;
                        if (editor.popups.print_animation_gif) {
                            var images = std.ArrayList(zstbi.Image).init(editor.arena.allocator());

                            const path = response.path;

                            const ext = std.fs.path.extension(path);

                            if (std.mem.eql(u8, ext, ".gif")) {
                                while (i < animation.start + animation.length) : (i += 1) {
                                    var sprite_image = try file.spriteToImageBGRA(i, true);
                                    defer sprite_image.deinit();

                                    const scaled_image = sprite_image.resize(
                                        file.tile_width * editor.popups.print_scale,
                                        file.tile_height * editor.popups.print_scale,
                                    );

                                    try images.append(scaled_image);
                                }

                                // Search all of our frames for transparency
                                var transparent: bool = false;

                                blk: for (images.items) |image| {
                                    const pixels = @as([*][4]u8, @ptrCast(image.data.ptr))[0 .. image.data.len / 4];
                                    for (pixels) |p| {
                                        if (p[3] == 0) {
                                            transparent = true;
                                            break :blk;
                                        }
                                    }
                                }

                                var new_gif = try gif.Gif.init(editor.arena.allocator(), .{
                                    .path = path,
                                    .width = file.tile_width * editor.popups.print_scale,
                                    .height = file.tile_height * editor.popups.print_scale,
                                    .use_dithering = false,
                                    .transparent = transparent,
                                });

                                const frames = images.items;
                                try new_gif.addFrames(frames, @intCast(animation.fps));

                                try new_gif.close();
                            }
                        } else {
                            while (i < animation.start + animation.length) : (i += 1) {
                                if (editor.popups.print_preserve_names) {
                                    const folder = response.path;
                                    const full_path = try std.fmt.allocPrintZ(editor.arena.allocator(), "{s}{c}{s}_{d}.png", .{ folder, std.fs.path.sep, animation.name, i - animation.start });

                                    var sprite_image = try file.spriteToImage(i, true);
                                    defer sprite_image.deinit();

                                    if (editor.popups.print_scale > 1) {
                                        var scaled_image = sprite_image.resize(file.tile_width * editor.popups.print_scale, file.tile_height * editor.popups.print_scale);
                                        defer scaled_image.deinit();
                                        try scaled_image.writeToFile(full_path, .png);
                                    } else {
                                        try sprite_image.writeToFile(full_path, .png);
                                    }
                                    editor.popups.print = false;
                                } else {
                                    const base_name = std.fs.path.basename(response.path);
                                    if (std.mem.indexOf(u8, response.path, base_name)) |folder_index| {
                                        const folder = response.path[0..folder_index];
                                        const ext = std.fs.path.extension(base_name);

                                        if (std.mem.eql(u8, ext, ".png")) {
                                            if (std.mem.indexOf(u8, base_name, ext)) |ext_index| {
                                                const name = base_name[0..ext_index];
                                                const full_path = try std.fmt.allocPrintZ(pixi.app.allocator, "{s}{s}_{d}.png", .{ folder, name, i });

                                                var sprite_image = try file.spriteToImage(i, true);
                                                defer sprite_image.deinit();

                                                if (editor.popups.print_scale > 1) {
                                                    var scaled_image = sprite_image.resize(file.tile_width * editor.popups.print_scale, file.tile_height * editor.popups.print_scale);
                                                    defer scaled_image.deinit();
                                                    try scaled_image.writeToFile(full_path, .png);
                                                } else {
                                                    try sprite_image.writeToFile(full_path, .png);
                                                }
                                                editor.popups.print = false;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    },

                    .export_layer => {
                        const ext = std.fs.path.extension(response.path);
                        var full_path: [:0]const u8 = undefined;
                        if (std.mem.eql(u8, ext, ".png")) {
                            full_path = response.path;
                        } else {
                            const name = file.layers.items(.name)[file.selected_layer_index];
                            full_path = try std.fmt.allocPrintZ(editor.arena.allocator(), "{s}{c}{s}.png", .{ response.path, std.fs.path.sep, name });
                        }

                        try file.layers.items(.texture)[file.selected_layer_index].stbi_image().writeToFile(full_path, .png);
                        editor.popups.print = false;
                    },

                    .export_all_layers => {
                        var i: usize = 0;
                        while (i < file.layers.slice().len) : (i += 1) {
                            if (editor.popups.print_preserve_names) {
                                const folder = response.path;
                                const name = file.layers.items(.name)[i];
                                const full_path = try std.fmt.allocPrintZ(editor.arena.allocator(), "{s}{c}{s}.png", .{ folder, std.fs.path.sep, name });
                                try file.layers.items(.texture)[i].stbi_image().writeToFile(full_path, .png);
                                editor.popups.print = false;
                            } else {
                                const base_name = std.fs.path.basename(response.path);
                                if (std.mem.indexOf(u8, response.path, base_name)) |folder_index| {
                                    const folder = response.path[0..folder_index];
                                    const ext = std.fs.path.extension(base_name);

                                    if (std.mem.eql(u8, ext, ".png")) {
                                        if (std.mem.indexOf(u8, base_name, ext)) |ext_index| {
                                            const name = base_name[0..ext_index];
                                            const full_path = try std.fmt.allocPrintZ(editor.arena.allocator(), "{s}{s}_{d}.png", .{ folder, name, i });

                                            try file.layers.items(.texture)[i].stbi_image().writeToFile(full_path, .png);
                                            editor.popups.print = false;
                                        }
                                    }
                                }
                            }
                        }
                    },

                    .export_full_image => {
                        var dest_image = try zstbi.Image.createEmpty(file.width, file.height, 4, .{});
                        defer dest_image.deinit();
                        var dest_pixels = @as([*][4]u8, @ptrCast(dest_image.data.ptr))[0 .. dest_image.data.len / 4];

                        var i: usize = file.layers.slice().len;
                        while (i > 0) {
                            i -= 1;
                            const src_image = file.layers.items(.texture)[i].stbi_image();
                            const src_pixels = @as([*][4]u8, @ptrCast(src_image.data.ptr))[0 .. src_image.data.len / 4];
                            for (src_pixels, 0..) |src, j| {
                                if (src[3] != 0) dest_pixels[j] = src;
                            }
                        }
                        try dest_image.writeToFile(response.path, .png);
                        editor.popups.print = false;
                    },
                    else => {},
                }

                switch (response.type) {
                    .export_sprite, .export_animation, .export_layer, .export_all_layers, .export_full_image => {
                        nfd.freePath(response.path);
                        editor.popups.file_dialog_response = null;
                    },
                    else => {},
                }
            }
        }
    }
}
