const zgui = @import("zgui");
const pixi = @import("pixi");
const settings = pixi.settings;

pub fn draw() void {
    zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.window_rounding, .v = 0.0 });
    defer zgui.popStyleVar(.{ .count = 1 });
    zgui.setNextWindowPos(.{
        .x = 0.0,
        .y = 0.0,
        .cond = .always,
    });
    zgui.setNextWindowSize(.{
        .w = settings.sidebar_width * pixi.state.window.scale[0],
        .h = pixi.state.window.size[1] * pixi.state.window.scale[1],
    });

    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.selectable_text_align, .v = .{ 0.5, 0.5 } });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.header, .c = pixi.state.style.foreground.toSlice() });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.window_bg, .c = pixi.state.style.foreground.toSlice() });
    defer zgui.popStyleVar(.{ .count = 1 });
    defer zgui.popStyleColor(.{ .count = 2 });

    if (zgui.begin("Sidebar", .{
        .flags = .{
            .no_title_bar = true,
            .no_resize = true,
            .no_move = true,
            .no_collapse = true,
        },
    })) {
        const selectable_width = (settings.sidebar_width - 8) * pixi.state.window.scale[0];
        const selectable_height = (settings.sidebar_width - 8) * pixi.state.window.scale[1];

        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.header_hovered, .c = pixi.state.style.background.toSlice() });
        zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.header_active, .c = pixi.state.style.background.toSlice() });

        // Files
        if (pixi.state.sidebar == .files) {
            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text.toSlice() });
        } else {
            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text_secondary.toSlice() });
        }
        if (zgui.selectable(pixi.fa.folder_open, .{
            .selected = pixi.state.sidebar == .files,
            .w = selectable_width,
            .h = selectable_height,
            .flags = .{
                .dont_close_popups = true,
            },
        })) {
            pixi.state.sidebar = .files;
        }
        zgui.popStyleColor(.{ .count = 1 });

        // Tools
        if (pixi.state.sidebar == .tools) {
            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text.toSlice() });
        } else {
            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text_secondary.toSlice() });
        }
        if (zgui.selectable(pixi.fa.pen_fancy, .{
            .selected = pixi.state.sidebar == .tools,
            .w = selectable_width,
            .h = selectable_height,
            .flags = .{
                .dont_close_popups = true,
            },
        })) {
            pixi.state.sidebar = .tools;
        }
        zgui.popStyleColor(.{ .count = 3 });
    }

    zgui.end();
}
