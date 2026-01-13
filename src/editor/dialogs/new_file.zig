const std = @import("std");
const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");

pub const DialogOptions = struct {
    window: ?*dvui.Window = null,
    id_extra: usize = 0,
    displayFn: dvui.Dialog.DisplayFn = dialogDisplay,
    callafterFn: dvui.DialogCallAfterFn = callAfter,
    parent_path: []const u8 = "",
};

pub fn dialog(src: std.builtin.SourceLocation, opts: DialogOptions) void {
    const id_mutex = dvui.dialogAdd(opts.window, src, opts.id_extra, opts.displayFn);
    const id = id_mutex.id;

    const title: []const u8 = "New File...";
    const message: []const u8 = "Testing...";
    const ok_label: []const u8 = "Ok";
    const cancel_label: []const u8 = "Cancel";
    const default: dvui.enums.DialogResponse = .ok;
    const callafter: dvui.DialogCallAfterFn = opts.callafterFn;
    const max_size: dvui.Options.MaxSize = .{ .w = 400, .h = 200 };

    dvui.dataSet(opts.window, id, "_modal", true);
    dvui.dataSetSlice(opts.window, id, "_title", title);
    dvui.dataSetSlice(opts.window, id, "_message", message);
    dvui.dataSet(opts.window, id, "_center_on", (opts.window orelse dvui.currentWindow()).subwindows.current_rect);
    dvui.dataSetSlice(opts.window, id, "_ok_label", ok_label);
    dvui.dataSetSlice(opts.window, id, "_cancel_label", cancel_label);
    dvui.dataSet(opts.window, id, "_default", default);
    dvui.dataSet(opts.window, id, "_callafter", callafter);
    dvui.dataSet(opts.window, id, "_max_size", max_size);
    dvui.dataSetSlice(opts.window, id, "_parent_path", opts.parent_path);

    id_mutex.mutex.unlock();
}

pub fn dialogDisplay(id: dvui.Id) anyerror!void {
    // const modal = dvui.dataGet(null, id, "_modal", bool) orelse {
    //     dvui.log.err("dialogDisplay lost data for dialog {x}\n", .{id});
    //     dvui.dialogRemove(id);
    //     return;
    // };

    const title = dvui.dataGetSlice(null, id, "_title", []u8) orelse {
        dvui.log.err("dialogDisplay lost data for dialog {x}\n", .{id});
        dvui.dialogRemove(id);
        return;
    };

    // const message = dvui.dataGetSlice(null, id, "_message", []u8) orelse {
    //     dvui.log.err("dialogDisplay lost data for dialog {x}\n", .{id});
    //     dvui.dialogRemove(id);
    //     return;
    // };

    const ok_label = dvui.dataGetSlice(null, id, "_ok_label", []u8) orelse {
        dvui.log.err("dialogDisplay lost data for dialog {x}\n", .{id});
        dvui.dialogRemove(id);
        return;
    };

    // If we don't reference this information here, DVUI will free it, so we need to reference it so it remains
    // valid when the callafterFn is called
    _ = dvui.dataGetSlice(dvui.currentWindow(), id, "_parent_path", []u8) orelse {
        dvui.log.err("dialogDisplay lost data for dialog {x}\n", .{id});
        dvui.dialogRemove(id);
        return;
    };

    const center_on = dvui.dataGet(null, id, "_center_on", dvui.Rect.Natural) orelse dvui.currentWindow().subwindows.current_rect;

    const cancel_label = dvui.dataGetSlice(null, id, "_cancel_label", []u8);
    const default = dvui.dataGet(null, id, "_default", dvui.enums.DialogResponse);

    const callafter = dvui.dataGet(null, id, "_callafter", dvui.DialogCallAfterFn);

    const maxSize = dvui.dataGet(null, id, "_max_size", dvui.Options.MaxSize);

    var win = pixi.dvui.floatingWindow(@src(), .{
        .modal = true,
        .center_on = center_on,
        .window_avoid = .nudge,
    }, .{
        .id_extra = id.asUsize(),
        .color_text = .black,
        .max_size_content = maxSize,
        .box_shadow = .{
            .color = .black,
            .alpha = 0.25,
            .offset = .{ .x = -4, .y = 4 },
            .fade = 8,
        },
    });
    defer win.deinit();

    var header_openflag = true;
    win.dragAreaSet(dvui.windowHeader(title, "", &header_openflag));
    if (!header_openflag) {
        dvui.dialogRemove(id);
        if (callafter) |ca| {
            ca(id, .cancel) catch |err| {
                dvui.log.debug("Dialog callafter for {x} returned {any}", .{ id, err });
            };
        }
        return;
    }

    {
        // Add the buttons at the bottom first, so that they are guaranteed to be shown
        var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{ .gravity_x = 0.5, .gravity_y = 1.0 });
        defer hbox.deinit();

        if (cancel_label) |cl| {
            var cancel_data: dvui.WidgetData = undefined;
            const gravx: f32, const tindex: u16 = switch (dvui.currentWindow().button_order) {
                .cancel_ok => .{ 0.0, 1 },
                .ok_cancel => .{ 1.0, 3 },
            };
            if (dvui.button(@src(), cl, .{}, .{ .tab_index = tindex, .data_out = &cancel_data, .gravity_x = gravx })) {
                dvui.dialogRemove(id);
                if (callafter) |ca| {
                    ca(id, .cancel) catch |err| {
                        dvui.log.debug("Dialog callafter for {x} returned {any}", .{ id, err });
                    };
                }
                return;
            }
            if (default != null and dvui.firstFrame(hbox.data().id) and default.? == .cancel) {
                dvui.focusWidget(cancel_data.id, null, null);
            }
        }

        var ok_data: dvui.WidgetData = undefined;
        if (dvui.button(@src(), ok_label, .{}, .{ .tab_index = 2, .data_out = &ok_data })) {
            dvui.dialogRemove(id);
            if (callafter) |ca| {
                ca(id, .ok) catch |err| {
                    dvui.log.debug("Dialog callafter for {x} returned {any}", .{ id, err });
                };
            }
            return;
        }
        if (default != null and dvui.firstFrame(hbox.data().id) and default.? == .ok) {
            dvui.focusWidget(ok_data.id, null, null);
        }
    }

    // Now add the scroll area which will get the remaining space
    var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both, .style = .window });
    var tl = dvui.textLayout(@src(), .{}, .{ .background = false });
    tl.addText("Which type of file do you want to create?", .{
        .font = dvui.themeGet().font_heading,
    });
    tl.deinit();
    scroll.deinit();
}

pub fn callAfter(id: dvui.Id, response: dvui.enums.DialogResponse) anyerror!void {
    _ = dvui.dataGetSlice(null, id, "_parent_path", []u8) orelse {
        dvui.log.err("dialogDisplay lost data for dialog {x}\n", .{id});
        dvui.dialogRemove(id);
        return;
    };

    switch (response) {
        .ok => {},
        .cancel => {},
        else => {},
    }
}
