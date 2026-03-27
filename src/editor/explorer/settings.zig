const builtin = @import("builtin");
const std = @import("std");

const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");
// const Core = @import("mach").Core;
const Editor = pixi.Editor;

const nfd = @import("nfd");
// const imgui = @import("zig-imgui");

pub fn draw() !void {
    var vbox = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .horizontal,
    });
    defer vbox.deinit();

    if (dvui.Theme.picker(@src(), pixi.editor.themes.items, .{})) {}

    if (true) {
        if (dvui.sliderEntry(@src(), "Window Opacity: {d:0.01}", .{
            .value = &if (dvui.themeGet().dark) pixi.editor.settings.window_opacity_dark else pixi.editor.settings.window_opacity_light,
            .interval = 0.01,
            .max = 1.0,
            .min = 0.0,
        }, .{
            .expand = .none,
        })) {
            pixi.backend.setTitlebarColor(dvui.currentWindow(), dvui.themeGet().color(.content, .fill).opacity(if (dvui.themeGet().dark) pixi.editor.settings.window_opacity_dark else pixi.editor.settings.window_opacity_light));
            dvui.refresh(null, @src(), vbox.data().id);
        }

        if (dvui.sliderEntry(@src(), "Content Opacity: {d:0.01}", .{
            .value = &pixi.editor.settings.content_opacity,
            .interval = 0.01,
            .max = 1.0,
            .min = 0.0,
        }, .{
            .expand = .none,
        })) {
            pixi.backend.setTitlebarColor(dvui.currentWindow(), dvui.themeGet().color(.content, .fill).opacity(pixi.editor.settings.content_opacity));
            dvui.refresh(null, @src(), vbox.data().id);
        }

        {
            const oldt = dvui.themeGet();
            var t = oldt;
            t.control.fill = t.window.fill;
            dvui.themeSet(t);
            defer dvui.themeSet(oldt);

            var dropdown: dvui.DropdownWidget = undefined;
            dropdown.init(@src(), .{ .label = "Transparency effect" }, .{
                .expand = .horizontal,
                .corner_radius = dvui.Rect.all(1000),
            });
            defer dropdown.deinit();

            var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .expand = .vertical,
                .gravity_x = 1.0,
            });

            const label_text = switch (pixi.editor.settings.transparency_effect) {
                .none => "None",
                .rainbow => "Rainbow",
                .animation => "Animation",
            };
            dvui.label(@src(), "{s}", .{label_text}, .{ .margin = .all(0), .padding = .all(0) });

            dvui.icon(
                @src(),
                "dropdown_triangle",
                dvui.entypo.triangle_down,
                .{},
                .{ .gravity_y = 0.5 },
            );

            hbox.deinit();

            if (dropdown.dropped()) {
                if (dropdown.addChoiceLabel("None")) {
                    pixi.editor.settings.transparency_effect = .none;
                    dvui.refresh(null, @src(), vbox.data().id);
                }
                if (dropdown.addChoiceLabel("Rainbow")) {
                    pixi.editor.settings.transparency_effect = .rainbow;
                    dvui.refresh(null, @src(), vbox.data().id);
                }
                if (dropdown.addChoiceLabel("Animation")) {
                    pixi.editor.settings.transparency_effect = .animation;
                    dvui.refresh(null, @src(), vbox.data().id);
                }
            }

            _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 10, .h = 10 } });
        }

        if (dvui.checkbox(@src(), &pixi.editor.settings.show_rulers, "Show Rulers", .{
            .expand = .none,
        })) {}

        if (dvui.checkbox(@src(), &pixi.editor.settings.perf_logging, "Console perf logging", .{
            .expand = .none,
        })) {
            pixi.perf.console_logging_enabled = pixi.editor.settings.perf_logging;
        }
    }

    dvui.label(@src(), "{d:0>3.0} fps", .{dvui.FPS()}, .{});
}
