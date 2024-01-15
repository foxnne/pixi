const std = @import("std");
const pixi = @import("../../pixi.zig");
const core = @import("mach-core");
const zgui = @import("zgui").MachImgui(core);

pub fn draw() void {
    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 8.0 * pixi.content_scale[0], 8.0 * pixi.content_scale[1] } });
    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.selectable_text_align, .v = .{ 0.5, 0.8 } });
    defer zgui.popStyleVar(.{ .count = 2 });

    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.header, .c = pixi.state.theme.foreground.toSlice() });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.header_hovered, .c = pixi.state.theme.foreground.toSlice() });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.header_active, .c = pixi.state.theme.foreground.toSlice() });
    defer zgui.popStyleColor(.{ .count = 3 });
    if (zgui.beginChild("Tools", .{
        .w = zgui.getWindowWidth() - pixi.state.settings.explorer_grip * pixi.content_scale[0],
        .h = -1.0,
    })) {
        defer zgui.endChild();

        const style = zgui.getStyle();
        const window_size = zgui.getWindowSize();

        const button_width = zgui.getWindowWidth() / 3.6;
        const button_height = button_width / 2.0;

        const color_width = window_size[0] / 2.2;

        // Row 1
        {
            zgui.setCursorPosX(style.item_spacing[0]);
            drawTool(pixi.fa.mouse_pointer, button_width, button_height, .pointer);
            zgui.sameLine(.{});
            drawTool(pixi.fa.pencil_alt, button_width, button_height, .pencil);
            zgui.sameLine(.{});
            drawTool(pixi.fa.eraser, button_width, button_height, .eraser);
        }

        // Row 2
        {
            zgui.setCursorPosX(style.item_spacing[0]);
            drawTool(pixi.fa.sort_amount_up, button_width, button_height, .heightmap);
            zgui.sameLine(.{});
            drawTool(pixi.fa.fill_drip, button_width, button_height, .bucket);
        }

        zgui.spacing();
        zgui.spacing();
        zgui.text("Colors", .{});
        zgui.separator();

        if (pixi.state.tools.current == .heightmap) {
            var height: i32 = @as(i32, @intCast(pixi.state.colors.height));
            if (zgui.sliderInt("Height", .{
                .v = &height,
                .min = 0,
                .max = 255,
            })) {
                pixi.state.colors.height = @as(u8, @intCast(std.math.clamp(height, 0, 255)));
            }
        } else {
            var primary: [4]f32 = if (pixi.state.tools.current == .heightmap) .{ 255, 255, 255, 255 } else .{
                @as(f32, @floatFromInt(pixi.state.colors.primary[0])) / 255.0,
                @as(f32, @floatFromInt(pixi.state.colors.primary[1])) / 255.0,
                @as(f32, @floatFromInt(pixi.state.colors.primary[2])) / 255.0,
                @as(f32, @floatFromInt(pixi.state.colors.primary[3])) / 255.0,
            };

            var secondary: [4]f32 = .{
                @as(f32, @floatFromInt(pixi.state.colors.secondary[0])) / 255.0,
                @as(f32, @floatFromInt(pixi.state.colors.secondary[1])) / 255.0,
                @as(f32, @floatFromInt(pixi.state.colors.secondary[2])) / 255.0,
                @as(f32, @floatFromInt(pixi.state.colors.secondary[3])) / 255.0,
            };

            if (zgui.colorButton("Primary", .{
                .col = primary,
                .w = color_width,
                .h = 64 * pixi.content_scale[1],
            })) {
                const color = pixi.state.colors.primary;
                pixi.state.colors.primary = pixi.state.colors.secondary;
                pixi.state.colors.secondary = color;
            }
            if (zgui.beginPopupContextItem()) {
                defer zgui.endPopup();
                if (zgui.colorPicker4("Primary", .{ .col = &primary })) {
                    pixi.state.colors.primary = .{
                        @as(u8, @intFromFloat(primary[0] * 255.0)),
                        @as(u8, @intFromFloat(primary[1] * 255.0)),
                        @as(u8, @intFromFloat(primary[2] * 255.0)),
                        @as(u8, @intFromFloat(primary[3] * 255.0)),
                    };
                }
            }
            zgui.sameLine(.{});

            if (zgui.colorButton("Secondary", .{
                .col = secondary,
                .w = color_width,
                .h = 64 * pixi.content_scale[1],
            })) {
                const color = pixi.state.colors.primary;
                pixi.state.colors.primary = pixi.state.colors.secondary;
                pixi.state.colors.secondary = color;
            }
            if (zgui.beginPopupContextItem()) {
                defer zgui.endPopup();
                if (zgui.colorPicker4("Secondary", .{ .col = &secondary })) {
                    pixi.state.colors.secondary = .{
                        @as(u8, @intFromFloat(secondary[0] * 255.0)),
                        @as(u8, @intFromFloat(secondary[1] * 255.0)),
                        @as(u8, @intFromFloat(secondary[2] * 255.0)),
                        @as(u8, @intFromFloat(secondary[3] * 255.0)),
                    };
                }
            }
        }

        zgui.spacing();
        zgui.spacing();
        zgui.text("Brush", .{});
        zgui.separator();

        if (zgui.radioButton("Circle", .{ .active = pixi.state.tools.shape == .circle })) {
            pixi.state.tools.shape = .circle;
        }

        zgui.sameLine(.{});

        if (zgui.radioButton("Square", .{ .active = pixi.state.tools.shape == .square })) {
            pixi.state.tools.shape = .square;
        }

        _ = zgui.sliderInt("##Size", .{
            .v = &pixi.state.tools.size,
            .min = pixi.Tools.MinSize,
            .max = pixi.Tools.MaxSize,
            .cfmt = "Size: %.0u",
        });

        zgui.sameLine(.{});

        if (zgui.button(" -1 ", .{})) {
            pixi.state.tools.increment_size(-1);
        }

        zgui.sameLine(.{});

        if (zgui.button(" +1 ", .{})) {
            pixi.state.tools.increment_size(1);
        }

        zgui.spacing();
        zgui.spacing();
        zgui.text("Palette", .{});
        zgui.separator();

        zgui.setNextItemWidth(-1.0);
        if (zgui.beginCombo("##PaletteCombo", .{ .preview_value = if (pixi.state.colors.palette) |palette| palette.name else "none", .flags = .{ .height_largest = true } })) {
            defer zgui.endCombo();
            searchPalettes() catch unreachable;
        }
        if (zgui.beginChild("PaletteColors", .{})) {
            defer zgui.endChild();
            if (pixi.state.colors.palette) |palette| {
                for (palette.colors, 0..) |color, i| {
                    const c: [4]f32 = .{
                        @as(f32, @floatFromInt(color[0])) / 255.0,
                        @as(f32, @floatFromInt(color[1])) / 255.0,
                        @as(f32, @floatFromInt(color[2])) / 255.0,
                        @as(f32, @floatFromInt(color[3])) / 255.0,
                    };
                    zgui.pushIntId(@as(i32, @intCast(i)));
                    if (zgui.colorButton(palette.name, .{
                        .col = c,
                    })) {
                        pixi.state.colors.primary = color;
                    }
                    zgui.popId();

                    const min_width = 32.0 * pixi.content_scale[0];
                    const columns: usize = @intFromFloat(@ceil((zgui.getWindowWidth() - pixi.state.settings.explorer_grip * pixi.content_scale[0]) / (min_width + style.item_spacing[0])));

                    if (@mod(i + 1, columns) > 0 and i != palette.colors.len - 1)
                        zgui.sameLine(.{});
                }
            } else {
                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.theme.text_background.toSlice() });
                defer zgui.popStyleColor(.{ .count = 1 });
                zgui.textWrapped("Currently there is no palette loaded, click the dropdown to select a palette", .{});
                zgui.textWrapped("To add new palettes, download a .hex palette from lospec.com and place it here: \n {s}{c}{s}", .{ pixi.state.root_path, std.fs.path.sep, pixi.assets.palettes });
            }
        }
    }
}

pub fn drawTool(label: [:0]const u8, w: f32, h: f32, tool: pixi.Tools.Tool) void {
    const selected = pixi.state.tools.current == tool;
    if (selected) {
        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.theme.text.toSlice() });
    } else {
        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.theme.text_secondary.toSlice() });
    }
    defer zgui.popStyleColor(.{ .count = 1 });
    if (zgui.selectable(label, .{
        .selected = selected,
        .w = w,
        .h = h,
    })) {
        pixi.state.tools.set(tool);
    }
    drawTooltip(tool);
}

pub fn drawTooltip(tool: pixi.Tools.Tool) void {
    if (zgui.isItemHovered(.{ .delay_short = true })) {
        if (zgui.beginTooltip()) {
            defer zgui.endTooltip();

            const text = switch (tool) {
                .pointer => "Pointer",
                .pencil => "Pencil",
                .eraser => "Eraser",
                .animation => "Animation",
                .heightmap => "Heightmap",
                .bucket => "Bucket",
            };

            if (pixi.state.hotkeys.hotkey(.{ .tool = tool })) |hotkey| {
                zgui.text("{s} ({s})", .{ text, hotkey.shortcut });
            } else {
                zgui.text("{s}", .{text});
            }

            switch (tool) {
                .animation => {
                    if (pixi.state.hotkeys.hotkey(.{ .proc = .primary })) |hotkey| {
                        zgui.textColored(pixi.state.theme.text_background.toSlice(), "Click and drag with ({s}) released to edit the current animation", .{hotkey.shortcut});
                        zgui.textColored(pixi.state.theme.text_background.toSlice(), "Click and drag while holding ({s}) to create a new animation", .{hotkey.shortcut});
                    }
                },
                else => {},
            }
        }
    }
}

fn searchPalettes() !void {
    var dir_opt = std.fs.cwd().openIterableDir(pixi.assets.palettes, .{ .access_sub_paths = false }) catch null;
    if (dir_opt) |*dir| {
        defer dir.close();
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file) {
                const ext = std.fs.path.extension(entry.name);
                if (std.mem.eql(u8, ext, ".hex")) {
                    const label = try std.fmt.allocPrintZ(pixi.state.allocator, "{s}", .{entry.name});
                    defer pixi.state.allocator.free(label);
                    if (zgui.selectable(label, .{})) {
                        const abs_path = try std.fs.path.joinZ(pixi.state.allocator, &.{ pixi.assets.palettes, entry.name });
                        defer pixi.state.allocator.free(abs_path);
                        if (pixi.state.colors.palette) |*palette|
                            palette.deinit();

                        pixi.state.colors.palette = pixi.storage.Internal.Palette.loadFromFile(abs_path) catch null;
                    }
                }
            }
        }
    }
}
