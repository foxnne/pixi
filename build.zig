const std = @import("std");
const builtin = @import("builtin");

const zgpu = @import("src/deps/zig-gamedev/zgpu/build.zig");
const zmath = @import("src/deps/zig-gamedev/zmath/build.zig");
const zpool = @import("src/deps/zig-gamedev/zpool/build.zig");
const zglfw = @import("src/deps/zig-gamedev/zglfw/build.zig");
const zstbi = @import("src/deps/zig-gamedev/zstbi/build.zig");
const zgui = @import("src/deps/zig-gamedev/zgui/build.zig");

const nfd = @import("src/deps/nfd-zig/build.zig");
const zip = @import("src/deps/zip/build.zig");

const content_dir = "assets/";

const src_path = "src/pixi.zig";
const name = @import("src/pixi.zig").name;

const ProcessAssetsStep = @import("src/tools/process_assets.zig").ProcessAssetsStep;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    ensureTarget(target) catch return;
    ensureGit(b.allocator) catch return;
    ensureGitLfs(b.allocator, "install") catch return;
    ensureGitLfs(b.allocator, "pull") catch return;

    // Fetch the latest Dawn/WebGPU binaries.
    {
        var child = std.ChildProcess.init(&.{ "git", "submodule", "update", "--init", "--remote" }, b.allocator);
        child.cwd = thisDir();
        child.stderr = std.io.getStdErr();
        child.stdout = std.io.getStdOut();
        _ = child.spawnAndWait() catch {
            std.log.err("Failed to fetch git submodule. Please try to re-clone.", .{});
            return;
        };
    }
    ensureGitLfsContent("/src/deps/zig-gamedev/zgpu/libs/dawn/x86_64-windows-gnu/dawn.lib") catch return;

    var exe = b.addExecutable(.{
        .name = name,
        .root_source_file = .{ .path = src_path },
        .optimize = optimize,
        .target = target,
    });

    exe.want_lto = false;
    if (exe.optimize == .ReleaseFast) {
        exe.strip = true;
        if (target.isWindows()) {
            exe.subsystem = .Windows;
        } else {
            exe.subsystem = .Posix;
        }
    }
    b.default_step.dependOn(&exe.step);

    const zstbi_pkg = zstbi.package(b, target, optimize, .{});
    const zmath_pkg = zmath.package(b, target, optimize, .{});
    const zglfw_pkg = zglfw.package(b, target, optimize, .{});
    const zpool_pkg = zpool.package(b, target, optimize, .{});
    const zgpu_pkg = zgpu.package(b, target, optimize, .{
        .options = .{ .uniforms_buffer_size = 4 * 1024 * 1024 },
        .deps = .{ .zpool = zpool_pkg.zpool, .zglfw = zglfw_pkg.zglfw },
    });
    const zgui_pkg = zgui.package(b, target, optimize, .{
        .options = .{
            .backend = .glfw_wgpu,
        },
    });
    const zip_pkg = zip.package(b, .{});

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", b.fmt("run {s}", .{name}));
    run_cmd.step.dependOn(b.getInstallStep());
    run_step.dependOn(&run_cmd.step);
    exe.addModule("zstbi", zstbi_pkg.zstbi);
    exe.addModule("zmath", zmath_pkg.zmath);
    exe.addModule("zpool", zpool_pkg.zpool);
    exe.addModule("zglfw", zglfw_pkg.zglfw);
    exe.addModule("zgpu", zgpu_pkg.zgpu);
    exe.addModule("zgui", zgui_pkg.zgui);
    exe.addModule("nfd", nfd.getModule(b));
    exe.addModule("zip", zip_pkg.module);

    const nfd_lib = nfd.makeLib(b, target, optimize);

    zgpu_pkg.link(exe);
    zglfw_pkg.link(exe);
    zstbi_pkg.link(exe);
    zgui_pkg.link(exe);
    exe.linkLibrary(nfd_lib);
    zip.link(exe);

    const tests = b.step("test", "Run all tests");
    const pixi_tests = b.addTest(.{
        .root_source_file = .{ .path = thisDir() ++ "src/pixi.zig" },
        .target = target,
        .optimize = optimize,
    });
    pixi_tests.addModule("zstbi", zstbi_pkg.zstbi);
    pixi_tests.addModule("zmath", zmath_pkg.zmath);
    pixi_tests.addModule("zpool", zpool_pkg.zpool);
    pixi_tests.addModule("zglfw", zglfw_pkg.zglfw);
    pixi_tests.addModule("zgui", zgui_pkg.zgui);
    pixi_tests.addModule("zgpu", zgpu_pkg.zgpu);

    zgpu_pkg.link(pixi_tests);
    zglfw_pkg.link(pixi_tests);
    zstbi_pkg.link(pixi_tests);
    zgui_pkg.link(pixi_tests);
    tests.dependOn(&pixi_tests.step);

    const assets = ProcessAssetsStep.init(b, "assets", "src/assets.zig", "src/animations.zig");
    const process_assets_step = b.step("process-assets", "generates struct for all assets");
    process_assets_step.dependOn(&assets.step);

    const install_content_step = b.addInstallDirectory(.{
        .source_dir = .{ .path = thisDir() ++ "/" ++ content_dir },
        .install_dir = .{ .custom = "" },
        .install_subdir = "bin/" ++ content_dir,
    });
    exe.step.dependOn(&install_content_step.step);
    b.installArtifact(exe);
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}

fn ensureTarget(cross: std.zig.CrossTarget) !void {
    const target = (std.zig.system.NativeTargetInfo.detect(cross) catch unreachable).target;

    const supported = switch (target.os.tag) {
        .windows => target.cpu.arch.isX86() and target.abi.isGnu(),
        .linux => (target.cpu.arch.isX86() or target.cpu.arch.isAARCH64()) and target.abi.isGnu(),
        .macos => blk: {
            if (!target.cpu.arch.isX86() and !target.cpu.arch.isAARCH64()) break :blk false;

            // If min. target macOS version is lesser than the min version we have available, then
            // our Dawn binary is incompatible with the target.
            if (target.os.version_range.semver.min.order(
                .{ .major = 12, .minor = 0, .patch = 0 },
            ) == .lt) break :blk false;
            break :blk true;
        },
        else => false,
    };
    if (!supported) {
        std.log.err("\n" ++
            \\---------------------------------------------------------------------------
            \\
            \\Unsupported build target. Dawn/WebGPU binary for this target is not available.
            \\
            \\Following targets are supported:
            \\
            \\x86_64-windows-gnu
            \\x86_64-linux-gnu
            \\x86_64-macos.12-none
            \\aarch64-linux-gnu
            \\aarch64-macos.12-none
            \\
            \\---------------------------------------------------------------------------
            \\
        , .{});
        return error.TargetNotSupported;
    }
}

fn ensureGit(allocator: std.mem.Allocator) !void {
    const printErrorMsg = (struct {
        fn impl() void {
            std.log.err("\n" ++
                \\---------------------------------------------------------------------------
                \\
                \\'git version' failed. Is Git not installed?
                \\
                \\---------------------------------------------------------------------------
                \\
            , .{});
        }
    }).impl;
    const argv = &[_][]const u8{ "git", "version" };
    const result = std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = argv,
        .cwd = ".",
    }) catch { // e.g. FileNotFound
        printErrorMsg();
        return error.GitNotFound;
    };
    defer {
        allocator.free(result.stderr);
        allocator.free(result.stdout);
    }
    if (result.term.Exited != 0) {
        printErrorMsg();
        return error.GitNotFound;
    }
}

fn ensureGitLfs(allocator: std.mem.Allocator, cmd: []const u8) !void {
    const printNoGitLfs = (struct {
        fn impl() void {
            std.log.err("\n" ++
                \\---------------------------------------------------------------------------
                \\
                \\Please install Git LFS (Large File Support) extension and run 'zig build' again.
                \\
                \\For more info about Git LFS see: https://git-lfs.github.com/
                \\
                \\---------------------------------------------------------------------------
                \\
            , .{});
        }
    }).impl;
    const argv = &[_][]const u8{ "git", "lfs", cmd };
    const result = std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = argv,
        .cwd = ".",
    }) catch { // e.g. FileNotFound
        printNoGitLfs();
        return error.GitLfsNotFound;
    };
    defer {
        allocator.free(result.stderr);
        allocator.free(result.stdout);
    }
    if (result.term.Exited != 0) {
        printNoGitLfs();
        return error.GitLfsNotFound;
    }
}

fn ensureGitLfsContent(comptime file_path: []const u8) !void {
    const printNoGitLfsContent = (struct {
        fn impl() void {
            std.log.err("\n" ++
                \\---------------------------------------------------------------------------
                \\
                \\Something went wrong, Git LFS content has not been downloaded.
                \\
                \\Please try to re-clone the repo and build again.
                \\
                \\---------------------------------------------------------------------------
                \\
            , .{});
        }
    }).impl;
    const file = std.fs.openFileAbsolute(thisDir() ++ file_path, .{}) catch {
        printNoGitLfsContent();
        return error.GitLfsNoContent;
    };
    defer file.close();

    const size = file.getEndPos() catch {
        printNoGitLfsContent();
        return error.GitLfsNoContent;
    };
    if (size <= 1024) {
        printNoGitLfsContent();
        return error.GitLfsNoContent;
    }
}
