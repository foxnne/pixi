const std = @import("std");

const dvui = @import("dvui");
const pixi = @import("../../pixi.zig");

const Core = @import("mach").Core;
const App = pixi.App;
const Editor = pixi.Editor;
const Packer = pixi.Packer;

const nfd = @import("nfd");
//const imgui = @import("zig-imgui");

pub const Explorer = @This();

pub const files = @import("files.zig");
// pub const tools = @import("tools.zig");
// pub const layers = @import("layers.zig");
// pub const sprites = @import("sprites.zig");
// pub const animations = @import("animations.zig");
// pub const keyframe_animations = @import("keyframe_animations.zig");
// pub const project = @import("project.zig");
pub const settings = @import("settings.zig");

pane: Pane = .files,

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
    return .{};
}

pub fn deinit() void {
    // TODO: Free memory
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

pub fn processKeybinds(_: *Explorer) !void {}

pub fn draw(explorer: *Explorer) !dvui.App.Result {
    const vbox = dvui.box(@src(), .vertical, .{
        .expand = .both,
        .background = false,
    });
    defer vbox.deinit();

    try drawHeader(explorer);

    _ = dvui.separator(@src(), .{ .expand = .horizontal });

    const pane_vbox = dvui.box(@src(), .vertical, .{
        .expand = .both,
        .background = false,
    });
    defer pane_vbox.deinit();

    var scroll = dvui.scrollArea(@src(), .{ .horizontal = .auto }, .{
        .expand = .both,
        .background = false,
        .color_fill = .fill,
    });
    defer scroll.deinit();

    switch (explorer.pane) {
        .files => try files.draw(),
        .settings => try settings.draw(),
        else => {},
    }

    // Only draw shadow if the scroll bar has been scrolled some
    if (scroll.si.offset(.vertical) > 0.0) {
        var rs = pane_vbox.data().contentRectScale();
        rs.r.h = 20.0;

        var path: dvui.Path.Builder = .init(dvui.currentWindow().arena());
        path.addRect(rs.r, dvui.Rect.Physical.all(5));

        var triangles = try path.build().fillConvexTriangles(dvui.currentWindow().arena(), .{ .center = rs.r.center() });

        const black: dvui.Color = .black;
        const ca0 = black.opacity(0.1);
        const ca1 = black.opacity(0);

        for (triangles.vertexes) |*v| {
            const t = std.math.clamp((v.pos.y - rs.r.y) / rs.r.h, 0.0, 1.0);
            v.col = v.col.multiply(.fromColor(dvui.Color.lerp(ca0, ca1, t)));
        }
        try dvui.renderTriangles(triangles, null);

        triangles.deinit(dvui.currentWindow().arena());
        path.deinit();
    }

    return .ok;
}

pub fn drawHeader(explorer: *Explorer) !void {
    const header_title = title(explorer.pane, true);

    const text_layout = dvui.textLayout(@src(), .{}, .{ .background = false, .max_size_content = .{ .h = dvui.themeGet().font_heading.lineHeight() * 2.0, .w = std.math.floatMax(f32) } });
    defer text_layout.deinit();

    text_layout.addText(header_title, .{ .font_style = .title });
}

// pub fn draw(core: *Core, app: *App, editor: *Editor, explorer: *Explorer, packer: *Packer) !void {
//     imgui.pushStyleVar(imgui.StyleVar_WindowRounding, 0.0);
//     imgui.pushStyleVar(imgui.StyleVar_WindowBorderSize, 0.0);
//     imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 0.0, .y = 0.0 });
//     imgui.pushStyleColorImVec4(imgui.Col_WindowBg, pixi.editor.theme.foreground.toImguiVec4());
//     defer imgui.popStyleColor();

//     const explorer_width = editor.settings.explorer_width;

//     imgui.setNextWindowPos(.{
//         .x = editor.settings.sidebar_width,
//         .y = 0,
//     }, imgui.Cond_Always);
//     imgui.setNextWindowSize(.{
//         .x = explorer_width,
//         .y = app.window_size[1],
//     }, imgui.Cond_None);

//     var explorer_flags: imgui.WindowFlags = 0;
//     explorer_flags |= imgui.WindowFlags_NoTitleBar;
//     explorer_flags |= imgui.WindowFlags_NoResize;
//     explorer_flags |= imgui.WindowFlags_NoMove;
//     explorer_flags |= imgui.WindowFlags_NoCollapse;
//     explorer_flags |= imgui.WindowFlags_HorizontalScrollbar;
//     explorer_flags |= imgui.WindowFlags_MenuBar;
//     explorer_flags |= imgui.WindowFlags_NoBringToFrontOnFocus;

//     if (imgui.begin("Explorer", null, explorer_flags)) {
//         defer imgui.end();
//         imgui.popStyleVarEx(3);

//         imgui.pushStyleVarImVec2(imgui.StyleVar_ItemSpacing, .{ .x = 4.0, .y = 6.0 });
//         imgui.pushStyleVarImVec2(imgui.StyleVar_FramePadding, .{ .x = 0.0, .y = 8.0 });
//         defer imgui.popStyleVarEx(2);

//         imgui.pushStyleColorImVec4(imgui.Col_Separator, editor.theme.text_background.toImguiVec4());
//         imgui.pushStyleColorImVec4(imgui.Col_Header, editor.theme.foreground.toImguiVec4());
//         defer imgui.popStyleColorEx(2);

//         switch (explorer.pane) {
//             .files => {
//                 if (imgui.beginMenuBar()) {
//                     if (editor.hotkeys.hotkey(.{ .sidebar = .files })) |hotkey| {
//                         const title = try std.fmt.allocPrintZ(editor.arena.allocator(), "Explorer ({s})", .{hotkey.shortcut});
//                         imgui.separatorText(title);
//                     } else {
//                         imgui.separatorText("Explorer");
//                     }
//                     imgui.endMenuBar();
//                 }
//                 imgui.spacing();
//                 imgui.spacing();
//                 try files.draw(editor);
//             },
//             .tools => {
//                 if (imgui.beginMenuBar()) {
//                     if (editor.hotkeys.hotkey(.{ .sidebar = .tools })) |hotkey| {
//                         const title = try std.fmt.allocPrintZ(editor.arena.allocator(), "Tools ({s})", .{hotkey.shortcut});
//                         imgui.separatorText(title);
//                     } else {
//                         imgui.separatorText("Tools");
//                     }
//                     imgui.endMenuBar();
//                 }
//                 imgui.spacing();
//                 imgui.spacing();

//                 try tools.draw(editor);
//             },
//             .sprites => {
//                 if (imgui.beginMenuBar()) {
//                     if (editor.hotkeys.hotkey(.{ .sidebar = .sprites })) |hotkey| {
//                         const title = try std.fmt.allocPrintZ(editor.arena.allocator(), "Sprites ({s})", .{hotkey.shortcut});
//                         imgui.separatorText(title);
//                     } else {
//                         imgui.separatorText("Sprites");
//                     }
//                     imgui.endMenuBar();
//                 }
//                 imgui.spacing();
//                 imgui.spacing();
//                 try sprites.draw(editor);
//             },
//             .animations => {
//                 if (imgui.beginMenuBar()) {
//                     if (editor.hotkeys.hotkey(.{ .sidebar = .animations })) |hotkey| {
//                         const title = try std.fmt.allocPrintZ(editor.arena.allocator(), "Animations ({s})", .{hotkey.shortcut});
//                         imgui.separatorText(title);
//                     } else {
//                         imgui.separatorText("Animations");
//                     }
//                     imgui.endMenuBar();
//                 }
//                 imgui.spacing();
//                 imgui.spacing();
//                 try animations.draw(editor);
//             },
//             .keyframe_animations => {
//                 if (imgui.beginMenuBar()) {
//                     if (editor.hotkeys.hotkey(.{ .sidebar = .keyframe_animations })) |hotkey| {
//                         const title = try std.fmt.allocPrintZ(editor.arena.allocator(), "Keyframe Animations ({s})", .{hotkey.shortcut});
//                         imgui.separatorText(title);
//                     } else {
//                         imgui.separatorText("Keyframe Animations");
//                     }
//                     imgui.endMenuBar();
//                 }
//                 imgui.spacing();
//                 imgui.spacing();
//                 try keyframe_animations.draw(editor);
//             },
//             .pack => {
//                 if (imgui.beginMenuBar()) {
//                     if (editor.hotkeys.hotkey(.{ .sidebar = .pack })) |hotkey| {
//                         const title = try std.fmt.allocPrintZ(editor.arena.allocator(), "Project ({s})", .{hotkey.shortcut});
//                         imgui.separatorText(title);
//                     } else {
//                         imgui.separatorText("Project");
//                     }
//                     imgui.endMenuBar();
//                 }
//                 imgui.spacing();
//                 imgui.spacing();
//                 try project.draw(app, editor, packer);
//             },
//             .settings => {
//                 if (imgui.beginMenuBar()) {
//                     if (editor.hotkeys.hotkey(.{ .sidebar = .settings })) |hotkey| {
//                         const title = try std.fmt.allocPrintZ(editor.arena.allocator(), "Settings ({s})", .{hotkey.shortcut});
//                         imgui.separatorText(title);
//                     } else {
//                         imgui.separatorText("Settings");
//                     }
//                     imgui.endMenuBar();
//                 }
//                 imgui.spacing();
//                 imgui.spacing();
//                 try settings.draw(core, editor);
//             },
//         }
//     }

//     imgui.pushStyleVarImVec2(imgui.StyleVar_WindowMinSize, .{ .x = 0.0, .y = 0.0 });
//     defer imgui.popStyleVar();

//     imgui.pushStyleColorImVec4(imgui.Col_ButtonHovered, editor.theme.foreground.toImguiVec4());
//     imgui.pushStyleColorImVec4(imgui.Col_ButtonActive, editor.theme.foreground.toImguiVec4());
//     imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text_background.toImguiVec4());
//     defer imgui.popStyleColorEx(3);

//     imgui.setNextWindowPos(.{
//         .x = editor.settings.sidebar_width + explorer_width,
//         .y = 0,
//     }, imgui.Cond_Always);
//     imgui.setNextWindowSize(.{
//         .x = editor.settings.explorer_grip,
//         .y = app.window_size[1],
//     }, imgui.Cond_Always);

//     var grip_flags: imgui.WindowFlags = 0;
//     grip_flags |= imgui.WindowFlags_NoTitleBar;
//     grip_flags |= imgui.WindowFlags_NoResize;
//     grip_flags |= imgui.WindowFlags_NoMove;
//     grip_flags |= imgui.WindowFlags_NoCollapse;
//     grip_flags |= imgui.WindowFlags_NoScrollbar;
//     grip_flags |= imgui.WindowFlags_NoScrollWithMouse;

//     if (imgui.begin("Grip", null, grip_flags)) {
//         defer imgui.end();

//         imgui.setCursorPosY(0.0);
//         imgui.setCursorPosX(0.0);

//         const avail = imgui.getContentRegionAvail().y;
//         const curs_y = imgui.getCursorPosY();

//         var color = editor.theme.text_background.toImguiVec4();

//         _ = imgui.invisibleButton("GripButton", .{
//             .x = editor.settings.explorer_grip,
//             .y = -1.0,
//         }, imgui.ButtonFlags_None);

//         var hovered_flags: imgui.HoveredFlags = 0;
//         hovered_flags |= imgui.HoveredFlags_AllowWhenOverlapped;
//         hovered_flags |= imgui.HoveredFlags_AllowWhenBlockedByActiveItem;

//         if (imgui.isItemHovered(hovered_flags)) {
//             imgui.setMouseCursor(imgui.MouseCursor_ResizeEW);
//             color = editor.theme.text.toImguiVec4();

//             if (imgui.isMouseDoubleClicked(imgui.MouseButton_Left)) {
//                 editor.settings.split_artboard = !editor.settings.split_artboard;
//             }
//         }

//         if (imgui.isItemActive()) {
//             color = editor.theme.text.toImguiVec4();

//             imgui.setMouseCursor(imgui.MouseCursor_ResizeEW);
//             editor.settings.explorer_width = std.math.clamp(
//                 editor.settings.explorer_width + (editor.mouse.position[0] - editor.settings.explorer_width - editor.settings.sidebar_width - editor.settings.explorer_grip / 2.0),
//                 200,
//                 app.window_size[0] / 2.0 - editor.settings.sidebar_width,
//             );
//         }

//         imgui.setCursorPosY(curs_y + avail / 2.0);
//         imgui.textColored(color, pixi.fa.grip_lines_vertical);
//     }
// }
