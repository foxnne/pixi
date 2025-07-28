const std = @import("std");
const mach = @import("mach");
const Core = mach.Core;

pub const version: std.SemanticVersion = .{
    .major = 0,
    .minor = 2,
    .patch = 0,
};

// Generated files, these contain helpers for autocomplete
// So you can get a named index into atlas.sprites
pub const paths = @import("generated/paths.zig");
pub const atlas = @import("generated/atlas.zig");

// Other helpers and namespaces
pub const algorithms = @import("algorithms/algorithms.zig");
pub const fa = @import("tools/font_awesome.zig");
pub const fs = @import("tools/fs.zig");
pub const gfx = @import("gfx/gfx.zig");
pub const image = @import("gfx/image.zig");
pub const input = @import("input/input.zig");
pub const math = @import("math/math.zig");
pub const shaders = @import("shaders/shaders.zig");

pub const App = @import("App.zig");
//pub const Artboard = @import("editor/artboard/Artboard.zig");
pub const Assets = @import("Assets.zig");
pub const Editor = @import("editor/Editor.zig");
pub const Explorer = @import("editor/explorer/Explorer.zig");
pub const Packer = @import("tools/Packer.zig");
//pub const Popups = @import("editor/popups/Popups.zig");
pub const Sidebar = @import("editor/Sidebar.zig");

// Global pointers
pub var app: *App = undefined;
pub var editor: *Editor = undefined;
pub var packer: *Packer = undefined;
pub var assets: *Assets = undefined;

/// Internal types
/// These types contain additional data to support the editor
/// An example of this is File. pixi.File matches the file type to read from JSON,
/// while the pixi.Internal.File contains cameras, timers, file-specific editor fields.
pub const Internal = struct {
    pub const Animation = @import("internal/Animation.zig");
    pub const Atlas = @import("internal/Atlas.zig");
    pub const Buffers = @import("internal/Buffers.zig");
    pub const File = @import("internal/File.zig");
    pub const Frame = @import("internal/Frame.zig");
    pub const History = @import("internal/History.zig");
    pub const Keyframe = @import("internal/Keyframe.zig");
    pub const KeyframeAnimation = @import("internal/KeyframeAnimation.zig");
    pub const Layer = @import("internal/Layer.zig");
    pub const Palette = @import("internal/Palette.zig");
    pub const Reference = @import("internal/Reference.zig");
    pub const Sprite = @import("internal/Sprite.zig");
    pub const Texture = @import("internal/Texture.zig");
};

/// Frame-by-frame sprite animation
pub const Animation = Internal.Animation;

/// Contains lists of sprites and animations
pub const Atlas = @import("Atlas.zig");

/// The data that gets written to disk in a .pixi file and read back into this type
pub const File = @import("File.zig");

/// Contains information such as the name, visibility and collapse settings of a texture layer
pub const Layer = @import("Layer.zig");

/// Source location within the atlas texture and origin location
pub const Sprite = @import("Sprite.zig");

/// Custom dvui stuff
pub const dvui = @import("dvui.zig");
