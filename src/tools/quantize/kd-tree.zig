const std = @import("std");
const FixedStack = @import("fixed-stack.zig").FixedStack;

const BoundingBox = struct {
    min: [3]u8, // min RGB coords.
    max: [3]u8, // max RGB coords.
};

const Color = struct {
    rgb: [3]u8,
    color_table_index: u8,
};

/// A Node in a KD-Tree
pub const KdNode = struct {
    /// The key that cuts the RGB space into two sub-spaces with a plane.
    key: Color,
    cut_dim: usize, // 0 = r, 1 = g, 2 = b
    /// The bounding box of the sub-space that this node represents.
    /// For leaf nodes, this is a single point.
    bounding_box: BoundingBox,
    left: ?*KdNode, // left subtree
    right: ?*KdNode, // right subtree
};

fn colorLessThan(channel: usize, a: Color, b: Color) bool {
    return a.rgb[channel] < b.rgb[channel];
}

inline fn squaredDistRgb(color_a: [3]u8, color_b: [3]u8) usize {
    const a: @Vector(3, i32) = color_a;
    const b: @Vector(3, i32) = color_b;

    const diff = a - b;

    const dr = diff[0];
    const dg = diff[1];
    const db = diff[2];

    return @intCast(dr * dr + dg * dg + db * db);
}

/// A 3-dimensional KD-Tree that stores colors in the RGB space.
pub const KDTree = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    /// `depth` is the maximum distance between the root and any leaf.
    /// Depth of the root is 0, and depth of a child is `1 + depth(parent)`.
    depth: usize,

    /// Root node if the KD Tree.
    root: KdNode,

    pub fn init(allocator: std.mem.Allocator, color_table: []const u8) !KDTree {
        std.debug.assert(color_table.len % 3 == 0);
        const ncolors = color_table.len / 3;
        const colors = try allocator.alloc(Color, ncolors);
        defer allocator.free(colors);

        // Also compute the bounding box of the root node of the KD Tree.
        var bb_min = [3]u8{ 255, 255, 255 };
        var bb_max = [3]u8{ 0, 0, 0 };

        for (0..ncolors) |i| {
            colors[i] = .{
                .rgb = .{
                    color_table[i * 3 + 0], // r
                    color_table[i * 3 + 1], // g
                    color_table[i * 3 + 2], // b
                },
                .color_table_index = @truncate(i),
            };

            for (0..3) |j| {
                bb_min[j] = @min(bb_min[j], colors[i].rgb[j]);
                bb_max[j] = @max(bb_max[j], colors[i].rgb[j]);
            }
        }

        const bb = BoundingBox{ .min = bb_min, .max = bb_max };

        const tree = try constructKdTree(allocator, bb, colors);
        return .{
            .root = tree.root,
            .depth = tree.depth,
            .allocator = allocator,
        };
    }

    const Stack = FixedStack(*const KdNode, 32);
    pub inline fn findNearestColor(self: *const Self, target: [3]u8) *const Color {
        var stack = Stack{};
        stack.push(&self.root);

        var best_dist: usize = squaredDistRgb(self.root.key.rgb, target);
        var nearest: *const Color = &self.root.key;

        while (!stack.isEmpty()) {
            const node = stack.pop();
            const dist = squaredDistRgb(node.key.rgb, target);
            if (dist < best_dist) {
                best_dist = dist;
                nearest = &node.key;
            }

            var near: ?*KdNode = undefined;
            var far: ?*KdNode = undefined;

            const dim = node.cut_dim;
            const split_key = node.key.rgb;
            if (target[dim] < split_key[dim]) {
                near = node.left;
                far = node.right;
            } else {
                near = node.right;
                far = node.left;
            }

            if (far) |far_node| {
                const node_x: i32 = split_key[dim];
                const target_x: i32 = target[dim];
                const dx = target_x - node_x;
                if (best_dist >= dx * dx) {
                    stack.push(far_node);
                }
            }

            if (near) |near_node| {
                stack.push(near_node);
            }
        }

        return nearest;
    }

    fn constructKdTree(
        allocator: std.mem.Allocator,
        bounding_box: BoundingBox,
        colors: []Color,
    ) !struct { root: KdNode, depth: usize } {
        std.debug.assert(colors.len > 1);

        var root: KdNode = undefined;
        root.cut_dim = 0; // red.
        root.bounding_box = bounding_box;

        std.sort.heap(Color, colors, root.cut_dim, colorLessThan);

        const median = colors.len / 2;
        root.key = colors[median];

        var depth: usize = 1;

        const left = try allocator.create(KdNode);
        left.* = try constructRecursive(allocator, &root, true, colors[0..median], 1, &depth);

        if (median + 1 < colors.len) {
            const right = try allocator.create(KdNode);
            right.* = try constructRecursive(allocator, &root, false, colors[median + 1 ..], 1, &depth);
            root.right = right;
        } else {
            root.right = null;
        }

        root.left = left;

        return .{ .root = root, .depth = depth };
    }

    /// Constructs a bounding box for the child node from its parent's bounding box.
    inline fn makeChildBoundingBox(parent: *const KdNode, is_left: bool) BoundingBox {
        var bb = parent.bounding_box;
        if (is_left) {
            bb.max[parent.cut_dim] = parent.key.rgb[parent.cut_dim];
        } else {
            bb.min[parent.cut_dim] = parent.key.rgb[parent.cut_dim];
        }
        return bb;
    }

    /// Recursively constructs a KD Tree from a list of colors and a root node.
    /// `parent_node`: Parent of the current node being constructed.
    /// `is_left_child`: True if the current node is the left child of `parent_node`.
    /// `colors`: List of colors to be partitioned by the current one.
    /// `current_depth`: Depth of the current node.
    /// `total_depth`: An in-out parameter that is updated with the depth of the tree.
    fn constructRecursive(
        allocator: std.mem.Allocator,
        parent_node: *const KdNode,
        is_left_child: bool,
        colors: []Color,
        current_depth: usize,
        total_depth: *usize,
    ) !KdNode {
        total_depth.* = @max(total_depth.*, current_depth);

        var node: KdNode = undefined;
        node.cut_dim = current_depth % 3;

        if (colors.len == 1) {
            node.key = colors[0];
            node.bounding_box = BoundingBox{ .min = colors[0].rgb, .max = colors[0].rgb };
            node.left = null;
            node.right = null;
            return node;
        }

        node.bounding_box = makeChildBoundingBox(parent_node, is_left_child);

        // sort all colors along the cut dimension.
        std.sort.heap(Color, colors, node.cut_dim, colorLessThan);

        const median = colors.len / 2;
        node.key = colors[median];

        const lower = colors[0..median];
        if (lower.len == 0) {
            node.left = null;
        } else {
            const left = try allocator.create(KdNode);
            left.* = try constructRecursive(
                allocator,
                &node,
                true,
                lower,
                current_depth + 1,
                total_depth,
            );

            node.left = left;
        }

        if (median + 1 < colors.len) {
            const higher = colors[median + 1 ..];
            const right = try allocator.create(KdNode);
            right.* = try constructRecursive(
                allocator,
                &node,
                false,
                higher,
                current_depth + 1,
                total_depth,
            );
            node.right = right;
        } else {
            node.right = null;
        }

        return node;
    }

    pub fn deinit(self: *const Self) void {
        if (self.root.left) |left| {
            self.destroyNode(left);
        }

        if (self.root.right) |right| {
            self.destroyNode(right);
        }
    }

    fn destroyNode(self: *const Self, node: *KdNode) void {
        if (node.left) |left| {
            self.destroyNode(left);
        }

        if (node.right) |right| {
            self.destroyNode(right);
        }

        self.allocator.destroy(node);
    }
};

const t = std.testing;
test "KDTree construction" {
    const allocator = t.allocator;
    const color_table = [_]u8{
        200, 0,   0,
        100, 1,   200,
        80,  100, 0,

        50,  200, 100,
        0,   100, 22,
        0,   55,  100,
    };

    const tree = try KDTree.init(allocator, &color_table);
    defer tree.deinit();

    try t.expectEqual(2, tree.depth);

    try t.expectEqual(0, tree.root.cut_dim);
    try t.expectEqualDeep([3]u8{ 80, 100, 0 }, tree.root.key.rgb);
    try t.expectEqualDeep([3]u8{ 0, 0, 0 }, tree.root.bounding_box.min);
    try t.expectEqualDeep([3]u8{ 200, 200, 200 }, tree.root.bounding_box.max);

    const left_of_root = tree.root.left.?;
    try t.expect(left_of_root.cut_dim == 1);
    try t.expectEqualDeep([3]u8{ 0, 100, 22 }, left_of_root.key.rgb);
    try t.expectEqualDeep([3]u8{ 0, 0, 0 }, left_of_root.bounding_box.min);
    try t.expectEqualDeep([3]u8{ 80, 200, 200 }, left_of_root.bounding_box.max);

    try t.expectEqualDeep([3]u8{ 0, 55, 100 }, left_of_root.left.?.key.rgb);

    const right_of_root = tree.root.right.?;
    try t.expectEqual(1, right_of_root.cut_dim);
    try t.expectEqualDeep([3]u8{ 100, 1, 200 }, right_of_root.key.rgb);
    try t.expectEqualDeep([3]u8{ 80, 0, 0 }, right_of_root.bounding_box.min);
    try t.expectEqualDeep([3]u8{ 200, 200, 200 }, right_of_root.bounding_box.max);

    var c = tree.findNearestColor([3]u8{ 197, 11, 78 });
    try t.expectEqualDeep([3]u8{ 200, 0, 0 }, c.rgb);

    c = tree.findNearestColor([3]u8{ 8, 123, 139 });
    try t.expectEqualDeep([3]u8{ 0, 55, 100 }, c.rgb);

    for (0..color_table.len / 3) |i| {
        const clr = [3]u8{
            color_table[i * 3 + 0],
            color_table[i * 3 + 1],
            color_table[i * 3 + 2],
        };

        const actual = tree.findNearestColor(clr);
        const expected = clr;
        try t.expectEqualDeep(expected, actual.rgb);
    }

    c = tree.findNearestColor([3]u8{ 120, 1, 200 });
    try t.expectEqualDeep([3]u8{ 100, 1, 200 }, c.rgb);

    c = tree.findNearestColor([3]u8{ 100, 3, 200 });
    try t.expectEqualDeep([3]u8{ 100, 1, 200 }, c.rgb);

    var gen = std.rand.DefaultPrng.init(@abs(std.time.milliTimestamp()));
    for (0..10_000) |_| {
        const target = .{
            gen.random().int(u8),
            gen.random().int(u8),
            gen.random().int(u8),
        };

        const expected = findNearestBrute(&color_table, target);
        const actual = tree.findNearestColor(target);

        const expected_dist = squaredDistRgb(target, expected);
        const actual_dist = squaredDistRgb(target, actual.rgb);

        try t.expectEqual(expected_dist, actual_dist);
    }
}

fn findNearestBrute(colors: []const u8, target: [3]u8) [3]u8 {
    var best_dist: usize = std.math.maxInt(usize);
    var nearest: [3]u8 = undefined;

    for (0..colors.len / 3) |i| {
        const color: [3]u8 = .{
            colors[i * 3 + 0],
            colors[i * 3 + 1],
            colors[i * 3 + 2],
        };
        const dist = squaredDistRgb(target, color);
        if (dist < best_dist) {
            best_dist = dist;
            nearest = color;
        }
    }

    return nearest;
}

test "KDTree – Search" {
    const allocator = t.allocator;
    const ncolors = 255;
    const color_table = try allocator.alloc(u8, ncolors * 3);
    defer allocator.free(color_table);

    var gen = std.rand.DefaultPrng.init(@abs(std.time.milliTimestamp()));
    for (0..color_table.len) |i| {
        color_table[i] = gen.random().int(u8);
    }

    const tree = try KDTree.init(allocator, color_table);
    defer tree.deinit();

    for (0..std.math.pow(2, 15)) |_| {
        const target = .{
            gen.random().int(u8),
            gen.random().int(u8),
            gen.random().int(u8),
        };

        const expected = findNearestBrute(color_table, target);
        const actual = tree.findNearestColor(target).rgb;

        const expected_dist = squaredDistRgb(target, expected);
        const actual_dist = squaredDistRgb(target, actual);

        try t.expectEqual(expected_dist, actual_dist);
    }
}
