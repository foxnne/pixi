const pixi = @import("../pixi.zig");
const Core = @import("mach").Core;

const App = pixi.App;
const Editor = pixi.Editor;

const Pane = @import("explorer/Explorer.zig").Pane;

const imgui = @import("zig-imgui");

pub const Sidebar = @This();

pub const mach_module = .sidebar;
pub const mach_systems = .{ .init, .deinit, .draw };

pub fn init(sidebar: *Sidebar) !void {
    sidebar.* = .{};
}

pub fn deinit() void {
    // TODO: Free memory
}

pub fn draw(app: *App, editor: *Editor) !void {
    imgui.pushStyleVar(imgui.StyleVar_WindowRounding, 0.0);
    defer imgui.popStyleVar();
    imgui.setNextWindowPos(.{
        .x = 0.0,
        .y = 0.0,
    }, imgui.Cond_Always);
    imgui.setNextWindowSize(.{
        .x = editor.settings.sidebar_width,
        .y = app.window_size[1],
    }, imgui.Cond_None);
    imgui.pushStyleVarImVec2(imgui.StyleVar_SelectableTextAlign, .{ .x = 0.5, .y = 0.5 });
    imgui.pushStyleColorImVec4(imgui.Col_Header, editor.theme.foreground.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_WindowBg, editor.theme.foreground.toImguiVec4());
    defer imgui.popStyleVar();
    defer imgui.popStyleColorEx(2);

    var sidebar_flags: imgui.WindowFlags = 0;
    sidebar_flags |= imgui.WindowFlags_NoTitleBar;
    sidebar_flags |= imgui.WindowFlags_NoResize;
    sidebar_flags |= imgui.WindowFlags_NoMove;
    sidebar_flags |= imgui.WindowFlags_NoCollapse;
    sidebar_flags |= imgui.WindowFlags_NoScrollbar;
    sidebar_flags |= imgui.WindowFlags_NoScrollWithMouse;
    sidebar_flags |= imgui.WindowFlags_NoBringToFrontOnFocus;

    if (imgui.begin("Sidebar", null, sidebar_flags)) {
        imgui.pushStyleColorImVec4(imgui.Col_HeaderHovered, editor.theme.foreground.toImguiVec4());
        imgui.pushStyleColorImVec4(imgui.Col_HeaderActive, editor.theme.foreground.toImguiVec4());
        defer imgui.popStyleColorEx(2);

        drawOption(.files, pixi.fa.folder_open, editor);
        drawOption(.tools, pixi.fa.pencil_alt, editor);
        drawOption(.sprites, pixi.fa.th, editor);
        drawOption(.animations, pixi.fa.play_circle, editor);
        drawOption(.keyframe_animations, pixi.fa.key, editor);
        drawOption(.pack, pixi.fa.box_open, editor);
        drawOption(.settings, pixi.fa.cog, editor);
    }

    imgui.end();
}

fn drawOption(option: Pane, icon: [:0]const u8, editor: *Editor) void {
    const position = imgui.getCursorPos();
    const selectable_width = (editor.settings.sidebar_width - 8);
    const selectable_height = (editor.settings.sidebar_width - 8);
    imgui.dummy(.{
        .x = selectable_width,
        .y = selectable_height,
    });

    imgui.setCursorPos(position);
    if (editor.explorer.pane == option) {
        imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.highlight_primary.toImguiVec4());
    } else if (imgui.isItemHovered(imgui.HoveredFlags_None)) {
        imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text.toImguiVec4());
    } else {
        imgui.pushStyleColorImVec4(imgui.Col_Text, editor.theme.text_secondary.toImguiVec4());
    }

    const selectable_flags: imgui.SelectableFlags = imgui.SelectableFlags_DontClosePopups;
    if (imgui.selectableEx(icon, editor.explorer.pane == option, selectable_flags, .{ .x = selectable_width, .y = selectable_height })) {
        editor.explorer.pane = option;
        if (option == .sprites)
            editor.tools.set(.pointer);
    }
    imgui.popStyleColor();
}
