const pixi = @import("root");
const core = @import("mach-core");

const Self = @This();

current: Cursor = .arrow,
edit: pixi.gfx.Texture,

pub fn update(self: Self) void {
    switch (self.current) {
        .arrow => {
            core.setCursorMode(.normal);
            core.setCursorShape(.arrow);
        },
        .resize_ns => {
            core.setCursorMode(.normal);
            core.setCursorShape(.resize_ns);
        },
        .resize_ew => {
            core.setCursorMode(.normal);
            core.setCursorShape(.resize_ew);
        },
        else => {
            core.setCursorMode(.hidden);
        },
    }
}

pub fn deinit(cursors: *Self) void {
    cursors.edit.deinit();
}

pub fn size() u32 {
    return if (pixi.content_scale[1] > 1) 64 else 32;
}

fn src_x_index(cursor: Cursor) f32 {
    switch (cursor) {
        .eraser => return 0,
        .pencil => return 1,
        else => return 0,
    }
}

fn src_y_index() f32 {
    return if (pixi.content_scale[1] > 1) 0 else 12;
}

pub fn src_rect(self: Self) [4]f32 {
    const cursor_size: f32 = @as(f32, @floatFromInt(size()));
    const image_width: f32 = @as(f32, @floatFromInt(self.edit.image.width));
    const image_height: f32 = @as(f32, @floatFromInt(self.edit.image.height));

    const src_x: f32 = src_x_index(self.current) * cursor_size / image_width;
    const src_y: f32 = src_y_index() * cursor_size / image_height;

    const src_width: f32 = cursor_size / image_width;
    const src_height: f32 = cursor_size / image_height;

    return .{ src_x, src_y, src_width, src_height };
}

pub const Cursor = enum {
    arrow,
    resize_ns,
    resize_ew,
    pencil,
    eraser,
};
