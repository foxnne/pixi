const std = @import("std");
const builtin = std.builtin;

fn sdkPath(comptime suffix: []const u8) []const u8 {
    if (suffix[0] != '/') @compileError("relToPath requires an absolute path!");
    return comptime blk: {
        const root_dir = std.fs.path.dirname(@src().file) orelse ".";
        break :blk root_dir ++ suffix;
    };
}

pub fn makeLib(b: *std.Build, target: std.zig.CrossTarget, optimize: builtin.OptimizeMode) *std.Build.CompileStep {
    const lib = b.addStaticLibrary(.{
        .name = "nfd",
        .root_source_file = .{ .path = sdkPath("/src/lib.zig") },
        .target = target,
        .optimize = optimize,
    });

    const cflags = [_][]const u8{ "-m64", "-g", "-Wall", "-Wextra", "-fno-exceptions" };
    lib.addIncludePath(.{ .path = sdkPath("/nativefiledialog/src/include") });
    lib.addCSourceFile(.{ .file = .{ .path = sdkPath("/nativefiledialog/src/nfd_common.c") }, .flags = &cflags });
    if (lib.target.isDarwin()) {
        lib.addCSourceFile(.{ .file = .{ .path = sdkPath("/nativefiledialog/src/nfd_cocoa.m") }, .flags = &cflags });
    } else if (lib.target.isWindows()) {
        lib.addCSourceFile(.{ .file = .{ .path = sdkPath("/nativefiledialog/src/nfd_win.cpp") }, .flags = &cflags });
    } else {
        lib.addCSourceFile(.{ .file = .{ .path = sdkPath("/nativefiledialog/src/nfd_gtk.c") }, .flags = &cflags });
    }

    lib.linkLibC();
    if (lib.target.isDarwin()) {
        lib.linkFramework("AppKit");
        lib.linkFramework("Foundation");
    } else if (lib.target.isWindows()) {
        lib.linkSystemLibrary("shell32");
        lib.linkSystemLibrary("ole32");
        lib.linkSystemLibrary("uuid"); // needed by MinGW
    } else {
        lib.linkSystemLibrary("atk-1.0");
        lib.linkSystemLibrary("gdk-3");
        lib.linkSystemLibrary("gtk-3");
        lib.linkSystemLibrary("glib-2.0");
        lib.linkSystemLibrary("gobject-2.0");
    }

    return lib;
}

pub fn getModule(b: *std.Build) *std.build.Module {
    return b.createModule(.{ .source_file = .{ .path = sdkPath("/src/lib.zig") } });
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const lib = makeLib(b, target, optimize);
    lib.install();

    var demo = b.addExecutable(.{
        .name = "demo",
        .root_source_file = .{ .path = "src/demo.zig" },
        .target = target,
        .optimize = optimize,
    });
    demo.addModule("nfd", getModule(b));
    demo.linkLibrary(lib);
    demo.install();

    const run_demo_cmd = demo.run();
    run_demo_cmd.step.dependOn(b.getInstallStep());

    const run_demo_step = b.step("run", "Run the demo");
    run_demo_step.dependOn(&run_demo_cmd.step);
}
