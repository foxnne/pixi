const pixi = @import("../Pixi.zig");

pub const Mouse = @import("Mouse.zig");
pub const Hotkeys = @import("Hotkeys.zig");

pub fn process() !void {
    if (!pixi.state.popups.anyPopupOpen()) {
        try pixi.state.hotkeys.process();
    }
}
