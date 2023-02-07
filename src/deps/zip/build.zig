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
    exe.addIncludePath(thisDir() ++ "/src");
    const c_flags = [_][]const u8{ "-std=c99", "-fno-sanitize=undefined" };
    exe.addCSourceFile(thisDir() ++ "/src/zip.c", &c_flags);
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
