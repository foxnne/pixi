const pixi = @import("../pixi.zig");

pub const Mouse = @import("Mouse.zig");
pub const Hotkeys = @import("Hotkeys.zig");

pub fn process() !void {
    if (!pixi.editor.popups.anyPopupOpen()) {
        try pixi.editor.hotkeys.process(pixi.editor);
        //pixi.editor.hotkeys.pushHotkeyPreviousStates();
    }
}
