const pixi = @import("../pixi.zig");
const dvui = @import("dvui");

const RenderFileOptions = struct {
    file: *pixi.Internal.File,
    rs: dvui.RectScale,
    color_mod: dvui.Color = .white,
    fade: f32 = 0.0,
    uv: dvui.Rect = .{ .w = 1.0, .h = 1.0 },
    corner_radius: dvui.Rect = .all(0),
};

/// Renders all visible layers of a file if the file is not isolated
/// Will peek layers if the peek layer index is set, and draw other layers as dimmed
/// Pass a valid uv if you want to draw a specific sprite of the file
pub fn renderLayers(init_opts: RenderFileOptions) !void {
    const cw = dvui.currentWindow();
    var content_rs = init_opts.rs;

    if (content_rs.s == 0) return;
    if (dvui.clipGet().intersect(content_rs.r).empty()) return;

    if (cw.snap_to_pixels) {
        content_rs.r.x = @round(content_rs.r.x);
        content_rs.r.y = @round(content_rs.r.y);
    }

    var min_layer_index: usize = 0;
    if (init_opts.file.editor.isolate_layer) {
        if (init_opts.file.peek_layer_index) |peek_layer_index| {
            min_layer_index = peek_layer_index;
        } else if (!pixi.editor.explorer.tools.layersHovered()) {
            min_layer_index = init_opts.file.selected_layer_index;
        }
    }

    var path: dvui.Path.Builder = .init(dvui.currentWindow().lifo());
    defer path.deinit();

    path.addRect(content_rs.r, init_opts.corner_radius.scale(content_rs.s, dvui.Rect.Physical));

    var triangles = try path.build().fillConvexTriangles(cw.lifo(), .{ .color = init_opts.color_mod.opacity(cw.alpha), .fade = init_opts.fade });
    defer triangles.deinit(cw.lifo());

    triangles.uvFromRectuv(content_rs.r, init_opts.uv);
    triangles.rotate(content_rs.r.center(), 0.0);

    var dimmed_triangles = try triangles.dupe(cw.lifo());
    defer dimmed_triangles.deinit(cw.lifo());
    dimmed_triangles.color(.gray);

    defer {
        dvui.renderTriangles(triangles, init_opts.file.editor.selection_layer.source.getTexture() catch null) catch {
            dvui.log.err("Failed to render selection layer", .{});
        };
        dvui.renderTriangles(triangles, init_opts.file.editor.temporary_layer.source.getTexture() catch null) catch {
            dvui.log.err("Failed to render temporary layer", .{});
        };
    }

    var layer_index: usize = init_opts.file.layers.len;
    while (layer_index > min_layer_index) {
        layer_index -= 1;

        const visible = init_opts.file.layers.items(.visible)[layer_index];
        if (!visible) continue;

        var tris = triangles;
        if (init_opts.file.peek_layer_index) |peek_layer_index| {
            if (peek_layer_index != layer_index) {
                tris = dimmed_triangles;
            }
        }

        const source = init_opts.file.layers.items(.source)[layer_index];

        if (source.getTexture() catch null) |tex| {
            if (!cw.render_target.rendering) {
                cw.addRenderCommand(.{ .texture = .{ .tex = tex, .rs = content_rs, .opts = .{
                    .colormod = init_opts.color_mod,
                    .fade = init_opts.fade,
                } } }, false);
                return;
            }

            try dvui.renderTriangles(tris, tex);
        }
    }
}
