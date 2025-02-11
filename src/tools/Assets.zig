const std = @import("std");
const zstbi = @import("zstbi");
const mach = @import("mach");
const builtin = @import("builtin");
const pixi = @import("../pixi.zig");

const Assets = @This();

pub const AssetType = enum {
    texture,
    atlas,
    unsupported,
};

// Mach module, systems, and main
pub const mach_module = .assets;
pub const mach_systems = .{ .init, .listen, .deinit };
pub const mach_tags = .{.auto_reload};

const log = std.log.scoped(.watcher);
const ListenerFn = fn (self: *Assets, path: []const u8, name: []const u8) void;
const Watcher = switch (builtin.target.os.tag) {
    .linux => @import("watcher/LinuxWatcher.zig"),
    .macos => @import("watcher/MacosWatcher.zig"),
    .windows => @import("watcher/WindowsWatcher.zig"),
    else => @compileError("unsupported platform"),
};

textures: mach.Objects(.{ .track_fields = false }, struct {
    path: [:0]const u8,
    options: pixi.gfx.Texture.SamplerOptions = .{},
    texture: ?pixi.gfx.Texture = null,
}),

atlases: mach.Objects(.{ .track_fields = false }, struct {
    path: [:0]const u8,
    atlas: ?pixi.Atlas = null,
}),

allocator: std.mem.Allocator,
watcher: Watcher = undefined,
thread: std.Thread = undefined,
watching: bool = false,

var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;

pub fn init(assets: *Assets) !void {
    const allocator = gpa.allocator();

    zstbi.init(allocator);
    assets.* = .{
        .textures = assets.textures,
        .atlases = assets.atlases,
        .allocator = allocator,
    };
}

pub fn loadTexture(assets: *Assets, path: []const u8, options: pixi.gfx.Texture.SamplerOptions) !mach.ObjectID {
    assets.textures.lock();
    defer assets.textures.unlock();

    const term_path = try std.fmt.allocPrintZ(assets.allocator, "{s}", .{path});

    const id = try assets.textures.new(.{
        .path = term_path,
        .texture = pixi.gfx.Texture.loadFromFile(term_path, options) catch null,
        .options = options,
    });

    return id;
}

pub fn loadAtlas(assets: *Assets, path: []const u8) !mach.ObjectID {
    assets.atlases.lock();
    defer assets.atlases.unlock();

    const term_path = try std.fmt.allocPrintZ(assets.allocator, "{s}", .{path});

    const id = try assets.atlases.new(.{
        .path = term_path,
        .atlas = pixi.Atlas.loadFromFile(assets.allocator, term_path) catch null,
    });

    return id;
}

pub fn reload(assets: *Assets, id: mach.ObjectID) !void {
    if (assets.textures.is(id)) {
        var t = assets.textures.getValue(id);
        defer assets.textures.setValueRaw(id, t);
        if (t.texture) |*texture| texture.deinit();
        t.texture = pixi.gfx.Texture.loadFromFile(t.path, t.options) catch null;
    } else if (assets.atlases.is(id)) {
        var a = assets.atlases.getValue(id);
        defer assets.atlases.setValueRaw(id, a);
        if (a.atlas) |*atlas| atlas.deinit(assets.allocator);
        a.atlas = pixi.Atlas.loadFromFile(assets.allocator, a.path) catch null;
    }
}

pub fn getTexture(assets: *Assets, id: mach.ObjectID) ?pixi.gfx.Texture {
    return assets.textures.get(id, .texture);
}

pub fn getAtlas(assets: *Assets, id: mach.ObjectID) ?pixi.Atlas {
    return assets.atlases.get(id, .atlas);
}

pub fn getPath(assets: *Assets, id: mach.ObjectID) []const u8 {
    if (assets.textures.is(id))
        return assets.textures.get(id, .path)
    else if (assets.atlases.is(id))
        return assets.atlases.get(id, .path)
    else
        return "";
}

/// Returns the watch paths for the currently loaded assets.
/// Caller owns the memory.
pub fn getWatchPaths(assets: *Assets, allocator: std.mem.Allocator) ![]const []const u8 {
    var paths = std.ArrayList([]const u8).init(allocator);

    var textures = assets.textures.slice();
    while (textures.next()) |id|
        try paths.append(textures.objs.get(id, .path));

    var atlases = assets.atlases.slice();
    while (atlases.next()) |id|
        try paths.append(atlases.objs.get(id, .path));

    return paths.toOwnedSlice();
}

/// Returns the watch directories for the currently loaded assets.
/// Caller owns the memory.
pub fn getWatchDirs(assets: *Assets, allocator: std.mem.Allocator) ![]const []const u8 {
    var dirs = std.ArrayList([]const u8).init(allocator);

    var textures = assets.textures.slice();
    tex_blk: while (textures.next()) |id| {
        if (std.fs.path.dirname(textures.objs.get(id, .path))) |tex_dir| {
            for (dirs.items) |dir| {
                if (std.mem.eql(u8, dir, tex_dir)) {
                    continue :tex_blk;
                }
            }

            try dirs.append(tex_dir);
        }
    }

    var atlases = assets.atlases.slice();
    atl_blk: while (atlases.next()) |id| {
        if (std.fs.path.dirname(atlases.objs.get(id, .path))) |atl_dir| {
            for (dirs.items) |dir| {
                if (std.mem.eql(u8, dir, atl_dir)) {
                    continue :atl_blk;
                }
            }

            try dirs.append(atl_dir);
        }
    }

    return dirs.toOwnedSlice();
}

/// Spawns a watch thread for all of the currently registered assets
/// If you add or change assets, you need to call stopWatch and then watch again to reset the background thread
pub fn watch(assets: *Assets) !void {
    if (!assets.watching)
        try spawnWatchThread(assets);
}

/// Stops the asset watching thread
pub fn stopWatch(assets: *Assets) void {
    assets.stopWatchThread();
}

fn spawnWatchThread(assets: *Assets) !void {
    assets.watcher = try Watcher.init(assets.allocator);
    assets.thread = try std.Thread.spawn(.{}, listen, .{assets});
    assets.thread.detach();
    assets.watching = true;
}

fn stopWatchThread(assets: *Assets) void {
    assets.watching = false;
    assets.watcher.stop();
    //assets.thread.join();
    //assets.thread = undefined;
}

/// Kicks off the listening loop, this will not return
pub fn listen(assets: *Assets) !void {
    try assets.watcher.listen(assets);
}

fn comparePaths(allocator: std.mem.Allocator, path1: []const u8, path2: []const u8) !bool {
    const rel_1 = try std.fs.path.relative(allocator, pixi.app.root_path, path1);
    const rel_2 = try std.fs.path.relative(allocator, pixi.app.root_path, path2);

    std.log.debug("{s} {s}", .{ rel_1, rel_2 });

    defer allocator.free(rel_1);
    defer allocator.free(rel_2);

    return std.mem.eql(u8, rel_1, rel_2);
}

/// Called from the watchers when assets change, this is where we reload our assets based on path.
pub fn onAssetChange(assets: *Assets, path: []const u8, name: []const u8) void {
    const changed_path = std.fs.path.join(assets.allocator, &.{ path, name }) catch return;
    defer assets.allocator.free(changed_path);

    const extension = std.fs.path.extension(name);

    var asset_type: AssetType = .unsupported;

    if (std.mem.eql(u8, extension, ".png") or std.mem.eql(u8, extension, ".jpg"))
        asset_type = .texture
    else if (std.mem.eql(u8, extension, ".atlas"))
        asset_type = .atlas;

    switch (asset_type) {
        .texture => {
            var textures = assets.textures.slice();
            while (textures.next()) |texture_id| {
                if (!assets.textures.hasTag(texture_id, Assets, .auto_reload)) continue;

                const p = assets.getPath(texture_id);
                if (comparePaths(assets.allocator, changed_path, p) catch false) {
                    try assets.reload(texture_id);

                    std.log.debug("Reloaded texture {s}", .{changed_path});
                }
            }
        },
        .atlas => {
            var atlases = assets.atlases.slice();
            while (atlases.next()) |atlas_id| {
                if (!assets.atlases.hasTag(atlas_id, Assets, .auto_reload)) continue;

                const p = assets.getPath(atlas_id);
                if (comparePaths(assets.allocator, changed_path, p) catch false) {
                    try assets.reload(atlas_id);

                    std.log.debug("Reloaded atlas {s}", .{changed_path});
                }
            }
        },
        .unsupported => {},
    }
}

pub fn deinit(assets: *Assets) void {
    assets.stopWatch();

    var textures = assets.textures.slice();
    while (textures.next()) |id| {
        var t = assets.textures.getValue(id);
        if (t.texture) |*texture| texture.deinit();

        assets.allocator.free(textures.objs.get(id, .path));
    }

    var atlases = assets.atlases.slice();
    while (atlases.next()) |id| {
        var a = assets.atlases.getValue(id);
        if (a.atlas) |*atlas| atlas.deinit(assets.allocator);

        assets.allocator.free(atlases.objs.get(id, .path));
    }

    zstbi.deinit();
}
