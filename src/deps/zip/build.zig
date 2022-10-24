const builtin = @import("builtin");
const std = @import("std");
const Builder = std.build.Builder;

pub const pkg = std.build.Pkg{
    .name = "zip",
    .source = .{ .path = thisDir() ++ "/zip.zig" },
};

pub fn link(exe: *std.build.LibExeObjStep) void {
    exe.linkLibC();
    exe.addIncludePath(thisDir() ++ "/src");
    const c_flags = [_][]const u8{ "-std=c99", "-fno-sanitize=undefined" };
    exe.addCSourceFile(thisDir() ++ "/src/zip.c", &c_flags);
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
