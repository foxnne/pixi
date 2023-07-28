const pixi = @import("root");

const Self = @This();

pencil: pixi.gfx.Texture,
eraser: pixi.gfx.Texture,

pub fn deinit(cursors: *Self) void {
    cursors.pencil.deinit();
    cursors.eraser.deinit();
}
