const std = @import("std");
const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");

/// Set in `request` for `callAfter` (header close) and button handlers.
pub var pending_mode: Mode = .tab_close;

pub const Mode = enum {
    tab_close,
    app_quit,
};

pub fn request(file_id: u64, mode: Mode) void {
    pending_mode = mode;
    var mutex = pixi.dvui.dialog(@src(), .{
        .displayFn = dialog,
        .callafterFn = callAfter,
        .title = "Unsaved changes",
        .ok_label = "",
        .cancel_label = "",
        .resizeable = false,
        .default = .cancel,
        .hide_footer = true,
        .max_size = .{ .w = 520, .h = 280 },
    });
    dvui.dataSet(null, mutex.id, "_unsaved_file_id", file_id);
    mutex.mutex.unlock();
}

fn fileBasename(file_id: u64) []const u8 {
    const file = pixi.editor.open_files.get(file_id) orelse return "?";
    return std.fs.path.basename(file.path);
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

pub fn dialog(id: dvui.Id) anyerror!bool {
    const file_id = dvui.dataGet(null, id, "_unsaved_file_id", u64) orelse return false;
    const name = fileBasename(file_id);

    var outer = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both, .padding = .all(8) });
    defer outer.deinit();

    dvui.label(
        @src(),
        "Save changes to \"{s}\" before closing?",
        .{name},
        .{ .font = dvui.Font.theme(.body) },
    );

    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 8, .h = 16 } });

    var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
    defer row.deinit();

    var btn_row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .none, .gravity_x = 0.5 });
    defer btn_row.deinit();

    if (dialogButton(@src(), "Close", .control, 1, 0)) {
        try onDiscard(file_id);
    }
    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 10, .h = 1 } });
    if (dialogButton(@src(), "Save and Close", .highlight, 2, 1)) {
        try onSaveAndClose(file_id);
    }
    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 10, .h = 1 } });
    if (dialogButton(@src(), "Cancel", .control, 3, 2)) {
        onCancel();
    }

    return true;
}

fn onDiscard(file_id: u64) !void {
    try pixi.editor.rawCloseFileID(file_id);
    pixi.dvui.closeFloatingDialogAnchored();
    if (pending_mode == .app_quit) {
        pixi.editor.pending_quit_continue = true;
    }
}

fn onCancel() void {
    if (pending_mode == .app_quit) {
        pixi.editor.quit_in_progress = false;
    }
    pixi.dvui.closeFloatingDialogAnchored();
}

/// Must complete before the file is closed — `saveAsync` runs on another thread and races with `deinit`.
fn saveSynchronously(file: *pixi.Internal.File) !void {
    const ext = std.fs.path.extension(file.path);
    const win = dvui.currentWindow();
    if (std.mem.eql(u8, ext, ".pixi")) {
        try file.saveZip(win);
    } else if (std.mem.eql(u8, ext, ".png")) {
        try file.savePng(win);
    } else if (std.mem.eql(u8, ext, ".jpg") or std.mem.eql(u8, ext, ".jpeg")) {
        try file.saveJpg(win);
    } else {
        return error.UnsupportedSaveExtension;
    }
}

fn onSaveAndClose(file_id: u64) !void {
    const file = pixi.editor.open_files.getPtr(file_id) orelse return;
    if (!pixi.Internal.File.hasRecognizedSaveExtension(file.path)) {
        const idx = pixi.editor.open_files.getIndex(file_id) orelse return;
        pixi.editor.setActiveFile(idx);
        pixi.editor.pending_close_file_id = file_id;
        pixi.dvui.closeFloatingDialogAnchored();
        pixi.editor.requestSaveAs();
        return;
    }
    saveSynchronously(file) catch |err| {
        dvui.log.err("Save and Close failed: {s}", .{@errorName(err)});
        return;
    };
    try pixi.editor.rawCloseFileID(file_id);
    pixi.dvui.closeFloatingDialogAnchored();
    if (pending_mode == .app_quit) {
        pixi.editor.pending_quit_continue = true;
    }
}

pub fn callAfter(_: dvui.Id, response: dvui.enums.DialogResponse) !void {
    switch (response) {
        .cancel => {
            if (pending_mode == .app_quit) {
                pixi.editor.quit_in_progress = false;
            }
        },
        else => {},
    }
}

/// After closing a tab during app quit, open the next dirty prompt or finish quit.
pub fn continueAppQuitIfNeeded() void {
    if (!pixi.editor.quit_in_progress) return;

    var first_dirty: ?u64 = null;
    for (pixi.editor.open_files.values()) |f| {
        if (f.dirty()) {
            first_dirty = f.id;
            break;
        }
    }

    if (first_dirty == null) {
        pixi.editor.quit_in_progress = false;
        pixi.editor.pending_app_close = true;
        return;
    }

    request(first_dirty.?, .app_quit);
}
