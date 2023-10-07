const builtin = @import("builtin");
const std = @import("std");

pub fn build(_: *std.Build) !void {}

pub const Package = struct {
    module: *std.Build.Module,
};

pub fn package(b: *std.Build, _: struct {}) Package {
    const module = b.createModule(.{
        .source_file = .{ .path = thisDir() ++ "/zip.zig" },
    });
    return .{ .module = module };
}

pub fn link(exe: *std.Build.CompileStep) void {
    exe.linkLibC();
    exe.addIncludePath(.{ .path = thisDir() ++ "/src" });
    const c_flags = [_][]const u8{"-fno-sanitize=undefined"};
    exe.addCSourceFile(.{ .file = .{ .path = thisDir() ++ "/src/zip.c" }, .flags = &c_flags });
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
