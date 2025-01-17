const std = @import("std");
const Pixi = @import("../../Pixi.zig");
const core = @import("mach").core;
const imgui = @import("zig-imgui");

pub fn draw() !void {
    if (Pixi.editor.popups.file_setup) {
        imgui.openPopup("File Setup...", imgui.PopupFlags_None);
    } else return;

    const popup_width = 350 * Pixi.app.content_scale[0];
    const popup_height = 300 * Pixi.app.content_scale[1];

    const window_size = Pixi.app.window_size;
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

    if (imgui.beginPopupModal("File Setup...", &Pixi.editor.popups.file_setup, modal_flags)) {
        defer imgui.endPopup();

        const style = imgui.getStyle();

        const full_width = popup_width - (style.frame_padding.x * 3 * Pixi.app.content_scale[0]) - imgui.calcTextSize("Tile Height").x;
        const base_name = std.fs.path.basename(&Pixi.editor.popups.file_setup_path);
        const base_name_index = if (std.mem.indexOf(u8, Pixi.editor.popups.file_setup_path[0..], base_name)) |index| index else 0;

        imgui.spacing();
        imgui.pushItemWidth(full_width);

        var input_text_flags: imgui.InputTextFlags = 0;
        input_text_flags |= imgui.InputTextFlags_AutoSelectAll;
        input_text_flags |= imgui.InputTextFlags_EnterReturnsTrue;

        const enter = imgui.inputText(
            "Name",
            Pixi.editor.popups.file_setup_path[base_name_index..],
            Pixi.editor.popups.file_setup_path[base_name_index..].len,
            input_text_flags,
        );

        const max_file_size = Pixi.editor.settings.max_file_size;
        const max_file_width = switch (Pixi.editor.popups.file_setup_state) {
            .slice, .import_png => Pixi.editor.popups.file_setup_width,
            else => max_file_size[0],
        };
        const max_file_height = switch (Pixi.editor.popups.file_setup_state) {
            .slice, .import_png => Pixi.editor.popups.file_setup_height,
            else => max_file_size[1],
        };

        imgui.spacing();
        if (inputIntClamp("Tile Width", &Pixi.editor.popups.file_setup_tile_size[0], 1, max_file_width)) {
            Pixi.editor.popups.file_setup_tiles[0] = std.math.clamp(switch (Pixi.editor.popups.file_setup_state) {
                .slice, .import_png => @divTrunc(max_file_width, Pixi.editor.popups.file_setup_tile_size[0]),
                else => Pixi.editor.popups.file_setup_tiles[0],
            }, 1, @divTrunc(max_file_width, Pixi.editor.popups.file_setup_tile_size[0]));
        }
        if (inputIntClamp("Tile Height", &Pixi.editor.popups.file_setup_tile_size[1], 1, max_file_height)) {
            Pixi.editor.popups.file_setup_tiles[1] = std.math.clamp(switch (Pixi.editor.popups.file_setup_state) {
                .slice, .import_png => @divTrunc(max_file_height, Pixi.editor.popups.file_setup_tile_size[1]),
                else => Pixi.editor.popups.file_setup_tiles[1],
            }, 1, @divTrunc(max_file_height, Pixi.editor.popups.file_setup_tile_size[1]));
        }

        imgui.spacing();
        imgui.separator();
        imgui.spacing();

        switch (Pixi.editor.popups.file_setup_state) {
            .slice, .import_png => imgui.beginDisabled(true),
            else => {},
        }

        if (imgui.inputInt("Tiles Wide", &Pixi.editor.popups.file_setup_tiles[0])) {
            Pixi.editor.popups.file_setup_tiles[0] = std.math.clamp(Pixi.editor.popups.file_setup_tiles[0], 1, @divTrunc(max_file_width, Pixi.editor.popups.file_setup_tile_size[0]));
        }

        if (imgui.inputInt("Tiles Tall", &Pixi.editor.popups.file_setup_tiles[1])) {
            Pixi.editor.popups.file_setup_tiles[1] = std.math.clamp(Pixi.editor.popups.file_setup_tiles[1], 1, @divTrunc(max_file_height, Pixi.editor.popups.file_setup_tile_size[1]));
        }

        switch (Pixi.editor.popups.file_setup_state) {
            .slice, .import_png => imgui.endDisabled(),
            else => {},
        }
        imgui.popItemWidth();
        imgui.spacing();

        const combined_size: [2]i32 = .{
            Pixi.editor.popups.file_setup_tile_size[0] * Pixi.editor.popups.file_setup_tiles[0],
            Pixi.editor.popups.file_setup_tile_size[1] * Pixi.editor.popups.file_setup_tiles[1],
        };

        const sizes_match = switch (Pixi.editor.popups.file_setup_state) {
            .slice, .import_png => combined_size[0] == Pixi.editor.popups.file_setup_width and combined_size[1] == Pixi.editor.popups.file_setup_height,
            else => true,
        };

        imgui.text(
            "Image size: %dx%d",
            if (!sizes_match) Pixi.editor.popups.file_setup_width else combined_size[0],
            if (!sizes_match) Pixi.editor.popups.file_setup_height else combined_size[1],
        );
        imgui.spacing();

        const file_setup_path = std.mem.trimRight(u8, &Pixi.editor.popups.file_setup_path, "\u{0}");
        const ext = std.fs.path.extension(&Pixi.editor.popups.file_setup_path);

        if (!sizes_match) {
            imgui.textColored(Pixi.editor.theme.text_red.toImguiVec4(), "Tile sizes and count do not match image size! %dx%d", combined_size[0], combined_size[1]);
        } else if (ext.len < 5 or !std.mem.eql(u8, ".pixi", ext[0..5])) {
            imgui.textColored(Pixi.editor.theme.text_red.toImguiVec4(), "File name must end with .pixi extension!");
        } else {
            imgui.textColored(Pixi.editor.theme.highlight_primary.toImguiVec4(), " " ++ Pixi.fa.check);
        }

        const spacing = 5.0 * Pixi.app.content_scale[0];
        const half_width = (popup_width - (style.frame_padding.x * 2.0 * Pixi.app.content_scale[0]) - spacing) / 2.0;
        if (imgui.buttonEx("Cancel", .{ .x = half_width, .y = 0.0 })) {
            Pixi.editor.popups.fileSetupClose();
        }
        imgui.sameLineEx(0.0, spacing);
        if (!sizes_match) {
            imgui.beginDisabled(true);
        }

        if (imgui.buttonEx("Ok", .{ .x = half_width, .y = 0.0 }) or enter) {
            if (ext.len > 0 and std.mem.eql(u8, ".pixi", ext[0..5])) {
                switch (Pixi.editor.popups.file_setup_state) {
                    .new => {
                        if (try Pixi.editor.newFile(try Pixi.app.allocator.dupeZ(u8, file_setup_path), null)) {
                            if (Pixi.editor.getFile(0)) |file| {
                                try file.save();
                            }
                        }
                    },
                    .import_png => {
                        const file_setup_png_path = std.mem.trimRight(u8, &Pixi.editor.popups.file_setup_png_path, "\u{0}");
                        if (try Pixi.editor.importPng(try Pixi.app.allocator.dupeZ(u8, file_setup_png_path), try Pixi.app.allocator.dupeZ(u8, file_setup_path))) {
                            if (Pixi.editor.getFile(0)) |file| {
                                try file.save();
                            }
                        }
                    },
                    .slice => {
                        if (Pixi.editor.getFileIndex(Pixi.editor.popups.file_setup_path[0..file_setup_path.len :0])) |index| {
                            if (Pixi.editor.getFile(index)) |file| {
                                file.tile_width = @as(u32, @intCast(Pixi.editor.popups.file_setup_tile_size[0]));
                                file.tile_height = @as(u32, @intCast(Pixi.editor.popups.file_setup_tile_size[1]));
                            }
                        }
                    },
                    else => {},
                }

                Pixi.editor.popups.fileSetupClose();
            }
        }

        if (!sizes_match) {
            imgui.endDisabled();
        }
    }
}

fn inputIntClamp(label: [:0]const u8, v: *i32, min: i32, max: i32) bool {
    const b = imgui.inputInt(label, v);
    if (b) {
        v.* = std.math.clamp(v.*, min, max);
    }
    return b;
}
