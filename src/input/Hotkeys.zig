const std = @import("std");
const zm = @import("zmath");
const math = @import("../math/math.zig");
const pixi = @import("../pixi.zig");
const nfd = @import("nfd");
const mach = @import("core");

const Key = mach.Core.Key;
const Mods = mach.Core.KeyMods;

const builtin = @import("builtin");

const Self = @This();

pub const Tool = pixi.Tool;
pub const Sidebar = pixi.Sidebar;

pub const KeyState = enum {
    press,
    repeat,
    release,
};

pub const Proc = enum {
    save,
    save_all,
    undo,
    redo,
    primary,
    secondary,
    sample,
    zoom,
    folder,
    export_png,
    size_up,
    size_down,
    playpause,
};

pub const Action = union(enum) {
    tool: Tool,
    sidebar: Sidebar,
    proc: Proc,
};

hotkeys: []Hotkey,

pub const Hotkey = struct {
    shortcut: [:0]const u8 = undefined,
    key: mach.Core.Key,
    mods: ?Mods = null,
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

pub fn hotkey(self: *Self, action: Action) ?*Hotkey {
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

pub fn setHotkeyState(self: *Self, k: Key, mods: Mods, state: KeyState) void {
    for (self.hotkeys) |*hk| {
        if (hk.key == k) {
            if (state == .release or hk.mods == null) {
                hk.previous_state = hk.state;
                hk.state = switch (state) {
                    .release => false,
                    else => true,
                };
            } else if (hk.mods) |md| {
                if (@as(u8, @bitCast(md)) == @as(u8, @bitCast(mods))) {
                    hk.previous_state = hk.state;
                    hk.state = switch (state) {
                        .release => false,
                        else => true,
                    };
                }
            }
        }
    }
}

pub fn process(self: *Self) !void {
    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
        if (self.hotkey(.{ .proc = .save })) |hk| {
            if (hk.pressed())
                try file.saveAsync();
        }

        if (self.hotkey(.{ .proc = .undo })) |hk| {
            if (hk.pressed())
                try file.undo();
        }

        if (self.hotkey(.{ .proc = .redo })) |hk| {
            if (hk.pressed())
                try file.redo();
        }

        if (self.hotkey(.{ .proc = .export_png })) |hk| {
            if (hk.pressed())
                pixi.state.popups.export_to_png = true;
        }

        if (self.hotkey(.{ .proc = .size_up })) |hk| {
            if (hk.pressed()) {
                if (pixi.state.tools.current == .heightmap) {
                    if (pixi.state.colors.height < 255)
                        pixi.state.colors.height += 1;
                }
            }
        }

        if (self.hotkey(.{ .proc = .size_down })) |hk| {
            if (hk.pressed()) {
                if (pixi.state.tools.current == .heightmap) {
                    if (pixi.state.colors.height > 0)
                        pixi.state.colors.height -= 1;
                }
            }
        }

        if (self.hotkey(.{ .proc = .playpause })) |hk| {
            if (hk.pressed()) {
                file.selected_animation_state = switch (file.selected_animation_state) {
                    .pause => .play,
                    .play => .pause,
                };
            }
        }
    }
    if (self.hotkey(.{ .proc = .folder })) |hk| {
        if (hk.pressed()) {
            pixi.state.popups.user_state = .folder;
            pixi.state.popups.user_path_type = .project;
        }
    }

    for (self.hotkeys) |hk| {
        if (hk.pressed()) {
            switch (hk.action) {
                .tool => |tool| pixi.state.tools.set(tool),
                .sidebar => |sidebar| pixi.state.sidebar = sidebar,
                else => {},
            }
        }
    }
}

pub fn initDefault(allocator: std.mem.Allocator) !Self {
    var hotkeys = std.ArrayList(Hotkey).init(allocator);

    const os = builtin.target.os.tag;
    const windows = os == .windows;
    const macos = os == .macos;

    { // Primary/secondary
        // Primary
        try hotkeys.append(.{
            .shortcut = if (windows) "ctrl" else if (macos) "cmd" else "super",
            .key = if (windows) Key.left_control else Key.left_super,
            .mods = .{
                .control = windows,
                .super = !windows,
                .shift = false,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.primary },
        });

        // Secondary
        try hotkeys.append(.{
            .shortcut = "shift",
            .key = Key.left_shift,
            .mods = .{
                .control = false,
                .super = false,
                .shift = true,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.secondary },
        });
    }

    { // Procs
        // Save
        try hotkeys.append(.{
            .shortcut = if (windows) "ctrl+s" else if (macos) "cmd+s" else "super+s",
            .key = Key.s,
            .mods = .{
                .control = windows,
                .super = !windows,
                .shift = false,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.save },
        });

        // Save all
        try hotkeys.append(.{
            .shortcut = if (windows) "ctrl+shift+s" else if (macos) "cmd+shift+s" else "super+shift+s",
            .key = Key.s,
            .mods = .{
                .control = windows,
                .super = !windows,
                .shift = true,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.save_all },
        });

        // Undo
        try hotkeys.append(.{
            .shortcut = if (windows) "ctrl+z" else if (macos) "cmd+z" else "super+z",
            .key = Key.z,
            .mods = .{
                .control = windows,
                .super = !windows,
                .shift = false,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.undo },
        });

        // Redo
        try hotkeys.append(.{
            .shortcut = if (windows) "ctrl+shift+z" else if (macos) "cmd+shift+z" else "super+shift+z",
            .key = Key.z,
            .mods = .{
                .control = windows,
                .super = !windows,
                .shift = true,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.redo },
        });

        // Zoom
        try hotkeys.append(.{
            .key = if (windows) Key.left_control else Key.left_super,
            .mods = .{
                .control = windows,
                .super = !windows,
                .shift = false,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.zoom },
        });

        // Sample
        try hotkeys.append(.{
            .key = Key.left_alt,
            .mods = .{
                .control = false,
                .super = false,
                .shift = false,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.sample },
        });

        // Open folder
        try hotkeys.append(.{
            .shortcut = if (windows) "ctrl+f" else if (macos) "cmd+f" else "super+f",
            .key = Key.f,
            .mods = .{
                .control = windows,
                .super = !windows,
                .shift = false,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.folder },
        });

        // Export png
        try hotkeys.append(.{
            .shortcut = if (windows) "ctrl+p" else if (macos) "cmd+p" else "super+p",
            .key = Key.p,
            .mods = .{
                .control = windows,
                .super = !windows,
                .shift = false,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.export_png },
        });

        // Size up
        try hotkeys.append(.{
            .shortcut = "]",
            .key = Key.right_bracket,
            .action = .{ .proc = Proc.size_up },
        });

        // Size down
        try hotkeys.append(.{
            .shortcut = "[",
            .key = Key.left_bracket,
            .action = .{ .proc = Proc.size_down },
        });

        // Play/Pause
        try hotkeys.append(.{
            .shortcut = "space",
            .key = Key.space,
            .action = .{ .proc = Proc.playpause },
        });
    }

    { // Tools

        // Pointer
        try hotkeys.append(.{
            .shortcut = "esc",
            .key = Key.escape,
            .action = .{ .tool = Tool.pointer },
        });

        // Pencil
        try hotkeys.append(.{
            .shortcut = "d",
            .key = Key.d,
            .action = .{ .tool = Tool.pencil },
        });

        // Eraser
        try hotkeys.append(.{
            .shortcut = "e",
            .key = Key.e,
            .action = .{ .tool = Tool.eraser },
        });

        // Animation
        try hotkeys.append(.{
            .shortcut = "a",
            .key = Key.a,
            .action = .{ .tool = Tool.animation },
        });

        // Heightmap
        try hotkeys.append(.{
            .shortcut = "h",
            .key = Key.h,
            .action = .{ .tool = Tool.heightmap },
        });

        // Bucket
        try hotkeys.append(.{
            .shortcut = "b",
            .key = Key.b,
            .action = .{ .tool = Tool.bucket },
        });
    }

    { // Sidebars
        // Explorer
        try hotkeys.append(.{
            .shortcut = "f",
            .key = Key.f,
            .action = .{ .sidebar = Sidebar.files },
        });

        // Tools
        try hotkeys.append(.{
            .shortcut = "t",
            .key = Key.t,
            .action = .{ .sidebar = Sidebar.tools },
        });

        // Layers
        try hotkeys.append(.{
            .shortcut = "l",
            .key = Key.l,
            .action = .{ .sidebar = Sidebar.layers },
        });

        // Sprites
        try hotkeys.append(.{
            .shortcut = "s",
            .key = Key.s,
            .action = .{ .sidebar = Sidebar.sprites },
        });

        // Animations
        try hotkeys.append(.{
            .shortcut = "a",
            .key = Key.a,
            .action = .{ .sidebar = Sidebar.animations },
        });

        // Pack
        try hotkeys.append(.{
            .shortcut = "p",
            .key = Key.p,
            .action = .{ .sidebar = Sidebar.pack },
        });
    }

    return .{ .hotkeys = try hotkeys.toOwnedSlice() };
}
