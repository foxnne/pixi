const builtin = @import("builtin");
const std = @import("std");
const Builder = std.build.Builder;

pub const pkg = std.build.Pkg{
    .name = "filebrowser",
    .source = .{ .path = thisDir() ++ "/filebrowser.zig" },
};

pub fn link(exe: *std.build.LibExeObjStep) void {
    const target = (std.zig.system.NativeTargetInfo.detect(exe.target) catch unreachable).target;
    if (target.os.tag == .windows) {
        exe.linkSystemLibrary("comdlg32");
        exe.linkSystemLibrary("ole32");
        exe.linkSystemLibrary("user32");
        exe.linkSystemLibrary("shell32");
        exe.linkSystemLibrary("c");
    }
    exe.linkLibC();

    const lib_cflags = &[_][]const u8{ "-D_CRT_SECURE_NO_WARNINGS", "-D_CRT_SECURE_NO_DEPRECATE" };
    exe.addCSourceFile(thisDir() ++ "/src/tinyfiledialogs.c", lib_cflags);
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
