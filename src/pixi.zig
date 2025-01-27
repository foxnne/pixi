const std = @import("std");
const mach = @import("mach");
const Core = mach.Core;

pub const version: std.SemanticVersion = .{ .major = 0, .minor = 2, .patch = 0 };

// Generated files, these contain helpers for autocomplete
// So you can get a named index into atlas.sprites
pub const animations = @import("animations.zig");
pub const atlas = paths.pixi_atlas;
pub const paths = @import("assets.zig");
pub const shaders = @import("shaders.zig");

// Other helpers and namespaces
pub const algorithms = @import("algorithms/algorithms.zig");
pub const fa = @import("tools/font_awesome.zig");
pub const fs = @import("tools/fs.zig");
pub const gfx = @import("gfx/gfx.zig");
pub const input = @import("input/input.zig");
pub const math = @import("math/math.zig");

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
};

/// pixi.animation, which refers to a frame-by-frame sprite animation
pub const Animation = Internal.Animation;

/// pixi.atlas, which contains a list of sprites and animations
pub const Atlas = @import("Atlas.zig");

/// pixi.file, this is the data that gets written to disk in a .pixi file and read back into this type
pub const File = @import("File.zig");

/// pixi.layer, which contains information such as the name, visibility, and collapse settings
pub const Layer = @import("Layer.zig");

/// pixi.sprite, which is just a name, source location within the atlas texture, and origin
/// TODO: can we discover a new way to handle this and remove the name field?
/// Names could instead be derived from what animations they take part in
pub const Sprite = @import("Sprite.zig");

// Global pointers
pub var core: *Core = undefined;
pub var app: *App = undefined;
pub var editor: *Editor = undefined;
pub var packer: *Packer = undefined;

// Modules
pub const App = @import("App.zig");
pub const Editor = @import("editor/Editor.zig");
pub const Packer = @import("tools/Packer.zig");
pub const Popups = @import("editor/popups/Popups.zig");
pub const Explorer = @import("editor/explorer/Explorer.zig");
pub const Artboard = @import("editor/artboard/Artboard.zig");
pub const Sidebar = @import("editor/Sidebar.zig");

// The set of Mach modules our application may use.
const Modules = mach.Modules(.{
    App,
    Artboard,
    Core,
    Editor,
    Explorer,
    Packer,
    Popups,
    Sidebar,
});

// TODO: move this to a mach "entrypoint" zig module which handles nuances like WASM requires.
pub fn main() !void {
    const allocator = std.heap.c_allocator;

    // The set of Mach modules our application may use.
    var mods: Modules = undefined;
    try mods.init(allocator);
    // TODO: enable mods.deinit(allocator); for allocator leak detection
    // defer mods.deinit(allocator);

    const application = mods.get(.app);
    application.run(.main);
}
