const std = @import("std");
const pixi = @import("pixi");
const zip = @import("zip");
const zstbi = @import("zstbi");
const zgpu = @import("zgpu");

pub const Style = @import("style.zig");

pub const sidebar = @import("sidebar/sidebar.zig");
pub const explorer = @import("explorer/explorer.zig");
pub const artboard = @import("artboard/artboard.zig");

pub fn draw() void {
    sidebar.draw();
    explorer.draw();
    artboard.draw();
}

pub fn setProjectFolder(path: [*:0]const u8) void {
    pixi.state.project_folder = path[0..std.mem.len(path) :0];
}

/// Returns true if a new file was created.
pub fn newFile(path: [:0]const u8) !bool {
    for (pixi.state.open_files.items) |file, i| {
        if (std.mem.eql(u8, file.path, path)) {
            // Free path since we aren't adding it to open files again.
            pixi.state.allocator.free(path);
            setActiveFile(i);
            return false;
        }
    }
}

/// Returns true if png was imported and new file created.
pub fn importPng(path: [:0]const u8) !bool {
    if (!std.mem.eql(u8, std.fs.path.extension(path[0..path.len]), ".png"))
        return false;

    var new_file_path = pixi.state.allocator.alloc(u8, path.len + 1) catch unreachable;
    _ = std.mem.replace(u8, path, ".png", ".pixi", new_file_path);

    std.log.debug("{s}", .{new_file_path});

    for (pixi.state.open_files.items) |file, i| {
        if (std.mem.eql(u8, file.path, new_file_path)) {
            // Free path since we aren't adding it to open files again.
            pixi.state.allocator.free(new_file_path);
            setActiveFile(i);
            return false;
        }
    }

    return true;
}

/// Returns true if a new file was opened.
pub fn openFile(path: [:0]const u8) !bool {
    if (!std.mem.eql(u8, std.fs.path.extension(path[0..path.len]), ".pixi"))
        return false;

    for (pixi.state.open_files.items) |file, i| {
        if (std.mem.eql(u8, file.path, path)) {
            // Free path since we aren't adding it to open files again.
            pixi.state.allocator.free(path);
            setActiveFile(i);
            return false;
        }
    }

    if (zip.zip_open(path.ptr, 0, 'r')) |pixi_file| {
        defer zip.zip_close(pixi_file);

        var buf: ?*anyopaque = null;
        var size: u64 = 0;
        _ = zip.zip_entry_open(pixi_file, "pixidata.json");
        _ = zip.zip_entry_read(pixi_file, &buf, &size);
        _ = zip.zip_entry_close(pixi_file);

        var content: []const u8 = @ptrCast([*]const u8, buf)[0..size];
        const options = std.json.ParseOptions{
            .allocator = pixi.state.allocator,
            .duplicate_field_behavior = .UseFirst,
            .ignore_unknown_fields = true,
            .allow_trailing_data = true,
        };

        var stream = std.json.TokenStream.init(content);
        const external = std.json.parse(pixi.storage.External.Pixi, &stream, options) catch unreachable;
        defer std.json.parseFree(pixi.storage.External.Pixi, external, options);

        var internal: pixi.storage.Internal.Pixi = .{
            .path = path,
            .width = external.width,
            .height = external.height,
            .tile_width = external.tileWidth,
            .tile_height = external.tileHeight,
            .layers = std.ArrayList(pixi.storage.Internal.Layer).init(pixi.state.allocator),
            .sprites = std.ArrayList(pixi.storage.Internal.Sprite).init(pixi.state.allocator),
            .animations = std.ArrayList(pixi.storage.Internal.Animation).init(pixi.state.allocator),
            .flipbook_camera = .{ .position = .{ -@intToFloat(f32, external.tileWidth) / 2.0, 0.0 } },
            .background_image = undefined,
            .background_image_data = undefined,
            .background_texture_handle = undefined,
            .background_texture_view_handle = undefined,
            .dirty = false,
        };

        // Handle background image/texture
        {
            internal.background_image_data = try pixi.state.allocator.alloc(u8, @intCast(usize, external.tileWidth * 2 * external.tileHeight * 2 * 4));
            internal.background_image = pixi.gfx.createImage(internal.background_image_data, external.tileWidth * 2, external.tileHeight * 2);
            // Set background image data to checkerboard
            {
                var i: usize = 0;
                while (i < @intCast(usize, external.tileWidth * 2 * external.tileHeight * 2 * 4)) : (i += 4) {
                    const r = i;
                    const g = i + 1;
                    const b = i + 2;
                    const a = i + 3;
                    const primary = pixi.state.style.checkerboard_primary.bytes();
                    const secondary = pixi.state.style.checkerboard_secondary.bytes();
                    if (i % 3 == 0) {
                        internal.background_image.data[r] = primary[0];
                        internal.background_image.data[g] = primary[1];
                        internal.background_image.data[b] = primary[2];
                        internal.background_image.data[a] = primary[3];
                    } else {
                        internal.background_image.data[r] = secondary[0];
                        internal.background_image.data[g] = secondary[1];
                        internal.background_image.data[b] = secondary[2];
                        internal.background_image.data[a] = secondary[3];
                    }
                }
            }
            internal.background_texture_handle = pixi.state.gctx.createTexture(.{
                .usage = .{ .texture_binding = true, .copy_dst = true },
                .size = .{
                    .width = external.tileWidth * 2,
                    .height = external.tileHeight * 2,
                    .depth_or_array_layers = 1,
                },
                .format = zgpu.imageInfoToTextureFormat(4, 1, false),
            });
            internal.background_texture_view_handle = pixi.state.gctx.createTextureView(internal.background_texture_handle, .{});
            pixi.state.gctx.queue.writeTexture(
                .{ .texture = pixi.state.gctx.lookupResource(internal.background_texture_handle).? },
                .{
                    .bytes_per_row = internal.background_image.bytes_per_row,
                    .rows_per_image = internal.background_image.height,
                },
                .{ .width = internal.background_image.width, .height = internal.background_image.height },
                u8,
                internal.background_image.data,
            );
        }

        for (external.layers) |layer| {
            const layer_image_name = try std.fmt.allocPrintZ(pixi.state.allocator, "{s}.png", .{layer.name});
            defer pixi.state.allocator.free(layer_image_name);

            var img_buf: ?*anyopaque = null;
            var img_len: usize = 0;

            _ = zip.zip_entry_open(pixi_file, layer_image_name.ptr);
            _ = zip.zip_entry_read(pixi_file, &img_buf, &img_len);
            defer _ = zip.zip_entry_close(pixi_file);

            if (img_buf) |data| {
                var new_layer: pixi.storage.Internal.Layer = .{
                    .name = try pixi.state.allocator.dupeZ(u8, layer.name),
                    .texture_handle = undefined,
                    .texture_view_handle = undefined,
                    .image = undefined,
                    .data = undefined,
                };

                new_layer.texture_handle = pixi.state.gctx.createTexture(.{
                    .usage = .{ .texture_binding = true, .copy_dst = true },
                    .size = .{
                        .width = external.width,
                        .height = external.height,
                        .depth_or_array_layers = 1,
                    },
                    .format = zgpu.imageInfoToTextureFormat(4, 1, false),
                });

                new_layer.texture_view_handle = pixi.state.gctx.createTextureView(new_layer.texture_handle, .{});
                new_layer.data = try pixi.state.allocator.dupe(u8, @ptrCast([*]u8, data)[0..img_len]);
                new_layer.image = try zstbi.Image.initFromData(@ptrCast([*]u8, new_layer.data)[0..img_len], 4);

                pixi.state.gctx.queue.writeTexture(
                    .{ .texture = pixi.state.gctx.lookupResource(new_layer.texture_handle).? },
                    .{
                        .bytes_per_row = new_layer.image.bytes_per_row,
                        .rows_per_image = new_layer.image.height,
                    },
                    .{ .width = new_layer.image.width, .height = new_layer.image.height },
                    u8,
                    new_layer.image.data,
                );

                try internal.layers.append(new_layer);
            }
        }

        for (external.sprites) |sprite, i| {
            try internal.sprites.append(.{
                .name = try pixi.state.allocator.dupeZ(u8, sprite.name),
                .index = i,
                .origin_x = sprite.origin_x,
                .origin_y = sprite.origin_y,
            });
        }

        for (external.animations) |animation| {
            try internal.animations.append(.{
                .name = try pixi.state.allocator.dupeZ(u8, animation.name),
                .start = animation.start,
                .length = animation.length,
                .fps = animation.fps,
            });
        }

        try pixi.state.open_files.insert(0, internal);
        setActiveFile(0);
        return true;
    }

    pixi.state.allocator.free(path);
    return error.FailedToOpenFile;
}

pub fn setActiveFile(index: usize) void {
    if (index >= pixi.state.open_files.items.len) return;
    pixi.state.open_file_index = index;
}

pub fn getFileIndex(path: [:0]const u8) ?usize {
    for (pixi.state.open_files.items) |file, i| {
        if (std.mem.eql(u8, file.path, path))
            return i;
    }
    return null;
}

pub fn getFile(index: usize) ?*pixi.storage.Internal.Pixi {
    if (index >= pixi.state.open_files.items.len) return null;

    return &pixi.state.open_files.items[index];
}

pub fn closeFile(index: usize) !void {
    pixi.state.open_file_index = 0;
    var file = pixi.state.open_files.swapRemove(index);
    pixi.state.allocator.free(file.background_image_data);
    for (file.layers.items) |*layer| {
        pixi.state.gctx.releaseResource(layer.texture_handle);
        pixi.state.gctx.releaseResource(layer.texture_view_handle);
        pixi.state.gctx.releaseResource(file.background_texture_handle);
        pixi.state.gctx.releaseResource(file.background_texture_view_handle);
        pixi.state.allocator.free(layer.name);
        layer.image.deinit();
        pixi.state.allocator.free(layer.data);
    }
    for (file.sprites.items) |*sprite| {
        pixi.state.allocator.free(sprite.name);
    }
    for (file.animations.items) |*animation| {
        pixi.state.allocator.free(animation.name);
    }
    file.layers.deinit();
    file.sprites.deinit();
    file.animations.deinit();
    pixi.state.allocator.free(file.path);
}

pub fn deinit() void {
    for (pixi.state.open_files.items) |_| {
        try closeFile(0);
    }
    pixi.state.open_files.deinit();
}
