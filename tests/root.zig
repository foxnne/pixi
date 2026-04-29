//! Aggregator for `zig build test`.
//!
//! The Zig test runner discovers `test "..."` blocks reachable from this
//! file at compile time. We deliberately import only modules that are
//! pure logic — no dvui, no SDL, no globals — so the unit-test target
//! compiles fast and never needs a window or GPU.
//!
//! Each module is exposed as a named import in `build.zig` rather than
//! a relative path, because Zig 0.15 modules cannot import source files
//! outside their own directory via `../`.
//!
//! Heavier integration tests (Phase 2 of the testing plan) live in a
//! separate test target wired through dvui's testing backend.

comptime {
    // Phase 1: pure-logic unit tests.
    _ = @import("pixi-direction");
    _ = @import("pixi-easing");
    _ = @import("pixi-layer-order");
    _ = @import("pixi-palette-parse");
    _ = @import("pixi-layout-anchor");
}
