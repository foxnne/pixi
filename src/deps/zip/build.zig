const builtin = @import("builtin");
const std = @import("std");
const Builder = std.build.Builder;

pub const pkg = std.build.Pkg{
    .name = "zip",
    .source = .{ .path = thisDir() ++ "/zip.zig" },
};

pub fn link(exe: *std.build.LibExeObjStep) void {
    const target = (std.zig.system.NativeTargetInfo.detect(exe.target) catch unreachable).target;
    exe.linkLibC();

    switch (target.os.tag) {
        .windows => {},
        .macos => {
            exe.addFrameworkPath(thisDir() ++ "/../zig-gamedev/system-sdk/macos12/System/Library/Frameworks");
            exe.addSystemIncludePath(thisDir() ++ "/../zig-gamedev/system-sdk/macos12/usr/include");
            exe.addLibraryPath(thisDir() ++ "/../zig-gamedev/system-sdk/macos12/usr/lib");
            exe.linkSystemLibraryName("objc");
            exe.linkFramework("Foundation");
            exe.linkFramework("Cocoa");
            exe.linkFramework("Quartz");
            exe.linkFramework("QuartzCore");
            exe.linkFramework("Metal");
            exe.linkFramework("MetalKit");
            exe.linkFramework("OpenGL");
            exe.linkFramework("Audiotoolbox");
            exe.linkFramework("CoreAudio");
            exe.linkSystemLibrary("c++");
        },
        else => {
            exe.linkSystemLibrary("GL");
            exe.linkSystemLibrary("GLEW");
            exe.linkSystemLibrary("X11");
        },
    }

    exe.addIncludePath(thisDir() ++ "/src");
    const c_flags = [_][]const u8{ "-std=c99"};
    exe.addCSourceFile(thisDir() ++ "/src/zip.c", &c_flags);
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
