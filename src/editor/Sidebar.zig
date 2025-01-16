const Pixi = @import("../Pixi.zig");
const Core = @import("mach").Core;

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

pub fn draw(app: *Pixi) !void {
    imgui.pushStyleVar(imgui.StyleVar_WindowRounding, 0.0);
    defer imgui.popStyleVar();
    imgui.setNextWindowPos(.{
        .x = 0.0,
        .y = 0.0,
    }, imgui.Cond_Always);
    imgui.setNextWindowSize(.{
        .x = app.settings.sidebar_width * app.content_scale[0],
        .y = app.window_size[1],
    }, imgui.Cond_None);
    imgui.pushStyleVarImVec2(imgui.StyleVar_SelectableTextAlign, .{ .x = 0.5, .y = 0.5 });
    imgui.pushStyleColorImVec4(imgui.Col_Header, Pixi.editor.theme.foreground.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_WindowBg, Pixi.editor.theme.foreground.toImguiVec4());
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
        imgui.pushStyleColorImVec4(imgui.Col_HeaderHovered, Pixi.editor.theme.foreground.toImguiVec4());
        imgui.pushStyleColorImVec4(imgui.Col_HeaderActive, Pixi.editor.theme.foreground.toImguiVec4());
        defer imgui.popStyleColorEx(2);

        drawOption(.files, Pixi.fa.folder_open, app);
        drawOption(.tools, Pixi.fa.pencil_alt, app);
        drawOption(.sprites, Pixi.fa.th, app);
        drawOption(.animations, Pixi.fa.play_circle, app);
        drawOption(.keyframe_animations, Pixi.fa.key, app);
        drawOption(.pack, Pixi.fa.box_open, app);
        drawOption(.settings, Pixi.fa.cog, app);
    }

    imgui.end();
}

fn drawOption(option: Pixi.Sidebar, icon: [:0]const u8, app: *Pixi) void {
    const position = imgui.getCursorPos();
    const selectable_width = (app.settings.sidebar_width - 8) * app.content_scale[0];
    const selectable_height = (app.settings.sidebar_width - 8) * app.content_scale[1];
    imgui.dummy(.{
        .x = selectable_width,
        .y = selectable_height,
    });

    imgui.setCursorPos(position);
    if (app.sidebar == option) {
        imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.highlight_primary.toImguiVec4());
    } else if (imgui.isItemHovered(imgui.HoveredFlags_None)) {
        imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text.toImguiVec4());
    } else {
        imgui.pushStyleColorImVec4(imgui.Col_Text, Pixi.editor.theme.text_secondary.toImguiVec4());
    }

    const selectable_flags: imgui.SelectableFlags = imgui.SelectableFlags_DontClosePopups;
    if (imgui.selectableEx(icon, app.sidebar == option, selectable_flags, .{ .x = selectable_width, .y = selectable_height })) {
        app.sidebar = option;
        if (option == .sprites)
            app.tools.set(.pointer);
    }
    imgui.popStyleColor();
}
