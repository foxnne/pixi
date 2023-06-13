const std = @import("std");
const zm = @import("zmath");
const zglfw = @import("zglfw");
const math = @import("../math/math.zig");
const pixi = @import("root");

const builtin = @import("builtin");

const Self = @This();

pub const Tool = pixi.Tool;
pub const Sidebar = pixi.Sidebar;

pub const Proc = enum {
    save,
    save_all,
    undo,
    redo,
    primary,
    secondary,
    sample,
    zoom,
};

pub const Action = union(enum) {
    tool: Tool,
    sidebar: Sidebar,
    proc: Proc,
};

hotkeys: []Hotkey,

pub const Hotkey = struct {
    key: zglfw.Key,
    mods: zglfw.Mods,
    action: Action,
    state: bool = false,
    previous_state: bool = false,

    /// Returns true the frame the key was pressed.
    pub fn pressed(self: Hotkey) bool {
        return (self.state == true and self.state != self.previous_state);
    }

    /// Returns true while the key is pressed down.
    pub fn down(self: Hotkey) bool {
        return self.state == true;
    }

    /// Returns true the frame the key was released.
    pub fn released(self: Hotkey) bool {
        return (self.state == false and self.state != self.previous_state);
    }

    /// Returns true while the key is released.
    pub fn up(self: Hotkey) bool {
        return self.state == false;
    }
};

pub fn hotkey(self: Self, action: Action) ?*Hotkey {
    for (self.hotkeys) |*hk| {
        const key_tag = std.meta.activeTag(hk.action);
        if (key_tag == std.meta.activeTag(action)) {
            switch (hk.action) {
                .tool => |tool| {
                    if (tool == action.tool) return hk;
                },
                .sidebar => |sidebar| {
                    if (sidebar == action.sidebar) return hk;
                },
                .proc => |proc| {
                    if (proc == action.proc) return hk;
                },
            }
        }
    }
    return null;
}

pub fn setHotkeyState(self: *Self, k: zglfw.Key, mods: zglfw.Mods, action: zglfw.Action) void {
    for (self.hotkeys) |*hk| {
        if (hk.key == k) {
            if (action == .release) {
                hk.previous_state = hk.state;
                hk.state = switch (action) {
                    .release => false,
                    else => true,
                };
            }
            if (@bitCast(i32, hk.mods) == @bitCast(i32, mods)) {
                hk.previous_state = hk.state;
                hk.state = switch (action) {
                    .release => false,
                    else => true,
                };
            }
        }
    }
}

pub fn initDefault(allocator: std.mem.Allocator) !Self {
    var hotkeys = std.ArrayList(Hotkey).init(allocator);

    const windows = builtin.target.os.tag == .windows;

    { // Primary/secondary
        // Primary
        try hotkeys.append(.{
            .key = if (windows) zglfw.Key.left_control else zglfw.Key.left_super,
            .mods = .{ .control = windows, .super = !windows },
            .action = .{ .proc = Proc.primary },
        });

        // Secondary
        try hotkeys.append(.{
            .key = zglfw.Key.left_shift,
            .mods = .{ .shift = true },
            .action = .{ .proc = Proc.secondary },
        });
    }

    { // Procs
        // Save
        try hotkeys.append(.{
            .key = zglfw.Key.s,
            .mods = .{ .control = windows, .super = !windows },
            .action = .{ .proc = Proc.save },
        });

        // Save all
        try hotkeys.append(.{
            .key = zglfw.Key.s,
            .mods = .{ .control = windows, .super = !windows, .shift = true },
            .action = .{ .proc = Proc.save_all },
        });

        // Undo
        try hotkeys.append(.{
            .key = zglfw.Key.z,
            .mods = .{ .control = windows, .super = !windows },
            .action = .{ .proc = Proc.undo },
        });

        // Redo
        try hotkeys.append(.{
            .key = zglfw.Key.z,
            .mods = .{ .control = windows, .super = !windows, .shift = true },
            .action = .{ .proc = Proc.redo },
        });

        // Zoom
        try hotkeys.append(.{
            .key = if (windows) zglfw.Key.left_control else zglfw.Key.left_super,
            .mods = .{ .control = windows, .super = !windows },
            .action = .{ .proc = Proc.zoom },
        });

        // Sample
        try hotkeys.append(.{
            .key = zglfw.Key.left_alt,
            .mods = .{},
            .action = .{ .proc = Proc.sample },
        });
    }

    { // Tools

        // Pointer
        try hotkeys.append(.{
            .key = zglfw.Key.escape,
            .mods = .{},
            .action = .{ .tool = Tool.pointer },
        });

        // Pencil
        try hotkeys.append(.{
            .key = zglfw.Key.d,
            .mods = .{},
            .action = .{ .tool = Tool.pencil },
        });

        // Eraser
        try hotkeys.append(.{
            .key = zglfw.Key.e,
            .mods = .{},
            .action = .{ .tool = Tool.eraser },
        });

        // Animation
        try hotkeys.append(.{
            .key = zglfw.Key.a,
            .mods = .{},
            .action = .{ .tool = Tool.animation },
        });
    }

    { // Sidebars
        // Explorer
        try hotkeys.append(.{
            .key = zglfw.Key.f,
            .mods = .{},
            .action = .{ .sidebar = Sidebar.files },
        });

        // Tools
        try hotkeys.append(.{
            .key = zglfw.Key.d,
            .mods = .{},
            .action = .{ .sidebar = Sidebar.tools },
        });
        try hotkeys.append(.{
            .key = zglfw.Key.e,
            .mods = .{},
            .action = .{ .sidebar = Sidebar.tools },
        });

        // Layers
        try hotkeys.append(.{
            .key = zglfw.Key.l,
            .mods = .{},
            .action = .{ .sidebar = Sidebar.layers },
        });

        // Sprites
        try hotkeys.append(.{
            .key = zglfw.Key.s,
            .mods = .{},
            .action = .{ .sidebar = Sidebar.sprites },
        });

        // Animations
        try hotkeys.append(.{
            .key = zglfw.Key.a,
            .mods = .{},
            .action = .{ .sidebar = Sidebar.animations },
        });
    }

    return .{ .hotkeys = try hotkeys.toOwnedSlice() };
}
