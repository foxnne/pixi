const std = @import("std");
const zm = @import("zmath");
const zglfw = @import("zglfw");
const math = @import("../math/math.zig");
const pixi = @import("root");

pub const callbacks = @import("callbacks.zig");

pub const Controls = struct {
    mouse: Mouse = .{},
};

pub const MouseButton = struct {
    name: [:0]const u8,
    button: zglfw.MouseButton,
    state: bool = false,
    previous_state: bool = false,

    /// Returns true the frame the mouse button was pressed.
    pub fn pressed(self: MouseButton) bool {
        return self.state == true and self.state != self.previous_state;
    }

    /// Returns true while the mouse button is pressed down.
    pub fn down(self: MouseButton) bool {
        return self.state == true;
    }

    /// Returns true the frame the mouse button was released.
    pub fn released(self: MouseButton) bool {
        return self.state == false and self.state != self.previous_state;
    }

    /// Returns true while the mouse button is released.
    pub fn up(self: MouseButton) bool {
        return self.state == false;
    }
};

pub const MousePosition = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,

    /// Returns the screen position.
    pub fn screen(self: MousePosition) zm.F32x4 {
        return zm.f32x4(self.x, self.y, 0, 0);
    }

    /// Returns the world position.
    pub fn world(self: MousePosition) zm.F32x4 {
        const fb = pixi.state.camera.frameBufferMatrix();
        const position = self.screen();
        return pixi.state.camera.screenToWorld(position, fb);
    }

    pub fn toSlice(self: MousePosition) [2]f32 {
        return .{ self.x, self.y };
    }
};

pub const MouseCursor = enum {
    standard,
    drag,
};

pub const Mouse = struct {
    primary: MouseButton = .{ .name = "Primary", .button = zglfw.MouseButton.left },
    secondary: MouseButton = .{ .name = "Secondary", .button = zglfw.MouseButton.right },
    position: MousePosition = .{},
    previous_position: MousePosition = .{},
    clicked_position: MousePosition = .{},
    scroll_x: ?f32 = null,
    scroll_y: ?f32 = null,
    cursor: MouseCursor = .standard,

    pub fn dragging(self: Mouse) bool {
        return self.primary.down() and (self.previous_position.x != self.position.x or self.previous_position.y != self.position.y);
    }
};

pub fn process() !void {
    if (!pixi.state.popups.anyPopupOpen()) {
        if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
            if (pixi.state.hotkeys.hotkey(.{ .proc = .save })) |hotkey| {
                if (hotkey.pressed())
                    try file.saveAsync();
            }

            if (pixi.state.hotkeys.hotkey(.{ .proc = .undo })) |hotkey| {
                if (hotkey.pressed())
                    try file.undo();
            }

            if (pixi.state.hotkeys.hotkey(.{ .proc = .redo })) |hotkey| {
                if (hotkey.pressed())
                    try file.redo();
            }
        }

        for (pixi.state.hotkeys.hotkeys) |hotkey| {
            if (hotkey.pressed()) {
                switch (hotkey.action) {
                    .tool => |tool| pixi.state.tools.set(tool),
                    .sidebar => |sidebar| pixi.state.sidebar = sidebar,
                    else => {},
                }
            }
        }
    }
}
