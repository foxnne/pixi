const std = @import("std");
const pixi = @import("../../pixi.zig");
const core = @import("mach").core;
const imgui = @import("zig-imgui");

var open: bool = false;

pub fn draw() void {
    if (!pixi.state.popups.references) return;

    const popup_size = 200 * pixi.content_scale[0];

    const window_size = pixi.window_size;

    imgui.setNextWindowPos(.{
        .x = window_size[0] - popup_size - 30.0,
        .y = 30.0,
    }, imgui.Cond_Appearing);
    imgui.setNextWindowSize(.{
        .x = popup_size,
        .y = popup_size,
    }, imgui.Cond_Appearing);

    var popup_flags: imgui.WindowFlags = 0;
    popup_flags |= imgui.WindowFlags_None;

    imgui.pushStyleColorImVec4(imgui.Col_WindowBg, .{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 0.0 });
    defer imgui.popStyleColor();

    if (imgui.begin(
        "References",
        &pixi.state.popups.references,
        popup_flags,
    )) {
        var ref_flags: imgui.TabBarFlags = 0;
        ref_flags |= imgui.TabBarFlags_Reorderable;
        ref_flags |= imgui.TabBarFlags_AutoSelectNewTabs;

        if (imgui.beginTabBar("ReferencesTabBar", ref_flags)) {
            defer imgui.endTabBar();

            for (pixi.state.open_references.items, 0..) |reference, i| {
                var tab_open: bool = true;

                const file_name = std.fs.path.basename(reference.path);

                imgui.pushIDInt(@as(c_int, @intCast(i)));
                defer imgui.popID();

                const label = std.fmt.allocPrintZ(pixi.state.allocator, " {s}  {s} ", .{ pixi.fa.file_image, file_name }) catch unreachable;
                defer pixi.state.allocator.free(label);

                var file_tab_flags: imgui.TabItemFlags = 0;
                file_tab_flags |= imgui.TabItemFlags_None;

                if (imgui.beginTabItem(
                    label,
                    &tab_open,
                    file_tab_flags,
                )) {
                    imgui.endTabItem();
                }

                if (!tab_open) {
                    pixi.editor.closeReference(i) catch unreachable;
                }

                if (imgui.isItemClickedEx(imgui.MouseButton_Left)) {
                    pixi.editor.setActiveReference(i);
                }
            }

            var canvas_flags: imgui.WindowFlags = 0;
            canvas_flags |= imgui.WindowFlags_HorizontalScrollbar;

            if (pixi.editor.getReference(pixi.state.open_reference_index)) |reference| {
                if (imgui.beginChild(
                    reference.path,
                    .{ .x = 0.0, .y = 0.0 },
                    imgui.ChildFlags_None,
                    canvas_flags,
                )) {
                    const window_width = imgui.getWindowWidth();
                    const window_height = imgui.getWindowHeight();

                    const file_width: f32 = @floatFromInt(reference.texture.image.width);
                    const file_height: f32 = @floatFromInt(reference.texture.image.height);

                    const canvas_center_offset = reference.canvasCenterOffset();

                    { // Handle reference camera
                        var camera: pixi.gfx.Camera = .{
                            .zoom = @min(window_width / file_width, window_height / file_height),
                        };
                        camera.setNearestZoomFloor();
                        if (!reference.camera.zoom_initialized) {
                            reference.camera.zoom_initialized = true;
                            reference.camera.zoom = camera.zoom;
                        }
                        camera.setNearestZoomFloor();
                        const min_zoom = @min(camera.zoom, pixi.state.settings.zoom_steps[0]);

                        reference.camera.processPanZoom();

                        // Lock camera from zooming in or out too far for the flipbook
                        reference.camera.zoom = std.math.clamp(reference.camera.zoom, min_zoom, pixi.state.settings.zoom_steps[pixi.state.settings.zoom_steps.len - 1]);

                        // Lock camera from moving too far away from canvas
                        reference.camera.position[0] = std.math.clamp(reference.camera.position[0], -(canvas_center_offset[0] + file_width), canvas_center_offset[0] + file_width);
                        reference.camera.position[1] = std.math.clamp(reference.camera.position[1], -(canvas_center_offset[1] + file_height), canvas_center_offset[1] + file_height);
                    }

                    { // Draw reference texture
                        reference.camera.drawTexture(reference.texture.view_handle, reference.texture.image.width, reference.texture.image.height, canvas_center_offset, 0xFFFFFFFF);
                    }

                    { // Allow dropper support
                        if (imgui.isWindowHovered(imgui.HoveredFlags_None)) {
                            reference.processSampleTool();
                        }
                    }
                }
                imgui.endChild();
            }
        }
    }
    imgui.end();
}
