const std = @import("std");
const glfw = @import("glfw");
const zgpu = @import("zgpu");
const zstbi = @import("zstbi");
const wgpu = zgpu.wgpu;
const zm = @import("zmath");

const game = @import("game");

pub const Texture = struct {
    handle: zgpu.TextureHandle,
    view_handle: zgpu.TextureViewHandle,
    sampler_handle: zgpu.SamplerHandle,
    width: u32,
    height: u32,

    pub const SamplerOptions = struct {
        address_mode: wgpu.AddressMode = .clamp_to_edge,
        filter: wgpu.FilterMode = .nearest,
    };

    pub fn init(gctx: *zgpu.GraphicsContext, width: u32, height: u32, options: Texture.SamplerOptions) Texture {
        const handle = gctx.createTexture(.{
            .usage = .{ .texture_binding = true, .render_attachment = true, .copy_dst = true },
            .size = .{
                .width = width,
                .height = height,
                .depth_or_array_layers = 1,
            },
            .format = .bgra8_unorm,
        });
        const view_handle = gctx.createTextureView(handle, .{});

        const sampler_handle = gctx.createSampler(.{
            .address_mode_u = options.address_mode,
            .address_mode_v = options.address_mode,
            .address_mode_w = options.address_mode,
            .mag_filter = options.filter,
            .min_filter = options.filter,
        });

        return .{
            .handle = handle,
            .view_handle = view_handle,
            .sampler_handle = sampler_handle,
            .width = width,
            .height = height,
        };
    }

    pub fn initFromFile(gctx: *zgpu.GraphicsContext, file: [:0]const u8, options: Texture.SamplerOptions) !Texture {
        var image = try zstbi.Image.init(file, 4);
        defer image.deinit();

        const handle = gctx.createTexture(.{
            .usage = .{ .texture_binding = true, .copy_dst = true },
            .size = .{
                .width = image.width,
                .height = image.height,
                .depth_or_array_layers = 1,
            },
            .format = zgpu.imageInfoToTextureFormat(
                image.num_components,
                image.bytes_per_component,
                image.is_hdr,
            ),
        });

        const view_handle = gctx.createTextureView(handle, .{});

        gctx.queue.writeTexture(
            .{ .texture = gctx.lookupResource(handle).? },
            .{
                .bytes_per_row = image.bytes_per_row,
                .rows_per_image = image.height,
            },
            .{ .width = image.width, .height = image.height },
            u8,
            image.data,
        );

        const sampler_handle = gctx.createSampler(.{
            .address_mode_u = options.address_mode,
            .address_mode_v = options.address_mode,
            .address_mode_w = options.address_mode,
            .mag_filter = options.filter,
            .min_filter = options.filter,
        });

        return Texture{
            .handle = handle,
            .view_handle = view_handle,
            .sampler_handle = sampler_handle,
            .width = image.width,
            .height = image.height,
        };
    }
};
