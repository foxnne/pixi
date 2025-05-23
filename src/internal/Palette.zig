const std = @import("std");
const pixi = @import("../pixi.zig");

const PackedColor = packed struct(u32) { r: u8, g: u8, b: u8, a: u8 };

pub const Palette = @This();

name: [:0]const u8,
colors: [][4]u8,

pub fn loadFromFile(file: [:0]const u8) !Palette {
    var colors = std.ArrayList([4]u8).init(pixi.app.allocator);
    const base_name = std.fs.path.basename(file);
    const ext = std.fs.path.extension(file);
    if (std.mem.eql(u8, ext, ".hex")) {
        var contents = try std.fs.cwd().openFile(file, .{});
        defer contents.close();

        while (try contents.reader().readUntilDelimiterOrEofAlloc(pixi.app.allocator, '\n', 200000)) |line| {
            const color_u32 = try std.fmt.parseInt(u32, line[0 .. line.len - 1], 16);
            const color_packed: PackedColor = @as(PackedColor, @bitCast(color_u32));
            try colors.append(.{ color_packed.b, color_packed.g, color_packed.r, 255 });
            pixi.app.allocator.free(line);
        }
    } else {
        return error.WrongFileType;
    }

    return .{
        .name = try pixi.app.allocator.dupeZ(u8, base_name),
        .colors = try colors.toOwnedSlice(),
    };
}

pub fn deinit(self: *Palette) void {
    pixi.app.allocator.free(self.name);
    pixi.app.allocator.free(self.colors);
}
