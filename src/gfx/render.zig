const std = @import("std");
const pixi = @import("../pixi.zig");
const dvui = @import("dvui");

const RenderFileOptions = struct {
    file: *pixi.Internal.File,
    rs: dvui.RectScale,
    color_mod: dvui.Color = .white,
    fade: f32 = 0.0,
    uv: dvui.Rect = .{ .w = 1.0, .h = 1.0 },
    corner_radius: dvui.Rect = .all(0),
    allow_peek: bool = true,
};

/// Renders all visible layers of a file if the file is not isolated
/// Will peek layers if the peek layer index is set, and draw other layers as dimmed
/// Pass a valid uv if you want to draw a specific sprite of the file
pub fn renderLayers(init_opts: RenderFileOptions) !void {
    const content_rs = init_opts.rs;

    if (content_rs.s == 0) return;
    if (dvui.clipGet().intersect(content_rs.r).empty()) return;

    var min_layer_index: usize = 0;
    if (init_opts.allow_peek) {
        if (init_opts.file.editor.isolate_layer) {
            if (init_opts.file.peek_layer_index) |peek_layer_index| {
                min_layer_index = peek_layer_index;
            } else if (!pixi.editor.explorer.tools.layersHovered()) {
                min_layer_index = init_opts.file.selected_layer_index;
            }
        }
    }

    var path: dvui.Path.Builder = .init(pixi.app.allocator);
    defer path.deinit();

    path.addRect(content_rs.r, init_opts.corner_radius.scale(content_rs.s, dvui.Rect.Physical));

    var triangles = try path.build().fillConvexTriangles(pixi.app.allocator, .{ .color = init_opts.color_mod, .fade = init_opts.fade });
    defer triangles.deinit(pixi.app.allocator);

    triangles.uvFromRectuv(content_rs.r, init_opts.uv);

    var dimmed_triangles = try triangles.dupe(pixi.app.allocator);
    defer dimmed_triangles.deinit(pixi.app.allocator);
    dimmed_triangles.color(.gray);

    defer {
        dvui.renderTriangles(triangles, init_opts.file.editor.selection_layer.source.getTexture() catch null) catch {
            dvui.log.err("Failed to render selection layer", .{});
        };

        dvui.renderTriangles(triangles, init_opts.file.editor.temporary_layer.source.getTexture() catch null) catch {
            dvui.log.err("Failed to render temporary layer", .{});
        };

        if (init_opts.file.editor.transform) |*transform| {
            if (dvui.textureFromTarget(transform.target_texture) catch null) |tex| {
                dvui.renderTriangles(triangles, tex) catch {
                    dvui.log.err("Failed to render transform layer", .{});
                };
            }
        }
    }

    var layer_index: usize = init_opts.file.layers.len;
    while (layer_index > min_layer_index) {
        layer_index -= 1;

        const visible = init_opts.file.layers.items(.visible)[layer_index];
        if (!visible) continue;

        var tris = triangles;

        if (init_opts.allow_peek) {
            if (init_opts.file.peek_layer_index) |peek_layer_index| {
                if (peek_layer_index != layer_index) {
                    tris = dimmed_triangles;
                }
            }
        }

        const source = init_opts.file.layers.items(.source)[layer_index];

        if (source.getTexture() catch null) |tex| {
            dvui.renderTriangles(tris, tex) catch {
                dvui.log.err("Failed to render triangles", .{});
            };
        }
    }
}
