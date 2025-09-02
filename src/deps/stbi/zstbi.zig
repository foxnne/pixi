pub const version = @import("std").SemanticVersion{ .major = 0, .minor = 9, .patch = 3 };
const std = @import("std");
const assert = std.debug.assert;

pub const Rect = extern struct {
    id: u32,
    w: u16,
    h: u16,
    x: u16 = 0,
    y: u16 = 0,
    was_packed: i32 = 0,

    pub fn slice(self: Rect) [4]u32 {
        return .{
            @intCast(self.x),
            @intCast(self.y),
            @intCast(self.w),
            @intCast(self.h),
        };
    }
};

pub const Node = extern struct {
    x: u16,
    y: u16,
    next: [*c]Node,
};

pub const Context = extern struct {
    width: i32,
    height: i32,
    @"align": i32,
    init_mode: i32,
    heuristic: i32,
    num_nodes: i32,
    active_head: [*c]Node,
    free_head: [*c]Node,
    extra: [2]Node,
};

pub const Heuristic = enum(u32) {
    skyline_default,
    skyline_bl_sort_height,
    skyline_bf_sort_height,
};

pub fn initTarget(context: *Context, width: u32, height: u32, nodes: []Node) void {
    stbrp_init_target(context, width, height, nodes.ptr, nodes.len);
}

pub fn packRects(context: *Context, rects: []Rect) usize {
    return @as(usize, @intCast(stbrp_pack_rects(context, rects.ptr, rects.len)));
}

pub fn setupHeuristic(context: *Context, heuristic: Heuristic) void {
    stbrp_setup_heuristic(context, @as(u32, @intCast(@intFromEnum(heuristic))));
}

pub extern fn stbrp_init_target(context: [*c]Context, width: u32, height: u32, nodes: [*c]Node, num_nodes: usize) void;
pub extern fn stbrp_pack_rects(context: [*c]Context, rects: [*c]Rect, num_rects: usize) usize;
pub extern fn stbrp_setup_allow_out_of_mem(context: [*c]Context, allow_out_of_mem: u32) void;
pub extern fn stbrp_setup_heuristic(context: [*c]Context, heuristic: u32) void;
