const std = @import("std");
const builtin = @import("builtin");

const mach_core = @import("mach_core");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const use_dusk = b.option(bool, "use_dusk", "Use Dusk") orelse false;
    const use_freetype = b.option(bool, "use_freetype", "Use Freetype") orelse false;

    const mach_core_dep = b.dependency("mach_core", .{
        .target = target,
        .optimize = optimize,
    });

    const module = b.addModule("zig-imgui", .{
        .source_file = .{ .path = "src/imgui.zig" },
        .dependencies = &.{
            .{ .name = "mach-core", .module = mach_core_dep.module("mach-core") },
        },
    });

    const lib = b.addStaticLibrary(.{
        .name = "imgui",
        .root_source_file = .{ .path = "src/cimgui.cpp" },
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibC();

    const imgui_dep = b.dependency("imgui", .{});

    var files = std.ArrayList([]const u8).init(b.allocator);
    defer files.deinit();

    var flags = std.ArrayList([]const u8).init(b.allocator);
    defer flags.deinit();

    try files.appendSlice(&.{
        imgui_dep.path("imgui.cpp").getPath(b),
        imgui_dep.path("imgui_widgets.cpp").getPath(b),
        imgui_dep.path("imgui_tables.cpp").getPath(b),
        imgui_dep.path("imgui_draw.cpp").getPath(b),
        imgui_dep.path("imgui_demo.cpp").getPath(b),
    });

    if (use_freetype) {
        try flags.append("-DIMGUI_ENABLE_FREETYPE");
        try files.append("imgui/misc/freetype/imgui_freetype.cpp");

        lib.linkLibrary(b.dependency("freetype", .{
            .target = target,
            .optimize = optimize,
        }).artifact("freetype"));
    }

    lib.addIncludePath(imgui_dep.path("."));
    lib.addCSourceFiles(.{
        .files = files.items,
        .flags = flags.items,
    });
    b.installArtifact(lib);

    // Example
    const build_options = b.addOptions();
    build_options.addOption(bool, "use_dusk", use_dusk);

    const app = try mach_core.App.init(b, mach_core_dep.builder, .{
        .name = "mach-imgui-example",
        .src = "examples/example_mach.zig",
        .target = target,
        .deps = &[_]std.build.ModuleDependency{
            .{ .name = "imgui", .module = module },
            .{ .name = "build-options", .module = build_options.createModule() },
        },
        .optimize = optimize,
    });
    app.compile.linkLibrary(lib);

    if (use_dusk) {
        const mach_dusk_dep = b.dependency("mach_dusk", .{
            .target = target,
            .optimize = optimize,
        });
        app.compile.linkLibrary(mach_dusk_dep.artifact("mach-dusk"));
        @import("mach_dusk").link(mach_dusk_dep.builder, app.compile);
    }

    const run_step = b.step("run", "Run the example");
    run_step.dependOn(&app.run.step);

    // Generator
    const generator_exe = b.addExecutable(.{
        .name = "mach-imgui-generator",
        .root_source_file = .{ .path = "src/generate.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(generator_exe);

    const generate_step = b.step("generate", "Generate the bindings");
    generate_step.dependOn(&b.addRunArtifact(generator_exe).step);
}
