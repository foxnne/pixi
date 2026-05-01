//! Aggregator for `zig build test`.
//!
//! The Zig test runner discovers `test "..."` blocks reachable from this
//! file at compile time. We deliberately import only modules that are
//! pure logic — no dvui, no SDL, no globals — so the unit-test target
//! compiles fast and never needs a window or GPU.

comptime {
    // Phase 1: pure-logic unit tests.
    _ = @import("pixi-direction");
    _ = @import("pixi-easing");
    _ = @import("pixi-layer-order");
    _ = @import("pixi-palette-parse");
    _ = @import("pixi-layout-anchor");
    _ = @import("pixi-reduce");
    _ = @import("pixi-grid-validate");
    _ = @import("pixi-animation");
}
