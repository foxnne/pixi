const std = @import("std");
const glfw = @import("glfw");
const zgpu = @import("zgpu");
const zstbi = @import("zstbi");
const wgpu = zgpu.wgpu;
const zm = @import("zmath");

const mach = @import("core");
const gpu = mach.gpu;

const game = @import("game");

pub const Texture = struct {
    handle: *gpu.Texture,
    view_handle: *gpu.TextureView,
    sampler_handle: *gpu.Sampler,
    image: zstbi.Image,

    pub const SamplerOptions = struct {
        address_mode: gpu.Sampler.AddressMode = .clamp_to_edge,
        filter: gpu.FilterMode = .nearest,
    };

    pub fn createEmpty(device: *gpu.Device, width: u32, height: u32, options: Texture.SamplerOptions) !Texture {
        var image = try zstbi.Image.createEmpty(width, height, 4, .{});
        return create(device, image, options);
    }

    pub fn loadFromFile(device: *gpu.Device, file: [:0]const u8, options: Texture.SamplerOptions) !Texture {
        var image = try zstbi.Image.loadFromFile(file, 4);
        return create(device, image, options);
    }

    pub fn loadFromMemory(device: *gpu.Device, data: []const u8, options: Texture.SamplerOptions) !Texture {
        var image = try zstbi.Image.loadFromMemory(data, 0);
        return create(device, image, options);
    }

    pub fn create(device: *gpu.Device, image: zstbi.Image, options: Texture.SamplerOptions) Texture {
        const image_size = gpu.Extent3D{ .width = image.width, .height = image.height };

        const texture = device.createTexture(.{
            .size = image_size,
            .format = .rgba8_unorm,
            .usage = .{
                .texture_binding = true,
                .copy_dst = true,
            },
        });

        const view = texture.createView(.{
            .format = .rgba8_unorm,
            .dimension = .dimension_2d,
            .array_layer_count = 1,
        });

        const queue = device.getQueue();

        const data_layout = gpu.Texture.DataLayout{
            .bytes_per_row = image.width * 4,
            .rows_per_image = image.height,
        };

        queue.writeTexture(&.{ .texture = texture }, &data_layout, &image_size, image.data);

        const sampler = device.createSampler(.{
            .address_mode_u = options.address_mode,
            .address_mode_v = options.address_mode,
            .address_mode_w = options.address_mode,
            .mag_filter = options.filter,
            .min_filter = options.filter,
        });

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

    pub fn update(texture: *Texture, device: *mach.device) void {
        const image_size = gpu.Extent3D{ .width = texture.image.width, .height = texture.image.height };
        const queue = device.device().getQueue();

        const data_layout = gpu.Texture.DataLayout{
            .bytes_per_row = texture.image.width * 4,
            .rows_per_image = texture.image.height,
        };

        queue.writeTexture(&.{ .texture = texture }, &data_layout, &image_size, texture.image.data);
    }

    pub fn deinit(texture: *Texture) void {
        texture.handle.release();
        texture.view_handle.release();
        texture.sampler_handle.release();
        texture.image.deinit();
    }
};
