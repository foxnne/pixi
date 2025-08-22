const pixi = @import("../pixi.zig");
const dvui = @import("dvui");

pub const Transform = @This();

/// Points of the transform
/// 1-4: the vertices of the transform
/// 5: the pivot point
/// 6: the rotation point
data_points: [6]dvui.Point,
active_data_point: ?TransformPoint = null,
rotation: f32 = 0.0,
file_id: u64,
layer_id: u64,
source: dvui.ImageSource,

pub fn point(self: *Transform, transform_point: TransformPoint) *dvui.Point {
    return &self.data_points[@intFromEnum(transform_point)];
}

/// Cancels the transform and restores the layer to its original state
pub fn cancel(self: *Transform) void {
    if (pixi.editor.open_files.getPtr(self.file_id)) |file| {
        var layer = file.getLayer(self.layer_id) orelse return;
        var iterator = file.selection_layer.mask.iterator(.{ .kind = .set, .direction = .forward });
        while (iterator.next()) |pixel_index| {
            layer.pixels()[pixel_index] = file.selection_layer.pixels()[pixel_index];
        }
        layer.invalidate();
        file.selection_layer.clear();
        file.selection_layer.clearMask();
        file.selection_layer.invalidate();
        file.editor.transform = null;
        pixi.app.allocator.free(pixi.image.bytes(self.source));
        self.* = undefined;
    }
}

pub const TransformPoint = enum(usize) {
    top_left = 0,
    top_right = 1,
    bottom_right = 2,
    bottom_left = 3,
    pivot = 4,
    rotate = 5,
};

pub const TransformAction = enum {
    none,
    pan,
    rotate,
    move_pivot,
    move_vertex,
};

pub const TransformControl = struct {
    index: usize,
    mode: TransformMode,
};

pub const TransformMode = enum {
    locked_aspect,
    free_aspect,
    free,
};
