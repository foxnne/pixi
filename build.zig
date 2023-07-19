const std = @import("std");
const builtin = @import("builtin");

const zmath = @import("src/deps/zig-gamedev/zmath/build.zig");
const zstbi = @import("src/deps/zig-gamedev/zstbi/build.zig");
const zgui = @import("src/deps/zig-gamedev/zgui/build.zig");

const glfw = @import("mach_glfw");
const gpu_dawn = @import("src/deps/mach-gpu-dawn/build.zig");
const gpu = @import("src/deps/mach-gpu/build.zig").Sdk(.{
    .gpu_dawn = gpu_dawn,
});
pub const core = @import("src/deps/mach-core/build.zig").Sdk(.{
    .gpu = gpu,
    .gpu_dawn = gpu_dawn,
    .glfw = glfw,
});

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

    const zgui_pkg = zgui.Package(.{
        .gpu_dawn = core.gpu_dawn,
    }).build(b, target, optimize, .{
        .options = .{
            .backend = .mach,
        },
        .gpu_dawn_options = .{},
    }) catch unreachable;

    const zip_pkg = zip.package(b, .{});

    const app = try core.App.init(b, .{
        .name = "pixi",
        .src = src_path,
        .target = target,
        .deps = &[_]std.build.ModuleDependency{
            .{ .name = "zstbi", .module = zstbi_pkg.zstbi },
            .{ .name = "zmath", .module = zmath_pkg.zmath },
            .{ .name = "zgui", .module = zgui_pkg.zgui },
            .{ .name = "nfd", .module = nfd.getModule(b) },
            .{ .name = "zip", .module = zip_pkg.module },
        },
        .optimize = optimize,
    });
    try app.link(.{});

    const compile_step = b.step("pixi", "Compile pixi");
    compile_step.dependOn(&app.getInstallStep().?.step);

    app.install();

    const run_cmd = b.addRunArtifact(app.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const nfd_lib = nfd.makeLib(b, target, optimize);
    zstbi_pkg.link(app.step);
    zgui_pkg.link(app.step);
    app.step.linkLibrary(nfd_lib);
    zip.link(app.step);

    const assets = ProcessAssetsStep.init(b, "assets", "src/assets.zig", "src/animations.zig");
    const process_assets_step = b.step("process-assets", "generates struct for all assets");
    process_assets_step.dependOn(&assets.step);

    const install_content_step = b.addInstallDirectory(.{
        .source_dir = .{ .path = thisDir() ++ "/" ++ content_dir },
        .install_dir = .{ .custom = "" },
        .install_subdir = "bin/" ++ content_dir,
    });
    app.step.step.dependOn(&install_content_step.step);
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}

fn glfwLink(b: *std.Build, step: *std.build.CompileStep) void {
    const glfw_dep = b.dependency("mach_glfw", .{
        .target = step.target,
        .optimize = step.optimize,
    });
    step.linkLibrary(glfw_dep.artifact("mach-glfw"));
    step.addModule("glfw", glfw_dep.module("mach-glfw"));

    // TODO(build-system): Zig package manager currently can't handle transitive deps like this, so we need to use
    // these explicitly here:
    @import("glfw").addPaths(step);
    if (step.target.toTarget().isDarwin()) xcode_frameworks.addPaths(b, step);
    step.linkLibrary(b.dependency("vulkan_headers", .{
        .target = step.target,
        .optimize = step.optimize,
    }).artifact("vulkan-headers"));
    step.linkLibrary(b.dependency("x11_headers", .{
        .target = step.target,
        .optimize = step.optimize,
    }).artifact("x11-headers"));
    step.linkLibrary(b.dependency("wayland_headers", .{
        .target = step.target,
        .optimize = step.optimize,
    }).artifact("wayland-headers"));
}

fn sdkPath(comptime suffix: []const u8) []const u8 {
    if (suffix[0] != '/') @compileError("suffix must be an absolute path");
    return comptime blk: {
        const root_dir = std.fs.path.dirname(@src().file) orelse ".";
        break :blk root_dir ++ suffix;
    };
}

pub fn Sdk(comptime deps: anytype) type {
    return struct {
        pub const gpu_dawn = deps.gpu_dawn;

        pub const Options = struct {
            gpu_dawn_options: deps.gpu_dawn.Options = .{},

            pub fn gpuOptions(options: Options) deps.gpu.Options {
                return .{
                    .gpu_dawn_options = options.gpu_dawn_options,
                };
            }
        };

        var _module: ?*std.build.Module = null;

        pub fn module(b: *std.Build, optimize: std.builtin.OptimizeMode, target: std.zig.CrossTarget) *std.build.Module {
            if (_module) |m| return m;

            const gamemode_dep = b.dependency("mach_gamemode", .{});

            _module = b.createModule(.{
                .source_file = .{ .path = sdkPath("/src/main.zig") },
                .dependencies = &.{
                    .{ .name = "gpu", .module = deps.gpu.module(b) },
                    .{ .name = "glfw", .module = b.dependency("mach_glfw", .{
                        .target = target,
                        .optimize = optimize,
                    }).module("mach-glfw") },
                    .{ .name = "gamemode", .module = gamemode_dep.module("mach-gamemode") },
                },
            });
            return _module.?;
        }

        pub fn testStep(b: *std.Build, optimize: std.builtin.OptimizeMode, target: std.zig.CrossTarget) !*std.build.RunStep {
            const main_tests = b.addTest(.{
                .name = "core-tests",
                .root_source_file = .{ .path = sdkPath("/src/main.zig") },
                .target = target,
                .optimize = optimize,
            });
            var iter = module(b, optimize, target).dependencies.iterator();
            while (iter.next()) |e| {
                main_tests.addModule(e.key_ptr.*, e.value_ptr.*);
            }
            main_tests.addModule("glfw", b.dependency("mach_glfw", .{
                .target = target,
                .optimize = optimize,
            }).module("mach-glfw"));
            glfwLink(b, main_tests);
            if (target.isLinux()) {
                const gamemode_dep = b.dependency("mach_gamemode", .{});
                main_tests.addModule("gamemode", gamemode_dep.module("mach-gamemode"));
            }
            main_tests.addIncludePath(sdkPath("/include"));
            b.installArtifact(main_tests);
            return b.addRunArtifact(main_tests);
        }

        pub const App = struct {
            b: *std.Build,
            name: []const u8,
            step: *std.build.CompileStep,
            platform: Platform,
            res_dirs: ?[]const []const u8,
            watch_paths: ?[]const []const u8,
            sysjs_dep: ?*std.Build.Dependency,

            const web_install_dir = std.build.InstallDir{ .custom = "www" };

            pub const Platform = enum {
                native,
                web,

                pub fn fromTarget(target: std.Target) Platform {
                    if (target.cpu.arch == .wasm32) return .web;
                    return .native;
                }
            };

            pub fn init(
                b: *std.Build,
                options: struct {
                    name: []const u8,
                    src: []const u8,
                    target: std.zig.CrossTarget,
                    optimize: std.builtin.OptimizeMode,
                    custom_entrypoint: ?[]const u8 = null,
                    deps: ?[]const std.build.ModuleDependency = null,
                    res_dirs: ?[]const []const u8 = null,
                    watch_paths: ?[]const []const u8 = null,
                },
            ) !App {
                const target = (try std.zig.system.NativeTargetInfo.detect(options.target)).target;
                const platform = Platform.fromTarget(target);

                var dependencies = std.ArrayList(std.build.ModuleDependency).init(b.allocator);
                try dependencies.append(.{ .name = "core", .module = module(b, options.optimize, options.target) });
                if (options.deps) |app_deps| try dependencies.appendSlice(app_deps);

                const app_module = b.createModule(.{
                    .source_file = .{ .path = options.src },
                    .dependencies = try dependencies.toOwnedSlice(),
                });

                const sysjs_dep = if (platform == .web) b.dependency("mach_sysjs", .{
                    .target = options.target,
                    .optimize = options.optimize,
                }) else null;

                const step = blk: {
                    if (platform == .web) {
                        const lib = b.addSharedLibrary(.{
                            .name = options.name,
                            .root_source_file = .{ .path = options.custom_entrypoint orelse sdkPath("/src/platform/wasm/entry.zig") },
                            .target = options.target,
                            .optimize = options.optimize,
                        });
                        lib.rdynamic = true;
                        lib.addModule("sysjs", sysjs_dep.?.module("mach-sysjs"));
                        break :blk lib;
                    } else {
                        const exe = b.addExecutable(.{
                            .name = options.name,
                            .root_source_file = .{ .path = options.custom_entrypoint orelse sdkPath("/src/platform/native/entry.zig") },
                            .target = options.target,
                            .optimize = options.optimize,
                        });
                        // TODO(core): figure out why we need to disable LTO: https://github.com/hexops/mach/issues/597
                        exe.want_lto = false;
                        exe.addModule("glfw", b.dependency("mach_glfw", .{
                            .target = exe.target,
                            .optimize = exe.optimize,
                        }).module("mach-glfw"));

                        if (target.os.tag == .linux) {
                            const gamemode_dep = b.dependency("mach_gamemode", .{});
                            exe.addModule("gamemode", gamemode_dep.module("mach-gamemode"));
                        }

                        break :blk exe;
                    }
                };

                if (options.custom_entrypoint == null) step.main_pkg_path = sdkPath("/src");
                step.addModule("core", module(b, options.optimize, options.target));
                step.addModule("app", app_module);

                return .{
                    .b = b,
                    .step = step,
                    .name = options.name,
                    .platform = platform,
                    .res_dirs = options.res_dirs,
                    .watch_paths = options.watch_paths,
                    .sysjs_dep = sysjs_dep,
                };
            }

            pub fn link(app: *const App, options: Options) !void {
                if (app.platform != .web) {
                    glfwLink(app.b, app.step);
                    deps.gpu.link(app.b, app.step, options.gpuOptions()) catch return error.FailedToLinkGPU;
                }
            }

            pub fn install(app: *const App) void {
                app.b.installArtifact(app.step);

                // Install additional files (mach.js and mach-sysjs.js)
                // in case of wasm
                if (app.platform == .web) {
                    // Set install directory to '{prefix}/www'
                    app.getInstallStep().?.dest_dir = web_install_dir;

                    inline for (.{ sdkPath("/src/platform/wasm/mach.js"), @import("mach_sysjs").getJSPath() }) |js| {
                        const install_js = app.b.addInstallFileWithDir(
                            .{ .path = js },
                            web_install_dir,
                            std.fs.path.basename(js),
                        );
                        app.getInstallStep().?.step.dependOn(&install_js.step);
                    }
                }

                // Install resources
                if (app.res_dirs) |res_dirs| {
                    for (res_dirs) |res| {
                        const install_res = app.b.addInstallDirectory(.{
                            .source_dir = .{ .path = res },
                            .install_dir = app.getInstallStep().?.dest_dir,
                            .install_subdir = std.fs.path.basename(res),
                            .exclude_extensions = &.{},
                        });
                        app.getInstallStep().?.step.dependOn(&install_res.step);
                    }
                }
            }

            pub fn addRunArtifact(app: *const App) *std.build.RunStep {
                return app.b.addRunArtifact(app.step);
            }

            pub fn getInstallStep(app: *const App) ?*std.build.InstallArtifactStep {
                return app.b.addInstallArtifact(app.step);
            }
        };
    };
}

const xcode_frameworks = struct {
    pub fn addPaths(b: *std.Build, step: *std.build.CompileStep) void {
        // branch: mach
        xEnsureGitRepoCloned(b.allocator, "https://github.com/hexops/xcode-frameworks", "723aa55e9752c8c6c25d3413722b5fe13d72ac4f", xSdkPath("/zig-cache/xcode_frameworks")) catch |err| @panic(@errorName(err));

        step.addFrameworkPath(xSdkPath("/zig-cache/xcode_frameworks/Frameworks"));
        step.addSystemIncludePath(xSdkPath("/zig-cache/xcode_frameworks/include"));
        step.addLibraryPath(xSdkPath("/zig-cache/xcode_frameworks/lib"));
    }

    fn xEnsureGitRepoCloned(allocator: std.mem.Allocator, clone_url: []const u8, revision: []const u8, dir: []const u8) !void {
        if (xIsEnvVarTruthy(allocator, "NO_ENSURE_SUBMODULES") or xIsEnvVarTruthy(allocator, "NO_ENSURE_GIT")) {
            return;
        }

        xEnsureGit(allocator);

        if (std.fs.openDirAbsolute(dir, .{})) |_| {
            const current_revision = try xGetCurrentGitRevision(allocator, dir);
            if (!std.mem.eql(u8, current_revision, revision)) {
                // Reset to the desired revision
                xExec(allocator, &[_][]const u8{ "git", "fetch" }, dir) catch |err| std.debug.print("warning: failed to 'git fetch' in {s}: {s}\n", .{ dir, @errorName(err) });
                try xExec(allocator, &[_][]const u8{ "git", "checkout", "--quiet", "--force", revision }, dir);
                try xExec(allocator, &[_][]const u8{ "git", "submodule", "update", "--init", "--recursive" }, dir);
            }
            return;
        } else |err| return switch (err) {
            error.FileNotFound => {
                std.log.info("cloning required dependency..\ngit clone {s} {s}..\n", .{ clone_url, dir });

                try xExec(allocator, &[_][]const u8{ "git", "clone", "-c", "core.longpaths=true", clone_url, dir }, ".");
                try xExec(allocator, &[_][]const u8{ "git", "checkout", "--quiet", "--force", revision }, dir);
                try xExec(allocator, &[_][]const u8{ "git", "submodule", "update", "--init", "--recursive" }, dir);
                return;
            },
            else => err,
        };
    }

    fn xExec(allocator: std.mem.Allocator, argv: []const []const u8, cwd: []const u8) !void {
        var child = std.ChildProcess.init(argv, allocator);
        child.cwd = cwd;
        _ = try child.spawnAndWait();
    }

    fn xGetCurrentGitRevision(allocator: std.mem.Allocator, cwd: []const u8) ![]const u8 {
        const result = try std.ChildProcess.exec(.{ .allocator = allocator, .argv = &.{ "git", "rev-parse", "HEAD" }, .cwd = cwd });
        allocator.free(result.stderr);
        if (result.stdout.len > 0) return result.stdout[0 .. result.stdout.len - 1]; // trim newline
        return result.stdout;
    }

    fn xEnsureGit(allocator: std.mem.Allocator) void {
        const argv = &[_][]const u8{ "git", "--version" };
        const result = std.ChildProcess.exec(.{
            .allocator = allocator,
            .argv = argv,
            .cwd = ".",
        }) catch { // e.g. FileNotFound
            std.log.err("mach: error: 'git --version' failed. Is git not installed?", .{});
            std.process.exit(1);
        };
        defer {
            allocator.free(result.stderr);
            allocator.free(result.stdout);
        }
        if (result.term.Exited != 0) {
            std.log.err("mach: error: 'git --version' failed. Is git not installed?", .{});
            std.process.exit(1);
        }
    }

    fn xIsEnvVarTruthy(allocator: std.mem.Allocator, name: []const u8) bool {
        if (std.process.getEnvVarOwned(allocator, name)) |truthy| {
            defer allocator.free(truthy);
            if (std.mem.eql(u8, truthy, "true")) return true;
            return false;
        } else |_| {
            return false;
        }
    }

    fn xSdkPath(comptime suffix: []const u8) []const u8 {
        if (suffix[0] != '/') @compileError("suffix must be an absolute path");
        return comptime blk: {
            const root_dir = std.fs.path.dirname(@src().file) orelse ".";
            break :blk root_dir ++ suffix;
        };
    }
};
