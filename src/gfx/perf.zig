const std = @import("std");
const builtin = @import("builtin");

/// Enable perf recording in Debug and ReleaseSafe builds.
pub const record: bool = builtin.mode == .Debug or builtin.mode == .ReleaseSafe;

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

    if (frame_index % log_interval_frames != 0) return;

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
