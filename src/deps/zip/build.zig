const builtin = @import("builtin");
const std = @import("std");

pub fn build(_: *std.Build) !void {}

pub const Package = struct {
    module: *std.Build.Module,
};

pub fn package(b: *std.Build, _: struct {}) Package {
    const module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = thisDir() ++ "/zip.zig" },
    });
    return .{ .module = module };
}

pub fn link(exe: *std.Build.Step.Compile) void {
    exe.linkLibC();
    exe.addIncludePath(.{ .cwd_relative = thisDir() ++ "/src" });
    const c_flags = [_][]const u8{"-fno-sanitize=undefined"};
    exe.addCSourceFile(.{ .file = .{ .cwd_relative = thisDir() ++ "/src/zip.c" }, .flags = &c_flags });
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
