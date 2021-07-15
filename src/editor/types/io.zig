const std = @import("std");
const upaya = @import("upaya");
const editor = @import("../editor.zig");

const types = @import("types.zig");

const IOAnimation = types.Animation;
const File = types.File;

pub const IOFile = struct {
    name: []const u8,
    width: i32,
    height: i32,
    tileWidth: i32,
    tileHeight: i32,
    layers: []IOLayer,
    sprites: []IOSprite,
    animations: []IOAnimation,

    // pub fn toInternalFile (self: IOFile) File {

        

    //     return .{
    //         .name = std.mem.dupe(upaya.mem.allocator, u8, self.name) catch unreachable,
    //         .width = self.width,
    //         .height = self.height,
    //         .tileWidth = self.tileWidth,
    //         .tileHeight = self.tileHeight,
    //         .background = upaya.Texture.initChecker(self.width, self.height, editor.checkerColor1, editor.checkerColor2),
            

    //     };
    // }
};

pub const IOLayer = struct {
    name: []const u8,
};

pub const IOSprite = struct {
    name: []const u8,
    origin_x: f32,
    origin_y: f32,
};