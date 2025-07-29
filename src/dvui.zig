const dvui = @import("dvui");
const builtin = @import("builtin");
const icons = @import("icons");
const Widgets = @import("editor/Widgets.zig");

pub const FileWidget = Widgets.FileWidget;
pub const TabsWidget = Widgets.TabsWidget;
pub const ImageWidget = Widgets.ImageWidget;
pub const CanvasWidget = Widgets.CanvasWidget;

pub fn toastDisplay(id: dvui.WidgetId) !void {
    const message = dvui.dataGetSlice(null, id, "_message", []u8) orelse {
        dvui.log.err("toastDisplay lost data for toast {x}\n", .{id});
        return;
    };

    var animator = dvui.animate(@src(), .{ .kind = .alpha, .duration = 300_000 }, .{ .id_extra = id.asUsize() });
    defer animator.deinit();

    dvui.labelNoFmt(@src(), message, .{}, .{
        .background = true,
        .corner_radius = dvui.Rect.all(1000),
        .padding = .{ .x = 16, .y = 8, .w = 16, .h = 8 },
        .color_fill = .fill_window,
        .border = dvui.Rect.all(2),
    });

    if (dvui.timerDone(id)) {
        animator.startEnd();
    }

    if (animator.end()) {
        dvui.toastRemove(id);
    }
}

pub fn labelWithKeybind(label_str: []const u8, hotkey: dvui.enums.Keybind, opts: dvui.Options) void {
    const box = dvui.box(@src(), .{ .dir = .horizontal }, opts);
    defer box.deinit();

    dvui.labelNoFmt(@src(), label_str, .{}, opts.strip());
    _ = dvui.spacer(@src(), .{ .min_size_content = .width(4) });

    var second_opts = opts.strip();
    second_opts.color_text = .text_press;
    second_opts.gravity_y = 0.5;

    keybindLabels(&hotkey, second_opts);
}

pub fn keybindLabels(self: *const dvui.enums.Keybind, opts: dvui.Options) void {
    var needs_space = false;
    var needs_plus = false;
    if (self.control) |ctrl| {
        if (ctrl) {
            if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts);
            if (needs_plus) dvui.labelNoFmt(@src(), "+", .{}, opts) else needs_plus = true;
            if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts) else needs_space = true;

            dvui.labelNoFmt(@src(), "ctrl", .{}, opts);
        }
    }

    if (self.command) |cmd| {
        if (cmd) {
            if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts);
            if (needs_plus) dvui.labelNoFmt(@src(), "+", .{}, opts) else needs_plus = true;
            if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts) else needs_space = true;
            if (builtin.os.tag == .macos) {
                dvui.icon(@src(), "cmd", icons.tvg.lucide.command, .{ .fill_color = .fromTheme(.text_press) }, .{ .gravity_y = 0.5 });
            } else {
                dvui.labelNoFmt(@src(), "cmd", .{}, opts);
            }
        }
    }

    if (self.alt) |alt| {
        if (alt) {
            if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts);
            if (needs_plus) dvui.labelNoFmt(@src(), "+", .{}, opts) else needs_plus = true;
            if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts) else needs_space = true;
            if (builtin.os.tag == .macos) {
                dvui.icon(@src(), "option", icons.tvg.lucide.option, .{ .fill_color = .fromTheme(.text_press) }, .{ .gravity_y = 0.5 });
            } else {
                dvui.labelNoFmt(@src(), "alt", .{}, opts);
            }
        }
    }

    if (self.shift) |shift| {
        if (shift) {
            if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts);
            if (needs_plus) dvui.labelNoFmt(@src(), "+", .{}, opts) else needs_plus = true;
            if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts) else needs_space = true;
            dvui.labelNoFmt(@src(), "shift", .{}, opts);
        }
    }

    if (self.key) |key| {
        if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts);
        if (needs_plus) dvui.labelNoFmt(@src(), "+", .{}, opts) else needs_plus = true;
        if (needs_space) dvui.labelNoFmt(@src(), " ", .{}, opts) else needs_space = true;
        dvui.labelNoFmt(@src(), @tagName(key), .{}, opts);
    }
}
