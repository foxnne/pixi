const std = @import("std");

const dvui = @import("dvui");
const pixi = @import("../../pixi.zig");

const Core = @import("mach").Core;
const App = pixi.App;
const Editor = pixi.Editor;
const Packer = pixi.Packer;

const nfd = @import("nfd");

pub const Explorer = @This();

pub const files = @import("files.zig");
pub const Tools = @import("tools.zig");
pub const Sprites = @import("sprites.zig");
// pub const animations = @import("animations.zig");
// pub const keyframe_animations = @import("keyframe_animations.zig");
pub const project = @import("project.zig");
pub const settings = @import("settings.zig");

sprites: Sprites = .{},
tools: Tools = .{},
pane: Pane = .files,
paned: *pixi.dvui.PanedWidget = undefined,
scroll_info: dvui.ScrollInfo = .{
    .horizontal = .auto,
},
rect: dvui.Rect = .{},
open_branches: std.AutoHashMap(dvui.Id, void) = undefined,
pinned_palettes: bool = false,
layers_ratio: f32 = 0.5,
animations_ratio: f32 = 0.5,
closed: bool = false,

pub const Pane = enum(u32) {
    files,
    tools,
    sprites,
    animations,
    keyframe_animations,
    project,
    settings,
};

pub fn init() Explorer {
    return .{
        .open_branches = .init(pixi.app.allocator),
    };
}

pub fn deinit(self: *Explorer) void {
    // TODO: Free memory
    self.open_branches.deinit();
}

pub fn title(pane: Pane, all_caps: bool) []const u8 {
    return switch (pane) {
        .files => if (all_caps) "FILES" else "Files",
        .tools => if (all_caps) "TOOLS" else "Tools",
        .sprites => if (all_caps) "SPRITES" else "Sprites",
        .animations => if (all_caps) "ANIMATIONS" else "Animations",
        .keyframe_animations => if (all_caps) "KEYFRAME ANIMATIONS" else "Keyframe Animations",
        .project => if (all_caps) "PROJECT" else "Project",
        .settings => if (all_caps) "SETTINGS" else "Settings",
    };
}

pub fn close(explorer: *Explorer) void {
    explorer.paned.animateSplit(0.0);
    explorer.closed = true;
}

pub fn open(explorer: *Explorer) void {
    if (explorer.paned.collapsed()) return;

    if (pixi.editor.settings.explorer_ratio > 0.0) {
        explorer.paned.animateSplit(pixi.editor.settings.explorer_ratio);
    } else {
        explorer.paned.animateSplit(0.2);
    }

    explorer.closed = false;
}

pub fn draw(explorer: *Explorer) !dvui.App.Result {
    const vbox = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .both,
        .background = false,
    });
    defer vbox.deinit();

    explorer.rect = vbox.data().rect;

    try drawHeader(explorer);

    _ = dvui.spacer(@src(), .{});

    const pane_vbox = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .both,
        .background = false,
    });

    var scroll = dvui.scrollArea(@src(), .{ .scroll_info = &explorer.scroll_info, .horizontal_bar = .auto_overlay, .vertical_bar = .auto_overlay }, .{
        .expand = .both,
        .background = false,
    });

    switch (explorer.pane) {
        .files => try files.draw(),
        .settings => try settings.draw(),
        .project => try project.draw(),
        .tools => try explorer.tools.draw(),
        .sprites => try explorer.sprites.draw(),
        else => {},
    }

    const vertical_scroll = scroll.si.offset(.vertical);
    const horizontal_scroll = scroll.si.offset(.horizontal);

    scroll.deinit();

    if (vertical_scroll > 0.0) {
        pixi.dvui.drawEdgeShadow(pane_vbox.data().contentRectScale(), .top, .{ .offset = .{ .w = -10.0 * dvui.currentWindow().natural_scale } });
    }

    if (explorer.scroll_info.virtual_size.h > explorer.scroll_info.viewport.h) {
        pixi.dvui.drawEdgeShadow(pane_vbox.data().contentRectScale(), .bottom, .{ .offset = .{ .w = -10.0 * dvui.currentWindow().natural_scale } });
    }

    pane_vbox.deinit();

    if (explorer.scroll_info.virtual_size.w > explorer.scroll_info.viewport.w) {
        var offset: dvui.Rect = .{};

        if (explorer.scroll_info.virtual_size.h > explorer.scroll_info.viewport.h) {
            offset.x -= 10.0 * dvui.currentWindow().natural_scale;
        }

        pixi.dvui.drawEdgeShadow(vbox.data().contentRectScale(), .right, .{ .offset = offset });
    }

    if (horizontal_scroll > 0.0) {
        pixi.dvui.drawEdgeShadow(vbox.data().contentRectScale(), .left, .{});
    }

    return .ok;
}

pub fn hovered(explorer: *Explorer) bool {
    return pixi.dvui.hovered(explorer.paned.data());
}

pub fn drawHeader(explorer: *Explorer) !void {
    const header_title = title(explorer.pane, true);

    dvui.labelNoFmt(@src(), header_title, .{}, .{ .font = dvui.Font.theme(.title).larger(-3.0).withWeight(.bold) });
}
