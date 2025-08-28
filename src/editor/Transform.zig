const pixi = @import("../pixi.zig");
const dvui = @import("dvui");

pub const Transform = @This();

/// Points of the transform
/// 1-4: the corner vertices of the transform
/// 5: the pivot point, defaulted to the center of the transform
/// 6: the rotation point
data_points: [6]dvui.Point,
track_pivot: bool = false,
dragging: bool = false,
active_point: ?TransformPoint = null,
rotation: f32 = 0.0,
start_rotation: f32 = 0.0,
radius: f32 = 0.0,
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

pub fn hovered(self: *Transform, data_point: dvui.Point) bool {
    var is_hovered = false;

    var path = dvui.Path.Builder.init(dvui.currentWindow().arena());
    path.addPoint(.{ .x = self.point(.top_left).x, .y = self.point(.top_left).y });
    path.addPoint(.{ .x = self.point(.top_right).x, .y = self.point(.top_right).y });
    path.addPoint(.{ .x = self.point(.bottom_right).x, .y = self.point(.bottom_right).y });
    path.addPoint(.{ .x = self.point(.bottom_left).x, .y = self.point(.bottom_left).y });

    var centroid = self.data_points[0];
    for (self.data_points[1..4]) |*p| {
        centroid.x += p.x;
        centroid.y += p.y;
    }
    centroid.x /= 4;
    centroid.y /= 4;

    var triangles = path.build().fillConvexTriangles(dvui.currentWindow().arena(), .{
        .center = .{ .x = centroid.x, .y = centroid.y },
        .color = .white,
    }) catch null;

    if (triangles) |*t| {
        t.rotate(.{ .x = self.point(.pivot).x, .y = self.point(.pivot).y }, self.rotation);

        const top_left = t.vertexes[0];
        const top_right = t.vertexes[1];
        const bottom_right = t.vertexes[2];
        const bottom_left = t.vertexes[3];

        {
            const triangle_1 = [3]dvui.Point{
                .{ .x = top_left.pos.x, .y = top_left.pos.y },
                .{ .x = top_right.pos.x, .y = top_right.pos.y },
                .{ .x = data_point.x, .y = data_point.y },
            };

            const triangle_2 = [3]dvui.Point{
                .{ .x = top_right.pos.x, .y = top_right.pos.y },
                .{ .x = bottom_right.pos.x, .y = bottom_right.pos.y },
                .{ .x = data_point.x, .y = data_point.y },
            };

            const triangle_3 = [3]dvui.Point{
                .{ .x = bottom_right.pos.x, .y = bottom_right.pos.y },
                .{ .x = top_left.pos.x, .y = top_left.pos.y },
                .{ .x = data_point.x, .y = data_point.y },
            };

            const triangle_4 = [3]dvui.Point{
                .{ .x = top_left.pos.x, .y = top_left.pos.y },
                .{ .x = top_right.pos.x, .y = top_right.pos.y },
                .{ .x = bottom_right.pos.x, .y = bottom_right.pos.y },
            };

            const area_1 = area(triangle_1);
            const area_2 = area(triangle_2);
            const area_3 = area(triangle_3);
            const area_4 = area(triangle_4);

            const combined = area_1 + area_2 + area_3;
            const diff = @abs(combined - area_4);

            if (!is_hovered)
                is_hovered = diff < 0.1;
        }
        {
            const triangle_1 = [3]dvui.Point{
                .{ .x = bottom_right.pos.x, .y = bottom_right.pos.y },
                .{ .x = bottom_left.pos.x, .y = bottom_left.pos.y },
                .{ .x = data_point.x, .y = data_point.y },
            };

            const triangle_2 = [3]dvui.Point{
                .{ .x = bottom_left.pos.x, .y = bottom_left.pos.y },
                .{ .x = top_left.pos.x, .y = top_left.pos.y },
                .{ .x = data_point.x, .y = data_point.y },
            };

            const triangle_3 = [3]dvui.Point{
                .{ .x = top_left.pos.x, .y = top_left.pos.y },
                .{ .x = bottom_right.pos.x, .y = bottom_right.pos.y },
                .{ .x = data_point.x, .y = data_point.y },
            };

            const triangle_4 = [3]dvui.Point{
                .{ .x = top_left.pos.x, .y = top_left.pos.y },
                .{ .x = bottom_right.pos.x, .y = bottom_right.pos.y },
                .{ .x = bottom_left.pos.x, .y = bottom_left.pos.y },
            };

            const area_1 = area(triangle_1);
            const area_2 = area(triangle_2);
            const area_3 = area(triangle_3);
            const area_4 = area(triangle_4);

            const combined = area_1 + area_2 + area_3;
            const diff = @abs(combined - area_4);

            if (!is_hovered)
                is_hovered = diff < 0.1;
        }
    }

    return is_hovered;
}

fn area(triangle: [3]dvui.Point) f32 {
    return @abs((triangle[0].x * (triangle[1].y - triangle[2].y) + triangle[1].x * (triangle[2].y - triangle[0].y) + triangle[2].x * (triangle[0].y - triangle[1].y)) / 2.0);
}

pub const TransformPoint = enum(usize) {
    top_left = 0,
    top_right = 1,
    bottom_right = 2,
    bottom_left = 3,
    pivot = 4,
    rotate = 5,
};
