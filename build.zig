const std = @import("std");
const builtin = @import("builtin");

const zip = @import("src/deps/zip/build.zig");

const content_dir = "assets/";

const ProcessAssetsStep = @import("src/tools/process_assets.zig");

const update = @import("update.zig");
const GitDependency = update.GitDependency;
fn update_step(step: *std.Build.Step, _: std.Build.Step.MakeOptions) !void {
    const deps = &.{
        GitDependency{
            // mach_objc
            .url = "https://github.com/foxnne/mach-objc",
            .branch = "dvuizig15",
        },
        GitDependency{
            // zigwin32
            .url = "https://github.com/marlersoft/zigwin32",
            .branch = "main",
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
    };
    try update.update_dependency(step.owner.allocator, deps);
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const no_emit = b.option(bool, "no-emit", "Check for compile errors without emitting any code") orelse false;

    const step = b.step("update", "update git dependencies");
    step.makeFn = update_step;

    const zip_pkg = zip.package(b, .{});

    const dvui_dep = b.dependency("dvui", .{ .target = target, .optimize = optimize, .backend = .sdl3 });

    const zstbi_lib = b.addLibrary(.{
        .name = "zstbi",
        .root_module = b.addModule("zstbi", .{
            .target = target,
            .optimize = optimize,
            .root_source_file = .{ .cwd_relative = "src/deps/stbi/zstbi.zig" },
        }),
    });
    const zstbi_module = zstbi_lib.root_module;

    zstbi_lib.addCSourceFile(.{ .file = std.Build.path(b, "src/deps/stbi/zstbi.c") });

    const msf_gif_lib = b.addLibrary(.{
        .name = "msf_gif",
        .root_module = b.addModule("msf_gif", .{
            .target = target,
            .optimize = optimize,
            .root_source_file = .{ .cwd_relative = "src/deps/msf_gif/msf_gif.zig" },
        }),
    });
    const msf_gif_module = msf_gif_lib.root_module;

    msf_gif_lib.addCSourceFile(.{ .file = std.Build.path(b, "src/deps/msf_gif/msf_gif.c") });

    const exe = b.addExecutable(.{
        .name = "Pixi",
        .root_module = b.addModule("App", .{
            .target = target,
            .optimize = optimize,
            .root_source_file = .{ .cwd_relative = "src/App.zig" },
        }),
        //.use_llvm = true,
    });

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

    exe.root_module.addImport("zstbi", zstbi_module);
    exe.root_module.addImport("msf_gif", msf_gif_module);
    exe.root_module.addImport("zip", zip_pkg.module);
    exe.root_module.addImport("dvui", dvui_dep.module("dvui_sdl3"));

    if (b.lazyDependency("icons", .{ .target = target, .optimize = optimize })) |dep| {
        exe.root_module.addImport("icons", dep.module("icons"));
    }

    if (target.result.os.tag == .macos) {
        if (b.lazyDependency("mach_objc", .{
            .target = target,
            .optimize = optimize,
        })) |dep| {
            exe.root_module.addImport("objc", dep.module("mach-objc"));
            if (dep.builder.lazyDependency("xcode_frameworks", .{})) |d| {
                exe.root_module.addSystemIncludePath(d.path("include"));
            }
        }
    } else if (target.result.os.tag == .windows) {
        if (b.lazyDependency("zigwin32", .{})) |dep| {
            exe.root_module.addImport("win32", dep.module("win32"));
        }
    }

    exe.linkLibCpp();
    zip.link(exe);
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
