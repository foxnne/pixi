const std = @import("std");
const builtin = @import("builtin");

const zip = @import("src/deps/zip/build.zig");

const dvui = @import("dvui");

const content_dir = "assets/";

const ProcessAssetsStep = @import("src/tools/process_assets.zig");

const update = @import("update.zig");
const GitDependency = update.GitDependency;
fn update_step(step: *std.Build.Step, _: std.Build.Step.MakeOptions) !void {
    const deps = &.{
        GitDependency{
            // zig_objc
            .url = "https://github.com/foxnne/zig-objc",
            .branch = "main",
        },
        GitDependency{
            // zigwin32 (kristoff-it fork has the zig 0.16 fix branch)
            .url = "https://github.com/kristoff-it/zigwin32",
            .branch = "fix/zig16",
        },
        GitDependency{
            // icons
            .url = "https://github.com/foxnne/zig-lib-icons",
            .branch = "dvui",
        },
        GitDependency{
            // dvui
            .url = "https://github.com/foxnne/dvui-dev",
            .branch = "main",
        },
        GitDependency{
            // assetpack
            .url = "https://github.com/foxnne/assetpack",
            .branch = "main",
        },
    };
    try update.update_dependency(step.owner.allocator, step.owner.graph.io, deps);
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const no_emit = b.option(bool, "no-emit", "Check for compile errors without emitting any code") orelse false;

    const step = b.step("update", "update git dependencies");
    step.makeFn = update_step;

    const zip_pkg = zip.package(b, .{});

    const accesskit = b.option(dvui.AccesskitOptions, "accesskit", "Enable accesskit") orelse .off;

    const dvui_dep = b.dependency("dvui", .{ .target = target, .optimize = optimize, .backend = .sdl3, .accesskit = accesskit });

    const zstbi_lib = b.addLibrary(.{
        .name = "zstbi",
        .root_module = b.addModule("zstbi", .{
            .target = target,
            .optimize = optimize,
            .root_source_file = .{ .cwd_relative = "src/deps/stbi/zstbi.zig" },
        }),
    });
    const zstbi_module = zstbi_lib.root_module;

    zstbi_module.addCSourceFile(.{ .file = std.Build.path(b, "src/deps/stbi/zstbi.c") });

    const msf_gif_lib = b.addLibrary(.{
        .name = "msf_gif",
        .root_module = b.addModule("msf_gif", .{
            .target = target,
            .optimize = optimize,
            .root_source_file = .{ .cwd_relative = "src/deps/msf_gif/msf_gif.zig" },
        }),
    });
    const msf_gif_module = msf_gif_lib.root_module;

    msf_gif_module.addCSourceFile(.{ .file = std.Build.path(b, "src/deps/msf_gif/msf_gif.c") });

    const exe = b.addExecutable(.{
        .name = "Pixi",
        .root_module = b.addModule("App", .{
            .target = target,
            .optimize = optimize,
            .root_source_file = .{ .cwd_relative = "src/App.zig" },
        }),
    });
    // Keep DWARF in the binary so Instruments / lldb show symbols (esp. when profiling Release).
    exe.root_module.strip = false;

    const assetpack = @import("assetpack");
    const assets_module = assetpack.pack(b, b.path("assets"), .{});
    exe.root_module.addImport("assets", assets_module);

    const known_folders = b.dependency("known_folders", .{
        .target = target,
        .optimize = optimize,
    }).module("known-folders");
    exe.root_module.addImport("known-folders", known_folders);

    // Generated atlas / asset stubs (`src/generated/*.zig`) are imported
    // unconditionally by `pixi.zig`, so the process-assets step has to
    // run before any target that touches pixi.zig — exe, integration
    // tests, etc.
    const assets_processing = try ProcessAssetsStep.init(b, "assets", "src/generated/");
    const process_assets_step = b.step("process-assets", "generates struct for all assets");
    process_assets_step.dependOn(&assets_processing.step);
    exe.step.dependOn(process_assets_step);

    if (no_emit) {
        b.getInstallStep().dependOn(&exe.step);
    } else {
        b.installArtifact(exe);

        if (optimize != .Debug) {
            switch (target.result.os.tag) {
                .windows => exe.subsystem = .Windows,
                else => exe.subsystem = .Posix,
            }
        }

        const run_cmd = b.addRunArtifact(exe);
        const run_step = b.step("run", "Run the example");

        const installArtifact = b.addInstallArtifact(exe, .{});
        run_cmd.step.dependOn(&installArtifact.step);
        run_step.dependOn(&run_cmd.step);
        b.getInstallStep().dependOn(&installArtifact.step);
    }

    exe.root_module.addImport("zstbi", zstbi_module);
    exe.root_module.addImport("msf_gif", msf_gif_module);
    exe.root_module.addImport("zip", zip_pkg.module);
    exe.root_module.addImport("dvui", dvui_dep.module("dvui_sdl3"));
    // Add backend module so we can use it directly
    exe.root_module.addImport("backend", dvui_dep.module("sdl3"));

    if (b.lazyDependency("icons", .{ .target = target, .optimize = optimize })) |dep| {
        exe.root_module.addImport("icons", dep.module("icons"));
    }

    if (target.result.os.tag == .macos) {
        if (b.lazyDependency("zig_objc", .{
            .target = target,
            .optimize = optimize,
        })) |dep| {
            exe.root_module.addImport("objc", dep.module("objc"));
        }
        // Custom NSVisualEffectView subclass that forwards right-click to the content view (SDL).
        exe.root_module.addCSourceFile(.{ .file = std.Build.path(b, "src/objc/PixiVisualEffectView.m") });
        // Target for macOS menu bar items (File menu); calls back into Zig via PixiNativeMenuAction.
        exe.root_module.addCSourceFile(.{ .file = std.Build.path(b, "src/objc/PixiMenuTarget.m") });
    } else if (target.result.os.tag == .windows) {
        if (b.lazyDependency("zigwin32", .{})) |dep| {
            exe.root_module.addImport("win32", dep.module("win32"));
        }
        exe.root_module.linkSystemLibrary("comctl32", .{});
    }

    exe.root_module.link_libcpp = true;
    zip.link(exe);

    // ---------------------------------------------------------------
    // Tests
    // ---------------------------------------------------------------
    //
    // Pixi has two test layers (see tests/README.md):
    //
    //   1. Unit tests — pure-logic only (math, palette parsing, layer
    //      order). The test root imports nothing but std + the pure
    //      modules under test, so it compiles in well under a second
    //      and never needs dvui/SDL/assets.
    //
    //   2. Integration tests (added in Phase 2 of the testing plan)
    //      will use dvui's testing backend and exercise real pixi
    //      drawing functions in a headless Window.
    //
    // Both share the same `zig build test` and `zig build check`
    // entry points.

    const test_filters = b.option(
        []const []const u8,
        "test-filter",
        "Skip tests that do not match any filter",
    ) orelse &[0][]const u8{};

    const tests_module = b.addModule("pixi-tests", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("tests/root.zig"),
    });

    // Wire each pure-logic source file as a named module on the test
    // target. Zig 0.15 disallows importing source files outside the test
    // module's own directory via relative paths, so we expose them by
    // name. Each of these files imports only `std`, so they remain free
    // of dvui / SDL / globals.
    inline for (.{
        .{ "pixi-direction", "src/math/direction.zig" },
        .{ "pixi-easing", "src/math/easing.zig" },
        .{ "pixi-layer-order", "src/internal/layer_order.zig" },
        .{ "pixi-palette-parse", "src/internal/palette_parse.zig" },
        .{ "pixi-layout-anchor", "src/math/layout_anchor.zig" },
    }) |entry| {
        tests_module.addAnonymousImport(entry[0], .{
            .root_source_file = b.path(entry[1]),
            .target = target,
            .optimize = optimize,
        });
    }

    const unit_tests = b.addTest(.{
        .name = "pixi-unit-tests",
        .root_module = tests_module,
        .filters = test_filters,
    });

    const test_step = b.step("test", "Run pixi tests");
    test_step.dependOn(&b.addRunArtifact(unit_tests).step);

    const check_step = b.step("check", "Compile pixi tests without running them");
    check_step.dependOn(&unit_tests.step);

    // ---------------------------------------------------------------
    // Layer 2: headless integration tests against dvui's testing
    // backend. Same `test` step runs them too.
    // ---------------------------------------------------------------
    //
    // We build the integration target with all the same module imports
    // as the production exe, but with a dvui dependency built against
    // `.backend = .testing`. dvui exposes that as a separate module
    // name (`dvui_testing` / `testing`), so the two dvui builds coexist
    // cleanly in the same `zig build` invocation.

    const dvui_testing_dep = b.dependency("dvui", .{
        .target = target,
        .optimize = optimize,
        .backend = .testing,
        .accesskit = accesskit,
    });

    // Build a module rooted at `src/pixi.zig` carrying all the same
    // imports the production exe carries. Because pixi.zig's transitive
    // imports (App.zig, Editor.zig, …) reference `dvui`, `assets`,
    // `known-folders`, etc. by name, those names must be wired here.
    // We point dvui at the *testing* backend so calling drawing
    // functions doesn't try to open a real OS window.
    const pixi_test_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/pixi.zig"),
    });
    pixi_test_module.addImport("dvui", dvui_testing_dep.module("dvui_testing"));
    pixi_test_module.addImport("backend", dvui_testing_dep.module("testing"));
    pixi_test_module.addImport("assets", assets_module);
    pixi_test_module.addImport("known-folders", known_folders);
    pixi_test_module.addImport("zstbi", zstbi_module);
    pixi_test_module.addImport("msf_gif", msf_gif_module);
    pixi_test_module.addImport("zip", zip_pkg.module);
    if (b.lazyDependency("icons", .{ .target = target, .optimize = optimize })) |dep| {
        pixi_test_module.addImport("icons", dep.module("icons"));
    }
    if (target.result.os.tag == .macos) {
        if (b.lazyDependency("zig_objc", .{ .target = target, .optimize = optimize })) |dep| {
            pixi_test_module.addImport("objc", dep.module("objc"));
        }
    } else if (target.result.os.tag == .windows) {
        if (b.lazyDependency("zigwin32", .{})) |dep| {
            pixi_test_module.addImport("win32", dep.module("win32"));
        }
    }

    const integration_module = b.addModule("pixi-integration-tests", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("tests/integration.zig"),
    });
    // The test root file lives in tests/ so it can't reach src/ via
    // relative imports under Zig 0.15's module-path rules. Expose pixi
    // (and dvui) by name instead.
    integration_module.addImport("pixi", pixi_test_module);
    integration_module.addImport("dvui", dvui_testing_dep.module("dvui_testing"));

    const integration_tests = b.addTest(.{
        .name = "pixi-integration-tests",
        .root_module = integration_module,
        .filters = test_filters,
    });

    if (target.result.os.tag == .windows) {
        integration_tests.root_module.linkSystemLibrary("comctl32", .{});
    }
    integration_tests.root_module.link_libcpp = true;
    zip.link(integration_tests);

    integration_tests.step.dependOn(process_assets_step);

    test_step.dependOn(&b.addRunArtifact(integration_tests).step);
    check_step.dependOn(&integration_tests.step);
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}

fn addImport(
    compile: *std.Build.Step.Compile,
    name: [:0]const u8,
    module: *std.Build.Module,
) void {
    compile.root_module.addImport(name, module);
}

fn addCGif(b: *std.Build, compile: *std.Build.Step.Compile) void {
    compile.addIncludePath(std.Build.path(b, "src/deps/cgif/inc"));
    compile.addCSourceFile(.{ .file = std.Build.path(b, "src/deps/cgif/cgif.c") });
    compile.addCSourceFile(.{ .file = std.Build.path(b, "src/deps/cgif/cgif_raw.c") });
}
