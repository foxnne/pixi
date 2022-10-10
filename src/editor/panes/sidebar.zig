const zgui = @import("zgui");
const pixi = @import("pixi");
const settings = pixi.settings;

pub fn draw() void {
    const width_offset = 5.0;

    zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.window_rounding, .v = 0.0 });
    defer zgui.popStyleVar(.{ .count = 1 });
    zgui.setNextWindowPos(.{
        .x = -width_offset,
        .y = -2.5 * pixi.state.window.scale[1],
        .cond = .always,
    });
    zgui.setNextWindowSize(.{
        .w = settings.sidebar_width * pixi.state.window.scale[0] + width_offset,
        .h = pixi.state.window.size[1] * pixi.state.window.scale[1] + 5.0,
    });

    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.selectable_text_align, .v = .{ 0.5, 0.5 } });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.header, .c = pixi.state.style.background.toSlice() });
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
        if (zgui.selectable("Files", .{
            .selected = pixi.state.sidebar == .files,
            .w = selectable_width,
            .h = selectable_height,
            .flags = .{
                .dont_close_popups = true,
            },
        })) {
            pixi.state.sidebar = .files;
        }
        if (zgui.selectable("Tools", .{
            .selected = pixi.state.sidebar == .tools,
            .w = selectable_width,
            .h = selectable_height,
            .flags = .{
                .dont_close_popups = true,
            },
        })) {
            pixi.state.sidebar = .tools;
        }
    }

    zgui.end();
}
