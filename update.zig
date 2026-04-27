const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;

// url must be something like: https://github.com/nat3Github/zig-lib-dvui-dev-fork
//  branch must be something like main or dev
pub fn get_hash(alloc: Allocator, io: Io, url: []const u8, branch: []const u8) ![]const u8 {
    const get_commit = &.{ "git", "ls-remote", url };
    const dat = try exec(alloc, io, get_commit);
    var tokenizer = std.mem.tokenizeAny(u8, dat, "\r\n");
    var hash: []const u8 = "";
    const refs_heads = "refs/heads/";
    var arlist: std.ArrayList([]const u8) = .empty;
    defer arlist.deinit(alloc);
    while (tokenizer.next()) |token| {
        hash = token[0..40];
        var ref = std.mem.trim(u8, token[40..], " \t");
        if (std.ascii.startsWithIgnoreCase(ref, refs_heads)) ref = ref[refs_heads.len..];
        if (std.mem.eql(u8, branch, ref)) return alloc.dupe(u8, hash);
        try arlist.append(alloc, ref);
    }
    const branches = arlist.items;
    std.log.err("url: {s} BRANCH: '{s}' NOT FOUND", .{ url, branch });
    std.log.info("there are {} other branches:", .{branches.len});
    for (branches[0..@min(10, branches.len)]) |s| {
        std.log.info("{s}", .{s});
    }
    return error.BranchNotFound;
}

pub fn get_zig_fetch_repo_string(alloc: Allocator, io: Io, url: []const u8, branch: []const u8) ![]const u8 {
    const hash = try get_hash(alloc, io, url, branch);
    const repo = try std.fmt.allocPrint(alloc, "git+{s}#{s}", .{ url, hash });
    return repo;
}

pub const GitDependency = struct {
    url: []const u8,
    branch: []const u8,
};

pub fn update_dependency(alloc: Allocator, io: Io, deps: []const GitDependency) !void {
    for (deps) |dep| {
        const rep = try get_zig_fetch_repo_string(alloc, io, dep.url, dep.branch);
        std.log.info("running zig fetch --save {s}", .{rep});
        _ = try exec(alloc, io, &.{
            "zig",
            "fetch",
            "--save",
            rep,
        });
    }
    std.log.info("ok", .{});
}

pub fn exec(alloc: Allocator, io: Io, args: []const []const u8) ![]const u8 {
    const result = try std.process.run(alloc, io, .{ .argv = args });
    defer alloc.free(result.stderr);
    errdefer alloc.free(result.stdout);
    switch (result.term) {
        .exited => |code| if (code != 0) {
            std.log.err("{s}\n", .{result.stderr});
            return error.Failed;
        },
        else => {
            std.log.err("{s}\n", .{result.stderr});
            return error.Failed;
        },
    }
    return result.stdout;
}
