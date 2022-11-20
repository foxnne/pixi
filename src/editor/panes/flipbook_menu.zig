const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("pixi");
const settings = pixi.settings;
const filebrowser = @import("filebrowser");
const nfd = @import("nfd");

pub fn draw(file: *pixi.storage.Internal.Pixi) void {
    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.window_padding, .v = .{ 10.0 * pixi.state.window.scale[0], 10.0 * pixi.state.window.scale[1] } });
    defer zgui.popStyleVar(.{ .count = 1 });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text_secondary.toSlice() });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.popup_bg, .c = pixi.state.style.foreground.toSlice() });
    defer zgui.popStyleColor(.{ .count = 2 });
    if (zgui.beginMenuBar()) {
        defer zgui.endMenuBar();

        if (zgui.button(if (file.selected_animation_state == .play) "Pause" else "Play", .{})) {
            file.selected_animation_state = switch (file.selected_animation_state) {
                .play => .pause,
                .pause => .play,
            };
        }

        _ = zgui.invisibleButton("FlipbookGrip", .{
            .w = -1.0,
            .h = -1.0,
        });

        if (zgui.isItemActive()) {
            const ratio = std.math.clamp(1.0 / (pixi.state.controls.mouse.position.y / pixi.state.window.size[1] * pixi.state.window.scale[1]), 0.1, 0.9);
            pixi.state.settings.flipbook_height = ratio;
        }
    }
}
