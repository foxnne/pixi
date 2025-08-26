const pixi = @import("../pixi.zig");
const dvui = @import("dvui");

pub const Transform = @This();

/// Points of the transform
/// 1-4: the corner vertices of the transform
/// 5: the pivot point, defaulted to the center of the transform
/// 6: the rotation point
data_points: [6]dvui.Point,
track_pivot: bool = false,
active_point: ?TransformPoint = null,
rotation: f32 = 0.0,
file_id: u64,
layer_id: u64,
source: dvui.ImageSource,

pub fn point(self: *Transform, transform_point: TransformPoint) *dvui.Point {
    return &self.data_points[@intFromEnum(transform_point)];
}

/// Accepts the current transform and applies it to the currently selected layer
/// Actively transformed pixels are being copied to the temporary layer for display
/// During a transform, the temporary layer is not used for anything else
pub fn accept(self: *Transform) void {
    if (pixi.editor.open_files.getPtr(self.file_id)) |file| {
        var layer = file.getLayer(self.layer_id) orelse return;

        for (file.editor.temporary_layer.pixels(), 0..) |*pixel, pixel_index| {
            if (pixel[3] != 0 or file.editor.transform_layer.pixels()[pixel_index][3] != 0) {
                file.buffers.stroke.append(pixel_index, file.editor.transform_layer.pixels()[pixel_index]) catch {
                    dvui.log.err("Failed to append stroke change to history", .{});
                };
            }
            if (pixel[3] != 0) {
                @memcpy(&layer.pixels()[pixel_index], pixel);
            }
        }

        const change = file.buffers.stroke.toChange(self.layer_id) catch null;
        if (change) |c| {
            file.history.append(c) catch {
                dvui.log.err("Failed to append stroke change to history", .{});
            };
        }

        layer.invalidate();
        file.editor.transform_layer.clear();
        file.editor.transform_layer.clearMask();
        file.editor.transform_layer.invalidate();
        file.editor.transform = null;
        pixi.app.allocator.free(pixi.image.bytes(self.source));
        self.* = undefined;
    }
}

/// Cancels the transform and restores the layer to its original state
pub fn cancel(self: *Transform) void {
    if (pixi.editor.open_files.getPtr(self.file_id)) |file| {
        var layer = file.getLayer(self.layer_id) orelse return;
        var iterator = file.editor.transform_layer.mask.iterator(.{ .kind = .set, .direction = .forward });
        while (iterator.next()) |pixel_index| {
            @memcpy(&layer.pixels()[pixel_index], &file.editor.transform_layer.pixels()[pixel_index]);
        }
        layer.invalidate();
        file.editor.transform_layer.clear();
        file.editor.transform_layer.clearMask();
        file.editor.transform_layer.invalidate();
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
