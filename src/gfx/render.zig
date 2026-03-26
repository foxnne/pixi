const std = @import("std");
const pixi = @import("../pixi.zig");
const dvui = @import("dvui");
const perf = pixi.perf;

/// Monotonic frame counter, incremented once per frame from Editor.tick.
pub var frame_index: u64 = 0;

const RenderFileOptions = struct {
    file: *pixi.Internal.File,
    rs: dvui.RectScale,
    color_mod: dvui.Color = .white,
    fade: f32 = 0.0,
    uv: dvui.Rect = .{ .w = 1.0, .h = 1.0 },
    corner_radius: dvui.Rect = .all(0),
    allow_peek: bool = true,
};

fn layerCompositeDrawEligible(
    init_opts: RenderFileOptions,
    min_layer_index: usize,
    needs_dimmed: bool,
) bool {
    if (needs_dimmed) return false;
    if (min_layer_index != 0) return false;
    if (init_opts.fade != 0) return false;
    if (!std.meta.eql(init_opts.color_mod, dvui.Color.white)) return false;
    const w = init_opts.file.width();
    const h = init_opts.file.height();
    if (w == 0 or h == 0) return false;
    return true;
}

/// Rebuilds the full-canvas flattened layer texture when content or structure
/// has actually changed, and at most once per frame. The target is kept alive
/// across frames to avoid recreating render targets every frame.
pub fn syncLayerComposite(file: *pixi.Internal.File) !void {
    const w = file.width();
    const h = file.height();
    if (w == 0 or h == 0) return;

    if (file.editor.layer_composite_frame_built == frame_index) return;
    file.editor.layer_composite_frame_built = frame_index;

    if (file.editor.layer_composite_target) |t| {
        if (t.width != w or t.height != h) {
            t.destroyLater();
            file.editor.layer_composite_target = null;
        }
    }

    var needs_rebuild = file.editor.layer_composite_target == null or file.editor.layer_composite_dirty;

    if (!needs_rebuild) {
        var i: usize = file.layers.len;
        while (i > 0) {
            i -= 1;
            if (!file.layers.items(.visible)[i]) continue;
            if (dvui.textureGetCached(file.layers.items(.source)[i].hash()) == null) {
                needs_rebuild = true;
                break;
            }
        }
    }

    if (!needs_rebuild) return;

    const sc_t0 = perf.syncCompositeBegin();
    defer perf.syncCompositeEnd(sc_t0);

    const target = if (file.editor.layer_composite_target) |t| t else blk: {
        const nt = try dvui.textureCreateTarget(w, h, .nearest, .rgba_8_8_8_8);
        file.editor.layer_composite_target = nt;
        break :blk nt;
    };

    const image_rect_physical = dvui.Rect.Physical{
        .x = 0,
        .y = 0,
        .w = @floatFromInt(w),
        .h = @floatFromInt(h),
    };

    target.clear();
    const previous_target = dvui.renderTarget(.{ .texture = target, .offset = image_rect_physical.topLeft() });
    defer _ = dvui.renderTarget(previous_target);

    const prev_clip = dvui.clipGet();
    defer dvui.clipSet(prev_clip);
    dvui.clipSet(image_rect_physical);

    var path: dvui.Path.Builder = .init(pixi.app.allocator);
    defer path.deinit();
    path.addRect(image_rect_physical, dvui.Rect.Physical.all(0));

    var flat_tris = try path.build().fillConvexTriangles(pixi.app.allocator, .{ .color = .white, .fade = 0 });
    defer flat_tris.deinit(pixi.app.allocator);
    flat_tris.uvFromRectuv(image_rect_physical, .{ .x = 0, .y = 0, .w = 1, .h = 1 });

    var layer_index: usize = file.layers.len;
    while (layer_index > 0) {
        layer_index -= 1;
        if (!file.layers.items(.visible)[layer_index]) continue;
        const source = file.layers.items(.source)[layer_index];
        if (source.getTexture() catch null) |tex| {
            dvui.renderTriangles(flat_tris, tex) catch {
                dvui.log.err("Failed to render triangles into layer composite", .{});
            };
        }
    }

    file.editor.layer_composite_dirty = false;
}

pub fn destroyLayerCompositeResources(file: *pixi.Internal.File) void {
    if (file.editor.layer_composite_target) |t| {
        t.destroyLater();
        file.editor.layer_composite_target = null;
    }
    file.editor.layer_composite_dirty = true;
}

/// Renders all visible layers of a file if the file is not isolated.
/// Will peek layers if the peek layer index is set, and draw other layers as dimmed.
/// Pass a valid uv if you want to draw a specific sprite of the file.
pub fn renderLayers(init_opts: RenderFileOptions) !void {
    const t0 = perf.renderLayersBegin();
    defer perf.renderLayersEnd(t0);

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

    const needs_dimmed = init_opts.allow_peek and init_opts.file.peek_layer_index != null;
    var dimmed_triangles: ?dvui.Triangles = null;
    defer {
        if (dimmed_triangles) |*dt| dt.deinit(pixi.app.allocator);
    }
    if (needs_dimmed) {
        var dt = try triangles.dupe(pixi.app.allocator);
        dt.color(.gray);
        dimmed_triangles = dt;
    }

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

    const use_composite = layerCompositeDrawEligible(init_opts, min_layer_index, needs_dimmed);
    if (use_composite) {
        syncLayerComposite(init_opts.file) catch |err| {
            dvui.log.err("Layer composite sync failed: {any}", .{err});
        };
        if (init_opts.file.editor.layer_composite_target) |ct| {
            if (dvui.Texture.fromTargetTemp(ct) catch null) |ctex| {
                dvui.renderTriangles(triangles, ctex) catch {
                    dvui.log.err("Failed to render layer composite", .{});
                };
                return;
            }
        }
    }

    var layer_index: usize = init_opts.file.layers.len;
    while (layer_index > min_layer_index) {
        layer_index -= 1;

        const visible = init_opts.file.layers.items(.visible)[layer_index];
        if (!visible) continue;

        var tris = triangles;

        if (needs_dimmed) {
            if (init_opts.file.peek_layer_index) |peek_layer_index| {
                if (peek_layer_index != layer_index) {
                    tris = dimmed_triangles.?;
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
