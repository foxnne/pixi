const std = @import("std");
const builtin = @import("builtin");

//const mach = @import("mach");

const nfd = @import("src/deps/nfd-zig/build.zig");
const zip = @import("src/deps/zip/build.zig");

const content_dir = "assets/";

const ProcessAssetsStep = @import("src/tools/process_assets.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create our pixi module, where our Modules declaration lives
    // const pixi_mod = b.createModule(.{
    //     .root_source_file = b.path("src/pixi.zig"),
    //     .optimize = optimize,
    //     .target = target,
    // });
    // _ = pixi_mod; // autofix

    const zstbi = b.dependency("zstbi", .{ .target = target, .optimize = optimize });
    const zmath = b.dependency("zmath", .{ .target = target, .optimize = optimize });

    const zip_pkg = zip.package(b, .{});

    // Add mach import to our app.
    // const mach_dep = b.dependency("mach", .{
    //     .target = target,
    //     .optimize = optimize,
    // });

    const dvui_dep = b.dependency("dvui", .{ .target = target, .optimize = optimize, .backend = .sdl3 });

    // const zig_imgui_dep = b.dependency("zig_imgui", .{ .target = target, .optimize = optimize });

    // const imgui_module = b.addModule("zig-imgui", .{
    //     .root_source_file = zig_imgui_dep.path("src/imgui.zig"),
    //     .imports = &.{
    //         .{ .name = "mach", .module = mach_dep.module("mach") },
    //     },
    // });

    const timerModule = b.addModule("timer", .{ .root_source_file = .{ .cwd_relative = "src/tools/timer.zig" } });

    // quantization library
    const quantizeLib = b.addStaticLibrary(.{
        .name = "quantize",
        .root_source_file = .{ .cwd_relative = "src/tools/quantize/quantize.zig" },
        .target = target,
        .optimize = optimize,
    });
    addImport(quantizeLib, "timer", timerModule);
    const quantizeModule = quantizeLib.root_module;

    // zgif library
    const zgifLibrary = b.addStaticLibrary(.{
        .name = "zgif",
        .root_source_file = .{ .cwd_relative = "src/tools/gif.zig" },
        .target = target,
        .optimize = optimize,
    });
    addCGif(b, zgifLibrary);
    addImport(zgifLibrary, "quantize", quantizeModule);
    const zgif_module = zgifLibrary.root_module;
    zgif_module.addImport("zstbi", zstbi.module("root"));

    // Have Mach create the executable for us
    // The mod we pass as .app must contain the Modules definition
    // And the Modules must include an App containing the main schedule
    // const exe = mach.addExecutable(mach_dep.builder, .{
    //     .name = "Pixi",
    //     .app = pixi_mod,
    //     .target = target,
    //     .optimize = optimize,
    // });
    const exe = b.addExecutable(.{
        .name = "Pixi",
        .root_source_file = .{ .cwd_relative = "src/App.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    if (optimize != .Debug) {
        switch (target.result.os.tag) {
            .windows => exe.subsystem = .Windows,
            else => exe.subsystem = .Posix,
        }
    }

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the example");

    //pixi_mod.addImport("mach", mach_dep.module("mach"));
    exe.root_module.addImport("zstbi", zstbi.module("root"));
    exe.root_module.addImport("zmath", zmath.module("root"));
    exe.root_module.addImport("nfd", nfd.getModule(b));
    exe.root_module.addImport("zip", zip_pkg.module);

    exe.root_module.addImport("dvui", dvui_dep.module("dvui_sdl3"));

    //pixi_mod.addImport("zig-imgui", imgui_module);
    exe.root_module.addImport("zgif", zgif_module);

    const nfd_lib = nfd.makeLib(b, target, optimize);
    exe.root_module.addImport("nfd", nfd_lib);

    if (target.result.os.tag == .macos) {
        if (b.lazyDependency("mach_objc", .{
            .target = target,
            .optimize = optimize,
        })) |dep| {
            exe.root_module.addImport("objc", dep.module("mach-objc"));
            if (dep.builder.lazyDependency("xcode_frameworks", .{})) |xcode_dep| {
                nfd_lib.addSystemIncludePath(xcode_dep.path("include"));
            }
        }
    }

    exe.linkLibCpp();

    //exe.linkLibrary(zig_imgui_dep.artifact("imgui"));
    exe.linkLibrary(zstbi.artifact("zstbi"));
    zip.link(exe);

    const assets = try ProcessAssetsStep.init(b, "assets", "src/generated/");
    var process_assets_step = b.step("process-assets", "generates struct for all assets");
    process_assets_step.dependOn(&assets.step);
    exe.step.dependOn(process_assets_step);

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
