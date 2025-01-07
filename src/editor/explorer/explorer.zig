const std = @import("std");
const Pixi = @import("../../Pixi.zig");
const nfd = @import("nfd");
const imgui = @import("zig-imgui");
const Core = @import("mach").Core;

pub const files = @import("files.zig");
pub const tools = @import("tools.zig");
pub const layers = @import("layers.zig");
pub const sprites = @import("sprites.zig");
pub const animations = @import("animations.zig");
pub const keyframe_animations = @import("keyframe_animations.zig");
pub const pack = @import("pack.zig");
pub const settings = @import("settings.zig");

pub fn draw(core: *Core) !void {
    imgui.pushStyleVar(imgui.StyleVar_WindowRounding, 0.0);
    imgui.pushStyleVar(imgui.StyleVar_WindowBorderSize, 0.0);
    imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 0.0, .y = 0.0 });
    imgui.pushStyleColorImVec4(imgui.Col_WindowBg, Pixi.editor.theme.foreground.toImguiVec4());
    defer imgui.popStyleColor();

    const explorer_width = Pixi.state.settings.explorer_width;

    imgui.setNextWindowPos(.{
        .x = Pixi.state.settings.sidebar_width * Pixi.state.content_scale[0],
        .y = 0,
    }, imgui.Cond_Always);
    imgui.setNextWindowSize(.{
        .x = explorer_width * Pixi.state.content_scale[0],
        .y = Pixi.state.window_size[1],
    }, imgui.Cond_None);

    var explorer_flags: imgui.WindowFlags = 0;
    explorer_flags |= imgui.WindowFlags_NoTitleBar;
    explorer_flags |= imgui.WindowFlags_NoResize;
    explorer_flags |= imgui.WindowFlags_NoMove;
    explorer_flags |= imgui.WindowFlags_NoCollapse;
    explorer_flags |= imgui.WindowFlags_HorizontalScrollbar;
    explorer_flags |= imgui.WindowFlags_MenuBar;
    explorer_flags |= imgui.WindowFlags_NoBringToFrontOnFocus;

    if (imgui.begin("Explorer", null, explorer_flags)) {
        defer imgui.end();
        imgui.popStyleVarEx(3);

        imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0 * Pixi.state.content_scale[0], .y = 6.0 * Pixi.state.content_scale[1] });
        imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 0.0, .y = 8.0 * Pixi.state.content_scale[1] });
        defer imgui.popStyleVarEx(2);

        imgui.pushStyleColorImVec4(imgui.Col_Separator, Pixi.editor.theme.text_background.toImguiVec4());
        imgui.pushStyleColorImVec4(imgui.Col_Header, Pixi.editor.theme.foreground.toImguiVec4());
        defer imgui.popStyleColorEx(2);

        switch (Pixi.state.sidebar) {
            .files => {
                if (imgui.beginMenuBar()) {
                    if (Pixi.state.hotkeys.hotkey(.{ .sidebar = .files })) |hotkey| {
                        const title = try std.fmt.allocPrintZ(Pixi.state.allocator, "Explorer ({s})", .{hotkey.shortcut});
                        defer Pixi.state.allocator.free(title);

                        imgui.separatorText(title);
                    } else {
                        imgui.separatorText("Explorer");
                    }
                    imgui.endMenuBar();
                }
                imgui.spacing();
                imgui.spacing();
                try files.draw();
            },
            .tools => {
                if (imgui.beginMenuBar()) {
                    if (Pixi.state.hotkeys.hotkey(.{ .sidebar = .tools })) |hotkey| {
                        const title = try std.fmt.allocPrintZ(Pixi.state.allocator, "Tools ({s})", .{hotkey.shortcut});
                        defer Pixi.state.allocator.free(title);

                        imgui.separatorText(title);
                    } else {
                        imgui.separatorText("Tools");
                    }
                    imgui.endMenuBar();
                }
                imgui.spacing();
                imgui.spacing();

                try tools.draw();
            },
            .sprites => {
                if (imgui.beginMenuBar()) {
                    if (Pixi.state.hotkeys.hotkey(.{ .sidebar = .sprites })) |hotkey| {
                        const title = try std.fmt.allocPrintZ(Pixi.state.allocator, "Sprites ({s})", .{hotkey.shortcut});
                        defer Pixi.state.allocator.free(title);

                        imgui.separatorText(title);
                    } else {
                        imgui.separatorText("Sprites");
                    }
                    imgui.endMenuBar();
                }
                imgui.spacing();
                imgui.spacing();
                try sprites.draw();
            },
            .animations => {
                if (imgui.beginMenuBar()) {
                    if (Pixi.state.hotkeys.hotkey(.{ .sidebar = .animations })) |hotkey| {
                        const title = try std.fmt.allocPrintZ(Pixi.state.allocator, "Animations ({s})", .{hotkey.shortcut});
                        defer Pixi.state.allocator.free(title);

                        imgui.separatorText(title);
                    } else {
                        imgui.separatorText("Animations");
                    }
                    imgui.endMenuBar();
                }
                imgui.spacing();
                imgui.spacing();
                try animations.draw();
            },
            .keyframe_animations => {
                if (imgui.beginMenuBar()) {
                    if (Pixi.state.hotkeys.hotkey(.{ .sidebar = .keyframe_animations })) |hotkey| {
                        const title = try std.fmt.allocPrintZ(Pixi.state.allocator, "Keyframe Animations ({s})", .{hotkey.shortcut});
                        defer Pixi.state.allocator.free(title);

                        imgui.separatorText(title);
                    } else {
                        imgui.separatorText("Keyframe Animations");
                    }
                    imgui.endMenuBar();
                }
                imgui.spacing();
                imgui.spacing();
                try keyframe_animations.draw();
            },
            .pack => {
                if (imgui.beginMenuBar()) {
                    if (Pixi.state.hotkeys.hotkey(.{ .sidebar = .pack })) |hotkey| {
                        const title = try std.fmt.allocPrintZ(Pixi.state.allocator, "Packing ({s})", .{hotkey.shortcut});
                        defer Pixi.state.allocator.free(title);

                        imgui.separatorText(title);
                    } else {
                        imgui.separatorText("Packing");
                    }
                    imgui.endMenuBar();
                }
                imgui.spacing();
                imgui.spacing();
                try pack.draw();
            },
            .settings => {
                if (imgui.beginMenuBar()) {
                    if (Pixi.state.hotkeys.hotkey(.{ .sidebar = .settings })) |hotkey| {
                        const title = try std.fmt.allocPrintZ(Pixi.state.allocator, "Settings ({s})", .{hotkey.shortcut});
                        defer Pixi.state.allocator.free(title);

                        imgui.separatorText(title);
                    } else {
                        imgui.separatorText("Settings");
                    }
                    imgui.endMenuBar();
                }
                imgui.spacing();
                imgui.spacing();
                try settings.draw(core);
            },
        }
    }

    imgui.pushStyleVarImVec2(imgui.StyleVar_WindowMinSize, .{ .x = 0.0, .y = 0.0 });
    defer imgui.popStyleVar();

    imgui.pushStyleColorImVec4(imgui.Col_ButtonHovered, Pixi.editor.theme.foreground.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_ButtonActive, Pixi.editor.theme.foreground.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_background.toImguiVec4());
    defer imgui.popStyleColorEx(3);

    imgui.setNextWindowPos(.{
        .x = Pixi.state.settings.sidebar_width + explorer_width,
        .y = 0,
    }, imgui.Cond_Always);
    imgui.setNextWindowSize(.{
        .x = Pixi.state.settings.explorer_grip,
        .y = Pixi.state.window_size[1],
    }, imgui.Cond_Always);

    var grip_flags: imgui.WindowFlags = 0;
    grip_flags |= imgui.WindowFlags_NoTitleBar;
    grip_flags |= imgui.WindowFlags_NoResize;
    grip_flags |= imgui.WindowFlags_NoMove;
    grip_flags |= imgui.WindowFlags_NoCollapse;
    grip_flags |= imgui.WindowFlags_NoScrollbar;
    grip_flags |= imgui.WindowFlags_NoScrollWithMouse;

    if (imgui.begin("Grip", null, grip_flags)) {
        defer imgui.end();

        imgui.setCursorPosY(0.0);
        imgui.setCursorPosX(0.0);

        const avail = imgui.getContentRegionAvail().y;
        const curs_y = imgui.getCursorPosY();

        var color = Pixi.editor.theme.text_background.toImguiVec4();

        _ = imgui.invisibleButton("GripButton", .{
            .x = Pixi.state.settings.explorer_grip,
            .y = -1.0,
        }, imgui.ButtonFlags_None);

        var hovered_flags: imgui.HoveredFlags = 0;
        hovered_flags |= imgui.HoveredFlags_AllowWhenOverlapped;
        hovered_flags |= imgui.HoveredFlags_AllowWhenBlockedByActiveItem;

        if (imgui.isItemHovered(hovered_flags)) {
            imgui.setMouseCursor(imgui.MouseCursor_ResizeEW);
            color = Pixi.editor.theme.text.toImguiVec4();

            if (imgui.isMouseDoubleClicked(imgui.MouseButton_Left)) {
                Pixi.state.settings.split_artboard = !Pixi.state.settings.split_artboard;
            }
        }

        if (imgui.isItemActive()) {
            color = Pixi.editor.theme.text.toImguiVec4();
            const prev = Pixi.state.mouse.previous_position;
            const cur = Pixi.state.mouse.position;

            const diff = cur[0] - prev[0];

            imgui.setMouseCursor(imgui.MouseCursor_ResizeEW);
            Pixi.state.settings.explorer_width = std.math.clamp(
                Pixi.state.settings.explorer_width + diff,
                200,
                Pixi.state.window_size[0] / 2.0 - Pixi.state.settings.sidebar_width,
            );
        }

        imgui.setCursorPosY(curs_y + avail / 2.0);
        imgui.textColored(color, Pixi.fa.grip_lines_vertical);
    }
}
