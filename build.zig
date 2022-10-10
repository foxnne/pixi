const std = @import("std");
const builtin = @import("builtin");

const LibExeObjStep = std.build.LibExeObjStep;
const Builder = std.build.Builder;
const Target = std.build.Target;
const Pkg = std.build.Pkg;

const pixi_pkg = std.build.Pkg{
    .name = "pixi",
    .source = .{ .path = "src/pixi.zig" },
};

const zgpu = @import("src/deps/zig-gamedev/zgpu/build.zig");
const zmath = @import("src/deps/zig-gamedev/zmath/build.zig");
const zpool = @import("src/deps/zig-gamedev/zpool/build.zig");
const zglfw = @import("src/deps/zig-gamedev/zglfw/build.zig");
const zstbi = @import("src/deps/zig-gamedev/zstbi/build.zig");
const zgui = @import("src/deps/zig-gamedev/zgui/build.zig");

const content_dir = "assets/";

const ProcessAssetsStep = @import("src/tools/process_assets.zig").ProcessAssetsStep;

pub fn build(b: *Builder) !void {
    const target = b.standardTargetOptions(.{});

    var exe = createExe(b, target, "run", "src/pixi.zig");
    b.default_step.dependOn(&exe.step);

    const zgpu_pkg = zgpu.getPkg(&.{ zpool.pkg, zglfw.pkg });
    const zgui_pkg = zgui.getPkg(&.{zglfw.pkg});

    const tests = b.step("test", "Run all tests");
    const pixi_tests = b.addTest(pixi_pkg.source.path);
    pixi_tests.addPackage(pixi_pkg);
    pixi_tests.addPackage(zgpu_pkg);
    pixi_tests.addPackage(zglfw.pkg);
    pixi_tests.addPackage(zgui_pkg);
    pixi_tests.addPackage(zstbi.pkg);
    pixi_tests.addPackage(zmath.pkg);

    zgpu.link(pixi_tests);
    zglfw.link(pixi_tests);
    zstbi.link(pixi_tests);
    zgui.link(pixi_tests);
    tests.dependOn(&pixi_tests.step);

    const assets = ProcessAssetsStep.init(b, "assets", "src/assets.zig", "src/animations.zig");
    const process_assets_step = b.step("process-assets", "generates struct for all assets");
    process_assets_step.dependOn(&assets.step);

    const install_content_step = b.addInstallDirectory(.{
        .source_dir = thisDir() ++ "/" ++ content_dir,
        .install_dir = .{ .custom = "" },
        .install_subdir = "bin/" ++ content_dir,
    });
    exe.step.dependOn(&install_content_step.step);
}

fn createExe(b: *Builder, target: std.zig.CrossTarget, name: []const u8, source: []const u8) *std.build.LibExeObjStep {
    var exe = b.addExecutable(name, source);
    exe.setBuildMode(b.standardReleaseOptions());

    exe.want_lto = false;
    if (b.is_release) {
        if (target.isWindows()) {
            exe.subsystem = .Windows;
        }

        if (builtin.os.tag == .macos and builtin.cpu.arch == std.Target.Cpu.Arch.aarch64) {
            exe.subsystem = .Posix;
        }
    }

    const zgpu_pkg = zgpu.getPkg(&.{ zpool.pkg, zglfw.pkg });
    const zgui_pkg = zgui.getPkg(&.{zglfw.pkg});

    exe.install();

    const run_cmd = exe.run();
    const exe_step = b.step("run", b.fmt("run {s}.zig", .{name}));
    run_cmd.step.dependOn(b.getInstallStep());
    exe_step.dependOn(&run_cmd.step);
    exe.addPackage(pixi_pkg);
    exe.addPackage(zgpu_pkg);
    exe.addPackage(zglfw.pkg);
    exe.addPackage(zgui_pkg);
    exe.addPackage(zstbi.pkg);
    exe.addPackage(zmath.pkg);

    zgpu.link(exe);
    zglfw.link(exe);
    zstbi.link(exe);
    zgui.link(exe);

    return exe;
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
