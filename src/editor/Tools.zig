const std = @import("std");
const pixi = @import("../pixi.zig");
const dvui = @import("dvui");

const Tools = @This();

pub const max_brush_size: u32 = 256;
pub const max_brush_size_float: f32 = @as(f32, @floatFromInt(max_brush_size));
pub const min_full_stroke_size: u32 = 10;

pub const Tool = enum(u32) {
    pointer,
    pencil,
    eraser,
    bucket,
    selection,
};

pub const Shape = enum(u32) {
    circle,
    square,
};

pub const RadialMenu = struct {
    mouse_position: dvui.Point.Physical = .{ .x = 0.0, .y = 0.0 },
    center: dvui.Point.Physical = .{ .x = 0.0, .y = 0.0 },
    visible: bool = false,
};

current: Tool = .pointer,
previous: Tool = .pointer,
stroke_size: u8 = 1,
stroke_shape: Shape = .circle,
previous_drawing_tool: Tool = .pencil,
radial_menu: RadialMenu = .{},

stroke: std.StaticBitSet(max_brush_size * max_brush_size) = .initEmpty(),
offset_table: [][2]f32 = undefined,

pub fn init(allocator: std.mem.Allocator) !Tools {
    var tools: Tools = .{
        .offset_table = try allocator.alloc([2]f32, max_brush_size * max_brush_size),
    };

    for (0..(max_brush_size * max_brush_size)) |index| {
        const center: dvui.Point = .{ .x = @floor(max_brush_size_float / 2), .y = @floor(max_brush_size_float / 2) };
        const x: f32 = @as(f32, @floatFromInt(@mod(index, max_brush_size)));
        const y: f32 = @as(f32, @floatFromInt(index)) / max_brush_size_float;
        tools.offset_table[index] = .{ @floor(x - center.x), @floor(y - center.y) };
    }

    tools.setStrokeSize(1);

    return tools;
}

// Recreates the stroke bitset
pub fn setStrokeSize(self: *Tools, size: u8) void {
    self.stroke_size = size;

    const stroke_size: usize = @intCast(size);

    self.stroke.setRangeValue(.{ .start = 0, .end = max_brush_size * max_brush_size }, false);

    const center: dvui.Point = .{ .x = @floor(max_brush_size_float / 2), .y = @floor(max_brush_size_float / 2) };

    for (0..(stroke_size * stroke_size)) |index| {
        if (self.getIndexShapeOffset(center, index)) |i| {
            self.stroke.set(i);
        }
    }
}

pub fn deinit(self: *Tools) void {
    self.stroke_layer.deinit();
}

pub fn set(self: *Tools, tool: Tool) void {
    if (self.current != tool) {
        // if (pixi.editor.getFile(pixi.editor.open_file_index)) |file| {
        //     // if (file.transform_texture != null and tool != .pointer)
        //     //     return;

        //     switch (tool) {
        //         .heightmap => {
        //             file.heightmap.enable();
        //             if (file.heightmap.layer == null)
        //                 return;
        //         },
        //         .pointer => {
        //             file.heightmap.disable();

        //             // if (self.current == .selection)
        //             //     file.selection_layer.clear(true);
        //         },
        //         else => {},
        //     }
        // }
        self.previous = self.current;
        switch (self.previous) {
            .pencil, .bucket => |t| self.previous_drawing_tool = t,
            else => {},
        }
        self.current = tool;
    }
}

pub fn swap(self: *Tools) void {
    const temp = self.current;
    self.current = self.previous;
    self.previous = temp;
}

pub fn getIndex(_: *Tools, point: dvui.Point) ?usize {
    if (point.x < 0 or point.y < 0) {
        return null;
    }

    if (point.x >= max_brush_size_float or point.y >= max_brush_size_float) {
        return null;
    }

    const p: [2]usize = .{ @intFromFloat(point.x), @intFromFloat(point.y) };

    const index = p[0] + p[1] * @as(usize, @intFromFloat(max_brush_size_float));
    if (index >= max_brush_size * max_brush_size) {
        return 0;
    }
    return index;
}

/// Only used for handling getting the pixels surrounding the origin
/// for stroke sizes larger than 1
pub fn getIndexShapeOffset(self: *Tools, origin: dvui.Point, current_index: usize) ?usize {
    const shape = pixi.editor.tools.stroke_shape;
    const s: i32 = @intCast(pixi.editor.tools.stroke_size);

    if (s == 1) {
        if (current_index != 0)
            return null;

        if (self.getIndex(origin)) |index| {
            return index;
        }
    }

    const size_center_offset: i32 = -@divFloor(@as(i32, @intCast(s)), 2);
    const index_i32: i32 = @as(i32, @intCast(current_index));
    const pixel_offset: [2]i32 = .{ @mod(index_i32, s) + size_center_offset, @divFloor(index_i32, s) + size_center_offset };

    if (shape == .circle) {
        const extra_pixel_offset_circle: [2]i32 = if (@mod(s, 2) == 0) .{ 1, 1 } else .{ 0, 0 };
        const pixel_offset_circle: [2]i32 = .{ pixel_offset[0] * 2 + extra_pixel_offset_circle[0], pixel_offset[1] * 2 + extra_pixel_offset_circle[1] };
        const sqr_magnitude = pixel_offset_circle[0] * pixel_offset_circle[0] + pixel_offset_circle[1] * pixel_offset_circle[1];

        // adjust radius check for nicer looking circles
        const radius_check_mult: f32 = (if (s == 3 or s > 10) 0.7 else 0.8);

        if (@as(f32, @floatFromInt(sqr_magnitude)) > @as(f32, @floatFromInt(s * s)) * radius_check_mult) {
            return null;
        }
    }

    const pixel_i32: [2]i32 = .{ @as(i32, @intFromFloat(origin.x)) + pixel_offset[0], @as(i32, @intFromFloat(origin.y)) + pixel_offset[1] };
    const size_i32: [2]i32 = .{ @as(i32, @intCast(max_brush_size)), @as(i32, @intCast(max_brush_size)) };

    if (pixel_i32[0] < 0 or pixel_i32[1] < 0 or pixel_i32[0] >= size_i32[0] or pixel_i32[1] >= size_i32[1]) {
        return null;
    }

    const pixel: dvui.Point = .{ .x = @floatFromInt(pixel_i32[0]), .y = @floatFromInt(pixel_i32[1]) };

    if (self.getIndex(pixel)) |index| {
        return index;
    }

    return null;
}

pub fn drawTooltip(_: Tools, tool: Tool, rect: dvui.Rect.Physical, id_extra: u64) !void {
    const tool_name = switch (tool) {
        .pointer => "POINTER",
        .pencil => "PENCIL",
        .eraser => "ERASER",
        .bucket => "BUCKET",
        .selection => "SELECTION",
    };

    const tool_description = switch (tool) {
        .pointer => "Select and move cells, rows, or columns. \n" ++
            "Hold cmd/ctrl to add to selection, and shift to subtract. \n" ++
            "Dragging can add multiple cells at once.",
        .pencil => "Draw on the canvas with the left mouse button.\n" ++
            "Right click to pick up a color from the canvas. \n" ++
            "[ & ] keys increase and decrease the stroke size.",
        .eraser => "Erase on the canvas.\n" ++
            "Right click an empty area to switch to the eraser tool. \n" ++
            "[ & ] keys increase and decrease the erase size.",
        .bucket => "Fill the canvas with a color.\n" ++ "Hold cmd/ctrl to replace all color, non-contiguously.\n",
        .selection => "Create pixel-level selections.\n" ++ "Hold cmd/ctrl to add to selection, and shift to subtract. \n",
    };

    var tooltip: dvui.FloatingTooltipWidget = undefined;
    tooltip.init(@src(), .{
        .active_rect = rect,
        .delay = 1_000_000,
    }, .{
        .id_extra = id_extra,
        .color_fill = dvui.themeGet().color(.window, .fill).opacity(0.75),
        .border = dvui.Rect.all(0),
        .box_shadow = .{
            .color = .black,
            .shrink = 0,
            .corner_radius = dvui.Rect.all(8),
            .offset = .{ .x = 0, .y = 2 },
            .fade = 4,
            .alpha = 0.2,
        },
    });
    defer tooltip.deinit();

    if (tooltip.shown()) {
        var animator = dvui.animate(@src(), .{
            .kind = .alpha,
            .duration = 500_000,
        }, .{
            .expand = .both,
        });
        defer animator.deinit();

        var vbox2 = dvui.box(@src(), .{ .dir = .vertical }, dvui.FloatingTooltipWidget.defaults.override(.{
            .background = false,
            .expand = .both,
            .border = dvui.Rect.all(0),
        }));
        defer vbox2.deinit();

        pixi.dvui.labelWithKeybind(
            tool_name,
            switch (tool) {
                .pointer => dvui.currentWindow().keybinds.get("pointer") orelse .{},
                .pencil => dvui.currentWindow().keybinds.get("pencil") orelse .{},
                .eraser => dvui.currentWindow().keybinds.get("eraser") orelse .{},
                .bucket => dvui.currentWindow().keybinds.get("bucket") orelse .{},
                .selection => dvui.currentWindow().keybinds.get("selection") orelse .{},
            },
            true,
            .{
                .font = dvui.Font.theme(.title).larger(-4.0),
            },
            .{
                .font = dvui.Font.theme(.mono).larger(-2.0),
                .margin = dvui.Rect.all(4),
            },
        );

        _ = dvui.separator(@src(), .{ .expand = .horizontal });

        dvui.labelNoFmt(@src(), tool_description, .{}, .{
            .font = dvui.Font.theme(.body).larger(-1.0),
            .margin = dvui.Rect.all(4),
        });
    }
}
