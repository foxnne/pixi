const std = @import("std");
const zstbi = @import("zstbi");

const pixi = @import("../pixi.zig");
const Core = @import("mach").Core;

pub const LDTKTileset = @import("LDTKTileset.zig");

const Packer = @This();

// Mach module, systems, and main
pub const mach_module = .packer;
pub const mach_systems = .{ .init, .deinit };

pub const Image = struct {
    width: usize,
    height: usize,
    pixels: [][4]u8,

    pub fn deinit(self: Image, allocator: std.mem.Allocator) void {
        allocator.free(self.pixels);
    }
};

pub const Sprite = struct {
    image: ?Image = null,
    heightmap_image: ?Image = null,
    origin: [2]i32 = .{ 0, 0 },

    pub fn deinit(self: *Sprite, allocator: std.mem.Allocator) void {
        if (self.image) |*image| {
            image.deinit(allocator);
        }
        if (self.heightmap_image) |*image| {
            image.deinit(allocator);
        }
    }
};

frames: std.ArrayList(zstbi.Rect),
sprites: std.ArrayList(Sprite),
animations: std.ArrayList(pixi.Animation),
id_counter: u32 = 0,
placeholder: Image,
contains_height: bool = false,
open_files: std.ArrayList(pixi.Internal.File),
target: PackTarget = .project,
camera: pixi.gfx.Camera = .{},

ldtk: bool = false,
ldtk_tilesets: std.ArrayList(LDTKTileset),

pub const PackTarget = enum {
    project,
    all_open,
    single_open,
};

pub fn init(packer: *Packer) !void {
    const pixels: [][4]u8 = try pixi.app.allocator.alloc([4]u8, 4);
    for (pixels) |*pixel| {
        pixel[3] = 0;
    }

    packer.* = .{
        .sprites = std.ArrayList(Sprite).init(pixi.app.allocator),
        .frames = std.ArrayList(zstbi.Rect).init(pixi.app.allocator),
        .animations = std.ArrayList(pixi.Animation).init(pixi.app.allocator),
        .open_files = std.ArrayList(pixi.Internal.File).init(pixi.app.allocator),
        .placeholder = .{ .width = 2, .height = 2, .pixels = pixels },
        .ldtk_tilesets = std.ArrayList(LDTKTileset).init(pixi.app.allocator),
    };
}

pub fn newId(self: *Packer) u32 {
    const i = self.id_counter;
    self.id_counter += 1;
    return i;
}

pub fn deinit(self: *Packer) void {
    pixi.app.allocator.free(self.placeholder.pixels);
    self.clearAndFree();
    self.sprites.deinit();
    self.frames.deinit();
    self.animations.deinit();
    self.ldtk_tilesets.deinit();
}

pub fn clearAndFree(self: *Packer) void {
    for (self.sprites.items) |*sprite| {
        sprite.deinit(pixi.app.allocator);
    }
    for (self.animations.items) |*animation| {
        pixi.app.allocator.free(animation.name);
    }
    for (self.ldtk_tilesets.items) |*tileset| {
        for (tileset.layer_paths) |path| {
            pixi.app.allocator.free(path);
        }
        pixi.app.allocator.free(tileset.sprites);
        pixi.app.allocator.free(tileset.layer_paths);
    }
    self.frames.clearAndFree();
    self.sprites.clearAndFree();
    self.animations.clearAndFree();
    self.contains_height = false;
    self.ldtk_tilesets.clearAndFree();

    for (self.open_files.items) |*file| {
        file.deinit();
    }
    self.open_files.clearAndFree();
}

pub fn append(self: *Packer, file: *pixi.Internal.File) !void {
    if (self.ldtk) {
        if (pixi.editor.folder) |project_folder_path| {
            const ldtk_path = try std.fs.path.joinZ(pixi.app.allocator, &.{ project_folder_path, "pixi-ldtk" });
            defer pixi.app.allocator.free(ldtk_path);

            const base_name_w_ext = std.fs.path.basename(file.path);
            const ext = std.fs.path.extension(base_name_w_ext);

            const base_name = base_name_w_ext[0 .. base_name_w_ext.len - ext.len];

            if (std.fs.path.dirname(file.path)) |file_dir_path| {
                const relative_path = file_dir_path[project_folder_path.len..];

                var layer_names = std.ArrayList([:0]const u8).init(pixi.app.allocator);
                var sprites = std.ArrayList(LDTKTileset.LDTKSprite).init(pixi.app.allocator);

                var index: usize = 0;
                while (index < file.layers.slice().len) : (index += 1) {
                    const layer = file.layers.slice().get(index);
                    const layer_name = try std.fmt.allocPrintZ(
                        pixi.app.allocator,
                        "pixi-ldtk{s}{c}{s}__{s}.png",
                        .{ relative_path, std.fs.path.sep, base_name, layer.name },
                    );
                    try layer_names.append(layer_name);
                }

                var sprite_index: usize = 0;
                while (sprite_index < file.sprites.slice().len) : (sprite_index += 1) {
                    const tiles_wide = @divExact(file.width, file.tile_width);

                    const column = @mod(@as(u32, @intCast(sprite_index)), tiles_wide);
                    const row = @divTrunc(@as(u32, @intCast(sprite_index)), tiles_wide);

                    const src_x = column * file.tile_width;
                    const src_y = row * file.tile_height;

                    try sprites.append(.{
                        .src = .{ src_x, src_y },
                    });
                }

                try self.ldtk_tilesets.append(.{
                    .layer_paths = try layer_names.toOwnedSlice(),
                    .sprite_size = .{ file.tile_width, file.tile_height },
                    .sprites = try sprites.toOwnedSlice(),
                });
            }
        }
        return;
    }

    var texture_opt: ?pixi.gfx.Texture = null;
    var index: usize = 0;
    while (index < file.layers.slice().len) : (index += 1) {
        const layer = file.layers.slice().get(index);
        if (!layer.visible) continue;

        const last_item: bool = index == file.layers.slice().len - 1;

        // If this layer is collapsed, we need to record its texture to survive the next loop
        if ((layer.collapse and !last_item) or ((index != 0 and file.layers.slice().get(index - 1).collapse))) {
            const layer_read = layer;

            const texture = if (texture_opt) |carry_over_texture| carry_over_texture else try pixi.gfx.Texture.createEmpty(file.width, file.height, .{});

            const src_pixels = @as([*][4]u8, @ptrCast(layer_read.texture.pixels.ptr))[0 .. layer_read.texture.pixels.len / 4];
            const dst_pixels = @as([*][4]u8, @ptrCast(texture.pixels.ptr))[0 .. texture.pixels.len / 4];

            for (src_pixels, dst_pixels) |src, *dst| {
                if (src[3] != 0 and dst[3] == 0) { //alpha
                    dst.* = src;
                }
            }
            texture_opt = texture;

            if (layer.collapse and !last_item) {
                continue;
            }
        }

        var texture = if (texture_opt) |carry_over_texture| carry_over_texture else layer.texture;

        const layer_width = @as(usize, @intCast(texture.width));
        var sprite_index: usize = 0;
        while (sprite_index < file.sprites.slice().len) : (sprite_index += 1) {
            const sprite = file.sprites.slice().get(sprite_index);
            const tiles_wide = @divExact(file.width, file.tile_width);

            const column = @mod(@as(u32, @intCast(sprite_index)), tiles_wide);
            const row = @divTrunc(@as(u32, @intCast(sprite_index)), tiles_wide);

            const src_x = column * file.tile_width;
            const src_y = row * file.tile_height;

            const src_rect: [4]usize = .{ @as(usize, @intCast(src_x)), @as(usize, @intCast(src_y)), @as(usize, @intCast(file.tile_width)), @as(usize, @intCast(file.tile_height)) };

            if (reduce(&texture, src_rect)) |reduced_rect| {
                const reduced_src_x = reduced_rect[0];
                const reduced_src_y = reduced_rect[1];
                const reduced_src_width = reduced_rect[2];
                const reduced_src_height = reduced_rect[3];

                const offset = .{ reduced_src_x - src_x, reduced_src_y - src_y };
                const src_pixels = @as([*][4]u8, @ptrCast(texture.pixels.ptr))[0 .. texture.pixels.len / 4];

                // Allocate pixels for reduced image
                var image: Image = .{
                    .width = reduced_src_width,
                    .height = reduced_src_height,
                    .pixels = try pixi.app.allocator.alloc([4]u8, reduced_src_width * reduced_src_height),
                };

                var contains_height: bool = false;
                var heightmap_image: ?Image = if (file.heightmap.layer != null) .{
                    .width = reduced_src_width,
                    .height = reduced_src_height,
                    .pixels = try pixi.app.allocator.alloc([4]u8, reduced_src_width * reduced_src_height),
                } else null;

                @memset(image.pixels, .{ 0, 0, 0, 0 });
                if (heightmap_image) |*img| {
                    @memset(img.pixels, .{ 0, 0, 0, 0 });
                }

                // Copy pixels to image
                {
                    var y: usize = reduced_src_y;
                    while (y < reduced_src_y + reduced_src_height) : (y += 1) {
                        const start = reduced_src_x + y * layer_width;
                        const src = src_pixels[start .. start + reduced_src_width];
                        const dst = image.pixels[(y - reduced_src_y) * image.width .. (y - reduced_src_y) * image.width + image.width];
                        @memcpy(dst, src);

                        if (heightmap_image) |heightmap_out| {
                            if (file.heightmap.layer) |heightmap_layer| {
                                const heightmap_pixels = @as([*][4]u8, @ptrCast(heightmap_layer.texture.pixels.ptr))[0 .. heightmap_layer.texture.pixels.len / 4];
                                const heightmap_src = heightmap_pixels[start .. start + reduced_src_width];
                                const heightmap_dst = heightmap_out.pixels[(y - reduced_src_y) * heightmap_out.width .. (y - reduced_src_y) * heightmap_out.width + heightmap_out.width];
                                for (src, heightmap_src, heightmap_dst) |src_pixel, heightmap_src_pixel, *dst_pixel| {
                                    if (src_pixel[3] != 0 and heightmap_src_pixel[3] != 0) {
                                        dst_pixel[0] = heightmap_src_pixel[0];
                                        dst_pixel[1] = heightmap_src_pixel[1];
                                        dst_pixel[2] = heightmap_src_pixel[2];
                                        dst_pixel[3] = heightmap_src_pixel[3];
                                        self.contains_height = true;
                                        contains_height = true;
                                    }
                                }
                            }
                        }
                    }
                }

                if (!contains_height) {
                    if (heightmap_image) |img| {
                        pixi.app.allocator.free(img.pixels);
                        heightmap_image = null;
                    }
                }

                try self.sprites.append(.{
                    .image = image,
                    .heightmap_image = heightmap_image,
                    .origin = .{ @as(i32, @intFromFloat(sprite.origin[0])) - @as(i32, @intCast(offset[0])), @as(i32, @intFromFloat(sprite.origin[1])) - @as(i32, @intCast(offset[1])) },
                });

                try self.frames.append(.{ .id = self.newId(), .w = @as(c_ushort, @intCast(image.width)), .h = @as(c_ushort, @intCast(image.height)) });
            } else {
                var animation_index: usize = 0;
                while (animation_index < file.animations.slice().len) : (animation_index += 1) {
                    const animation = file.animations.slice().get(animation_index);
                    if (sprite_index >= animation.start and sprite_index < animation.start + animation.length) {
                        // Sprite contains no pixels but is part of an animation
                        // To preserve the animation, add a blank pixel to the sprites list
                        try self.sprites.append(.{
                            .image = null,
                            .origin = .{ 0, 0 },
                        });

                        try self.frames.append(.{
                            .id = self.newId(),
                            .w = 2,
                            .h = 2,
                        });
                    }
                }
            }

            var animation_index: usize = 0;
            while (animation_index < file.animations.slice().len) : (animation_index += 1) {
                const animation = file.animations.slice().get(animation_index);
                if (sprite_index == animation.start) {
                    try self.animations.append(.{
                        .name = try std.fmt.allocPrintZ(pixi.app.allocator, "{s}_{s}", .{ animation.name, layer.name }),
                        .start = self.sprites.items.len - 1,
                        .length = animation.length,
                        .fps = animation.fps,
                    });
                }
            }
        }

        if (texture_opt) |*t| {
            t.deinit();
            texture_opt = null;
        }
    }
}

pub fn appendProject(packer: *Packer) !void {
    if (pixi.editor.folder) |root_directory| {
        try recurseFiles(packer, root_directory);
    }
}

pub fn recurseFiles(packer: *Packer, root_directory: [:0]const u8) !void {
    const recursor = struct {
        fn search(p: *Packer, directory: [:0]const u8) !void {
            var dir = try std.fs.cwd().openDir(directory, .{ .access_sub_paths = true, .iterate = true });
            defer dir.close();

            var iter = dir.iterate();
            while (try iter.next()) |entry| {
                if (entry.kind == .file) {
                    const ext = std.fs.path.extension(entry.name);
                    if (std.mem.eql(u8, ext, ".pixi")) {
                        const abs_path = try std.fs.path.joinZ(pixi.app.allocator, &.{ directory, entry.name });
                        defer pixi.app.allocator.free(abs_path);

                        if (pixi.editor.getFileIndex(abs_path)) |index| {
                            if (pixi.editor.getFile(index)) |file| {
                                try p.append(file);
                            }
                        } else {
                            if (try pixi.Internal.File.load(abs_path)) |file| {
                                try p.open_files.append(file);
                                try p.append(&p.open_files.items[p.open_files.items.len - 1]);
                            }
                        }
                    }
                } else if (entry.kind == .directory) {
                    const abs_path = try std.fs.path.joinZ(pixi.app.allocator, &[_][]const u8{ directory, entry.name });
                    defer pixi.app.allocator.free(abs_path);
                    try search(p, abs_path);
                }
            }
        }
    }.search;

    try recursor(packer, root_directory);

    return;
}

pub fn packAndClear(packer: *Packer) !void {
    if (try packer.packRects()) |size| {
        var atlas_texture = try pixi.gfx.Texture.createEmpty(size[0], size[1], .{});

        for (packer.frames.items, packer.sprites.items) |frame, sprite| {
            if (sprite.image) |image|
                atlas_texture.blit(image.pixels, frame.slice());
        }
        atlas_texture.update(pixi.core.windows.get(pixi.app.window, .device));

        if (pixi.editor.atlas.texture) |*texture| {
            texture.deinit();
            pixi.editor.atlas.texture = atlas_texture;
        } else {
            pixi.editor.atlas.texture = atlas_texture;
        }

        if (packer.contains_height) {
            var atlas_texture_h = try pixi.gfx.Texture.createEmpty(size[0], size[1], .{});

            for (packer.frames.items, packer.sprites.items) |frame, sprite| {
                if (sprite.heightmap_image) |image|
                    atlas_texture_h.blit(image.pixels, frame.slice());
            }
            atlas_texture_h.update(pixi.core.windows.get(pixi.app.window, .device));

            if (pixi.editor.atlas.heightmap) |*heightmap| {
                heightmap.deinit();
                pixi.editor.atlas.heightmap = atlas_texture_h;
            } else {
                pixi.editor.atlas.heightmap = atlas_texture_h;
            }
        } else {
            if (pixi.editor.atlas.heightmap) |*heightmap| {
                heightmap.deinit();
            }
        }

        const atlas: pixi.Atlas = .{
            .sprites = try pixi.app.allocator.alloc(pixi.Sprite, packer.sprites.items.len),
            .animations = try pixi.app.allocator.alloc(pixi.Animation, packer.animations.items.len),
        };

        for (atlas.sprites, packer.sprites.items, packer.frames.items) |*dst, src, src_rect| {
            dst.source = .{ src_rect.x, src_rect.y, src_rect.w, src_rect.h };
            dst.origin = src.origin;
        }

        for (atlas.animations, packer.animations.items) |*dst, src| {
            dst.name = try pixi.app.allocator.dupeZ(u8, src.name);
            dst.fps = src.fps;
            dst.length = src.length;
            dst.start = src.start;
        }

        if (pixi.editor.atlas.data) |*data| {
            for (data.animations) |*animation| {
                pixi.app.allocator.free(animation.name);
            }
            pixi.app.allocator.free(data.sprites);
            pixi.app.allocator.free(data.animations);

            pixi.editor.atlas.data = atlas;
        } else {
            pixi.editor.atlas.data = atlas;
        }

        packer.clearAndFree();
    }
}

/// Takes a texture and a src rect and reduces the rect removing all fully transparent pixels
/// If the src rect doesn't contain any opaque pixels, returns null
pub fn reduce(texture: *pixi.gfx.Texture, src: [4]usize) ?[4]usize {
    const pixels = @as([*][4]u8, @ptrCast(texture.pixels.ptr))[0 .. texture.pixels.len / 4];
    const layer_width = @as(usize, @intCast(texture.width));

    const src_x = src[0];
    const src_y = src[1];
    const src_width = src[2];
    const src_height = src[3];

    var top = src_y;
    var bottom = src_y + src_height - 1;
    var left = src_x;
    var right = src_x + src_width - 1;

    top: {
        while (top < bottom) : (top += 1) {
            const start = left + top * layer_width;
            const row = pixels[start .. start + src_width];
            for (row) |pixel| {
                if (pixel[3] != 0) {
                    break :top;
                }
            }
        }
    }
    if (top == bottom) return null;

    bottom: {
        while (bottom > top) : (bottom -= 1) {
            const start = left + bottom * layer_width;
            const row = pixels[start .. start + src_width];
            for (row) |pixel| {
                if (pixel[3] != 0) {
                    if (bottom < src_y + src_height)
                        bottom += 0; // Replace with 1 if needed
                    break :bottom;
                }
            }
        }
    }

    const height = bottom - top + 1;
    if (height == 0)
        return null;

    const new_top: usize = if (top > 0) top - 1 else 0;

    left: {
        while (left < right) : (left += 1) {
            var y = bottom + 1;
            while (y > new_top) {
                y -= 1;
                if (pixels[left + y * layer_width][3] != 0) {
                    break :left;
                }
            }
        }
    }

    right: {
        while (right > left) : (right -= 1) {
            var y = bottom + 1;
            while (y > new_top) {
                y -= 1;
                if (pixels[right + y * layer_width][3] != 0) {
                    if (right < src_x + src_width)
                        right += 1;
                    break :right;
                }
            }
        }
    }

    const width = right - left;
    if (width == 0)
        return null;

    // // If we are packing a tileset, we want a uniform / non-tightly-packed grid. We remove all
    // // completely empty sprite cells (the return null cases above), but do not trim transparent
    // // regions during packing.
    // if (pixi.app.pack_tileset) return src;

    return .{
        left,
        top,
        width,
        height,
    };
}

pub fn packRects(self: *Packer) !?[2]u16 {
    if (self.frames.items.len == 0) return null;

    var ctx: zstbi.Context = undefined;
    const node_count = 4096 * 2;
    var nodes: [node_count]zstbi.Node = undefined;

    const texture_sizes = [_][2]u32{
        [_]u32{ 256, 256 },   [_]u32{ 512, 256 },   [_]u32{ 256, 512 },
        [_]u32{ 512, 512 },   [_]u32{ 1024, 512 },  [_]u32{ 512, 1024 },
        [_]u32{ 1024, 1024 }, [_]u32{ 2048, 1024 }, [_]u32{ 1024, 2048 },
        [_]u32{ 2048, 2048 }, [_]u32{ 4096, 2048 }, [_]u32{ 2048, 4096 },
        [_]u32{ 4096, 4096 }, [_]u32{ 8192, 4096 }, [_]u32{ 4096, 8192 },
    };

    for (texture_sizes) |tex_size| {
        zstbi.initTarget(&ctx, tex_size[0], tex_size[1], &nodes);
        zstbi.setupHeuristic(&ctx, zstbi.Heuristic.skyline_bl_sort_height);
        if (zstbi.packRects(&ctx, self.frames.items) == 1) {
            return .{ @as(u16, @intCast(tex_size[0])), @as(u16, @intCast(tex_size[1])) };
        }
    }

    return null;
}
