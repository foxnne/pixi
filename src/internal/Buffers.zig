const std = @import("std");
const pixi = @import("../pixi.zig");

const History = @import("History.zig");
const Buffers = @This();

stroke: Stroke,
temporary_stroke: Stroke,

pub const Stroke = struct {
    //indices: std.ArrayList(usize),
    //values: std.ArrayList([4]u8),

    pixels: std.AutoHashMap(usize, [4]u8),
    //canvas: pixi.Internal.File.Canvas = .primary,

    pub fn init(allocator: std.mem.Allocator) Stroke {
        return .{
            .pixels = .init(allocator),
            // .indices = std.ArrayList(usize).init(allocator),
            // .values = std.ArrayList([4]u8).init(allocator),
        };
    }

    pub fn append(stroke: *Stroke, index: usize, value: [4]u8) !void {
        const ptr = try stroke.pixels.getOrPut(index);
        if (!ptr.found_existing)
            ptr.value_ptr.* = value;

        // try stroke.indices.append(index);

        // try stroke.values.append(value);
        //stroke.canvas = canvas;
    }

    pub fn appendSlice(stroke: *Stroke, indices: []usize, values: [][4]u8) !void {
        for (indices, values) |index, value| {
            try stroke.append(index, value);
        }

        //try stroke.indices.appendSlice(indices);
        //try stroke.values.appendSlice(values);
        //stroke.canvas = canvas;
    }

    pub fn toChange(stroke: *Stroke, layer_id: u64) !History.Change {
        var indices = pixi.app.allocator.alloc(usize, stroke.pixels.count()) catch return error.MemoryAllocationFailed;
        var values = pixi.app.allocator.alloc([4]u8, stroke.pixels.count()) catch return error.MemoryAllocationFailed;

        var it = stroke.pixels.iterator();

        var i: usize = 0;
        while (it.next()) |entry| {
            indices[i] = entry.key_ptr.*;
            values[i] = entry.value_ptr.*;
            i += 1;
        }

        stroke.pixels.clearAndFree();

        return .{ .pixels = .{
            .layer_id = layer_id,
            .indices = indices,
            .values = values,
        } };
    }

    pub fn clearAndFree(stroke: *Stroke) void {
        stroke.pixels.clearAndFree();
        // stroke.indices.clearAndFree();
        // stroke.values.clearAndFree();
    }

    pub fn deinit(stroke: *Stroke) void {
        stroke.clearAndFree();
        // stroke.indices.deinit();
        // stroke.values.deinit();
    }
};

pub fn init(allocator: std.mem.Allocator) Buffers {
    return .{
        .stroke = Stroke.init(allocator),
        .temporary_stroke = Stroke.init(allocator),
    };
}

pub fn clearAndFree(buffers: *Buffers) void {
    buffers.stroke.clearAndFree();
    buffers.temporary_stroke.clearAndFree();
}

pub fn deinit(buffers: *Buffers) void {
    buffers.clearAndFree();
    buffers.stroke.deinit();
    buffers.temporary_stroke.deinit();
}
