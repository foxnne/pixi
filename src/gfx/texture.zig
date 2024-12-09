const std = @import("std");
const glfw = @import("glfw");
const zgpu = @import("zgpu");
const zstbi = @import("zstbi");
const wgpu = zgpu.wgpu;
const zm = @import("zmath");
const pixi = @import("../pixi.zig");

const Core = @import("mach").Core;
const gpu = @import("mach").gpu;

const game = @import("game");

pub const Texture = struct {
    handle: *gpu.Texture,
    view_handle: *gpu.TextureView,
    sampler_handle: *gpu.Sampler,
    image: zstbi.Image,

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
        const image = try zstbi.Image.loadFromMemory(data, 0);
        return create(image, options);
    }

    pub fn create(image: zstbi.Image, options: SamplerOptions) Texture {
        const device = pixi.state.device;

        const image_size = .{ .width = image.width, .height = image.height };

        const texture_descriptor = .{
            .size = image_size,
            .format = options.format,
            .usage = .{
                .texture_binding = true,
                .copy_dst = true,
                .copy_src = true,
                .render_attachment = true,
                .storage_binding = options.storage_binding,
            },
        };

        const texture = device.createTexture(&texture_descriptor);

        const view_descriptor = .{
            .format = options.format,
            .dimension = .dimension_2d,
            .array_layer_count = 1,
        };

        const view = texture.createView(&view_descriptor);

        const queue = device.getQueue();

        const data_layout = gpu.Texture.DataLayout{
            .bytes_per_row = image.width * 4,
            .rows_per_image = image.height,
        };

        queue.writeTexture(&.{ .texture = texture }, &data_layout, &image_size, image.data);

        const sampler_descriptor = .{
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
            .image = image,
        };
    }

    pub fn blit(self: *Texture, src_pixels: [][4]u8, dst_rect: [4]u32) void {
        const x = @as(usize, @intCast(dst_rect[0]));
        const y = @as(usize, @intCast(dst_rect[1]));
        const width = @as(usize, @intCast(dst_rect[2]));
        const height = @as(usize, @intCast(dst_rect[3]));

        const tex_width = @as(usize, @intCast(self.image.width));

        var yy = y;
        var h = height;

        var dst_pixels = @as([*][4]u8, @ptrCast(self.image.data.ptr))[0 .. self.image.data.len / 4];

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
        const image_size = gpu.Extent3D{ .width = texture.image.width, .height = texture.image.height };
        const queue = device.getQueue();
        defer queue.release();

        const data_layout = gpu.Texture.DataLayout{
            .bytes_per_row = texture.image.width * 4,
            .rows_per_image = texture.image.height,
        };

        queue.writeTexture(&.{ .texture = texture.handle }, &data_layout, &image_size, texture.image.data);
    }

    pub fn deinit(texture: *Texture) void {
        texture.handle.release();
        texture.view_handle.release();
        texture.sampler_handle.release();
        texture.image.deinit();
    }
};
