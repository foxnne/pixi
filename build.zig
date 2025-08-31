const std = @import("std");
const builtin = @import("builtin");

const nfd = @import("src/deps/nfd-zig/build.zig");
const zip = @import("src/deps/zip/build.zig");

const content_dir = "assets/";

const ProcessAssetsStep = @import("src/tools/process_assets.zig");

const update = @import("update.zig");
const GitDependency = update.GitDependency;
fn update_step(step: *std.Build.Step, _: std.Build.Step.MakeOptions) !void {
    const deps = &.{
        // GitDependency{
        //     // zstbi
        //     .url = "https://github.com/foxnne/zstbi",
        //     .branch = "main",
        // },
        GitDependency{
            // mach_objc
            .url = "https://github.com/foxnne/mach-objc",
            .branch = "dvui",
        },
        GitDependency{
            // icons
            .url = "https://github.com/nat3Github/zig-lib-icons",
            .branch = "converter",
        },
        GitDependency{
            // dvui
            .url = "https://github.com/foxnne/dvui-dev",
            .branch = "main",
            //.branch = "main",
        },
    };
    try update.update_dependency(step.owner.allocator, deps);
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const step = b.step("update", "update git dependencies");
    step.makeFn = update_step;
    // if true return

    //const zstbi = b.dependency("zstbi", .{ .target = target, .optimize = optimize });

    const zip_pkg = zip.package(b, .{});

    const dvui_dep = b.dependency("dvui", .{ .target = target, .optimize = optimize, .backend = .sdl3 });

    //const timerModule = b.addModule("timer", .{ .root_source_file = .{ .cwd_relative = "src/tools/timer.zig" } });

    const zstbi_lib = b.addStaticLibrary(.{
        .name = "zstbi",
        .root_source_file = .{ .cwd_relative = "src/deps/stbi/zstbi.zig" },
        .target = target,
        .optimize = optimize,
    });
    const zstbi_module = zstbi_lib.root_module;

    zstbi_lib.addCSourceFile(.{ .file = std.Build.path(b, "src/deps/stbi/zstbi.c") });

    // quantization library
    // const quantizeLib = b.addStaticLibrary(.{
    //     .name = "quantize",
    //     .root_source_file = .{ .cwd_relative = "src/tools/quantize/quantize.zig" },
    //     .target = target,
    //     .optimize = optimize,
    // });
    // addImport(quantizeLib, "timer", timerModule);
    // const quantizeModule = quantizeLib.root_module;

    // zgif library
    // const zgifLibrary = b.addStaticLibrary(.{
    //     .name = "zgif",
    //     .root_source_file = .{ .cwd_relative = "src/tools/gif.zig" },
    //     .target = target,
    //     .optimize = optimize,
    // });
    // addCGif(b, zgifLibrary);
    // addImport(zgifLibrary, "quantize", quantizeModule);
    // const zgif_module = zgifLibrary.root_module;
    //zgif_module.addImport("zstbi",);

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

    exe.root_module.addImport("zstbi", zstbi_module);
    exe.root_module.addImport("nfd", nfd.getModule(b));
    exe.root_module.addImport("zip", zip_pkg.module);
    exe.root_module.addImport("dvui", dvui_dep.module("dvui_sdl3"));
    if (b.lazyDependency("icons", .{ .target = target, .optimize = optimize })) |dep| {
        exe.root_module.addImport("icons", dep.module("icons"));
    }

    //exe.root_module.addImport("zgif", zgif_module);
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
    //exe.linkLibrary(zstbi.artifact("zstbi"));
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
