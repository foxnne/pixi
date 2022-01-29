const std = @import("std");
const upaya_build = @import("src/deps/upaya/build.zig");
const builtin = @import("builtin");

const LibExeObjStep = std.build.LibExeObjStep;
const Builder = std.build.Builder;
const Target = std.build.Target;
const Pkg = std.build.Pkg;

pub fn build(b: *Builder) !void {
    const target = b.standardTargetOptions(.{});

    // use a different cache folder for macos arm builds
    //b.cache_root = if (std.builtin.os.tag == .macos and std.builtin.cpu.arch == std.Target.Cpu.Arch.aarch64) "zig-arm-cache" else "zig-cache";
    var exe = createExe(b, target, "Pixi", "src/pixi.zig");
    b.default_step.dependOn(&exe.step);
}

fn createExe(b: *Builder, target: std.zig.CrossTarget, name: []const u8, source: []const u8) *std.build.LibExeObjStep {
    var exe = b.addExecutable(name, source);
    exe.setBuildMode(b.standardReleaseOptions());

    if (builtin.os.tag == .macos) {
        const c_flags = [_][]const u8{ "-std=c99", "-ObjC" };
        exe.addCSourceFile("appdelegate/appdelegate.m", &c_flags);
    }

    if (b.is_release) {
        exe.want_lto = false; //workaround until this is supported

        if (target.isWindows()) {
            exe.subsystem = .Windows;
        }

        if (builtin.os.tag == .macos) {
            exe.subsystem = .Posix;
            const c_flags = [_][]const u8{ "-std=c99", "-ObjC" };
            exe.addCSourceFile("appdelegate/appdelegate.m", &c_flags);
        }
    }

    upaya_build.addUpayaToArtifact(b, exe, target, "src/deps/upaya/");

    const pixi_package = std.build.Pkg{
        .name = "pixi",
        .path = .{ .path = "src/pixi.zig" },
    };

    exe.install();

    if (builtin.os.tag == .macos) {
        const install_path = std.fmt.allocPrint(b.allocator, "{s}/bin/Pixi", .{b.install_path}) catch unreachable;
        defer b.allocator.free(install_path);
        b.installFile(install_path, "bin/Pixi.app/Contents/MacOS/Pixi");
        b.installFile("Info.plist", "bin/Pixi.app/Contents/Info.plist");
        b.installFile("Icon.icns", "bin/Pixi.app/Contents/Resources/Icon.icns");
    }

    

    const run_cmd = exe.run();
    const exe_step = b.step("run", b.fmt("run {s}.zig", .{name}));
    run_cmd.step.dependOn(b.getInstallStep());
    exe_step.dependOn(&run_cmd.step);
    exe.addPackage(pixi_package);

    return exe;
}
