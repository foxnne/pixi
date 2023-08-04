const pixi = @import("root");
const core = @import("core");

const Self = @This();

current: Cursor = .arrow,
pencil: pixi.gfx.Texture,
eraser: pixi.gfx.Texture,

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
    cursors.pencil.deinit();
    cursors.eraser.deinit();
}

pub const Cursor = enum {
    arrow,
    resize_ns,
    resize_ew,
    pencil,
    eraser,
};
