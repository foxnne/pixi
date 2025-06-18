const std = @import("std");

const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");

pub fn collapsibleMenu(src: std.builtin.SourceLocation, rect: *dvui.Rect, closing: *bool, opts: dvui.Options) !*dvui.MenuWidget {
    const menu_id = dvui.parentGet().extendId(@src(), 1);

    if (dvui.firstFrame(menu_id)) {
        dvui.animation(menu_id, "menu_y", .{ .start_val = 0.0, .end_val = 1.0, .start_time = 0, .end_time = 300_000 });
        dvui.dataSet(null, menu_id, "y", -rect.h);
    }

    if (closing.*) {
        closing.* = false;
        dvui.animation(menu_id, "menu_y", .{ .start_val = 1.0, .end_val = 0.0, .start_time = 0, .end_time = 300_000 });
        dvui.dataSet(null, menu_id, "y", -rect.h);
    }

    for (dvui.events()) |e| {
        if (e.evt == .mouse) {
            if (e.evt.mouse.p.y > 200.0 and !closing.*) {
                closing.* = true;
            }
            //dvui.animation(menu_id, "menu_y", .{ .start_val = 0.0, .end_val = 1.0, .start_time = 0, .end_time = 300_000 });
        }
    }

    var menu: *dvui.MenuWidget = undefined;

    if (dvui.animationGet(menu_id, "menu_y")) |a| {
        if (dvui.dataGet(null, menu_id, "y", f32)) |y| {
            _ = y; // autofix
            var r = rect.*;
            //r.x = r.x + (r.w / 2) - (dw / 2);
            //r.w = dw;
            r.y = r.y + a.value() * r.h;

            menu = try dvui.menu(src, .horizontal, opts.override(.{ .rect = r }));

            //r.h = dh;
        } else {
            menu = try dvui.menu(src, .horizontal, opts);
        }
    }

    return menu;
}
