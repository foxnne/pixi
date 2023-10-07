const std = @import("std");

pub fn Package(comptime deps: anytype) type {
    return struct {
        pub const Backend = enum {
            no_backend,
            glfw_wgpu,
            win32_dx12,
            mach,
        };
        pub const Options = struct {
            backend: Backend,
            shared: bool = false,
        };

        options: Options,
        zgui: *std.Build.Module,
        zgui_options: *std.Build.Module,
        zgui_c_cpp: *std.Build.CompileStep,

        pub fn build(
            b: *std.Build,
            target: std.zig.CrossTarget,
            optimize: std.builtin.Mode,
            args: struct {
                options: Options,
                gpu_dawn_options: deps.gpu_dawn.Options,
            },
        ) !@This() {
            const step = b.addOptions();
            step.addOption(Backend, "backend", args.options.backend);
            step.addOption(bool, "shared", args.options.shared);

            const zgui_options = step.createModule();

            const zgui = b.createModule(.{
                .source_file = .{ .path = thisDir() ++ "/src/main.zig" },
                .dependencies = &.{
                    .{ .name = "zgui_options", .module = zgui_options },
                },
            });

            const zgui_c_cpp = if (args.options.shared) blk: {
                const lib = b.addSharedLibrary(.{
                    .name = "zgui",
                    .target = target,
                    .optimize = optimize,
                });

                b.installArtifact(lib);
                if (target.isWindows()) {
                    lib.defineCMacro("IMGUI_API", "__declspec(dllexport)");
                    lib.defineCMacro("IMPLOT_API", "__declspec(dllexport)");
                    lib.defineCMacro("ZGUI_API", "__declspec(dllexport)");
                }

                break :blk lib;
            } else b.addStaticLibrary(.{
                .name = "zgui",
                .target = target,
                .optimize = optimize,
            });

            zgui_c_cpp.addIncludePath(.{ .path = thisDir() ++ "/libs" });
            zgui_c_cpp.addIncludePath(.{ .path = thisDir() ++ "/libs/imgui" });
            zgui_c_cpp.addIncludePath(.{ .path = thisDir() ++ "/libs/imgui/backends" });

            zgui_c_cpp.linkLibC();
            zgui_c_cpp.linkLibCpp();

            const cflags = &.{"-fno-sanitize=undefined"};

            zgui_c_cpp.addCSourceFile(.{ .file = .{ .path = thisDir() ++ "/src/zgui.cpp" }, .flags = cflags });

            zgui_c_cpp.addCSourceFile(.{ .file = .{ .path = thisDir() ++ "/libs/imgui/imgui.cpp" }, .flags = cflags });
            zgui_c_cpp.addCSourceFile(.{ .file = .{ .path = thisDir() ++ "/libs/imgui/imgui_widgets.cpp" }, .flags = cflags });
            zgui_c_cpp.addCSourceFile(.{ .file = .{ .path = thisDir() ++ "/libs/imgui/imgui_tables.cpp" }, .flags = cflags });
            zgui_c_cpp.addCSourceFile(.{ .file = .{ .path = thisDir() ++ "/libs/imgui/imgui_draw.cpp" }, .flags = cflags });
            zgui_c_cpp.addCSourceFile(.{ .file = .{ .path = thisDir() ++ "/libs/imgui/imgui_demo.cpp" }, .flags = cflags });

            zgui_c_cpp.addCSourceFile(.{ .file = .{ .path = thisDir() ++ "/libs/imgui/implot_demo.cpp" }, .flags = cflags });
            zgui_c_cpp.addCSourceFile(.{ .file = .{ .path = thisDir() ++ "/libs/imgui/implot.cpp" }, .flags = cflags });
            zgui_c_cpp.addCSourceFile(.{ .file = .{ .path = thisDir() ++ "/libs/imgui/implot_items.cpp" }, .flags = cflags });

            switch (args.options.backend) {
                .mach => {
                    zgui_c_cpp.addCSourceFile(.{ .file = .{ .path = thisDir() ++ "/libs/imgui/backends/imgui_impl_wgpu.cpp" }, .flags = cflags });
                    zgui_c_cpp.addCSourceFile(.{ .file = .{ .path = thisDir() ++ "/libs/imgui/imgui_impl_mach.cpp" }, .flags = cflags });
                    deps.gpu_dawn.link(b, zgui_c_cpp, args.gpu_dawn_options);
                },
                .glfw_wgpu => {
                    zgui_c_cpp.addIncludePath(.{ .path = thisDir() ++ "/../zglfw/libs/glfw/include" });
                    zgui_c_cpp.addIncludePath(.{ .path = thisDir() ++ "/../zgpu/libs/dawn/include" });
                    zgui_c_cpp.addCSourceFile(.{ .file = .{ .path = thisDir() ++ "/libs/imgui/backends/imgui_impl_glfw.cpp" }, .flags = cflags });
                    zgui_c_cpp.addCSourceFile(.{ .file = .{ .path = thisDir() ++ "/libs/imgui/backends/imgui_impl_wgpu.cpp" }, .flags = cflags });
                },
                .win32_dx12 => {
                    zgui_c_cpp.addCSourceFile(.{ .file = .{ .path = thisDir() ++ "/libs/imgui/backends/imgui_impl_win32.cpp" }, .flags = cflags });
                    zgui_c_cpp.addCSourceFile(.{ .file = .{ .path = thisDir() ++ "/libs/imgui/backends/imgui_impl_dx12.cpp" }, .flags = cflags });
                    zgui_c_cpp.linkSystemLibraryName("d3dcompiler_47");
                    zgui_c_cpp.linkSystemLibraryName("dwmapi");
                },
                .no_backend => {},
            }

            return .{
                .options = args.options,
                .zgui = zgui,
                .zgui_options = zgui_options,
                .zgui_c_cpp = zgui_c_cpp,
            };
        }

        pub fn link(zgui_pkg: @This(), exe: *std.Build.CompileStep) void {
            exe.linkLibrary(zgui_pkg.zgui_c_cpp);
            exe.addIncludePath(.{ .path = thisDir() ++ "/src" });
            exe.addIncludePath(.{ .path = thisDir() ++ "/libs" });
            exe.addIncludePath(.{ .path = thisDir() ++ "/libs/imgui" });
            exe.addIncludePath(.{ .path = thisDir() ++ "/libs/imgui/backends" });
        }
    };
}

pub fn build(_: *std.Build) void {}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
