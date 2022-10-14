const zgui = @import("zgui");
const pixi = @import("pixi");
const settings = pixi.settings;
const editor = pixi.editor;

pub fn draw() void {
    zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.window_rounding, .v = 0.0 });
    defer zgui.popStyleVar(.{ .count = 1 });
    zgui.setNextWindowPos(.{
        .x = (settings.sidebar_width + settings.explorer_width) * pixi.state.window.scale[0],
        .y = 0,
        .cond = .always,
    });
    zgui.setNextWindowSize(.{
        .w = (pixi.state.window.size[0] - settings.explorer_width - settings.sidebar_width) * pixi.state.window.scale[0],
        .h = pixi.state.window.size[1] * pixi.state.window.scale[1] + 5.0,
    });

    if (zgui.begin("Art", .{
        .flags = .{
            .no_title_bar = true,
            .no_resize = true,
            .no_move = true,
            .no_collapse = true,
            .menu_bar = true,
        },
    })) {
        editor.menu.draw();

        if (zgui.beginChild("Canvas", .{
            .w = 0.0,
            .h = pixi.state.window.size[1] / 1.5 * pixi.state.window.scale[1],
            .border = false,
            .flags = .{},
        })) {
            if (zgui.beginTabBar("Files", .{
                .reorderable = true,
                .auto_select_new_tabs = true,
            })) {
                if (zgui.beginTabItem("  " ++ pixi.fa.file_powerpoint ++ "  Test1  ", .{})) {
                    const w = @intToFloat(f32, pixi.state.background_logo.width) * 1.5 * pixi.state.window.scale[0];
                    const h = @intToFloat(f32, pixi.state.background_logo.height) * 1.5 * pixi.state.window.scale[1];
                    zgui.setCursorPosX((zgui.getWindowWidth() - w) / 2);
                    zgui.setCursorPosY((zgui.getWindowHeight() - h) / 2);
                    zgui.image(pixi.state.gctx.lookupResource(pixi.state.background_logo.view_handle).?, .{
                        .w = w,
                        .h = h,
                        .tint_col = .{ 1.0, 1.0, 1.0, 0.25 },
                    });
                    zgui.endTabItem();
                }

                if (zgui.beginTabItem("  " ++ pixi.fa.file_powerpoint ++ "  Test2  ", .{})) {
                    zgui.endTabItem();
                }

                zgui.endTabBar();
            }
            zgui.endChild();
        }
        zgui.separator();
        if (zgui.beginChild("Flipbook", .{
            .w = 0.0,
            .h = 0.0,
            .border = false,
            .flags = .{},
        })) {
            zgui.endChild();
        }
    }
    zgui.end();
}
