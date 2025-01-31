const std = @import("std");
const builtin = @import("builtin");

const mach = @import("mach");

const nfd = @import("src/deps/nfd-zig/build.zig");
const zip = @import("src/deps/zip/build.zig");

const content_dir = "assets/";

const ProcessAssetsStep = @import("src/tools/process_assets.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("pixi", .{
        .root_source_file = b.path("src/pixi.zig"),
    });

    const zstbi = b.dependency("zstbi", .{ .target = target, .optimize = optimize });
    const zmath = b.dependency("zmath", .{ .target = target, .optimize = optimize });

    const zip_pkg = zip.package(b, .{});

    const mach_dep = b.dependency("mach", .{
        .target = target,
        .optimize = optimize,
        .core = true,
    });

    const zig_imgui_dep = b.dependency("zig_imgui", .{ .target = target, .optimize = optimize });

    const imgui_module = b.addModule("zig-imgui", .{
        .root_source_file = zig_imgui_dep.path("src/imgui.zig"),
        .imports = &.{
            .{ .name = "mach", .module = mach_dep.module("mach") },
        },
    });

    const exe = b.addExecutable(.{
        .name = "pixi",
        .root_source_file = b.path("src/pixi.zig"),
        .target = target,
        .optimize = optimize,
    });

    if (optimize != .Debug) {
        switch (target.result.os.tag) {
            .windows => exe.subsystem = .Windows,
            else => exe.subsystem = .Posix,
        }
    }

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the example");

    exe.root_module.addImport("mach", mach_dep.module("mach"));
    exe.root_module.addImport("zstbi", zstbi.module("root"));
    exe.root_module.addImport("zmath", zmath.module("root"));
    exe.root_module.addImport("nfd", nfd.getModule(b));
    exe.root_module.addImport("zip", zip_pkg.module);
    exe.root_module.addImport("zig-imgui", imgui_module);
    //exe.root_module.addImport("pixi", module);

    const nfd_lib = nfd.makeLib(b, target, optimize);
    exe.root_module.addImport("nfd", nfd_lib);

    if (target.result.isDarwin()) {
        //     // MacOS: this must be defined for macOS 13.3 and older.
        //     // Critically, this MUST NOT be included as a -D__kernel_ptr_semantics flag. If it is,
        //     // then this macro will not be defined even if `defineCMacro` was also called!
        //nfd_lib.addCMacro("__kernel_ptr_semantics", "");
        //mach.addPaths(nfd_lib);
        if (mach_dep.builder.lazyDependency("xcode_frameworks", .{})) |dep| {
            nfd_lib.addSystemIncludePath(dep.path("include"));
        }
    }

    exe.linkLibCpp();

    exe.linkLibrary(zig_imgui_dep.artifact("imgui"));
    exe.linkLibrary(zstbi.artifact("zstbi"));
    zip.link(exe);

    // const assets = try ProcessAssetsStep.init(b, "assets", "src/assets.zig", "src/animations.zig");
    // var process_assets_step = b.step("process-assets", "generates struct for all assets");
    // process_assets_step.dependOn(&assets.step);
    // exe.step.dependOn(process_assets_step);

    const install_content_step = b.addInstallDirectory(.{
        .source_dir = .{ .cwd_relative = thisDir() ++ "/" ++ content_dir },
        .install_dir = .{ .custom = "" },
        .install_subdir = "bin/" ++ content_dir,
    });
    exe.step.dependOn(&install_content_step.step);

    const installArtifact = b.addInstallArtifact(exe, .{});
    run_cmd.step.dependOn(&installArtifact.step);
    run_step.dependOn(&run_cmd.step);
    b.getInstallStep().dependOn(&installArtifact.step);
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
