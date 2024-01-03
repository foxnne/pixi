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
    const use_freetype = b.option(bool, "use_freetype", "Use freetype") orelse false;

    const zip_pkg = zip.package(b, .{});

    const mach_core_dep = b.dependency("mach_core", .{
        .target = target,
        .optimize = optimize,
    });

    const imgui_module = b.addModule("zig-imgui", .{
        .source_file = .{ .path = "src/deps/imgui/src/imgui.zig" },
        .dependencies = &.{
            .{ .name = "mach-core", .module = mach_core_dep.module("mach-core") },
        },
    });

    const imgui_lib = b.addStaticLibrary(.{
        .name = "imgui",
        .root_source_file = .{ .path = "src/deps/imgui/src/cimgui.cpp" },
        .target = target,
        .optimize = optimize,
    });
    imgui_lib.linkLibC();

    const imgui_dep = b.dependency("imgui", .{});

    var imgui_files = std.ArrayList([]const u8).init(b.allocator);
    defer imgui_files.deinit();

    var imgui_flags = std.ArrayList([]const u8).init(b.allocator);
    defer imgui_flags.deinit();

    try imgui_files.appendSlice(&.{
        imgui_dep.path("imgui.cpp").getPath(b),
        imgui_dep.path("imgui_widgets.cpp").getPath(b),
        imgui_dep.path("imgui_tables.cpp").getPath(b),
        imgui_dep.path("imgui_draw.cpp").getPath(b),
        imgui_dep.path("imgui_demo.cpp").getPath(b),
    });

    if (use_freetype) {
        try imgui_flags.append("-DIMGUI_ENABLE_FREETYPE");
        try imgui_files.append("imgui/misc/freetype/imgui_freetype.cpp");

        imgui_lib.linkLibrary(b.dependency("freetype", .{
            .target = target,
            .optimize = optimize,
        }).artifact("freetype"));
    }

    imgui_lib.addIncludePath(imgui_dep.path("."));
    imgui_lib.addCSourceFiles(.{
        .files = imgui_files.items,
        .flags = imgui_flags.items,
    });

    b.installArtifact(imgui_lib);

    const build_options = b.addOptions();
    build_options.addOption(bool, "use_sysgpu", use_sysgpu);

    const app = try mach_core.App.init(b, mach_core_dep.builder, .{
        .name = "pixi",
        .src = src_path,
        .target = target,
        .deps = &[_]std.build.ModuleDependency{
            .{ .name = "zstbi", .module = zstbi_pkg.zstbi },
            .{ .name = "zmath", .module = zmath_pkg.zmath },
            .{ .name = "nfd", .module = nfd.getModule(b) },
            .{ .name = "zip", .module = zip_pkg.module },
            .{ .name = "zig-imgui", .module = imgui_module },
            .{ .name = "build-options", .module = build_options.createModule() },
        },
        .optimize = optimize,
    });

    if (use_sysgpu) {
        const mach_sysgpu_dep = b.dependency("mach_sysgpu", .{
            .target = target,
            .optimize = optimize,
        });

        app.compile.linkLibrary(mach_sysgpu_dep.artifact("mach-dusk"));
        @import("mach_sysgpu").link(mach_sysgpu_dep.builder, app.compile);
    }

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

    unit_tests.addModule("zstbi", zstbi_pkg.zstbi);
    unit_tests.addModule("zmath", zmath_pkg.zmath);
    unit_tests.addModule("nfd", nfd.getModule(b));
    unit_tests.addModule("zip", zip_pkg.module);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    app.compile.addModule("zstbi", zstbi_pkg.zstbi);
    app.compile.addModule("zmath", zmath_pkg.zmath);
    app.compile.addModule("nfd", nfd.getModule(b));
    app.compile.addModule("zip", zip_pkg.module);
    app.compile.addModule("zig-imgui", imgui_module);

    const nfd_lib = nfd.makeLib(b, target, optimize);
    if (nfd_lib.target_info.target.os.tag == .macos) {
        // MacOS: this must be defined for macOS 13.3 and older.
        // Critically, this MUST NOT be included as a -D__kernel_ptr_semantics flag. If it is,
        // then this macro will not be defined even if `defineCMacro` was also called!
        nfd_lib.defineCMacro("__kernel_ptr_semantics", "");
        xcode_frameworks.addPaths(nfd_lib);
    }
    app.compile.linkLibrary(nfd_lib);
    app.compile.linkLibrary(imgui_lib);
    zstbi_pkg.link(app.compile);
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

comptime {
    const min_zig = std.SemanticVersion.parse("0.11.0") catch unreachable;
    if (builtin.zig_version.order(min_zig) == .lt) {
        @compileError(std.fmt.comptimePrint("Your Zig version v{} does not meet the minimum build requirement of v{}", .{ builtin.zig_version, min_zig }));
    }
}
