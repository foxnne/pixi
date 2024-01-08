const std = @import("std");
const pixi = @import("../../pixi.zig");
const core = @import("mach-core");
const imgui = @import("zig-imgui");

pub fn draw() void {
    imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 8.0 * pixi.content_scale[0], .y = 8.0 * pixi.content_scale[1] });
    imgui.pushStyleVarImVec2(imgui.StyleVar_SelectableTextAlign, .{ .x = 0.5, .y = 0.8 });
    defer imgui.popStyleVarEx(2);

    imgui.pushStyleColorImVec4(imgui.Col_Header, pixi.state.theme.foreground.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_HeaderHovered, pixi.state.theme.foreground.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_HeaderActive, pixi.state.theme.foreground.toImguiVec4());
    defer imgui.popStyleColorEx(3);
    if (imgui.beginChild("Tools", .{
        .x = imgui.getWindowWidth(),
        .y = -1.0,
    }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
        defer imgui.endChild();

        const style = imgui.getStyle();
        const window_size = imgui.getWindowSize();

        const button_width = imgui.getWindowWidth() / 3.6;
        const button_height = button_width / 2.0;

        const color_width = window_size.x / 2.2;

        // Row 1
        {
            imgui.setCursorPosX(style.item_spacing.x);
            drawTool(pixi.fa.mouse_pointer, button_width, button_height, .pointer);
            imgui.sameLine();
            drawTool(pixi.fa.pencil_alt, button_width, button_height, .pencil);
            imgui.sameLine();
            drawTool(pixi.fa.eraser, button_width, button_height, .eraser);
        }

        // Row 2
        {
            imgui.setCursorPosX(style.item_spacing.x);
            drawTool(pixi.fa.sort_amount_up, button_width, button_height, .heightmap);
            imgui.sameLine();
            drawTool(pixi.fa.fill_drip, button_width, button_height, .bucket);
        }

        imgui.spacing();
        imgui.spacing();
        imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_secondary.toImguiVec4());
        imgui.separatorText("Colors  " ++ pixi.fa.paint_brush);
        imgui.popStyleColor();

        if (pixi.state.tools.current == .heightmap) {
            var height: i32 = @as(i32, @intCast(pixi.state.colors.height));
            if (imgui.sliderInt("Height", &height, 0, 255)) {
                pixi.state.colors.height = @as(u8, @intCast(std.math.clamp(height, 0, 255)));
            }
        } else {
            var primary: imgui.Vec4 = if (pixi.state.tools.current == .heightmap) .{ .x = 255, .y = 255, .z = 255, .w = 255 } else .{
                .x = @as(f32, @floatFromInt(pixi.state.colors.primary[0])) / 255.0,
                .y = @as(f32, @floatFromInt(pixi.state.colors.primary[1])) / 255.0,
                .z = @as(f32, @floatFromInt(pixi.state.colors.primary[2])) / 255.0,
                .w = @as(f32, @floatFromInt(pixi.state.colors.primary[3])) / 255.0,
            };

            var secondary: imgui.Vec4 = .{
                .x = @as(f32, @floatFromInt(pixi.state.colors.secondary[0])) / 255.0,
                .y = @as(f32, @floatFromInt(pixi.state.colors.secondary[1])) / 255.0,
                .z = @as(f32, @floatFromInt(pixi.state.colors.secondary[2])) / 255.0,
                .w = @as(f32, @floatFromInt(pixi.state.colors.secondary[3])) / 255.0,
            };

            if (imgui.colorButtonEx("Primary", primary, imgui.ColorEditFlags_None, .{
                .x = color_width,
                .y = 64 * pixi.content_scale[1],
            })) {
                const color = pixi.state.colors.primary;
                pixi.state.colors.primary = pixi.state.colors.secondary;
                pixi.state.colors.secondary = color;
            }
            if (imgui.beginItemTooltip()) {
                defer imgui.endTooltip();
                imgui.textColored(pixi.state.theme.text_background.toImguiVec4(), "Right click to edit color.");
            }
            if (imgui.beginPopupContextItem()) {
                defer imgui.endPopup();
                var c = pixi.math.Color.initFloats(primary.x, primary.y, primary.z, primary.w).toSlice();
                if (imgui.colorPicker4("Primary", &c, imgui.ColorEditFlags_None, null)) {
                    pixi.state.colors.primary = .{
                        @as(u8, @intFromFloat(c[0] * 255.0)),
                        @as(u8, @intFromFloat(c[1] * 255.0)),
                        @as(u8, @intFromFloat(c[2] * 255.0)),
                        @as(u8, @intFromFloat(c[3] * 255.0)),
                    };
                }
            }
            imgui.sameLine();

            if (imgui.colorButtonEx("Secondary", secondary, imgui.ColorEditFlags_None, .{
                .x = color_width,
                .y = 64 * pixi.content_scale[1],
            })) {
                const color = pixi.state.colors.primary;
                pixi.state.colors.primary = pixi.state.colors.secondary;
                pixi.state.colors.secondary = color;
            }

            if (imgui.beginItemTooltip()) {
                defer imgui.endTooltip();
                imgui.textColored(pixi.state.theme.text_background.toImguiVec4(), "Right click to edit color.");
            }

            if (imgui.beginPopupContextItem()) {
                defer imgui.endPopup();
                var c = pixi.math.Color.initFloats(primary.x, primary.y, primary.z, primary.w).toSlice();
                if (imgui.colorPicker4("Secondary", &c, imgui.ColorEditFlags_None, null)) {
                    pixi.state.colors.secondary = .{
                        @as(u8, @intFromFloat(c[0] * 255.0)),
                        @as(u8, @intFromFloat(c[1] * 255.0)),
                        @as(u8, @intFromFloat(c[2] * 255.0)),
                        @as(u8, @intFromFloat(c[3] * 255.0)),
                    };
                }
            }
        }

        imgui.spacing();
        imgui.spacing();
        imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_secondary.toImguiVec4());
        imgui.separatorText("Palette  " ++ pixi.fa.palette);
        imgui.popStyleColor();

        imgui.setNextItemWidth(-1.0);
        if (imgui.beginCombo("##PaletteCombo", if (pixi.state.colors.palette) |palette| palette.name else "none", imgui.ComboFlags_HeightLargest)) {
            defer imgui.endCombo();
            searchPalettes() catch unreachable;
        }
        if (imgui.beginChild("PaletteColors", .{ .x = 0.0, .y = 0.0 }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
            defer imgui.endChild();
            if (pixi.state.colors.palette) |palette| {
                for (palette.colors, 0..) |color, i| {
                    const c: imgui.Vec4 = .{
                        .x = @as(f32, @floatFromInt(color[0])) / 255.0,
                        .y = @as(f32, @floatFromInt(color[1])) / 255.0,
                        .z = @as(f32, @floatFromInt(color[2])) / 255.0,
                        .w = @as(f32, @floatFromInt(color[3])) / 255.0,
                    };
                    imgui.pushIDInt(@as(c_int, @intCast(i)));
                    if (imgui.colorButton(palette.name, .{ .x = c.x, .y = c.y, .z = c.z, .w = c.w }, imgui.ColorEditFlags_None)) {
                        pixi.state.colors.primary = color;
                    }
                    imgui.popID();

                    const min_width = 32.0 * pixi.content_scale[0];
                    const columns: usize = @intFromFloat(@ceil((imgui.getWindowWidth() - pixi.state.settings.explorer_grip * pixi.content_scale[0]) / (min_width + style.item_spacing.x)));

                    if (@mod(i + 1, columns) > 0 and i != palette.colors.len - 1)
                        imgui.sameLine();
                }
            } else {
                imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_background.toImguiVec4());
                defer imgui.popStyleColor();
                imgui.textWrapped("Currently there is no palette loaded, click the dropdown to select a palette");

                const new_palette_text = std.fmt.allocPrintZ(pixi.state.allocator, "To add new palettes, download a .hex palette from lospec.com and place it here: \n {s}{c}{s}", .{
                    pixi.state.root_path,
                    std.fs.path.sep,
                    pixi.assets.palettes,
                }) catch unreachable;
                defer pixi.state.allocator.free(new_palette_text);

                imgui.textWrapped(new_palette_text);
            }
        }
    }
}

pub fn drawTool(label: [:0]const u8, w: f32, h: f32, tool: pixi.Tools.Tool) void {
    const selected = pixi.state.tools.current == tool;
    if (selected) {
        imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text.toImguiVec4());
    } else {
        imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_secondary.toImguiVec4());
    }
    defer imgui.popStyleColor();
    if (imgui.selectableEx(label, selected, imgui.SelectableFlags_None, .{ .x = w, .y = h })) {
        pixi.state.tools.set(tool);
    }
    drawTooltip(tool);
}

pub fn drawTooltip(tool: pixi.Tools.Tool) void {
    if (imgui.isItemHovered(imgui.HoveredFlags_DelayShort)) {
        if (imgui.beginTooltip()) {
            defer imgui.endTooltip();

            const text = switch (tool) {
                .pointer => "Pointer",
                .pencil => "Pencil",
                .eraser => "Eraser",
                .animation => "Animation",
                .heightmap => "Heightmap",
                .bucket => "Bucket",
            };

            if (pixi.state.hotkeys.hotkey(.{ .tool = tool })) |hotkey| {
                const hotkey_text = std.fmt.allocPrintZ(pixi.state.allocator, "{s} ({s})", .{ text, hotkey.shortcut }) catch unreachable;
                defer pixi.state.allocator.free(hotkey_text);
                imgui.text(hotkey_text);
            } else {
                imgui.text(text);
            }

            switch (tool) {
                .animation => {
                    if (pixi.state.hotkeys.hotkey(.{ .proc = .primary })) |hotkey| {
                        const first_text = std.fmt.allocPrintZ(pixi.state.allocator, "Click and drag with ({s}) released to edit the current animation", .{hotkey.shortcut}) catch unreachable;
                        defer pixi.state.allocator.free(first_text);

                        const second_text = std.fmt.allocPrintZ(pixi.state.allocator, "Click and drag while holding ({s}) to create a new animation", .{hotkey.shortcut}) catch unreachable;
                        defer pixi.state.allocator.free(second_text);

                        imgui.textColored(pixi.state.theme.text_background.toImguiVec4(), first_text);
                        imgui.textColored(pixi.state.theme.text_background.toImguiVec4(), second_text);
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
                    if (imgui.selectable(label)) {
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
