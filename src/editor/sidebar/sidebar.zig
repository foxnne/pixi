const pixi = @import("../../Pixi.zig");
const core = @import("mach").core;
const imgui = @import("zig-imgui");

pub fn draw() void {
    imgui.pushStyleVar(imgui.StyleVar_WindowRounding, 0.0);
    defer imgui.popStyleVar();
    imgui.setNextWindowPos(.{
        .x = 0.0,
        .y = 0.0,
    }, imgui.Cond_Always);
    imgui.setNextWindowSize(.{
        .x = pixi.state.settings.sidebar_width * pixi.content_scale[0],
        .y = pixi.window_size[1],
    }, imgui.Cond_None);
    imgui.pushStyleVarImVec2(imgui.StyleVar_SelectableTextAlign, .{ .x = 0.5, .y = 0.5 });
    imgui.pushStyleColorImVec4(imgui.Col_Header, pixi.state.theme.foreground.toImguiVec4());
    imgui.pushStyleColorImVec4(imgui.Col_WindowBg, pixi.state.theme.foreground.toImguiVec4());
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
        imgui.pushStyleColorImVec4(imgui.Col_HeaderHovered, pixi.state.theme.foreground.toImguiVec4());
        imgui.pushStyleColorImVec4(imgui.Col_HeaderActive, pixi.state.theme.foreground.toImguiVec4());
        defer imgui.popStyleColorEx(2);

        drawOption(.files, pixi.fa.folder_open);
        drawOption(.tools, pixi.fa.pencil_alt);
        drawOption(.sprites, pixi.fa.th);
        drawOption(.animations, pixi.fa.play_circle);
        drawOption(.keyframe_animations, pixi.fa.key);
        drawOption(.pack, pixi.fa.box_open);
        drawOption(.settings, pixi.fa.cog);
    }

    imgui.end();
}

fn drawOption(option: pixi.Sidebar, icon: [:0]const u8) void {
    const position = imgui.getCursorPos();
    const selectable_width = (pixi.state.settings.sidebar_width - 8) * pixi.content_scale[0];
    const selectable_height = (pixi.state.settings.sidebar_width - 8) * pixi.content_scale[1];
    imgui.dummy(.{
        .x = selectable_width,
        .y = selectable_height,
    });

    imgui.setCursorPos(position);
    if (pixi.state.sidebar == option) {
        imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.highlight_primary.toImguiVec4());
    } else if (imgui.isItemHovered(imgui.HoveredFlags_None)) {
        imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text.toImguiVec4());
    } else {
        imgui.pushStyleColorImVec4(imgui.Col_Text, pixi.state.theme.text_secondary.toImguiVec4());
    }

    const selectable_flags: imgui.SelectableFlags = imgui.SelectableFlags_DontClosePopups;
    if (imgui.selectableEx(icon, pixi.state.sidebar == option, selectable_flags, .{ .x = selectable_width, .y = selectable_height })) {
        pixi.state.sidebar = option;
        if (option == .sprites)
            pixi.state.tools.set(.pointer);
    }
    imgui.popStyleColor();
}
