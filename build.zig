const std = @import("std");
const builtin = @import("builtin");

const zmath = @import("src/deps/zig-gamedev/zmath/build.zig");
const zstbi = @import("src/deps/zig-gamedev/zstbi/build.zig");
const zgui = @import("src/deps/zig-gamedev/zgui/build.zig");

const mach_core = @import("mach_core");
const mach_gpu_dawn = @import("mach_gpu_dawn");

const nfd = @import("src/deps/nfd-zig/build.zig");
const zip = @import("src/deps/zip/build.zig");

const content_dir = "assets/";
const src_path = "src/pixi.zig";

const ProcessAssetsStep = @import("src/tools/process_assets.zig").ProcessAssetsStep;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zstbi_pkg = zstbi.package(b, target, optimize, .{});
    const zmath_pkg = zmath.package(b, target, optimize, .{});

    const zgui_pkg = zgui.Package(.{
        .gpu_dawn = mach_gpu_dawn,
    }).build(b, target, optimize, .{
        .options = .{
            .backend = .mach,
        },
        .gpu_dawn_options = .{},
    }) catch unreachable;

    const zip_pkg = zip.package(b, .{});

    mach_core.mach_glfw_import_path = "mach_core.mach_gpu.mach_gpu_dawn.mach_glfw";
    const app = try mach_core.App.init(b, .{
        .name = "pixi",
        .src = src_path,
        .target = target,
        .deps = &[_]std.build.ModuleDependency{
            .{ .name = "zstbi", .module = zstbi_pkg.zstbi },
            .{ .name = "zmath", .module = zmath_pkg.zmath },
            .{ .name = "zgui", .module = zgui_pkg.zgui },
            .{ .name = "nfd", .module = nfd.getModule(b) },
            .{ .name = "zip", .module = zip_pkg.module },
        },
        .optimize = optimize,
    });

    const install_step = b.step("pixi", "Install pixi");
    install_step.dependOn(&app.install.step);
    b.getInstallStep().dependOn(install_step);

    const run_step = b.step("run", "Run pixi");
    run_step.dependOn(&app.run.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = src_path },
        .target = target,
        .optimize = optimize,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    app.compile.addModule("zstbi", zstbi_pkg.zstbi);
    app.compile.addModule("zgui", zgui_pkg.zgui);
    app.compile.addModule("zmath", zmath_pkg.zmath);
    app.compile.addModule("nfd", nfd.getModule(b));
    app.compile.addModule("zip", zip_pkg.module);

    const nfd_lib = nfd.makeLib(b, target, optimize);
    zstbi_pkg.link(app.compile);
    zgui_pkg.link(app.compile);
    app.compile.linkLibrary(nfd_lib);
    zip.link(app.compile);

    const assets = ProcessAssetsStep.init(b, "assets", "src/assets.zig", "src/animations.zig");
    const process_assets_step = b.step("process-assets", "generates struct for all assets");
    process_assets_step.dependOn(&assets.step);

    const install_content_step = b.addInstallDirectory(.{
        .source_dir = .{ .path = thisDir() ++ "/" ++ content_dir },
        .install_dir = .{ .custom = "" },
        .install_subdir = "bin/" ++ content_dir,
    });
    app.compile.step.dependOn(&install_content_step.step);
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
