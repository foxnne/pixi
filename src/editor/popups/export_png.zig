const std = @import("std");

const pixi = @import("../../pixi.zig");
const Editor = pixi.Editor;
const imgui = @import("zig-imgui");
const nfd = @import("nfd");
const zstbi = @import("zstbi");

pub fn draw(editor: *Editor) !void {
    if (editor.popups.export_to_png) {
        imgui.openPopup("Export to .png...", imgui.PopupFlags_None);
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
        "Export to .png...",
        &editor.popups.export_to_png,
        modal_flags,
    )) {
        defer imgui.endPopup();

        const style = imgui.getStyle();
        const spacing = style.item_spacing.x;
        const content = imgui.getContentRegionAvail();
        const half_width = (popup_width - (style.frame_padding.x * 2.0) - spacing) / 2.0;

        const plot_name = switch (editor.popups.export_to_png_state) {
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
                const current = @as(Editor.Popups.ExportToPngState, @enumFromInt(i));
                const current_plot_name = switch (current) {
                    .selected_sprite => "Selected Sprite",
                    .selected_animation => "Selected Animation",
                    .selected_layer => "Selected Layer",
                    .all_layers => "All Layers Individually",
                    .full_image => "Full Flattened Image",
                };
                if (imgui.selectableEx(current_plot_name, current == editor.popups.export_to_png_state, imgui.SelectableFlags_None, .{ .x = 0.0, .y = 0.0 })) {
                    editor.popups.export_to_png_state = current;
                }
            }
        }

        imgui.separator();
        imgui.spacing();

        var image_scale: i32 = 1;

        switch (editor.popups.export_to_png_state) {
            .selected_sprite, .selected_animation => {
                image_scale = @as(i32, @intCast(editor.popups.export_to_png_scale));

                imgui.text("Select an export scale:");
                if (imgui.sliderInt(
                    "Image Scale",
                    &image_scale,
                    1,
                    16,
                )) {
                    editor.popups.export_to_png_scale = @as(u32, @intCast(image_scale));
                }
            },
            else => {
                imgui.spacing();
            },
        }
        imgui.spacing();

        switch (editor.popups.export_to_png_state) {
            .selected_sprite,
            .selected_animation,
            .selected_layer,
            .all_layers,
            => {
                _ = imgui.checkbox("Preserve names", &editor.popups.export_to_png_preserve_names);
                imgui.spacing();
            },
            else => {
                imgui.spacing();
            },
        }

        imgui.popItemWidth();

        if (imgui.buttonEx("Cancel", .{ .x = half_width, .y = 0.0 })) {
            editor.popups.export_to_png = false;
        }
        imgui.sameLine();
        if (imgui.buttonEx("Export", .{ .x = half_width, .y = 0.0 })) {
            switch (editor.popups.export_to_png_state) {
                .selected_sprite => {
                    if (editor.popups.export_to_png_preserve_names) {
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
                    if (editor.popups.export_to_png_preserve_names) {
                        editor.popups.file_dialog_request = .{
                            .state = .folder,
                            .type = .export_animation,
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
                    if (editor.popups.export_to_png_preserve_names) {
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
                    if (editor.popups.export_to_png_preserve_names) {
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
                            const name = file.sprites.items(.name)[file.selected_sprite_index];
                            full_path = try std.fmt.allocPrintZ(pixi.app.allocator, "{s}{c}{s}.png", .{ response.path, std.fs.path.sep, name });
                        }

                        var sprite_image = try file.spriteToImage(file.selected_sprite_index, true);
                        defer sprite_image.deinit();

                        if (editor.popups.export_to_png_scale > 1) {
                            var scaled_image = sprite_image.resize(file.tile_width * editor.popups.export_to_png_scale, file.tile_height * editor.popups.export_to_png_scale);
                            defer scaled_image.deinit();
                            try scaled_image.writeToFile(full_path, .png);
                        } else {
                            try sprite_image.writeToFile(full_path, .png);
                        }
                        editor.popups.export_to_png = false;
                    },

                    .export_animation => {
                        const animation = file.animations.slice().get(file.selected_animation_index);

                        var i: usize = animation.start;
                        while (i < animation.start + animation.length) : (i += 1) {
                            if (editor.popups.export_to_png_preserve_names) {
                                const folder = response.path;
                                const name = file.sprites.items(.name)[i];
                                const full_path = try std.fmt.allocPrintZ(pixi.app.allocator, "{s}{c}{s}.png", .{ folder, std.fs.path.sep, name });

                                var sprite_image = try file.spriteToImage(i, true);
                                defer sprite_image.deinit();

                                if (editor.popups.export_to_png_scale > 1) {
                                    var scaled_image = sprite_image.resize(file.tile_width * editor.popups.export_to_png_scale, file.tile_height * editor.popups.export_to_png_scale);
                                    defer scaled_image.deinit();
                                    try scaled_image.writeToFile(full_path, .png);
                                } else {
                                    try sprite_image.writeToFile(full_path, .png);
                                }
                                editor.popups.export_to_png = false;
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

                                            if (editor.popups.export_to_png_scale > 1) {
                                                var scaled_image = sprite_image.resize(file.tile_width * editor.popups.export_to_png_scale, file.tile_height * editor.popups.export_to_png_scale);
                                                defer scaled_image.deinit();
                                                try scaled_image.writeToFile(full_path, .png);
                                            } else {
                                                try sprite_image.writeToFile(full_path, .png);
                                            }
                                            editor.popups.export_to_png = false;
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
                            full_path = try std.fmt.allocPrintZ(pixi.app.allocator, "{s}{c}{s}.png", .{ response.path, std.fs.path.sep, name });
                        }

                        try file.layers.items(.texture)[file.selected_layer_index].image.writeToFile(full_path, .png);
                        editor.popups.export_to_png = false;
                    },

                    .export_all_layers => {
                        var i: usize = 0;
                        while (i < file.layers.slice().len) : (i += 1) {
                            if (editor.popups.export_to_png_preserve_names) {
                                const folder = response.path;
                                const name = file.layers.items(.name)[i];
                                const full_path = try std.fmt.allocPrintZ(pixi.app.allocator, "{s}{c}{s}.png", .{ folder, std.fs.path.sep, name });
                                try file.layers.items(.texture)[i].image.writeToFile(full_path, .png);
                                editor.popups.export_to_png = false;
                            } else {
                                const base_name = std.fs.path.basename(response.path);
                                if (std.mem.indexOf(u8, response.path, base_name)) |folder_index| {
                                    const folder = response.path[0..folder_index];
                                    const ext = std.fs.path.extension(base_name);

                                    if (std.mem.eql(u8, ext, ".png")) {
                                        if (std.mem.indexOf(u8, base_name, ext)) |ext_index| {
                                            const name = base_name[0..ext_index];
                                            const full_path = try std.fmt.allocPrintZ(pixi.app.allocator, "{s}{s}_{d}.png", .{ folder, name, i });

                                            try file.layers.items(.texture)[i].image.writeToFile(full_path, .png);
                                            editor.popups.export_to_png = false;
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
                            const src_image = file.layers.items(.texture)[i].image;
                            const src_pixels = @as([*][4]u8, @ptrCast(src_image.data.ptr))[0 .. src_image.data.len / 4];
                            for (src_pixels, 0..) |src, j| {
                                if (src[3] != 0) dest_pixels[j] = src;
                            }
                        }
                        try dest_image.writeToFile(response.path, .png);
                        editor.popups.export_to_png = false;
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
