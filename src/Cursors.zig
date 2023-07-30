const pixi = @import("root");

const Self = @This();

current: Cursor = .arrow,
pencil: pixi.gfx.Texture,
eraser: pixi.gfx.Texture,

pub fn update(self: Self) void {
    switch (self.current) {
        .arrow => {
            pixi.application.core.setCursorMode(.normal);
            pixi.application.core.setCursorShape(.arrow);
        },
        .resize_ns => {
            pixi.application.core.setCursorMode(.normal);
            pixi.application.core.setCursorShape(.resize_ns);
        },
        .resize_ew => {
            pixi.application.core.setCursorMode(.normal);
            pixi.application.core.setCursorShape(.resize_ew);
        },
        else => {
            pixi.application.core.setCursorMode(.hidden);
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
