const Pixi = @import("../Pixi.zig");

pub const Mouse = @import("Mouse.zig");
pub const Hotkeys = @import("Hotkeys.zig");

pub fn process() !void {
    if (!Pixi.app.popups.anyPopupOpen()) {
        try Pixi.app.hotkeys.process();
    }
}
