const std = @import("std");

/// reads the contents of a file. Returned value is owned by the caller and must be freed!
pub fn read(allocator: std.mem.Allocator, filename: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    var buffer = try allocator.alloc(u8, file_size);
    _ = try file.read(buffer[0..buffer.len]);

    return buffer;
}

/// reads the contents of a file. Returned value is owned by the caller and must be freed!
pub fn readZ(allocator: std.mem.Allocator, filename: []const u8) ![:0]u8 {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    var buffer = try allocator.alloc(u8, file_size + 1);
    _ = try file.read(buffer[0..file_size]);
    buffer[file_size] = 0;

    return buffer[0..file_size: 0];
}
