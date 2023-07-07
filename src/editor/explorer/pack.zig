const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("root");

pub fn draw() void {
    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.frame_padding, .v = .{ 6.0 * pixi.state.window.scale[0], 5.0 * pixi.state.window.scale[1] } });
    defer zgui.popStyleVar(.{ .count = 1 });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button, .c = pixi.state.style.highlight_secondary.toSlice() });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button_active, .c = pixi.state.style.highlight_secondary.toSlice() });
    zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button_hovered, .c = pixi.state.style.hover_secondary.toSlice() });
    defer zgui.popStyleColor(.{ .count = 3 });

    const window_size = zgui.getContentRegionAvail();

    switch (pixi.state.pack_files) {
        .all_open => {
            if (pixi.state.open_files.items.len <= 1) {
                pixi.state.pack_files = .project;
            }
        },
        .single_open => {
            if (pixi.state.open_files.items.len == 0)
                pixi.state.pack_files = .project;
        },
        else => {},
    }

    const preview_text = switch (pixi.state.pack_files) {
        .project => "Full Project",
        .all_open => "All Open Files",
        .single_open => "Current Open File",
    };

    if (zgui.beginCombo("Files", .{ .preview_value = preview_text.ptr })) {
        defer zgui.endCombo();
        if (zgui.menuItem("Full Project", .{})) {
            pixi.state.pack_files = .project;
        }

        {
            const enabled = if (pixi.editor.getFile(pixi.state.open_file_index)) |_| true else false;
            if (zgui.menuItem("Current Open File", .{ .enabled = enabled })) {
                pixi.state.pack_files = .single_open;
            }
        }

        {
            const enabled = if (pixi.state.open_files.items.len > 1) true else false;
            if (zgui.menuItem("All Open Files", .{ .enabled = enabled })) {
                pixi.state.pack_files = .all_open;
            }
        }
    }

    {
        if (pixi.state.pack_files == .project and pixi.state.project_folder == null)
            zgui.beginDisabled(.{});
        if (zgui.button("Pack", .{ .w = window_size[0] })) {
            if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
                pixi.state.packer.append(file) catch unreachable;
                pixi.state.packer.packAndClear() catch unreachable;
            }
        }
        if (pixi.state.pack_files == .project and pixi.state.project_folder == null) {
            zgui.endDisabled();
            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = pixi.state.style.text_background.toSlice() });
            defer zgui.popStyleColor(.{ .count = 1 });
            zgui.textWrapped("Select a project folder to pack.", .{});
        }
    }
}
