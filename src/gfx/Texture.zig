const std = @import("std");
const zstbi = @import("zstbi");
const pixi = @import("../pixi.zig");

const gpu = @import("mach").gpu;

const Texture = @This();

/// gpu texture handle
handle: *gpu.Texture,

/// gpu texture view handle
view_handle: *gpu.TextureView,

/// gpu sampler handle
sampler_handle: *gpu.Sampler,

// Image fields
pixels: []u8,
width: u32,
height: u32,
num_components: u32,
bytes_per_component: u32,
bytes_per_row: u32,
is_hdr: bool,

// Options fields
address_mode: gpu.Sampler.AddressMode = .clamp_to_edge,
filter: gpu.FilterMode = .nearest,
format: gpu.Texture.Format = .rgba8_unorm,
storage_binding: bool = false,
texture_binding: bool = true,
copy_dst: bool = true,
copy_src: bool = true,
render_attachment: bool = true,

pub const SamplerOptions = struct {
    address_mode: gpu.Sampler.AddressMode = .clamp_to_edge,
    filter: gpu.FilterMode = .nearest,
    format: gpu.Texture.Format = .rgba8_unorm,
    storage_binding: bool = false,
};

pub fn createEmpty(width: u32, height: u32, options: SamplerOptions) !Texture {
    const image = try zstbi.Image.createEmpty(width, height, 4, .{});
    return create(image, options);
}

pub fn loadFromFile(file: [:0]const u8, options: SamplerOptions) !Texture {
    const image = try zstbi.Image.loadFromFile(file, 4);
    return create(image, options);
}

pub fn loadFromMemory(data: []const u8, options: SamplerOptions) !Texture {
    const image = try zstbi.Image.loadFromMemory(data, 4);
    return create(image, options);
}

pub fn create(image: zstbi.Image, options: SamplerOptions) Texture {
    const device: *gpu.Device = pixi.core.windows.get(pixi.app.window, .device);

    const image_size: gpu.Extent3D = .{ .width = image.width, .height = image.height };

    const texture_descriptor: gpu.Texture.Descriptor = .{
        .size = image_size,
        .format = options.format,
        .usage = .{
            .texture_binding = options.texture_binding,
            .copy_dst = options.copy_dst,
            .copy_src = options.copy_src,
            .render_attachment = options.render_attachment,
            .storage_binding = options.storage_binding,
        },
    };

    const texture = device.createTexture(&texture_descriptor);

    const view_descriptor: gpu.TextureView.Descriptor = .{
        .format = options.format,
        .dimension = .dimension_2d,
        .array_layer_count = 1,
    };

    const queue = device.getQueue();

    const data_layout = gpu.Texture.DataLayout{
        .bytes_per_row = image.width * 4,
        .rows_per_image = image.height,
    };

    queue.writeTexture(&.{ .texture = texture }, &data_layout, &image_size, image.data);

    const view = texture.createView(&view_descriptor);

    const sampler_descriptor: gpu.Sampler.Descriptor = .{
        .address_mode_u = options.address_mode,
        .address_mode_v = options.address_mode,
        .address_mode_w = options.address_mode,
        .mag_filter = options.filter,
        .min_filter = options.filter,
    };

    const sampler = device.createSampler(&sampler_descriptor);

    return Texture{
        .handle = texture,
        .view_handle = view,
        .sampler_handle = sampler,
        .pixels = image.data,
        .width = image.width,
        .height = image.height,
        .num_components = image.num_components,
        .bytes_per_component = image.bytes_per_component,
        .bytes_per_row = image.bytes_per_row,
        .is_hdr = image.is_hdr,
    };
}

pub fn blit(self: *Texture, src_pixels: [][4]u8, dst_rect: [4]u32) void {
    const x = @as(usize, @intCast(dst_rect[0]));
    const y = @as(usize, @intCast(dst_rect[1]));
    const width = @as(usize, @intCast(dst_rect[2]));
    const height = @as(usize, @intCast(dst_rect[3]));

    const tex_width = @as(usize, @intCast(self.width));

    var yy = y;
    var h = height;

    var dst_pixels = @as([*][4]u8, @ptrCast(self.pixels.ptr))[0 .. self.pixels.len / 4];

    var data = dst_pixels[x + yy * tex_width .. x + yy * tex_width + width];
    var src_y: usize = 0;
    while (h > 0) : (h -= 1) {
        const src_row = src_pixels[src_y * width .. (src_y * width) + width];
        @memcpy(data, src_row);

        // next row and move our slice to it as well
        src_y += 1;
        yy += 1;
        data = dst_pixels[x + yy * tex_width .. x + yy * tex_width + width];
    }
}

pub fn update(texture: *Texture, device: *gpu.Device) void {
    const image_size = gpu.Extent3D{ .width = texture.width, .height = texture.height };
    const queue = device.getQueue();

    const data_layout = gpu.Texture.DataLayout{
        .bytes_per_row = texture.width * 4,
        .rows_per_image = texture.height,
    };

    queue.writeTexture(&.{ .texture = texture.handle }, &data_layout, &image_size, texture.pixels);
}

pub fn stbi_image(texture: *const Texture) zstbi.Image {
    return zstbi.Image{
        .data = texture.pixels,
        .width = texture.width,
        .height = texture.height,
        .num_components = texture.num_components,
        .bytes_per_component = texture.bytes_per_component,
        .bytes_per_row = texture.bytes_per_row,
        .is_hdr = texture.is_hdr,
    };
}

pub fn deinit(texture: *Texture) void {
    texture.handle.release();
    texture.view_handle.release();
    texture.sampler_handle.release();

    var image = texture.stbi_image();
    image.deinit();
}
