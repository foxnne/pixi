const MacosWatcher = @This();

const std = @import("std");
const Assets = @import("../../Assets.zig");
const c = @cImport({
    @cInclude("CoreServices/CoreServices.h");
});

const log = std.log.scoped(.watcher);

pub fn init(
    allocator: std.mem.Allocator,
) !MacosWatcher {
    _ = allocator;

    return .{};
}

pub fn callback(
    streamRef: c.ConstFSEventStreamRef,
    clientCallBackInfo: ?*anyopaque,
    numEvents: usize,
    eventPaths: ?*anyopaque,
    eventFlags: ?[*]const c.FSEventStreamEventFlags,
    eventIds: ?[*]const c.FSEventStreamEventId,
) callconv(.C) void {
    _ = eventIds;
    _ = eventFlags;
    _ = streamRef;
    const ctx: *Context = @alignCast(@ptrCast(clientCallBackInfo));

    const paths: [*][*:0]u8 = @alignCast(@ptrCast(eventPaths));
    for (paths[0..numEvents]) |p| {
        const path = std.mem.span(p);

        const basename = std.fs.path.basename(path);
        var base_path = path[0 .. path.len - basename.len];
        if (std.mem.endsWith(u8, base_path, "/"))
            base_path = base_path[0 .. base_path.len - 1];

        ctx.assets.onAssetChange(base_path, basename);
    }
}

pub fn stop(_: *MacosWatcher) void {
    c.CFRunLoopStop(c.CFRunLoopGetCurrent());
}

const Context = struct {
    assets: *Assets,
};
pub fn listen(
    _: *MacosWatcher,
    assets: *Assets,
) !void {
    const in_paths = try assets.getWatchPaths(assets.allocator);
    var macos_paths = try assets.allocator.alloc(c.CFStringRef, in_paths.len);

    for (in_paths, macos_paths[0..]) |str, *ref| {
        ref.* = c.CFStringCreateWithCString(
            null,
            str.ptr,
            c.kCFStringEncodingUTF8,
        );
    }

    const paths_to_watch: c.CFArrayRef = c.CFArrayCreate(
        null,
        @ptrCast(macos_paths.ptr),
        @intCast(macos_paths.len),
        null,
    );

    var ctx: Context = .{
        .assets = assets,
    };

    var stream_context: c.FSEventStreamContext = .{ .info = &ctx };
    const stream: c.FSEventStreamRef = c.FSEventStreamCreate(
        null,
        &callback,
        &stream_context,
        paths_to_watch,
        c.kFSEventStreamEventIdSinceNow,
        0.05,
        c.kFSEventStreamCreateFlagFileEvents,
    );

    c.FSEventStreamScheduleWithRunLoop(
        stream,
        c.CFRunLoopGetCurrent(),
        c.kCFRunLoopDefaultMode,
    );

    if (c.FSEventStreamStart(stream) == 0) {
        @panic("failed to start the event stream");
    }

    // Free allocations before entering the run loop, it will not return
    assets.allocator.free(macos_paths);
    assets.allocator.free(in_paths);

    c.CFRunLoopRun();

    c.FSEventStreamStop(stream);
    c.FSEventStreamInvalidate(stream);
    c.FSEventStreamRelease(stream);

    c.CFRelease(paths_to_watch);
}
