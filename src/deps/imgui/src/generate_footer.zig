//-----------------------------------------------------------------------------
// Internal
//-----------------------------------------------------------------------------

const alignment = 16;

fn zigAlloc(sz: usize, user_data: ?*anyopaque) callconv(.C) ?*anyopaque {
    var allocator: *std.mem.Allocator = @ptrCast(@alignCast(user_data));

    if (allocator.alignedAlloc(u8, alignment, sz + alignment)) |mem| {
        const user_ptr = mem.ptr + alignment;
        var info_ptr: *usize = @ptrCast(mem.ptr);
        info_ptr.* = sz + alignment;
        return user_ptr;
    } else |_| {
        return null;
    }
}

fn zigFree(ptr: ?*anyopaque, user_data: ?*anyopaque) callconv(.C) void {
    var allocator: *std.mem.Allocator = @ptrCast(@alignCast(user_data));

    if (ptr) |p| {
        const user_ptr: [*]align(alignment) u8 = @ptrCast(@alignCast(p));
        const mem_ptr = user_ptr - alignment;
        const info_ptr: *usize = @ptrCast(mem_ptr);
        const sz = info_ptr.*;
        allocator.free(mem_ptr[0..sz]);
    }
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
