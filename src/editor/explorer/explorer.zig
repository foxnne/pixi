const std = @import("std");
const pixi = @import("../../pixi.zig");
const core = @import("mach-core");
const nfd = @import("nfd");
const imgui = @import("zig-imgui");

pub const files = @import("files.zig");
pub const tools = @import("tools.zig");
pub const layers = @import("layers.zig");
pub const sprites = @import("sprites.zig");
pub const animations = @import("animations.zig");
pub const pack = @import("pack.zig");
pub const settings = @import("settings.zig");

pub fn draw() void {
    imgui.pushStyleVar(imgui.StyleVar_WindowRounding, 0.0);
    imgui.pushStyleColorImVec4(imgui.Col_WindowBg, pixi.state.theme.foreground.toImguiVec4());
    defer imgui.popStyleVar();
    defer imgui.popStyleColor();
    imgui.setNextWindowPos(.{
        .x = pixi.state.settings.sidebar_width * pixi.content_scale[0],
        .y = 0,
    }, imgui.Cond_Always);
    imgui.setNextWindowSize(.{
        .x = pixi.state.settings.explorer_width * pixi.content_scale[0],
        .y = pixi.window_size[1],
    }, imgui.Cond_None);

    var explorer_flags: imgui.WindowFlags = 0;
    explorer_flags |= imgui.WindowFlags_NoTitleBar;
    explorer_flags |= imgui.WindowFlags_NoResize;
    explorer_flags |= imgui.WindowFlags_NoMove;
    explorer_flags |= imgui.WindowFlags_NoCollapse;
    explorer_flags |= imgui.WindowFlags_HorizontalScrollbar;
    explorer_flags |= imgui.WindowFlags_MenuBar;

    if (imgui.begin("Explorer", null, explorer_flags)) {
        // Push explorer style changes.
        imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0 * pixi.content_scale[0], .y = 6.0 * pixi.content_scale[1] });
        imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 0.0, .y = 8.0 * pixi.content_scale[1] });
        defer imgui.popStyleVarEx(2);

        imgui.pushStyleColorImVec4(imgui.Col_Separator, pixi.state.theme.text_background.toImguiVec4());
        imgui.pushStyleColorImVec4(imgui.Col_Header, pixi.state.theme.foreground.toImguiVec4());
        defer imgui.popStyleColorEx(2);

        switch (pixi.state.sidebar) {
            .files => {
                if (imgui.beginMenuBar()) {
                    if (pixi.state.hotkeys.hotkey(.{ .sidebar = .files })) |hotkey| {
                        const title = std.fmt.allocPrintZ(pixi.state.allocator, "Explorer ({s})", .{hotkey.shortcut}) catch unreachable;
                        defer pixi.state.allocator.free(title);

                        imgui.separatorText(title);
                    } else {
                        imgui.separatorText("Explorer");
                    }
                    imgui.endMenuBar();
                }
                imgui.spacing();
                files.draw();
            },
            .tools => {
                if (imgui.beginMenuBar()) {
                    if (pixi.state.hotkeys.hotkey(.{ .sidebar = .tools })) |hotkey| {
                        const title = std.fmt.allocPrintZ(pixi.state.allocator, "Tools ({s})", .{hotkey.shortcut}) catch unreachable;
                        defer pixi.state.allocator.free(title);

                        imgui.separatorText(title);
                    } else {
                        imgui.separatorText("Tools");
                    }
                    imgui.endMenuBar();
                }
                imgui.spacing();
                tools.draw();
            },
            .layers => {
                if (imgui.beginMenuBar()) {
                    if (pixi.state.hotkeys.hotkey(.{ .sidebar = .layers })) |hotkey| {
                        const title = std.fmt.allocPrintZ(pixi.state.allocator, "Layers ({s})", .{hotkey.shortcut}) catch unreachable;
                        defer pixi.state.allocator.free(title);

                        imgui.separatorText(title);
                    } else {
                        imgui.separatorText("Layers");
                    }
                    imgui.endMenuBar();
                }
                imgui.spacing();
                layers.draw();
            },
            .sprites => {
                if (imgui.beginMenuBar()) {
                    if (pixi.state.hotkeys.hotkey(.{ .sidebar = .sprites })) |hotkey| {
                        const title = std.fmt.allocPrintZ(pixi.state.allocator, "Sprites ({s})", .{hotkey.shortcut}) catch unreachable;
                        defer pixi.state.allocator.free(title);

                        imgui.separatorText(title);
                    } else {
                        imgui.separatorText("Sprites");
                    }
                    imgui.endMenuBar();
                }
                imgui.spacing();
                sprites.draw();
            },
            .animations => {
                if (imgui.beginMenuBar()) {
                    if (pixi.state.hotkeys.hotkey(.{ .sidebar = .animations })) |hotkey| {
                        const title = std.fmt.allocPrintZ(pixi.state.allocator, "Animations ({s})", .{hotkey.shortcut}) catch unreachable;
                        defer pixi.state.allocator.free(title);

                        imgui.separatorText(title);
                    } else {
                        imgui.separatorText("Animations");
                    }
                    imgui.endMenuBar();
                }
                imgui.spacing();
                animations.draw();
            },
            .pack => {
                if (imgui.beginMenuBar()) {
                    if (pixi.state.hotkeys.hotkey(.{ .sidebar = .pack })) |hotkey| {
                        const title = std.fmt.allocPrintZ(pixi.state.allocator, "Packing ({s})", .{hotkey.shortcut}) catch unreachable;
                        defer pixi.state.allocator.free(title);

                        imgui.separatorText(title);
                    } else {
                        imgui.separatorText("Packing");
                    }
                    imgui.endMenuBar();
                }
                imgui.spacing();
                pack.draw();
            },
            .settings => {
                if (imgui.beginMenuBar()) {
                    if (pixi.state.hotkeys.hotkey(.{ .sidebar = .settings })) |hotkey| {
                        const title = std.fmt.allocPrintZ(pixi.state.allocator, "Settings ({s})", .{hotkey.shortcut}) catch unreachable;
                        defer pixi.state.allocator.free(title);

                        imgui.separatorText(title);
                    } else {
                        imgui.separatorText("Settings");
                    }
                    imgui.endMenuBar();
                }
                imgui.spacing();
                settings.draw();
            },
        }
    }

    imgui.setCursorPosY(0.0);
    imgui.setCursorPosX(imgui.getWindowWidth() - pixi.state.settings.explorer_grip * pixi.content_scale[0] + imgui.getStyle().item_spacing.x);

    _ = imgui.invisibleButton(pixi.fa.grip_vertical, .{
        .x = pixi.state.settings.explorer_grip * pixi.content_scale[0] / 2.0,
        .y = -1.0,
    }, imgui.ButtonFlags_None);

    var hovered_flags: imgui.HoveredFlags = 0;
    hovered_flags |= imgui.HoveredFlags_AllowWhenOverlapped;
    hovered_flags |= imgui.HoveredFlags_AllowWhenBlockedByActiveItem;

    if (imgui.isItemHovered(hovered_flags)) {
        imgui.setMouseCursor(imgui.MouseCursor_ResizeEW);
    }

    if (imgui.isItemActive()) {
        const prev = pixi.state.mouse.previous_position;
        const cur = pixi.state.mouse.position;

        const diff = cur[0] - prev[0];

        imgui.setMouseCursor(imgui.MouseCursor_ResizeEW);
        pixi.state.settings.explorer_width = std.math.clamp(pixi.state.settings.explorer_width + diff / pixi.content_scale[0], 200, 500);
    }
    imgui.end();
}
