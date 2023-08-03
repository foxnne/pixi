const pixi = @import("../../pixi.zig");
const mach = @import("core");
const zgui = @import("zgui").MachImgui(mach);

pub fn draw() void {
    zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.window_rounding, .v = 0.0 });
    defer zgui.popStyleVar(.{ .count = 1 });
    zgui.setNextWindowPos(.{
        .x = 0.0,
        .y = 0.0,
        .cond = .always,
    });
    zgui.setNextWindowSize(.{
        .w = pixi.state.settings.sidebar_width * pixi.content_scale[0],
        .h = pixi.framebuffer_size[1],
    });
    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.selectable_text_align, .v = .{ 0.5, 0.5 } });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.header, .c = pixi.state.theme.foreground.toSlice() });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.window_bg, .c = pixi.state.theme.foreground.toSlice() });
    defer zgui.popStyleVar(.{ .count = 1 });
    defer zgui.popStyleColor(.{ .count = 2 });

    if (zgui.begin("Sidebar", .{
        .flags = .{
            .no_title_bar = true,
            .no_resize = true,
            .no_move = true,
            .no_collapse = true,
            .no_scrollbar = true,
            .no_scroll_with_mouse = true,
        },
    })) {
        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.header_hovered, .c = pixi.state.theme.foreground.toSlice() });
        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.header_active, .c = pixi.state.theme.foreground.toSlice() });
        defer zgui.popStyleColor(.{ .count = 2 });

        drawOption(.files, pixi.fa.folder_open);
        drawOption(.tools, pixi.fa.pencil_alt);
        drawOption(.layers, pixi.fa.layer_group);
        drawOption(.sprites, pixi.fa.th);
        drawOption(.animations, pixi.fa.play_circle);
        drawOption(.pack, pixi.fa.box_open);
        drawOption(.settings, pixi.fa.cog);
    }

    zgui.end();
}

fn drawOption(option: pixi.Sidebar, icon: [:0]const u8) void {
    const position = zgui.getCursorPos();
    const selectable_width = (pixi.state.settings.sidebar_width - 8) * pixi.content_scale[0];
    const selectable_height = (pixi.state.settings.sidebar_width - 8) * pixi.content_scale[1];
    zgui.dummy(.{
        .w = selectable_width,
        .h = selectable_height,
    });

    zgui.setCursorPos(position);
    if (pixi.state.sidebar == option) {
        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.theme.highlight_primary.toSlice() });
    } else if (zgui.isItemHovered(.{})) {
        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.theme.text.toSlice() });
    } else {
        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.theme.text_secondary.toSlice() });
    }
    if (zgui.selectable(icon, .{
        .selected = pixi.state.sidebar == option,
        .w = selectable_width,
        .h = selectable_height,
        .flags = .{
            .dont_close_popups = true,
        },
    })) {
        pixi.state.sidebar = option;
        if (option == .sprites)
            pixi.state.tools.set(.pointer);
    }
    zgui.popStyleColor(.{ .count = 1 });
}
