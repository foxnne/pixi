const std = @import("std");
const pixi = @import("../../pixi.zig");
const Editor = pixi.Editor;

const core = @import("mach").core;
const imgui = @import("zig-imgui");

var open: bool = false;

pub fn draw(editor: *Editor) !void {
    if (!editor.popups.references) return;

    const popup_size = 200;

    const window_size = pixi.app.window_size;

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

    var background_color = editor.theme.foreground;
    background_color.value[3] = editor.settings.reference_window_opacity / 100.0;

    imgui.pushStyleColorImVec4(imgui.Col_WindowBg, background_color.toImguiVec4());
    defer imgui.popStyleColor();

    if (imgui.begin(
        "References",
        &editor.popups.references,
        popup_flags,
    )) {
        var ref_flags: imgui.TabBarFlags = 0;
        ref_flags |= imgui.TabBarFlags_Reorderable;
        ref_flags |= imgui.TabBarFlags_AutoSelectNewTabs;

        if (imgui.beginTabBar("ReferencesTabBar", ref_flags)) {
            defer imgui.endTabBar();

            for (editor.open_references.items, 0..) |*reference, i| {
                var tab_open: bool = true;

                const file_name = std.fs.path.basename(reference.path);

                imgui.pushIDInt(@as(c_int, @intCast(i)));
                defer imgui.popID();

                const label = try std.fmt.allocPrintZ(pixi.app.allocator, " {s}  {s} ", .{ pixi.fa.file_image, file_name });
                defer pixi.app.allocator.free(label);

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
                    try editor.closeReference(i);
                    break;
                }

                if (imgui.isItemClickedEx(imgui.MouseButton_Left)) {
                    editor.setActiveReference(i);
                }

                if (imgui.beginPopupContextItem()) {
                    defer imgui.endPopup();
                    imgui.text("Opacity");
                    _ = imgui.sliderFloatEx("Background", &editor.settings.reference_window_opacity, 0.0, 100.0, "%.0f", imgui.SliderFlags_AlwaysClamp);
                    _ = imgui.sliderFloatEx("Reference", &reference.opacity, 0.0, 100.0, "%.0f", imgui.SliderFlags_AlwaysClamp);
                }
            }

            var canvas_flags: imgui.WindowFlags = 0;
            canvas_flags |= imgui.WindowFlags_ChildWindow;

            if (editor.getReference(editor.open_reference_index)) |reference| {
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
                        reference.camera.min_zoom = @min(camera.zoom, pixi.editor.settings.zoom_steps[0]);

                        reference.camera.processPanZoom(.reference);
                    }

                    { // Draw reference texture
                        const color = pixi.math.Color.initFloats(1.0, 1.0, 1.0, reference.opacity / 100.0);
                        reference.camera.drawTexture(reference.texture.view_handle, reference.texture.image.width, reference.texture.image.height, canvas_center_offset, color.toU32());
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
