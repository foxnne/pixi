const std = @import("std");
const pixi = @import("../pixi.zig");
const dvui = @import("dvui");
const perf = pixi.perf;

/// Monotonic frame counter, incremented once per frame from Editor.tick.
pub var frame_index: u64 = 0;

pub const RenderFileOptions = struct {
    file: *pixi.Internal.File,
    rs: dvui.RectScale,
    color_mod: dvui.Color = .white,
    fade: f32 = 0.0,
    uv: dvui.Rect = .{ .w = 1.0, .h = 1.0 },
    corner_radius: dvui.Rect = .all(0),
    allow_peek: bool = true,
};

fn layerViewStateForRender(init_opts: RenderFileOptions) struct { min_layer_index: usize, needs_dimmed: bool } {
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
    const needs_dimmed = init_opts.allow_peek and init_opts.file.peek_layer_index != null;
    return .{ .min_layer_index = min_layer_index, .needs_dimmed = needs_dimmed };
}

/// Builds the same cached composites `renderLayers` would use (split when drawing, full when idle),
/// so callers (e.g. sprite preview reflection) can draw before `renderLayers` runs.
pub fn ensureLayerCompositesForPreview(init_opts: RenderFileOptions) !void {
    const vs = layerViewStateForRender(init_opts);
    if (splitCompositeEligible(init_opts, vs.min_layer_index, vs.needs_dimmed)) {
        try syncSplitComposite(init_opts.file);
    } else if (fullCompositeEligible(init_opts, vs.min_layer_index, vs.needs_dimmed)) {
        try syncLayerComposite(init_opts.file);
    }
}

/// Draws the layer stack for the sprite-panel reflection using the same composite paths as
/// `renderLayers` (1–3 draws) instead of N per-layer draws when possible.
pub fn renderReflectionLayerStack(
    init_opts: RenderFileOptions,
    reflection_tris: dvui.Triangles,
    reflection_tris_dimmed: dvui.Triangles,
) !void {
    const file = init_opts.file;
    const vs = layerViewStateForRender(init_opts);
    try ensureLayerCompositesForPreview(init_opts);

    if (file.peek_layer_index != null) {
        var layer_index: usize = file.layers.len;
        while (layer_index > vs.min_layer_index) {
            layer_index -= 1;
            if (!file.layers.items(.visible)[layer_index]) continue;
            var tris = reflection_tris;
            if (vs.needs_dimmed) {
                if (file.peek_layer_index) |peek_layer_index| {
                    if (peek_layer_index != layer_index) {
                        tris = reflection_tris_dimmed;
                    }
                }
            }
            dvui.renderTriangles(tris, file.layers.items(.source)[layer_index].getTexture() catch null) catch {
                dvui.log.err("Failed to render reflection layer", .{});
            };
        }
        return;
    }

    if (splitCompositeEligible(init_opts, vs.min_layer_index, vs.needs_dimmed)) {
        if (file.editor.split_composite_below) |ct| {
            if (dvui.Texture.fromTargetTemp(ct) catch null) |tex| {
                dvui.renderTriangles(reflection_tris, tex) catch {
                    dvui.log.err("Failed to render reflection below composite", .{});
                };
            }
        }
        const active_source = file.layers.items(.source)[file.selected_layer_index];
        if (file.layers.items(.visible)[file.selected_layer_index]) {
            if (active_source.getTexture() catch null) |tex| {
                dvui.renderTriangles(reflection_tris, tex) catch {
                    dvui.log.err("Failed to render reflection active layer", .{});
                };
            }
        }
        if (file.editor.split_composite_above) |ct| {
            if (dvui.Texture.fromTargetTemp(ct) catch null) |tex| {
                dvui.renderTriangles(reflection_tris, tex) catch {
                    dvui.log.err("Failed to render reflection above composite", .{});
                };
            }
        }
        return;
    }

    if (fullCompositeEligible(init_opts, vs.min_layer_index, vs.needs_dimmed)) {
        if (file.editor.layer_composite_target) |ct| {
            if (dvui.Texture.fromTargetTemp(ct) catch null) |ctex| {
                dvui.renderTriangles(reflection_tris, ctex) catch {
                    dvui.log.err("Failed to render reflection full composite", .{});
                };
                return;
            }
        }
    }

    var layer_index: usize = file.layers.len;
    while (layer_index > vs.min_layer_index) {
        layer_index -= 1;
        if (!file.layers.items(.visible)[layer_index]) continue;
        var tris = reflection_tris;
        if (vs.needs_dimmed) {
            if (file.peek_layer_index) |peek_layer_index| {
                if (peek_layer_index != layer_index) {
                    tris = reflection_tris_dimmed;
                }
            }
        }
        dvui.renderTriangles(tris, file.layers.items(.source)[layer_index].getTexture() catch null) catch {
            dvui.log.err("Failed to render reflection layer stack fallback", .{});
        };
    }
}

fn fullCompositeEligible(
    init_opts: RenderFileOptions,
    min_layer_index: usize,
    needs_dimmed: bool,
) bool {
    if (needs_dimmed) return false;
    if (min_layer_index != 0) return false;
    if (init_opts.fade != 0) return false;
    if (!std.meta.eql(init_opts.color_mod, dvui.Color.white)) return false;
    if (init_opts.file.editor.active_drawing) return false;
    const w = init_opts.file.width();
    const h = init_opts.file.height();
    if (w == 0 or h == 0) return false;
    return true;
}

fn splitCompositeEligible(
    init_opts: RenderFileOptions,
    min_layer_index: usize,
    needs_dimmed: bool,
) bool {
    if (!init_opts.file.editor.active_drawing) return false;
    if (needs_dimmed) return false;
    if (min_layer_index != 0) return false;
    if (init_opts.fade != 0) return false;
    if (!std.meta.eql(init_opts.color_mod, dvui.Color.white)) return false;
    const w = init_opts.file.width();
    const h = init_opts.file.height();
    if (w == 0 or h == 0) return false;
    return true;
}

/// Rebuilds the full-canvas flattened layer texture (all layers included).
/// Used when NOT actively drawing.
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

    perf.draw_full_composite_rebuilds += 1;

    const sc_t0 = perf.syncCompositeBegin();
    defer perf.syncCompositeEnd(sc_t0);

    const target = if (file.editor.layer_composite_target) |t| t else blk: {
        const nt = try dvui.textureCreateTarget(w, h, .nearest, .rgba_8_8_8_8);
        file.editor.layer_composite_target = nt;
        break :blk nt;
    };

    try renderLayersIntoTarget(file, target, 0, file.layers.len, null);
    file.editor.layer_composite_dirty = false;
}

/// Builds two split composites that exclude the active (selected) layer.
/// The "below" target flattens layers visually below (higher index), and
/// the "above" target flattens layers visually above (lower index).
/// Only rebuilt when the split layer changes or a structural change occurs.
fn syncSplitComposite(file: *pixi.Internal.File) !void {
    const w = file.width();
    const h = file.height();
    if (w == 0 or h == 0) return;

    if (file.editor.split_composite_frame_built == frame_index) return;
    file.editor.split_composite_frame_built = frame_index;

    // Prevent the full composite from also rebuilding this frame (e.g. from
    // the sprite panel reflection calling syncLayerComposite directly).
    file.editor.layer_composite_frame_built = frame_index;

    const active_idx = file.selected_layer_index;

    var needs_rebuild = file.editor.split_composite_dirty or
        file.editor.split_composite_layer == null or
        file.editor.split_composite_layer.? != active_idx;

    inline for (&[_]*?dvui.Texture.Target{
        &file.editor.split_composite_below,
        &file.editor.split_composite_above,
    }) |target_ptr| {
        if (target_ptr.*) |t| {
            if (t.width != w or t.height != h) {
                t.destroyLater();
                target_ptr.* = null;
                needs_rebuild = true;
            }
        } else {
            needs_rebuild = true;
        }
    }

    if (!needs_rebuild) {
        var i: usize = file.layers.len;
        while (i > 0) {
            i -= 1;
            if (i == active_idx) continue;
            if (!file.layers.items(.visible)[i]) continue;
            if (dvui.textureGetCached(file.layers.items(.source)[i].hash()) == null) {
                needs_rebuild = true;
                break;
            }
        }
    }

    if (!needs_rebuild) return;

    perf.draw_split_rebuilds += 1;

    const sc_t0 = perf.syncCompositeBegin();
    defer perf.syncCompositeEnd(sc_t0);

    const below = if (file.editor.split_composite_below) |t| t else blk: {
        const nt = try dvui.textureCreateTarget(w, h, .nearest, .rgba_8_8_8_8);
        file.editor.split_composite_below = nt;
        break :blk nt;
    };

    const above = if (file.editor.split_composite_above) |t| t else blk: {
        const nt = try dvui.textureCreateTarget(w, h, .nearest, .rgba_8_8_8_8);
        file.editor.split_composite_above = nt;
        break :blk nt;
    };

    const t_below = std.time.nanoTimestamp();
    try renderLayersIntoTarget(file, below, active_idx + 1, file.layers.len, null);
    if (perf.record) {
        perf.split_composite_below_ns = @intCast(std.time.nanoTimestamp() - t_below);
    }

    const t_above = std.time.nanoTimestamp();
    try renderLayersIntoTarget(file, above, 0, active_idx, null);
    if (perf.record) {
        perf.split_composite_above_ns = @intCast(std.time.nanoTimestamp() - t_above);
    }

    file.editor.split_composite_layer = active_idx;
    file.editor.split_composite_dirty = false;
}

/// Pre-builds split-composite GPU targets and touches temp/selection textures so the first
/// stroke does not pay allocation + flatten cost. Safe to call once after open or when
/// selecting a drawing tool; no-op if composites are already current.
pub fn warmupDrawingComposites(file: *pixi.Internal.File) !void {
    const w0 = std.time.nanoTimestamp();
    try syncSplitComposite(file);
    _ = file.editor.temporary_layer.source.getTexture() catch null;
    _ = file.editor.selection_layer.source.getTexture() catch null;
    perf.composite_warmup_last_ns = @intCast(std.time.nanoTimestamp() - w0);
    perf.composite_warmup_total +%= 1;
}

/// Renders a range of visible layers into a render target. Layers are drawn
/// from high index (visually bottom) to low index (visually top). An optional
/// `skip_index` excludes a single layer.
fn renderLayersIntoTarget(
    file: *pixi.Internal.File,
    target: dvui.Texture.Target,
    min_index: usize,
    max_index: usize,
    skip_index: ?usize,
) !void {
    const w = file.width();
    const h = file.height();
    const image_rect = dvui.Rect.Physical{
        .x = 0,
        .y = 0,
        .w = @floatFromInt(w),
        .h = @floatFromInt(h),
    };

    target.clear();
    const prev_target = dvui.renderTarget(.{ .texture = target, .offset = image_rect.topLeft() });
    defer _ = dvui.renderTarget(prev_target);

    const prev_clip = dvui.clipGet();
    defer dvui.clipSet(prev_clip);
    dvui.clipSet(image_rect);

    var path: dvui.Path.Builder = .init(pixi.app.allocator);
    defer path.deinit();
    path.addRect(image_rect, dvui.Rect.Physical.all(0));

    var tris = try path.build().fillConvexTriangles(pixi.app.allocator, .{ .color = .white, .fade = 0 });
    defer tris.deinit(pixi.app.allocator);
    tris.uvFromRectuv(image_rect, .{ .x = 0, .y = 0, .w = 1, .h = 1 });

    var i: usize = max_index;
    while (i > min_index) {
        i -= 1;
        if (skip_index) |skip| {
            if (i == skip) continue;
        }
        if (!file.layers.items(.visible)[i]) continue;
        const source = file.layers.items(.source)[i];
        if (source.getTexture() catch null) |tex| {
            dvui.renderTriangles(tris, tex) catch {
                dvui.log.err("Failed to render layer into composite target", .{});
            };
        }
    }
}

pub fn destroyLayerCompositeResources(file: *pixi.Internal.File) void {
    if (file.editor.layer_composite_target) |t| {
        t.destroyLater();
        file.editor.layer_composite_target = null;
    }
    file.editor.layer_composite_dirty = true;

    destroySplitCompositeResources(file);
}

pub fn destroySplitCompositeResources(file: *pixi.Internal.File) void {
    if (file.editor.split_composite_below) |t| {
        t.destroyLater();
        file.editor.split_composite_below = null;
    }
    if (file.editor.split_composite_above) |t| {
        t.destroyLater();
        file.editor.split_composite_above = null;
    }
    file.editor.split_composite_dirty = true;
    file.editor.split_composite_layer = null;
}

/// Renders visible layers of a file. Uses a cached composite texture when all
/// layers are drawn without peeking or dimming; falls back to per-layer draws
/// otherwise. During active drawing, uses split composites (below/above the
/// active layer) to avoid per-frame render target switches while still reducing
/// draw calls from N to 5.
pub fn renderLayers(init_opts: RenderFileOptions) !void {
    const t0 = perf.renderLayersBegin();
    defer perf.renderLayersEnd(t0);

    perf.draw_render_layers_calls += 1;

    const content_rs = init_opts.rs;

    if (content_rs.s == 0) return;
    if (dvui.clipGet().intersect(content_rs.r).empty()) return;

    if (init_opts.file.editor.active_layer_dirty_rect) |dirty| {
        if (dirty.w > 0 and dirty.h > 0) {
            perf.draw_active_rect_area += @intFromFloat(dirty.w * dirty.h);
            const source = init_opts.file.layers.items(.source)[init_opts.file.selected_layer_index];
            if (dvui.textureGetCached(source.hash())) |cached| {
                var tex = cached;
                tex.updateSubRect(
                    pixi.image.bytes(source).ptr,
                    @intFromFloat(dirty.x),
                    @intFromFloat(dirty.y),
                    @intFromFloat(dirty.w),
                    @intFromFloat(dirty.h),
                ) catch |err| {
                    dvui.log.err("Sub-rect texture upload failed: {any}", .{err});
                };
            }
        }
        init_opts.file.editor.active_layer_dirty_rect = null;
    }

    const vs = layerViewStateForRender(init_opts);
    const min_layer_index = vs.min_layer_index;
    const needs_dimmed = vs.needs_dimmed;

    var path: dvui.Path.Builder = .init(pixi.app.allocator);
    defer path.deinit();

    path.addRect(content_rs.r, init_opts.corner_radius.scale(content_rs.s, dvui.Rect.Physical));

    var triangles = try path.build().fillConvexTriangles(pixi.app.allocator, .{ .color = init_opts.color_mod, .fade = init_opts.fade });
    defer triangles.deinit(pixi.app.allocator);

    triangles.uvFromRectuv(content_rs.r, init_opts.uv);

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
        if (dvui.textureGetCached(init_opts.file.editor.selection_layer.source.hash()) == null)
            perf.draw_texture_creates += 1;
        dvui.renderTriangles(triangles, init_opts.file.editor.selection_layer.source.getTexture() catch null) catch {
            dvui.log.err("Failed to render selection layer", .{});
        };

        if (init_opts.file.editor.temp_layer_has_content or
            init_opts.file.editor.temp_gpu_dirty_rect != null)
        {
            const temp_source = init_opts.file.editor.temporary_layer.source;
            if (dvui.textureGetCached(temp_source.hash()) == null)
                perf.draw_texture_creates += 1;
            if (dvui.textureGetCached(temp_source.hash())) |cached| {
                if (init_opts.file.editor.temp_gpu_dirty_rect) |dirty| {
                    if (dirty.w > 0 and dirty.h > 0) {
                        perf.draw_temp_rect_area += @intFromFloat(dirty.w * dirty.h);
                        var tex = cached;
                        tex.updateSubRect(
                            pixi.image.bytes(temp_source).ptr,
                            @intFromFloat(dirty.x),
                            @intFromFloat(dirty.y),
                            @intFromFloat(dirty.w),
                            @intFromFloat(dirty.h),
                        ) catch |err| {
                            dvui.log.err("Temp sub-rect upload failed: {any}", .{err});
                        };
                    }
                    init_opts.file.editor.temp_gpu_dirty_rect = null;
                }
                if (init_opts.file.editor.temp_layer_has_content) {
                    dvui.renderTriangles(triangles, cached) catch {
                        dvui.log.err("Failed to render temporary layer", .{});
                    };
                }
            } else if (init_opts.file.editor.temp_layer_has_content) {
                dvui.renderTriangles(triangles, temp_source.getTexture() catch null) catch {
                    dvui.log.err("Failed to render temporary layer", .{});
                };
                init_opts.file.editor.temp_gpu_dirty_rect = null;
            }
        }

        if (init_opts.file.editor.transform) |*transform| {
            if (dvui.textureFromTarget(transform.target_texture) catch null) |tex| {
                dvui.renderTriangles(triangles, tex) catch {
                    dvui.log.err("Failed to render transform layer", .{});
                };
            }
        }
    }

    // During active drawing: use split composites (below + active + above = 3 draws)
    if (splitCompositeEligible(init_opts, min_layer_index, needs_dimmed)) {
        syncSplitComposite(init_opts.file) catch |err| {
            dvui.log.err("Split composite sync failed: {any}", .{err});
        };

        const has_below = init_opts.file.editor.split_composite_below != null;
        const has_above = init_opts.file.editor.split_composite_above != null;

        if (has_below or has_above) {
            if (dvui.textureGetCached(init_opts.file.layers.items(.source)[init_opts.file.selected_layer_index].hash()) == null)
                perf.draw_texture_creates += 1;
            if (has_below) {
                if (dvui.Texture.fromTargetTemp(init_opts.file.editor.split_composite_below.?) catch null) |tex| {
                    dvui.renderTriangles(triangles, tex) catch {
                        dvui.log.err("Failed to render below composite", .{});
                    };
                }
            }

            const active_source = init_opts.file.layers.items(.source)[init_opts.file.selected_layer_index];
            if (init_opts.file.layers.items(.visible)[init_opts.file.selected_layer_index]) {
                if (active_source.getTexture() catch null) |tex| {
                    dvui.renderTriangles(triangles, tex) catch {
                        dvui.log.err("Failed to render active layer", .{});
                    };
                }
            }

            if (has_above) {
                if (dvui.Texture.fromTargetTemp(init_opts.file.editor.split_composite_above.?) catch null) |tex| {
                    dvui.renderTriangles(triangles, tex) catch {
                        dvui.log.err("Failed to render above composite", .{});
                    };
                }
            }

            return;
        }
    }

    // When idle: use full composite (all layers = 1 draw)
    if (fullCompositeEligible(init_opts, min_layer_index, needs_dimmed)) {
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

    // Fallback: per-layer rendering
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
