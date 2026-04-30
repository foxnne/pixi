const std = @import("std");
const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");

pub fn request() void {
    pixi.editor.app_quit_unsaved_dialog_open = true;
    var mutex = pixi.dvui.dialog(@src(), .{
        .displayFn = dialog,
        .callafterFn = callAfter,
        .title = "Quit Pixi?",
        .ok_label = "",
        .cancel_label = "",
        .resizeable = false,
        .default = .cancel,
        .hide_footer = true,
        .max_size = .{ .w = 520, .h = 280 },
        .header_kind = .err,
    });
    mutex.mutex.unlock(dvui.io);
}

fn dirtyCount() usize {
    var n: usize = 0;
    for (pixi.editor.open_files.values()) |f| {
        if (f.dirty()) n += 1;
    }
    return n;
}

fn dialogButton(src: std.builtin.SourceLocation, label_text: []const u8, style: dvui.Theme.Style.Name, tab_idx: u16, id_extra: usize) bool {
    const opts: dvui.Options = .{
        .tab_index = tab_idx,
        .style = style,
        .id_extra = id_extra,
        .box_shadow = .{
            .color = .black,
            .alpha = 0.25,
            .offset = .{ .x = -4, .y = 4 },
            .fade = 8,
        },
    };
    var button: dvui.ButtonWidget = undefined;
    button.init(src, .{}, opts);
    defer button.deinit();
    button.processEvents();
    button.drawFocus();
    button.drawBackground();
    dvui.labelNoFmt(src, label_text, .{}, opts.strip().override(button.style()).override(.{ .gravity_x = 0.5, .gravity_y = 0.5 }));
    return button.clicked();
}

pub fn dialog(_: dvui.Id) anyerror!bool {
    const n = dirtyCount();

    var outer = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both, .padding = .all(8) });
    defer outer.deinit();

    dvui.label(
        @src(),
        "You have {d} unsaved document(s). Save changes before quitting?",
        .{n},
        .{ .font = dvui.Font.theme(.body) },
    );

    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 8, .h = 16 } });

    var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
    defer row.deinit();

    var btn_row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .none, .gravity_x = 0.5 });
    defer btn_row.deinit();

    if (dialogButton(@src(), "Quit without saving", .control, 1, 0)) {
        try onQuitWithoutSaving();
    }
    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 10, .h = 1 } });
    if (dialogButton(@src(), "Save all and quit", .highlight, 2, 1)) {
        try onSaveAllAndQuit();
    }
    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 10, .h = 1 } });
    if (dialogButton(@src(), "Cancel", .control, 3, 2)) {
        onCancel();
    }

    return true;
}

fn onQuitWithoutSaving() !void {
    pixi.editor.app_quit_unsaved_dialog_open = false;
    pixi.dvui.closeFloatingDialogAnchored();

    const alloc = pixi.app.allocator;
    const keys = try alloc.alloc(u64, pixi.editor.open_files.count());
    defer alloc.free(keys);
    for (pixi.editor.open_files.keys(), 0..) |k, i| keys[i] = k;
    for (keys) |id| {
        try pixi.editor.rawCloseFileID(id);
    }
    pixi.editor.pending_app_close = true;
}

fn onSaveAllAndQuit() !void {
    pixi.editor.app_quit_unsaved_dialog_open = false;
    pixi.dvui.closeFloatingDialogAnchored();

    pixi.editor.quit_save_all_ids.clearRetainingCapacity();
    for (pixi.editor.open_files.values()) |f| {
        if (f.dirty()) try pixi.editor.quit_save_all_ids.append(pixi.app.allocator, f.id);
    }
    if (pixi.editor.quit_save_all_ids.items.len == 0) {
        pixi.editor.pending_app_close = true;
        return;
    }
    pixi.editor.quit_save_all_active = true;
    pixi.editor.quit_in_progress = true;
    pixi.editor.pending_quit_continue = true;
}

fn onCancel() void {
    pixi.editor.app_quit_unsaved_dialog_open = false;
    pixi.editor.quit_in_progress = false;
    pixi.dvui.closeFloatingDialogAnchored();
}

pub fn callAfter(_: dvui.Id, response: dvui.enums.DialogResponse) !void {
    switch (response) {
        .cancel => {
            pixi.editor.app_quit_unsaved_dialog_open = false;
            pixi.editor.quit_in_progress = false;
        },
        else => {},
    }
}
