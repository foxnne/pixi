//! Layer 2 (headless integration) test target.
//!
//! These tests run real pixi drawing functions against a *headless*
//! `dvui.Window` provided by dvui's testing backend. The shim in
//! `pixi_shim.zig` brings up just enough of `pixi.app` / `pixi.editor`
//! for the code paths exercised here to read the globals they need
//! without booting the full editor (no assets, no themes, no SDL).
//!
//! See `tests/README.md` for the overall layering.

const std = @import("std");
const dvui = @import("dvui");
const pixi = @import("pixi");
const shim = @import("pixi_shim.zig");

const Internal = pixi.Internal;

/// Create a small in-memory `Internal.File` suitable for tests. The
/// caller must already have a live shim context (so `pixi.app` /
/// `pixi.editor` / `dvui.currentWindow()` are valid). The returned
/// file must be torn down with `deinitFile` (not `file.deinit()`).
fn makeBlankFile(width_: u32, height_: u32) !Internal.File {
    return Internal.File.init("untitled-test", .{
        .columns = 1,
        .rows = 1,
        .column_width = width_,
        .row_height = height_,
    });
}

/// Tear down a file constructed with `makeBlankFile`. `Internal.File.deinit`
/// is leak-tolerant in production (the editor's higher-level close
/// paths free the rest via routes we don't take here): specifically
/// it does NOT release per-layer `mask` bit-sets and pixel buffers
/// for entries in `file.layers`, nor `editor.selected_sprites`,
/// `editor.checkerboard`, `editor.checkerboard_tile`. Note also that
/// `Internal.File.deinit` already frees each layer's `name`, so
/// calling `layer.deinit()` here would double-free it. We free the
/// leaked-in-tests pieces by hand.
fn deinitFile(file: *Internal.File) void {
    var i: usize = 0;
    while (i < file.layers.len) : (i += 1) {
        var layer = file.layers.get(i);
        switch (layer.source) {
            .imageFile => |image| pixi.app.allocator.free(image.bytes),
            .pixels => |p| pixi.app.allocator.free(p.rgba),
            .pixelsPMA => |p| pixi.app.allocator.free(p.rgba),
            .texture => |t| dvui.textureDestroyLater(t),
        }
        layer.mask.deinit();
    }
    file.editor.selected_sprites.deinit();
    file.editor.checkerboard.deinit();
    pixi.app.allocator.free(file.editor.checkerboard_tile.pixelsPMA.rgba);
    file.deinit();
}

test "shim brings up a dvui.testing window with usable pixi globals" {
    var ctx = try shim.init(std.testing.allocator);
    defer ctx.deinit(std.testing.allocator);

    const arena = dvui.currentWindow().arena();
    const buf = try arena.alloc(u8, 16);
    @memset(buf, 0);

    try std.testing.expect(pixi.app == ctx.app);
    try std.testing.expect(pixi.editor == ctx.editor);
}

test "Internal.File.init constructs a usable blank file" {
    var ctx = try shim.init(std.testing.allocator);
    defer ctx.deinit(std.testing.allocator);

    var file = try makeBlankFile(8, 8);
    defer deinitFile(&file);

    try std.testing.expectEqual(@as(u32, 8), file.width());
    try std.testing.expectEqual(@as(u32, 8), file.height());
    try std.testing.expectEqual(@as(usize, 1), file.layers.len);
    try std.testing.expectEqual(@as(usize, 0), file.selected_layer_index);
}

// -------------------------------------------------------------------
// Regression: bug #131 — fill tool followed by selection-mask tools
// did not show the alternating selection pattern until deselect+select
// because `Internal.File.fillPoint` modifies layer pixels but
// `ImageSource.hash()` is pointer-based, so
// `FileWidget.updateActiveLayerMask` saw a still-warm cache and
// skipped rebuilding the mask.
//
// The fix is `file.invalidateActiveLayerTransparencyMaskCache()` at
// the end of `fillPoint` for the selected layer. This test pins that
// behavior so we don't regress.
// -------------------------------------------------------------------
test "fillPoint invalidates active layer mask cache (regression #131)" {
    var ctx = try shim.init(std.testing.allocator);
    defer ctx.deinit(std.testing.allocator);

    var file = try makeBlankFile(8, 8);
    defer deinitFile(&file);

    // Pretend the mask cache was warmed by a prior frame.
    file.editor.mask_built_for_layer = file.selected_layer_index;
    file.editor.mask_built_source_hash = 0xdeadbeef;

    // Bucket fill at (1, 1) with red.
    file.fillPoint(.{ .x = 1, .y = 1 }, .selected, .{
        .color = .{ .r = 255, .g = 0, .b = 0, .a = 255 },
        .invalidate = false,
        .to_change = false,
    });

    try std.testing.expectEqual(@as(?usize, null), file.editor.mask_built_for_layer);
}

// -------------------------------------------------------------------
// `selectColorFloodFromPoint`: scanline-flood fills the selection mask
// for every pixel reachable through orthogonal neighbours that share
// the seed pixel's exact color, and stops at color boundaries. We
// arrange a 4x4 layer with two solid color regions split down the
// middle:
//
//   A A B B
//   A A B B
//   A A B B
//   A A B B
//
// then assert that flooding from inside the A region selects the 8 A
// pixels and nothing else, and similarly for B.
// -------------------------------------------------------------------
test "selectColorFloodFromPoint covers a connected region and stops at color boundaries" {
    var ctx = try shim.init(std.testing.allocator);
    defer ctx.deinit(std.testing.allocator);

    var file = try makeBlankFile(4, 4);
    defer deinitFile(&file);

    // Paint the two regions directly into the active layer's pixel
    // buffer. (Bypass `drawPoint` to keep the test focused on flood
    // semantics.)
    const layer_a = file.layers.get(file.selected_layer_index);
    const px = layer_a.pixels();
    const color_a: [4]u8 = .{ 200, 0, 0, 255 };
    const color_b: [4]u8 = .{ 0, 0, 200, 255 };
    var y: usize = 0;
    while (y < 4) : (y += 1) {
        var x: usize = 0;
        while (x < 4) : (x += 1) {
            px[y * 4 + x] = if (x < 2) color_a else color_b;
        }
    }

    // Flood A from (0, 0) and count selected bits.
    try file.selectColorFloodFromPoint(.{ .x = 0, .y = 0 }, true);

    var selected: usize = 0;
    var i: usize = 0;
    while (i < 16) : (i += 1) {
        if (file.editor.selection_layer.mask.isSet(i)) selected += 1;
    }
    try std.testing.expectEqual(@as(usize, 8), selected);

    // Sanity-check that the selected indices are exactly the A column.
    i = 0;
    while (i < 16) : (i += 1) {
        const x = i % 4;
        const expected = x < 2;
        try std.testing.expectEqual(expected, file.editor.selection_layer.mask.isSet(i));
    }

    // Flooding from a B pixel with `value = false` is a no-op on A
    // bits. Toggle the test: clear the mask, flood B, verify only B
    // bits are set.
    file.editor.selection_layer.clearMask();
    try file.selectColorFloodFromPoint(.{ .x = 3, .y = 3 }, true);
    selected = 0;
    i = 0;
    while (i < 16) : (i += 1) {
        if (file.editor.selection_layer.mask.isSet(i)) selected += 1;
    }
    try std.testing.expectEqual(@as(usize, 8), selected);
    i = 0;
    while (i < 16) : (i += 1) {
        const x = i % 4;
        const expected = x >= 2;
        try std.testing.expectEqual(expected, file.editor.selection_layer.mask.isSet(i));
    }
}

test "selectColorFloodFromPoint out-of-bounds is a no-op" {
    var ctx = try shim.init(std.testing.allocator);
    defer ctx.deinit(std.testing.allocator);

    var file = try makeBlankFile(4, 4);
    defer deinitFile(&file);

    try file.selectColorFloodFromPoint(.{ .x = -1, .y = 0 }, true);
    try file.selectColorFloodFromPoint(.{ .x = 0, .y = 4 }, true);

    var i: usize = 0;
    while (i < 16) : (i += 1) {
        try std.testing.expect(!file.editor.selection_layer.mask.isSet(i));
    }
}

// -------------------------------------------------------------------
// `.pixi` JSON parser fallbacks. The on-disk format has been bumped
// three times. `fromPathPixi` first tries the current `pixi.File`
// shape and, on failure, retries against `FileV3`, `FileV2`, and
// `FileV1`. This test exercises just the JSON layer (no zip, no
// `Internal.File` materialization) by parsing a small in-memory
// fixture for each version. It catches the kind of bug where someone
// renames or retypes a field on the public `pixi.File` types and
// silently breaks loading older saves.
// -------------------------------------------------------------------
test "pixi.File parses current-format JSON and round-trips" {
    const json =
        \\{
        \\  "version": { "major": 1, "minor": 0, "patch": 0, "pre": null, "build": null },
        \\  "columns": 2,
        \\  "rows": 1,
        \\  "column_width": 8,
        \\  "row_height": 8,
        \\  "layers": [{ "name": "Layer", "visible": true, "collapse": false }],
        \\  "sprites": [
        \\    { "origin": [0.0, 0.0] },
        \\    { "origin": [0.0, 0.0] }
        \\  ],
        \\  "animations": [
        \\    { "name": "idle", "frames": [{ "sprite_index": 0, "ms": 100 }] }
        \\  ]
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        pixi.File,
        std.testing.allocator,
        json,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    try std.testing.expectEqual(@as(u32, 2), parsed.value.columns);
    try std.testing.expectEqual(@as(u32, 1), parsed.value.rows);
    try std.testing.expectEqual(@as(usize, 1), parsed.value.layers.len);
    try std.testing.expectEqualStrings("Layer", parsed.value.layers[0].name);
    try std.testing.expectEqual(@as(usize, 2), parsed.value.sprites.len);
    try std.testing.expectEqual(@as(usize, 1), parsed.value.animations.len);
    try std.testing.expectEqualStrings("idle", parsed.value.animations[0].name);
    try std.testing.expectEqual(@as(usize, 1), parsed.value.animations[0].frames.len);
    try std.testing.expectEqual(@as(u32, 100), parsed.value.animations[0].frames[0].ms);

    // Re-serialize and re-parse — the second parse must equal the
    // first along every observable axis. This is the round-trip
    // guarantee that protects against asymmetric (de)serialization.
    const round_tripped = try std.json.Stringify.valueAlloc(std.testing.allocator, parsed.value, .{});
    defer std.testing.allocator.free(round_tripped);

    const reparsed = try std.json.parseFromSlice(
        pixi.File,
        std.testing.allocator,
        round_tripped,
        .{ .ignore_unknown_fields = true },
    );
    defer reparsed.deinit();

    try std.testing.expectEqual(parsed.value.columns, reparsed.value.columns);
    try std.testing.expectEqual(parsed.value.rows, reparsed.value.rows);
    try std.testing.expectEqual(parsed.value.column_width, reparsed.value.column_width);
    try std.testing.expectEqual(parsed.value.row_height, reparsed.value.row_height);
    try std.testing.expectEqual(parsed.value.layers.len, reparsed.value.layers.len);
    try std.testing.expectEqualStrings(parsed.value.layers[0].name, reparsed.value.layers[0].name);
    try std.testing.expectEqual(parsed.value.animations[0].frames[0].sprite_index, reparsed.value.animations[0].frames[0].sprite_index);
    try std.testing.expectEqual(parsed.value.animations[0].frames[0].ms, reparsed.value.animations[0].frames[0].ms);
}

test "pixi.File.FileV3 fixture parses" {
    // V3 keeps the columns/rows shape but uses the older `AnimationV2`
    // (frame indices + fps) form.
    const json =
        \\{
        \\  "version": { "major": 0, "minor": 7, "patch": 0, "pre": null, "build": null },
        \\  "columns": 2,
        \\  "rows": 1,
        \\  "column_width": 8,
        \\  "row_height": 8,
        \\  "layers": [{ "name": "Layer", "visible": true, "collapse": false }],
        \\  "sprites": [
        \\    { "origin": [0.0, 0.0] },
        \\    { "origin": [0.0, 0.0] }
        \\  ],
        \\  "animations": [{ "name": "idle", "frames": [0, 1], "fps": 10.0 }]
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        pixi.File.FileV3,
        std.testing.allocator,
        json,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    try std.testing.expectEqual(@as(u32, 2), parsed.value.columns);
    try std.testing.expectEqual(@as(usize, 2), parsed.value.animations[0].frames.len);
    try std.testing.expectEqual(@as(f32, 10.0), parsed.value.animations[0].fps);
}

test "pixi.File.FileV2 fixture parses (width/height + tile_size shape)" {
    const json =
        \\{
        \\  "version": { "major": 0, "minor": 5, "patch": 0, "pre": null, "build": null },
        \\  "width": 16,
        \\  "height": 8,
        \\  "tile_width": 8,
        \\  "tile_height": 8,
        \\  "layers": [{ "name": "Layer", "visible": true, "collapse": false }],
        \\  "sprites": [
        \\    { "origin": [0.0, 0.0] },
        \\    { "origin": [0.0, 0.0] }
        \\  ],
        \\  "animations": [{ "name": "idle", "frames": [0, 1], "fps": 12.0 }]
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        pixi.File.FileV2,
        std.testing.allocator,
        json,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    try std.testing.expectEqual(@as(u32, 16), parsed.value.width);
    try std.testing.expectEqual(@as(u32, 8), parsed.value.tile_width);
}

test "pixi.File.FileV1 fixture parses (start/length animation shape)" {
    const json =
        \\{
        \\  "version": { "major": 0, "minor": 1, "patch": 0, "pre": null, "build": null },
        \\  "width": 16,
        \\  "height": 8,
        \\  "tile_width": 8,
        \\  "tile_height": 8,
        \\  "layers": [{ "name": "Layer", "visible": true, "collapse": false }],
        \\  "sprites": [
        \\    { "origin": [0.0, 0.0] },
        \\    { "origin": [0.0, 0.0] }
        \\  ],
        \\  "animations": [{ "name": "idle", "start": 0, "length": 2, "fps": 8.0 }]
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        pixi.File.FileV1,
        std.testing.allocator,
        json,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 0), parsed.value.animations[0].start);
    try std.testing.expectEqual(@as(usize, 2), parsed.value.animations[0].length);
    try std.testing.expectEqual(@as(f32, 8.0), parsed.value.animations[0].fps);
}

test "fillPoint on temporary layer leaves selected-layer mask cache alone" {
    var ctx = try shim.init(std.testing.allocator);
    defer ctx.deinit(std.testing.allocator);

    var file = try makeBlankFile(8, 8);
    defer deinitFile(&file);

    file.editor.mask_built_for_layer = file.selected_layer_index;

    // Drawing on the temporary layer never touches the selected
    // layer's pixels and so must NOT invalidate the cache.
    file.fillPoint(.{ .x = 1, .y = 1 }, .temporary, .{
        .color = .{ .r = 0, .g = 255, .b = 0, .a = 255 },
        .invalidate = false,
        .to_change = false,
    });

    try std.testing.expectEqual(
        @as(?usize, file.selected_layer_index),
        file.editor.mask_built_for_layer,
    );
}
