const std = @import("std");
const pixi = @import("root");
const zgui = @import("zgui");

pub fn draw() void {
    if (pixi.state.popups.file_setup) {
        zgui.openPopup("File Setup...", .{});
    } else return;

    const popup_width = 350 * pixi.state.window.scale[0];
    const popup_height = 300 * pixi.state.window.scale[1];

    const window_size = pixi.state.window.size * pixi.state.window.scale;
    const window_center: [2]f32 = .{ window_size[0] / 2.0, window_size[1] / 2.0 };

    zgui.setNextWindowPos(.{
        .x = window_center[0] - popup_width / 2.0,
        .y = window_center[1] - popup_height / 2.0,
    });
    zgui.setNextWindowSize(.{
        .w = popup_width,
        .h = popup_height,
    });

    if (zgui.beginPopupModal("File Setup...", .{
        .popen = &pixi.state.popups.file_setup,
        .flags = .{
            .no_resize = true,
            .no_collapse = true,
        },
    })) {
        defer zgui.endPopup();

        const style = zgui.getStyle();

        const full_width = popup_width - (style.frame_padding[0] * 3 * pixi.state.window.scale[0]) - zgui.calcTextSize("Tile Height", .{})[0];
        const base_name_index = if (std.mem.lastIndexOf(u8, pixi.state.popups.file_setup_path[0..], &[_]u8{std.fs.path.sep})) |index| index + 1 else 0;

        zgui.spacing();
        zgui.pushItemWidth(full_width);
        _ = zgui.inputText("Name", .{
            .buf = pixi.state.popups.file_setup_path[base_name_index..],
            .flags = .{
                .chars_no_blank = true,
                .auto_select_all = true,
                .enter_returns_true = true,
            },
        });

        const max_file_size = pixi.state.settings.max_file_size;
        const max_file_width = switch (pixi.state.popups.file_setup_state) {
            .slice, .import_png => pixi.state.popups.file_setup_width,
            else => max_file_size[0],
        };
        const max_file_height = switch (pixi.state.popups.file_setup_state) {
            .slice, .import_png => pixi.state.popups.file_setup_height,
            else => max_file_size[1],
        };

        zgui.spacing();
        if (inputIntClamp("Tile Width", &pixi.state.popups.file_setup_tile_size[0], 1, max_file_width)) {
            pixi.state.popups.file_setup_tiles[0] = std.math.clamp(switch (pixi.state.popups.file_setup_state) {
                .slice, .import_png => @divTrunc(max_file_width, pixi.state.popups.file_setup_tile_size[0]),
                else => pixi.state.popups.file_setup_tiles[0],
            }, 1, @divTrunc(max_file_width, pixi.state.popups.file_setup_tile_size[0]));
        }
        if (inputIntClamp("Tile Height", &pixi.state.popups.file_setup_tile_size[1], 1, max_file_height)) {
            pixi.state.popups.file_setup_tiles[1] = std.math.clamp(switch (pixi.state.popups.file_setup_state) {
                .slice, .import_png => @divTrunc(max_file_height, pixi.state.popups.file_setup_tile_size[1]),
                else => pixi.state.popups.file_setup_tiles[1],
            }, 1, @divTrunc(max_file_height, pixi.state.popups.file_setup_tile_size[1]));
        }

        zgui.spacing();
        zgui.separator();
        zgui.spacing();

        switch (pixi.state.popups.file_setup_state) {
            .slice, .import_png => zgui.beginDisabled(.{}),
            else => {},
        }

        if (zgui.inputInt("Tiles Wide", .{ .v = &pixi.state.popups.file_setup_tiles[0] })) {
            pixi.state.popups.file_setup_tiles[0] = std.math.clamp(pixi.state.popups.file_setup_tiles[0], 1, @divTrunc(max_file_width, pixi.state.popups.file_setup_tile_size[0]));
        }

        if (zgui.inputInt("Tiles Tall", .{ .v = &pixi.state.popups.file_setup_tiles[1] })) {
            pixi.state.popups.file_setup_tiles[1] = std.math.clamp(pixi.state.popups.file_setup_tiles[1], 1, @divTrunc(max_file_height, pixi.state.popups.file_setup_tile_size[1]));
        }

        switch (pixi.state.popups.file_setup_state) {
            .slice, .import_png => zgui.endDisabled(),
            else => {},
        }
        zgui.popItemWidth();
        zgui.spacing();

        const combined_size: [2]i32 = .{
            pixi.state.popups.file_setup_tile_size[0] * pixi.state.popups.file_setup_tiles[0],
            pixi.state.popups.file_setup_tile_size[1] * pixi.state.popups.file_setup_tiles[1],
        };

        const sizes_match = switch (pixi.state.popups.file_setup_state) {
            .slice, .import_png => combined_size[0] == pixi.state.popups.file_setup_width and combined_size[1] == pixi.state.popups.file_setup_height,
            else => true,
        };

        zgui.text("Image size: {d}x{d}", .{
            if (!sizes_match) pixi.state.popups.file_setup_width else combined_size[0],
            if (!sizes_match) pixi.state.popups.file_setup_height else combined_size[1],
        });
        zgui.spacing();

        if (!sizes_match) {
            zgui.textColored(pixi.state.style.text_red.toSlice(), "Tile sizes and count do not match image size! {d}x{d}", .{ combined_size[0], combined_size[1] });
        } else {
            zgui.textColored(pixi.state.style.highlight_primary.toSlice(), " " ++ pixi.fa.check, .{});
        }

        zgui.setCursorPosY(popup_height - zgui.getTextLineHeightWithSpacing() * 2.0);

        const spacing = 5.0 * pixi.state.window.scale[0];
        const half_width = (popup_width - (style.frame_padding[0] * 2.0 * pixi.state.window.scale[0]) - spacing) / 2.0;
        if (zgui.button("Cancel", .{ .w = half_width })) {
            pixi.state.popups.fileSetupClose();
        }
        zgui.sameLine(.{ .spacing = spacing });
        if (!sizes_match) {
            zgui.beginDisabled(.{});
        }
        if (zgui.button("Ok", .{ .w = half_width })) {
            const file_setup_path = std.mem.trimRight(u8, pixi.state.popups.file_setup_path[0..], "\u{0}");
            const ext = std.fs.path.extension(file_setup_path);
            if (std.mem.eql(u8, ".pixi", ext)) {
                switch (pixi.state.popups.file_setup_state) {
                    .new => {
                        if (pixi.editor.newFile(pixi.state.allocator.dupeZ(u8, file_setup_path) catch unreachable, null) catch unreachable) {
                            if (pixi.editor.getFile(0)) |file| {
                                _ = file.save() catch unreachable;
                            }
                        }
                    },
                    .import_png => {
                        const file_setup_png_path = std.mem.trimRight(u8, pixi.state.popups.file_setup_png_path[0..], "\u{0}");
                        if (pixi.editor.importPng(pixi.state.allocator.dupeZ(u8, file_setup_png_path) catch unreachable, pixi.state.allocator.dupeZ(u8, file_setup_path) catch unreachable) catch unreachable) {
                            if (pixi.editor.getFile(0)) |file| {
                                _ = file.save() catch unreachable;
                            }
                        }
                    },
                    .slice => {
                        if (pixi.editor.getFileIndex(pixi.state.popups.file_setup_path[0..file_setup_path.len :0])) |index| {
                            if (pixi.editor.getFile(index)) |file| {
                                file.tile_width = @intCast(u32, pixi.state.popups.file_setup_tile_size[0]);
                                file.tile_height = @intCast(u32, pixi.state.popups.file_setup_tile_size[1]);
                            }
                        }
                    },
                    else => {},
                }

                pixi.state.popups.fileSetupClose();
            }
        }
        if (!sizes_match) {
            zgui.endDisabled();
        }
    }
}

fn inputIntClamp(label: [:0]const u8, v: *i32, min: i32, max: i32) bool {
    var b = zgui.inputInt(label, .{ .v = v });
    if (b) {
        v.* = std.math.clamp(v.*, min, max);
    }
    return b;
}
