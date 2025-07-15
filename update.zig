const std = @import("std");
const Allocator = std.mem.Allocator;
const Child = std.process.Child;

// url must be something like: https://github.com/nat3Github/zig-lib-dvui-dev-fork
//  branch must be something like main or dev
pub fn get_hash(alloc: Allocator, url: []const u8, branch: []const u8) ![]const u8 {
    const get_commit = &.{ "git", "ls-remote", url };
    const dat = try exec(alloc, get_commit);
    var tokenizer = std.mem.tokenizeAny(u8, dat, "\r\n");
    var hash: []const u8 = "";
    const refs_heads = "refs/heads/";
    var arlist = std.ArrayList([]const u8).init(alloc);
    defer arlist.deinit();
    while (tokenizer.next()) |token| {
        hash = token[0..40];
        var ref = std.mem.trim(u8, token[40..], " \t");
        if (std.ascii.startsWithIgnoreCase(ref, refs_heads)) ref = ref[refs_heads.len..];
        if (std.mem.eql(u8, branch, ref)) return alloc.dupe(u8, hash);
        try arlist.append(ref);
    }
    const branches = arlist.items;
    std.log.err("url: {s} BRANCH: '{s}' NOT FOUND", .{ url, branch });
    std.log.info("there are {} other branches:", .{branches.len});
    for (branches[0..@min(10, branches.len)]) |s| {
        std.log.info("{s}", .{s});
    }
    return error.BranchNotFound;
}

pub fn get_zig_fetch_repo_string(alloc: Allocator, url: []const u8, branch: []const u8) ![]const u8 {
    const hash = try get_hash(alloc, url, branch);
    const repo = try std.fmt.allocPrint(alloc, "git+{s}#{s}", .{ url, hash });
    return repo;
}

pub const GitDependency = struct {
    url: []const u8,
    branch: []const u8,
};

pub fn update_dependency(alloc: Allocator, deps: []const GitDependency) !void {
    for (deps) |dep| {
        const rep = try get_zig_fetch_repo_string(alloc, dep.url, dep.branch);
        std.log.info("running zig fetch --save {s}", .{rep});
        _ = try exec(alloc, &.{
            "zig",
            "fetch",
            "--save",
            rep,
        });
    }
    std.log.info("ok", .{});
}
pub fn exec(alloc: Allocator, args: []const []const u8) ![]const u8 {
    var caller = Child.init(args, alloc);
    caller.stdout_behavior = .Pipe;
    caller.stderr_behavior = .Pipe;
    var stdout = std.ArrayListUnmanaged(u8){};
    var stderr = std.ArrayListUnmanaged(u8){};
    errdefer stdout.deinit(alloc);
    defer stderr.deinit(alloc);
    try caller.spawn();
    try caller.collectOutput(alloc, &stdout, &stderr, 1024 * 1024);
    const res = try caller.wait();
    if (res.Exited > 0) {
        std.log.err("{s}\n", .{stderr.items});
        return error.Failed;
    } else {
        return stdout.items;
    }
}
