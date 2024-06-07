const std = @import("std");
const builtin = std.builtin;

fn sdkPath(comptime suffix: []const u8) []const u8 {
    if (suffix[0] != '/') @compileError("relToPath requires an absolute path!");
    return comptime blk: {
        const root_dir = std.fs.path.dirname(@src().file) orelse ".";
        break :blk root_dir ++ suffix;
    };
}

pub fn makeLib(b: *std.Build, target: std.Build.ResolvedTarget, optimize: builtin.OptimizeMode) *std.Build.Module {
    // const lib = b.addStaticLibrary(.{
    //     .name = "nfd",
    //     .root_source_file = .{ .path = sdkPath("/src/lib.zig") },
    //     .target = target,
    //     .optimize = optimize,
    // });

    const nfd_mod = b.addModule("nfd", .{
        .root_source_file = .{ .cwd_relative = sdkPath("/src/lib.zig") },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const cflags = [_][]const u8{"-Wall"};
    nfd_mod.addIncludePath(.{ .cwd_relative = sdkPath("/nativefiledialog/src/include") });
    nfd_mod.addCSourceFile(.{ .file = .{ .cwd_relative = sdkPath("/nativefiledialog/src/nfd_common.c") }, .flags = &cflags });
    switch (target.result.os.tag) {
        .macos => nfd_mod.addCSourceFile(.{ .file = .{ .cwd_relative = sdkPath("/nativefiledialog/src/nfd_cocoa.m") }, .flags = &cflags }),
        .windows => nfd_mod.addCSourceFile(.{ .file = .{ .cwd_relative = sdkPath("/nativefiledialog/src/nfd_win.cpp") }, .flags = &cflags }),
        .linux => nfd_mod.addCSourceFile(.{ .file = .{ .cwd_relative = sdkPath("/nativefiledialog/src/nfd_gtk.c") }, .flags = &cflags }),
        else => @panic("unsupported OS"),
    }

    switch (target.result.os.tag) {
        .macos => nfd_mod.linkFramework("AppKit", .{}),
        .windows => {
            nfd_mod.linkSystemLibrary("shell32", .{});
            nfd_mod.linkSystemLibrary("ole32", .{});
            nfd_mod.linkSystemLibrary("uuid", .{}); // needed by MinGW
        },
        .linux => {
            nfd_mod.linkSystemLibrary("atk-1.0", .{});
            nfd_mod.linkSystemLibrary("gdk-3", .{});
            nfd_mod.linkSystemLibrary("gtk-3", .{});
            nfd_mod.linkSystemLibrary("glib-2.0", .{});
            nfd_mod.linkSystemLibrary("gobject-2.0", .{});
        },
        else => @panic("unsupported OS"),
    }

    return nfd_mod;
}

pub fn getModule(b: *std.Build) *std.Build.Module {
    return b.createModule(.{ .root_source_file = .{ .cwd_relative = sdkPath("/src/lib.zig") } });
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
