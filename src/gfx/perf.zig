//! Frame and drawing-session counters for tuning. For ground truth use macOS Instruments (Time Profiler).
//! Validating first-stroke warmup: compare DRAW line tex_new= and split_rb= before/after composite warmup;
//! after warmup, the first stroke should avoid extra tex_new and split rebuilds. Toggle verbose_frame_log
//! to log every frame while profiling.
const std = @import("std");
const builtin = @import("builtin");

/// Enable perf recording in Debug and ReleaseSafe builds.
pub const record: bool = builtin.mode == .Debug or builtin.mode == .ReleaseSafe;

/// Lightweight drawing-specific counters active in ALL build modes.
pub var draw_event_count: u32 = 0;
pub var draw_active_rect_area: u64 = 0;
pub var draw_temp_rect_area: u64 = 0;
pub var draw_stroke_buf_count: u64 = 0;
pub var draw_frame_active: bool = false;
pub var draw_render_layers_calls: u32 = 0;
pub var draw_split_rebuilds: u32 = 0;
pub var draw_full_composite_rebuilds: u32 = 0;
pub var draw_texture_creates: u32 = 0;
var draw_frame_start_ts: i128 = 0;
var draw_frames_total: u64 = 0;
var draw_time_sum_us: u64 = 0;

pub fn drawFrameBegin(active_drawing: bool) void {
    draw_event_count = 0;
    draw_active_rect_area = 0;
    draw_temp_rect_area = 0;
    draw_stroke_buf_count = 0;
    draw_render_layers_calls = 0;
    draw_split_rebuilds = 0;
    draw_full_composite_rebuilds = 0;
    draw_texture_creates = 0;
    draw_frame_active = active_drawing;
    if (active_drawing) {
        draw_frame_start_ts = std.time.nanoTimestamp();
    }
}

pub fn drawFrameEnd() void {
    if (!draw_frame_active) {
        if (draw_frames_total > 0) {
            const avg_us = if (draw_frames_total > 0) draw_time_sum_us / draw_frames_total else 0;
            std.debug.print("DRAW SESSION END: {d} frames, avg {d} us/frame\n", .{ draw_frames_total, avg_us });
            draw_frames_total = 0;
            draw_time_sum_us = 0;
        }
        return;
    }
    const elapsed_ns: u64 = @intCast(std.time.nanoTimestamp() - draw_frame_start_ts);
    const elapsed_us = elapsed_ns / 1000;
    draw_frames_total += 1;
    draw_time_sum_us += elapsed_us;

    if (draw_frames_total <= 5 or draw_frames_total % 30 == 0) {
        std.debug.print(
            "DRAW f{d}: {d}us events={d} active_rect={d}px temp_rect={d}px rl={d} split_rb={d} full_rb={d} tex_new={d}\n",
            .{ draw_frames_total, elapsed_us, draw_event_count, draw_active_rect_area, draw_temp_rect_area, draw_render_layers_calls, draw_split_rebuilds, draw_full_composite_rebuilds, draw_texture_creates },
        );
    }
}

pub var render_layers_ns: u64 = 0;
pub var render_layers_calls: u32 = 0;
pub var draw_layers_ns: u64 = 0;
pub var draw_layers_calls: u32 = 0;
pub var temp_memset_pixels: u64 = 0;
pub var temp_memset_calls: u32 = 0;
pub var sprite_preview_ns: u64 = 0;
pub var sprite_preview_calls: u32 = 0;
pub var visible_canvas_panes: u32 = 0;
pub var tick_total_ns: u64 = 0;
pub var sync_composite_ns: u64 = 0;
pub var sync_composite_calls: u32 = 0;
pub var tool_process_ns: u64 = 0;
pub var update_mask_ns: u64 = 0;
pub var process_events_ns: u64 = 0;

var tick_start_ts: i128 = 0;
var frame_index: u64 = 0;
const log_interval_frames: u64 = 120;

/// When true, `endFrameAndMaybeLog` prints every frame (very noisy; hurts fps). Default off.
pub var verbose_frame_log: bool = false;

/// Last split-composite rebuild: time spent in `renderLayersIntoTarget` for below / above (nanoseconds).
pub var split_composite_below_ns: u64 = 0;
pub var split_composite_above_ns: u64 = 0;

/// Enable `debugAgentLog` (writes NDJSON to a fixed path). Off by default.
pub const debug_agent_log: bool = false;

/// `warmupDrawingComposites` calls (session total) and duration of the last run (nanoseconds).
pub var composite_warmup_total: u64 = 0;
pub var composite_warmup_last_ns: u64 = 0;

pub fn beginFrame() void {
    if (!record) return;
    frame_index +%= 1;
    tick_start_ts = std.time.nanoTimestamp();
    render_layers_ns = 0;
    render_layers_calls = 0;
    draw_layers_ns = 0;
    draw_layers_calls = 0;
    temp_memset_pixels = 0;
    temp_memset_calls = 0;
    sprite_preview_ns = 0;
    sprite_preview_calls = 0;
    visible_canvas_panes = 0;
    tick_total_ns = 0;
    sync_composite_ns = 0;
    sync_composite_calls = 0;
    tool_process_ns = 0;
    update_mask_ns = 0;
    process_events_ns = 0;
}

pub fn endFrameAndMaybeLog() void {
    if (!record) return;

    const tick_end_ts = std.time.nanoTimestamp();
    tick_total_ns = @intCast(tick_end_ts - tick_start_ts);

    if (!verbose_frame_log and frame_index % log_interval_frames != 0) return;

    const rl_avg: u64 = if (render_layers_calls > 0) render_layers_ns / render_layers_calls else 0;
    const dl_avg: u64 = if (draw_layers_calls > 0) draw_layers_ns / draw_layers_calls else 0;
    const sc_avg: u64 = if (sync_composite_calls > 0) sync_composite_ns / sync_composite_calls else 0;

    std.log.info(
        \\perf frame ~{d}:
        \\  tick total: {d} us
        \\  renderLayers: {d} calls, {d} us total, {d} us/call
        \\  syncComposite: {d} calls, {d} us total, {d} us/call
        \\  drawLayers: {d} calls, {d} us total, {d} us/call
        \\  processEvents: {d} us
        \\  tool process: {d} us
        \\  mask update: {d} us
        \\  sprite preview: {d} calls, {d} us
        \\  temp memset: {d} calls, {d} pixels
        \\  visible canvas panes: {d}
        \\  split last rebuild only (not per-frame): below {d} us, above {d} us
        \\  composite warmup (session total calls, last run us): {d} / {d}
    , .{
        frame_index,
        tick_total_ns / 1000,
        render_layers_calls,
        render_layers_ns / 1000,
        rl_avg / 1000,
        sync_composite_calls,
        sync_composite_ns / 1000,
        sc_avg / 1000,
        draw_layers_calls,
        draw_layers_ns / 1000,
        dl_avg / 1000,
        process_events_ns / 1000,
        tool_process_ns / 1000,
        update_mask_ns / 1000,
        sprite_preview_calls,
        sprite_preview_ns / 1000,
        temp_memset_calls,
        temp_memset_pixels,
        visible_canvas_panes,
        split_composite_below_ns / 1000,
        split_composite_above_ns / 1000,
        composite_warmup_total,
        composite_warmup_last_ns / 1000,
    });
}

pub inline fn renderLayersBegin() i128 {
    if (!record) return 0;
    return std.time.nanoTimestamp();
}

pub inline fn renderLayersEnd(start: i128) void {
    if (!record) return;
    render_layers_ns +%= @intCast(std.time.nanoTimestamp() - start);
    render_layers_calls += 1;
}

pub inline fn drawLayersBegin() i128 {
    if (!record) return 0;
    return std.time.nanoTimestamp();
}

pub inline fn drawLayersEnd(start: i128) void {
    if (!record) return;
    draw_layers_ns +%= @intCast(std.time.nanoTimestamp() - start);
    draw_layers_calls += 1;
}

pub inline fn recordTempMemset(pixel_count: usize) void {
    if (!record) return;
    temp_memset_calls += 1;
    temp_memset_pixels +%= @intCast(pixel_count);
}

pub inline fn spritePreviewBegin() i128 {
    if (!record) return 0;
    return std.time.nanoTimestamp();
}

pub inline fn spritePreviewEnd(start: i128) void {
    if (!record) return;
    sprite_preview_ns +%= @intCast(std.time.nanoTimestamp() - start);
    sprite_preview_calls += 1;
}

pub inline fn canvasPaneDrawn() void {
    if (!record) return;
    visible_canvas_panes += 1;
}

pub inline fn syncCompositeBegin() i128 {
    if (!record) return 0;
    return std.time.nanoTimestamp();
}

pub inline fn syncCompositeEnd(start: i128) void {
    if (!record) return;
    sync_composite_ns +%= @intCast(std.time.nanoTimestamp() - start);
    sync_composite_calls += 1;
}

pub inline fn toolProcessBegin() i128 {
    if (!record) return 0;
    return std.time.nanoTimestamp();
}

pub inline fn toolProcessEnd(start: i128) void {
    if (!record) return;
    tool_process_ns +%= @intCast(std.time.nanoTimestamp() - start);
}

pub inline fn updateMaskBegin() i128 {
    if (!record) return 0;
    return std.time.nanoTimestamp();
}

pub inline fn updateMaskEnd(start: i128) void {
    if (!record) return;
    update_mask_ns +%= @intCast(std.time.nanoTimestamp() - start);
}

pub inline fn processEventsBegin() i128 {
    if (!record) return 0;
    return std.time.nanoTimestamp();
}

pub inline fn processEventsEnd(start: i128) void {
    if (!record) return;
    process_events_ns +%= @intCast(std.time.nanoTimestamp() - start);
}

pub fn debugAgentLog(msg: []const u8, d1: i64, d2: i64) void {
    if (!debug_agent_log) return;
    debugLog9b(msg, d1, d2);
}

// #region agent log
fn debugLog9b(msg: []const u8, d1: i64, d2: i64) void {
    const path = "/Users/foxnne/dev/proj/pixi/.cursor/debug-9b423f.log";
    var f = std.fs.cwd().openFile(path, .{ .mode = .read_write }) catch |e| blk: {
        if (e != error.FileNotFound) return;
        break :blk std.fs.cwd().createFile(path, .{ .read = true, .truncate = false }) catch return;
    };
    defer f.close();
    f.seekFromEnd(0) catch return;
    var buf: [512]u8 = undefined;
    var w = f.writer(&buf);
    w.interface.print("{{\"sessionId\":\"9b423f\",\"message\":\"{s}\",\"data\":{{\"v1\":{d},\"v2\":{d}}},\"timestamp\":{d}}}\n", .{ msg, d1, d2, std.time.milliTimestamp() }) catch return;
    w.end() catch return;
}
// #endregion
