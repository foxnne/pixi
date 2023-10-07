const std = @import("std");
const zm = @import("zmath");
const math = @import("../math/math.zig");
const pixi = @import("../pixi.zig");
const core = @import("mach-core");

const builtin = @import("builtin");

const Mods = core.KeyMods;
const MouseButton = core.MouseButton;

const Self = @This();

pub const ButtonState = enum {
    press,
    release,
};

pub const Button = struct {
    button: MouseButton,
    mods: ?Mods = null,
    action: Action,
    state: bool = false,
    previous_state: bool = false,

    /// Returns true the frame the key was pressed.
    pub fn pressed(self: Button) bool {
        return (self.state == true and self.state != self.previous_state);
    }

    /// Returns true while the key is pressed down.
    pub fn down(self: Button) bool {
        return self.state == true;
    }

    /// Returns true the frame the key was released.
    pub fn released(self: Button) bool {
        return (self.state == false and self.state != self.previous_state);
    }

    /// Returns true while the key is released.
    pub fn up(self: Button) bool {
        return self.state == false;
    }
};

pub const Action = enum {
    primary,
    secondary,
    sample,
};

buttons: []Button,
position: [2]f32 = .{ 0.0, 0.0 },
previous_position: [2]f32 = .{ 0.0, 0.0 },
scroll_x: ?f32 = null,
scroll_y: ?f32 = null,

pub fn button(self: *Self, action: Action) ?*Button {
    for (self.buttons) |*bt| {
        if (bt.action == action)
            return bt;
    }
    return null;
}

pub fn setButtonState(self: *Self, b: MouseButton, mods: Mods, state: ButtonState) void {
    for (self.buttons) |*bt| {
        if (bt.button == b) {
            if (state == .release or bt.mods == null) {
                bt.previous_state = bt.state;
                bt.state = switch (state) {
                    .press => true,
                    else => false,
                };
            } else if (bt.mods) |md| {
                if (@as(u8, @bitCast(md)) == @as(u8, @bitCast(mods))) {
                    bt.previous_state = bt.state;
                    bt.state = switch (state) {
                        .press => true,
                        else => false,
                    };
                }
            }
        }
    }
}

pub fn initDefault(allocator: std.mem.Allocator) !Self {
    var buttons = std.ArrayList(Button).init(allocator);

    const os = builtin.target.os.tag;
    const windows = os == .windows;
    _ = windows;
    const macos = os == .macos;
    _ = macos;

    {
        try buttons.append(.{
            .button = MouseButton.left,
            .action = Action.primary,
        });

        try buttons.append(.{
            .button = MouseButton.right,
            .action = Action.secondary,
        });

        try buttons.append(.{
            .button = MouseButton.right,
            .action = Action.sample,
        });
    }

    return .{ .buttons = try buttons.toOwnedSlice() };
}
