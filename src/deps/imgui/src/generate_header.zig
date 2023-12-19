// THIS FILE HAS BEEN AUTO-GENERATED USING THE 'DEAR BINDINGS' GENERATOR METADATA.
// **DO NOT EDIT DIRECTLY**
// https://github.com/dearimgui/dear_bindings

// Help:
// - Read FAQ at http://dearimgui.com/faq
// - Newcomers, read 'Programmer guide' in imgui.cpp for notes on how to setup Dear ImGui in your codebase.
// - Call and read ImGui::ShowDemoWindow() in imgui_demo.cpp. All applications in examples/ are doing that.
// Read imgui.cpp for details, links and comments.

// Resources:
// - FAQ                   http://dearimgui.com/faq
// - Homepage              https://github.com/ocornut/imgui
// - Releases & changelog  https://github.com/ocornut/imgui/releases
// - Gallery               https://github.com/ocornut/imgui/issues/6478 (please post your screenshots/video there!)
// - Wiki                  https://github.com/ocornut/imgui/wiki (lots of good stuff there)
// - Getting Started       https://github.com/ocornut/imgui/wiki/Getting-Started
// - Glossary              https://github.com/ocornut/imgui/wiki/Glossary
// - Issues & support      https://github.com/ocornut/imgui/issues
// - Tests & Automation    https://github.com/ocornut/imgui_test_engine

// Getting Started?
// - Read https://github.com/ocornut/imgui/wiki/Getting-Started
// - For first-time users having issues compiling/linking/running/loading fonts:
//   please post in https://github.com/ocornut/imgui/discussions if you cannot find a solution in resources above.

// zig fmt: off
const std = @import("std");
const c = @cImport({
    @cInclude("stdarg.h");
});
pub const backends = struct {
    pub const mach = @import("imgui_mach.zig");
};
