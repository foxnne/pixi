const std = @import("std");
const zm = @import("zmath");
const math = @import("../math/math.zig");
const pixi = @import("../pixi.zig");
const nfd = @import("nfd");
const core = @import("mach").core;

const Key = core.Key;
const Mods = core.KeyMods;

const builtin = @import("builtin");

const Self = @This();

pub const Tool = pixi.Tools.Tool;
pub const Sidebar = pixi.Sidebar;

pub const KeyState = enum {
    press,
    repeat,
    release,
};

pub const Proc = enum(u32) {
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
    height_up,
    height_down,
    play_pause,
    select_right,
    select_left,
    select_up,
    select_down,
    copy_right,
    copy_left,
    copy_up,
    copy_down,
    erase_sprite,
    shift_right,
    shift_left,
    shift_up,
    shift_down,
    copy,
    paste,
    paste_all,
    toggle_heightmap,
    toggle_references,
};

pub const Action = union(enum) {
    tool: Tool,
    sidebar: Sidebar,
    proc: Proc,
};

hotkeys: []Hotkey,
disable: bool = false,

pub const Hotkey = struct {
    shortcut: [:0]const u8 = undefined,
    key: core.Key,
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
            if (state == .release or (hk.mods == null and @as(u8, @bitCast(mods)) == 0)) {
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
    if (self.disable) {
        return;
    }

    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
        if (self.hotkey(.{ .proc = .save })) |hk| {
            if (hk.pressed()) {
                try file.saveAsync();
            }
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
                switch (pixi.state.tools.current) {
                    .pencil, .eraser => {
                        if (pixi.state.tools.stroke_size < pixi.state.settings.stroke_max_size)
                            pixi.state.tools.stroke_size += 1;
                    },
                    else => {},
                }
            }
        }

        if (self.hotkey(.{ .proc = .size_down })) |hk| {
            if (hk.pressed()) {
                switch (pixi.state.tools.current) {
                    .pencil, .eraser => {
                        if (pixi.state.tools.stroke_size > 1)
                            pixi.state.tools.stroke_size -= 1;
                    },
                    else => {},
                }
            }
        }

        if (self.hotkey(.{ .proc = .height_up })) |hk| {
            if (hk.pressed()) {
                if (file.heightmap.visible) {
                    if (pixi.state.colors.height < 255)
                        pixi.state.colors.height += 1;
                }
            }
        }

        if (self.hotkey(.{ .proc = .height_down })) |hk| {
            if (hk.pressed()) {
                if (file.heightmap.visible) {
                    if (pixi.state.colors.height > 0)
                        pixi.state.colors.height -= 1;
                }
            }
        }

        if (self.hotkey(.{ .proc = .toggle_heightmap })) |hk| {
            if (hk.pressed()) {
                file.heightmap.toggle();
            }
        }

        if (self.hotkey(.{ .proc = .play_pause })) |hk| {
            if (hk.pressed()) {
                file.selected_animation_state = switch (file.selected_animation_state) {
                    .pause => .play,
                    .play => .pause,
                };
            }
        }

        if (self.hotkey(.{ .proc = .select_right })) |hk| {
            if (hk.pressed()) {
                file.selectDirection(.e);
            }
        }

        if (self.hotkey(.{ .proc = .select_left })) |hk| {
            if (hk.pressed()) {
                file.selectDirection(.w);
            }
        }

        if (self.hotkey(.{ .proc = .select_up })) |hk| {
            if (hk.pressed()) {
                file.selectDirection(.n);
            }
        }

        if (self.hotkey(.{ .proc = .select_down })) |hk| {
            if (hk.pressed()) {
                file.selectDirection(.s);
            }
        }

        if (self.hotkey(.{ .proc = .copy })) |hk| {
            if (hk.pressed()) {
                file.copy_sprite = .{
                    .index = file.selected_sprite_index,
                    .layer_id = file.layers.items[file.selected_layer_index].id,
                };
            }
        }

        if (self.hotkey(.{ .proc = .paste })) |hk| {
            if (hk.pressed()) {
                if (file.copy_sprite) |src| {
                    try file.copySprite(src.index, file.selected_sprite_index, src.layer_id);
                }
            }
        }

        if (self.hotkey(.{ .proc = .paste_all })) |hk| {
            if (hk.pressed()) {
                if (file.copy_sprite) |src| {
                    try file.copySpriteAllLayers(src.index, file.selected_sprite_index);
                }
            }
        }

        if (self.hotkey(.{ .proc = .copy_right })) |hk| {
            if (hk.pressed()) {
                try file.copyDirection(.e);
            }
        }

        if (self.hotkey(.{ .proc = .copy_left })) |hk| {
            if (hk.pressed()) {
                try file.copyDirection(.w);
            }
        }

        if (self.hotkey(.{ .proc = .copy_up })) |hk| {
            if (hk.pressed()) {
                try file.copyDirection(.n);
            }
        }

        if (self.hotkey(.{ .proc = .copy_down })) |hk| {
            if (hk.pressed()) {
                try file.copyDirection(.s);
            }
        }

        if (self.hotkey(.{ .proc = .erase_sprite })) |hk| {
            if (hk.pressed()) {
                try file.eraseSprite(file.selected_sprite_index);
            }
        }

        if (self.hotkey(.{ .proc = .shift_right })) |hk| {
            if (hk.pressed()) {
                try file.shiftDirection(.e);
            }
        }

        if (self.hotkey(.{ .proc = .shift_left })) |hk| {
            if (hk.pressed()) {
                try file.shiftDirection(.w);
            }
        }

        if (self.hotkey(.{ .proc = .shift_up })) |hk| {
            if (hk.pressed()) {
                try file.shiftDirection(.n);
            }
        }

        if (self.hotkey(.{ .proc = .shift_down })) |hk| {
            if (hk.pressed()) {
                try file.shiftDirection(.s);
            }
        }
    }

    if (self.hotkey(.{ .proc = .folder })) |hk| {
        if (hk.pressed()) {
            pixi.state.popups.file_dialog_request = .{
                .state = .folder,
                .type = .project,
            };
        }
    }

    if (self.hotkey(.{ .proc = .toggle_references })) |hk| {
        if (hk.pressed()) {
            pixi.state.popups.references = !pixi.state.popups.references;
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
    const linux = os == .linux;

    const windows_or_linux = windows or linux;

    { // Primary/secondary
        // Primary
        try hotkeys.append(.{
            .shortcut = if (windows_or_linux) "ctrl" else "cmd",
            .key = if (windows_or_linux) Key.left_control else Key.left_super,
            .mods = .{
                .control = windows_or_linux,
                .super = !windows_or_linux,
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
            .shortcut = if (windows_or_linux) "ctrl+s" else "cmd+s",
            .key = Key.s,
            .mods = .{
                .control = windows_or_linux,
                .super = !windows_or_linux,
                .shift = false,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.save },
        });

        // Save all
        try hotkeys.append(.{
            .shortcut = if (windows_or_linux) "ctrl+shift+s" else "cmd+shift+s",
            .key = Key.s,
            .mods = .{
                .control = windows_or_linux,
                .super = !windows_or_linux,
                .shift = true,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.save_all },
        });

        // Undo
        try hotkeys.append(.{
            .shortcut = if (windows_or_linux) "ctrl+z" else "cmd+z",
            .key = Key.z,
            .mods = .{
                .control = windows_or_linux,
                .super = !windows_or_linux,
                .shift = false,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.undo },
        });

        // Redo
        try hotkeys.append(.{
            .shortcut = if (windows_or_linux) "ctrl+shift+z" else "cmd+shift+z",
            .key = Key.z,
            .mods = .{
                .control = windows_or_linux,
                .super = !windows_or_linux,
                .shift = true,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.redo },
        });

        // Zoom
        try hotkeys.append(.{
            .key = if (windows_or_linux) Key.left_control else Key.left_super,
            .mods = .{
                .control = windows_or_linux,
                .super = !windows_or_linux,
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
            .shortcut = if (windows_or_linux) "ctrl+f" else "cmd+f",
            .key = Key.f,
            .mods = .{
                .control = windows_or_linux,
                .super = !windows_or_linux,
                .shift = false,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.folder },
        });

        // Export png
        try hotkeys.append(.{
            .shortcut = if (windows_or_linux) "ctrl+p" else "cmd+p",
            .key = Key.p,
            .mods = .{
                .control = windows_or_linux,
                .super = !windows_or_linux,
                .shift = false,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.export_png },
        });

        // Toggle heightmap
        try hotkeys.append(.{
            .shortcut = "/",
            .key = Key.slash,
            .action = .{ .proc = Proc.toggle_heightmap },
        });

        // Toggle reference window
        try hotkeys.append(.{
            .shortcut = "r",
            .key = Key.r,
            .action = .{ .proc = Proc.toggle_references },
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

        // Height up
        try hotkeys.append(.{
            .shortcut = ".",
            .key = Key.period,
            .action = .{ .proc = Proc.height_up },
        });

        // Height down
        try hotkeys.append(.{
            .shortcut = ",",
            .key = Key.comma,
            .action = .{ .proc = Proc.height_down },
        });

        // Play/Pause
        try hotkeys.append(.{
            .shortcut = "space",
            .key = Key.space,
            .action = .{ .proc = Proc.play_pause },
        });

        try hotkeys.append(.{
            .shortcut = "backspace",
            .key = Key.backspace,
            .action = .{ .proc = Proc.erase_sprite },
        });

        try hotkeys.append(.{
            .shortcut = "right arrow",
            .key = Key.right,
            .action = .{ .proc = Proc.select_right },
        });

        try hotkeys.append(.{
            .shortcut = "left arrow",
            .key = Key.left,
            .action = .{ .proc = Proc.select_left },
        });

        try hotkeys.append(.{
            .shortcut = "up arrow",
            .key = Key.up,
            .action = .{ .proc = Proc.select_up },
        });

        try hotkeys.append(.{
            .shortcut = "down arrow",
            .key = Key.down,
            .action = .{ .proc = Proc.select_down },
        });

        try hotkeys.append(.{
            .shortcut = if (windows_or_linux) "ctrl+c" else "cmd+c",
            .key = Key.c,
            .mods = .{
                .control = windows_or_linux,
                .super = !windows_or_linux,
                .shift = false,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.copy },
        });

        try hotkeys.append(.{
            .shortcut = if (windows_or_linux) "ctrl+v" else "cmd+v",
            .key = Key.v,
            .mods = .{
                .control = windows_or_linux,
                .super = !windows_or_linux,
                .shift = false,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.paste },
        });

        try hotkeys.append(.{
            .shortcut = if (windows_or_linux) "ctrl+shift+v" else "cmd+shift+v",
            .key = Key.v,
            .mods = .{
                .control = windows_or_linux,
                .super = !windows_or_linux,
                .shift = true,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.paste_all },
        });

        try hotkeys.append(.{
            .shortcut = if (windows_or_linux) "ctrl+right arrow" else "cmd+right arrow",
            .key = Key.right,
            .mods = .{
                .control = windows_or_linux,
                .super = !windows_or_linux,
                .shift = false,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.copy_right },
        });

        try hotkeys.append(.{
            .shortcut = if (windows_or_linux) "ctrl+left arrow" else "cmd+left arrow",
            .key = Key.left,
            .mods = .{
                .control = windows_or_linux,
                .super = !windows_or_linux,
                .shift = false,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.copy_left },
        });

        try hotkeys.append(.{
            .shortcut = if (windows_or_linux) "ctrl+up arrow" else "cmd+up arrow",
            .key = Key.up,
            .mods = .{
                .control = windows_or_linux,
                .super = !windows_or_linux,
                .shift = false,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.copy_up },
        });

        try hotkeys.append(.{
            .shortcut = if (windows_or_linux) "ctrl+down arrow" else "cmd+down arrow",
            .key = Key.down,
            .mods = .{
                .control = windows_or_linux,
                .super = !windows_or_linux,
                .shift = false,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.copy_down },
        });

        try hotkeys.append(.{
            .shortcut = "shift+right arrow",
            .key = Key.right,
            .mods = .{
                .control = false,
                .super = false,
                .shift = true,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.shift_right },
        });

        try hotkeys.append(.{
            .shortcut = "shift+left arrow",
            .key = Key.left,
            .mods = .{
                .control = false,
                .super = false,
                .shift = true,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.shift_left },
        });

        try hotkeys.append(.{
            .shortcut = "shift+up arrow",
            .key = Key.up,
            .mods = .{
                .control = false,
                .super = false,
                .shift = true,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.shift_up },
        });

        try hotkeys.append(.{
            .shortcut = "shift+down arrow",
            .key = Key.down,
            .mods = .{
                .control = false,
                .super = false,
                .shift = true,
                .alt = false,
                .caps_lock = false,
                .num_lock = false,
            },
            .action = .{ .proc = Proc.shift_down },
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
