const std = @import("std");
const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");

pub var mode: enum(usize) {
    single,
    animation,
    layer,
    all,
} = .single;

pub var scale: u32 = 1;

pub const max_size: [2]u32 = .{ 4096, 4096 };
pub const min_size: [2]u32 = .{ 1, 1 };

pub const max_scale: u32 = 16;
pub const min_scale: u32 = 1;

pub fn dialog(_: dvui.Id) anyerror!bool {
    var outer_box = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both });
    defer outer_box.deinit();

    {
        const valid: bool = true;

        var horizontal_box = dvui.box(@src(), .{ .dir = .horizontal, .equal_space = true }, .{ .expand = .none, .gravity_x = 0.5 });
        defer horizontal_box.deinit();

        const field_names = std.meta.fieldNames(@TypeOf(mode));

        for (field_names, 0..) |tag, i| {
            const corner_radius: dvui.Rect = if (i == 0) .{
                .x = 100000,
                .h = 100000,
            } else if (i == field_names.len - 1) .{
                .y = 100000,
                .w = 100000,
            } else .all(0);

            var name = dvui.currentWindow().arena().dupe(u8, tag) catch {
                dvui.log.err("Failed to dupe tag {s}", .{tag});
                return false;
            };
            @memcpy(name.ptr, tag);
            name[0] = std.ascii.toUpper(name[0]);

            if (dvui.button(@src(), name, .{ .draw_focus = false }, .{
                .corner_radius = corner_radius,
                .id_extra = i,
                .margin = .all(0),
                .padding = .all(4),
                .expand = .horizontal,
                .color_fill = if (mode == @as(@TypeOf(mode), @enumFromInt(i))) dvui.themeGet().color(.window, .fill) else dvui.themeGet().color(.control, .fill),
            })) {
                mode = @enumFromInt(i);
            }
        }

        return valid;
    }

    return false;
}

/// Returns a physical rect that the dialog should animate into after closing, or null if the dialog should be removed without animation
pub fn callAfter(_: dvui.Id, response: dvui.enums.DialogResponse) anyerror!void {
    switch (response) {
        .ok => {},
        .cancel => {},
        else => {},
    }
}
