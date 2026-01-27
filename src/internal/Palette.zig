const std = @import("std");
const pixi = @import("../pixi.zig");
const dvui = @import("dvui");

const PackedColor = packed struct(u32) { r: u8, g: u8, b: u8, a: u8 };

pub const Palette = @This();

name: []const u8,
colors: [][4]u8,

pub fn getDVUIColor(self: *Palette, id: usize) dvui.Color {
    const new_id = id % self.colors.len;
    return .{ .r = self.colors[new_id][0], .g = self.colors[new_id][1], .b = self.colors[new_id][2], .a = self.colors[new_id][3] };
}

pub fn loadFromFile(allocator: std.mem.Allocator, file: []const u8) !Palette {
    const ext = std.fs.path.extension(file);

    if (std.mem.eql(u8, ext, ".hex")) {
        if (pixi.fs.read(pixi.app.allocator, file) catch null) |read| {
            defer pixi.app.allocator.free(read);

            return loadFromBytes(allocator, std.fs.path.basename(file), read);
        }
    }
    return error.WrongFileType;
}

pub fn loadFromBytes(allocator: std.mem.Allocator, name: []const u8, bytes: []const u8) !Palette {
    var colors = std.array_list.Managed([4]u8).init(allocator);
    var iter = std.mem.splitSequence(u8, bytes, "\n");
    while (iter.next()) |line| {
        if (line.len == 0) continue;
        const color_u32 = std.fmt.parseInt(u32, line[0 .. line.len - 1], 16) catch {
            dvui.log.err("Failed to parse color: {s}", .{line[0 .. line.len - 1]});
            return error.FailedToParseColor;
        };
        const color_packed: PackedColor = @as(PackedColor, @bitCast(color_u32));
        try colors.append(.{ color_packed.b, color_packed.g, color_packed.r, 255 });
    }

    return .{
        .name = try allocator.dupe(u8, name),
        .colors = try colors.toOwnedSlice(),
    };
}

pub fn deinit(self: *Palette) void {
    pixi.app.allocator.free(self.name);
    pixi.app.allocator.free(self.colors);
}
