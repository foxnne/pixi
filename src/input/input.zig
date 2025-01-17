const Pixi = @import("../Pixi.zig");

pub const Mouse = @import("Mouse.zig");
pub const Hotkeys = @import("Hotkeys.zig");

pub fn process() !void {
    if (!Pixi.editor.popups.anyPopupOpen()) {
        try Pixi.editor.hotkeys.process(Pixi.editor);
    }
}
