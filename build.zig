const std = @import("std");
const builtin = @import("builtin");

const zmath = @import("src/deps/zig-gamedev/zmath/build.zig");
const zstbi = @import("src/deps/zig-gamedev/zstbi/build.zig");

const mach_core = @import("mach_core");
const mach_gpu_dawn = @import("mach_gpu_dawn");
const xcode_frameworks = @import("xcode_frameworks");

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

    const use_sysgpu = b.option(bool, "use_sysgpu", "Use sysgpu") orelse false;

    const zip_pkg = zip.package(b, .{});

    const mach_core_dep = b.dependency("mach_core", .{
        .target = target,
        .optimize = optimize,
    });

    const zig_imgui_dep = b.dependency("zig_imgui", .{});

    const imgui_module = b.addModule("zig-imgui", .{
        .root_source_file = zig_imgui_dep.path("src/imgui.zig"),
        .imports = &.{
            .{ .name = "mach-core", .module = mach_core_dep.module("mach-core") },
        },
    });

    const build_options = b.addOptions();
    build_options.addOption(bool, "use_sysgpu", use_sysgpu);

    const app = try mach_core.App.init(b, mach_core_dep.builder, .{
        .name = "pixi",
        .src = src_path,
        .target = target,
        .deps = &.{
            .{ .name = "zstbi", .module = zstbi_pkg.zstbi },
            .{ .name = "zmath", .module = zmath_pkg.zmath },
            .{ .name = "nfd", .module = nfd.getModule(b) },
            .{ .name = "zip", .module = zip_pkg.module },
            .{ .name = "zig-imgui", .module = imgui_module },
            .{ .name = "build-options", .module = build_options.createModule() },
        },
        .optimize = optimize,
    });

    // if (use_sysgpu) {
    //     const mach_sysgpu_dep = b.dependency("mach_sysgpu", .{
    //         .target = target,
    //         .optimize = optimize,
    //     });

    //     app.compile.linkLibrary(mach_sysgpu_dep.artifact("mach-dusk"));
    //     //@import("mach_sysgpu").link(mach_sysgpu_dep.builder, app.compile);
    // }

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

    unit_tests.root_module.addImport("zstbi", zstbi_pkg.zstbi);
    unit_tests.root_module.addImport("zmath", zmath_pkg.zmath);
    unit_tests.root_module.addImport("nfd", nfd.getModule(b));
    unit_tests.root_module.addImport("zip", zip_pkg.module);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    app.compile.root_module.addImport("zstbi", zstbi_pkg.zstbi);
    app.compile.root_module.addImport("zmath", zmath_pkg.zmath);
    app.compile.root_module.addImport("nfd", nfd.getModule(b));
    app.compile.root_module.addImport("zip", zip_pkg.module);
    app.compile.root_module.addImport("zig-imgui", imgui_module);

    const nfd_lib = nfd.makeLib(b, target, optimize);
    app.compile.root_module.addImport("nfd", nfd_lib);
    // if (nfd_lib.target_info.target.os.tag == .macos) {
    //     // MacOS: this must be defined for macOS 13.3 and older.
    //     // Critically, this MUST NOT be included as a -D__kernel_ptr_semantics flag. If it is,
    //     // then this macro will not be defined even if `defineCMacro` was also called!
    //     nfd_lib.defineCMacro("__kernel_ptr_semantics", "");
    //     xcode_frameworks.addPaths(nfd_lib);
    // }
    app.compile.linkLibrary(zig_imgui_dep.artifact("imgui"));
    zstbi_pkg.link(app.compile);
    zip.link(app.compile);

    const assets = ProcessAssetsStep.init(b, "assets", "src/assets.zig", "src/animations.zig");
    var process_assets_step = b.step("process-assets", "generates struct for all assets");
    process_assets_step.dependOn(&assets.step);
    app.compile.step.dependOn(process_assets_step);

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

comptime {
    const min_zig = std.SemanticVersion.parse("0.11.0") catch unreachable;
    if (builtin.zig_version.order(min_zig) == .lt) {
        @compileError(std.fmt.comptimePrint("Your Zig version v{} does not meet the minimum build requirement of v{}", .{ builtin.zig_version, min_zig }));
    }
}
