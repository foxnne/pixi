const std = @import("std");
const pixi = @import("../pixi.zig");
//const zstbi = @import("zstbi");
const zip = @import("zip");
const dvui = @import("dvui");

const Editor = pixi.Editor;

const File = @This();

const Texture = @import("Texture.zig");
const Layer = @import("Layer.zig");
const Sprite = @import("Sprite.zig");
const Animation = @import("Animation.zig");

pub const FileWidgetData = struct {
    grouping: u64 = 0,
    rect: dvui.Rect.Physical = .{},
    scroll_container: *dvui.ScrollContainerWidget = undefined,
    scroll_rect_scale: dvui.RectScale = .{},
    screen_rect_scale: dvui.RectScale = .{},
    scroll_info: dvui.ScrollInfo = .{ .vertical = .given, .horizontal = .given },
    origin: dvui.Point = .{},
    scale: f32 = 1.0,
    prev_drag_point: ?dvui.Point = null,
    sample_data_point: ?dvui.Point = null,

    pub fn dataFromScreenPoint(self: *FileWidgetData, screen: dvui.Point.Physical) dvui.Point {
        return self.screen_rect_scale.pointFromPhysical(screen);
    }

    pub fn screenFromDataPoint(self: *FileWidgetData, data: dvui.Point) dvui.Point.Physical {
        return self.screen_rect_scale.pointToPhysical(data);
    }

    pub fn viewportFromScreenPoint(self: *FileWidgetData, screen: dvui.Point.Physical) dvui.Point {
        return self.scroll_rect_scale.pointFromPhysical(screen);
    }

    pub fn screenFromViewportPoint(self: *FileWidgetData, viewport: dvui.Point) dvui.Point.Physical {
        return self.scroll_rect_scale.pointToPhysical(viewport);
    }

    pub fn dataFromScreenRect(self: *FileWidgetData, screen: dvui.Rect.Physical) dvui.Rect {
        return self.screen_rect_scale.rectFromPhysical(screen);
    }

    pub fn screenFromDataRect(self: *FileWidgetData, data: dvui.Rect) dvui.Rect.Physical {
        return self.screen_rect_scale.rectToPhysical(data);
    }

    pub fn viewportFromScreenRect(self: *FileWidgetData, screen: dvui.Rect.Physical) dvui.Rect {
        return self.scroll_rect_scale.rectFromPhysical(screen);
    }

    pub fn screenFromViewportRect(self: *FileWidgetData, viewport: dvui.Rect) dvui.Rect.Physical {
        return self.scroll_rect_scale.rectToPhysical(viewport);
    }

    /// If the mouse position is currently contained within the canvas rect,
    /// Returns the data/world point of the mouse, which corresponds to the pixel input of
    /// Layer functions
    pub fn hovered(self: *FileWidgetData) ?dvui.Point {
        if (self.mouse()) |m| {
            if (self.rect.contains(m.p)) {
                return self.dataFromScreenPoint(m.p);
            }
        }

        return null;
    }

    pub fn clicked(self: *FileWidgetData) ?dvui.Point {
        if (self.hovered()) |p| {
            if (dvui.clicked(
                self.scroll_container.data().id,
                .{ .rect = self.rect },
            )) {
                return p;
            }
        }
    }

    /// Returns the mouse screen position if an event occured this frame
    pub fn mouse(self: *FileWidgetData) ?dvui.Event.Mouse {
        for (dvui.events()) |*e| {
            if (!self.scroll_container.matchEvent(e))
                continue;

            switch (e.evt) {
                .mouse => |me| {
                    return me;
                },
                else => {},
            }
        }

        return null;
    }
};

id: u64,
path: []const u8,
width: u32,
height: u32,
tile_width: u32,
tile_height: u32,
canvas: FileWidgetData = .{},
layers: std.MultiArrayList(Layer),
sprites: std.MultiArrayList(Sprite),
animations: std.MultiArrayList(Animation),
deleted_layers: std.MultiArrayList(Layer),
deleted_heightmap_layers: std.MultiArrayList(Layer),
deleted_animations: std.MultiArrayList(Animation),
selected_layer_index: usize = 0,
selected_sprite_index: usize = 0,
selected_sprites: std.ArrayList(usize),
temporary_layer: Layer,
selection_layer: Layer,
heightmap: Heightmap = .{},
history: History,
buffers: Buffers,
counter: u64 = 0,
saving: bool = false,

pub const ScrollRequest = struct {
    from: f32,
    to: f32,
    elapsed: f32 = 0.0,
    state: AnimationState,
};

pub const TransformTexture = struct {
    vertices: [4]TransformVertex,
    pivot: ?TransformVertex = null,
    control: ?TransformControl = null,
    action: TransformAction = .none,
    rotation: f32 = 0.0,
    rotation_grip_height: f32 = 8.0,
    texture: pixi.gfx.Texture,
    confirm: bool = false,
    pivot_offset_angle: f32 = 0.0,
    temporary: bool = false,
    keyframe_parent_id: ?u32 = null,
};

pub const TransformAction = enum {
    none,
    pan,
    rotate,
    move_pivot,
    move_vertex,
};

pub const TransformVertex = struct {
    position: [2]f32,
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

//pub const FlipbookView = enum { canvas, timeline };

pub const AnimationState = enum { pause, play };
pub const Canvas = enum { primary, flipbook };

pub const History = @import("History.zig");
pub const Buffers = @import("Buffers.zig");

pub const Heightmap = struct {
    visible: bool = false,
    layer: ?Layer = null,

    pub fn enable(self: *Heightmap) void {
        if (self.layer != null) {
            self.visible = true;
        }
        // } else {
        //     pixi.editor.popups.heightmap = true;
        // }
    }

    pub fn disable(self: *Heightmap) void {
        self.visible = false;
        if (pixi.editor.tools.current == .heightmap) {
            pixi.editor.tools.swap();
        }
    }

    pub fn toggle(self: *Heightmap) void {
        if (self.visible) self.disable() else self.enable();
    }
};

pub fn load(path: []const u8) !?pixi.Internal.File {
    if (!std.mem.eql(u8, std.fs.path.extension(path[0..path.len]), ".pixi"))
        return null;

    blk_open: {
        const null_terminated_path = try dvui.currentWindow().arena().dupeZ(u8, path);

        const pixi_file = zip.zip_open(null_terminated_path.ptr, 0, 'r') orelse break :blk_open;
        defer zip.zip_close(pixi_file);

        var buf: ?*anyopaque = null;
        var size: u64 = 0;
        _ = zip.zip_entry_open(pixi_file, "pixidata.json");
        _ = zip.zip_entry_read(pixi_file, &buf, &size);
        _ = zip.zip_entry_close(pixi_file);

        const content: []const u8 = @as([*]const u8, @ptrCast(buf))[0..size];

        const options = std.json.ParseOptions{
            .duplicate_field_behavior = .use_first,
            .ignore_unknown_fields = true,
        };

        var parsed = std.json.parseFromSlice(pixi.File, pixi.app.allocator, content, options) catch return error.FileLoadError;
        defer parsed.deinit();

        const ext = parsed.value;

        var internal: pixi.Internal.File = .{
            .id = pixi.editor.counter,
            .path = try pixi.app.allocator.dupe(u8, path),
            .width = ext.width,
            .height = ext.height,
            .tile_width = ext.tile_width,
            .tile_height = ext.tile_height,
            .layers = .{},
            .deleted_layers = .{},
            .deleted_heightmap_layers = .{},
            .sprites = .{},
            .selected_sprites = .init(pixi.app.allocator),
            .animations = .{},
            .deleted_animations = .{},
            .history = pixi.Internal.File.History.init(pixi.app.allocator),
            .buffers = pixi.Internal.File.Buffers.init(pixi.app.allocator),
            .temporary_layer = undefined,
            .selection_layer = undefined,
        };


        internal.temporary_layer = try .init(internal.newID(), "Temporary", .{ internal.width, internal.height }, .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .ptr);

        for (ext.layers) |l| {
            const layer_image_name = std.fmt.allocPrintZ(dvui.currentWindow().arena(), "{s}.png", .{l.name}) catch "Memory Allocation Failed";

            var img_buf: ?*anyopaque = null;
            var img_len: usize = 0;

            if (zip.zip_entry_open(pixi_file, layer_image_name.ptr) == 0) {
                _ = zip.zip_entry_read(pixi_file, &img_buf, &img_len);
                const data = img_buf orelse continue;

                const new_layer: pixi.Internal.Layer = try .fromImageFile(
                    internal.newID(),
                    l.name,
                    @as([*]u8, @ptrCast(data))[0..img_len],
                    .ptr,
                );
                internal.layers.append(pixi.app.allocator, new_layer) catch return error.FileLoadError;
            }

            _ = zip.zip_entry_close(pixi_file);
        }
        _ = zip.zip_entry_close(pixi_file);

        for (ext.sprites) |sprite| {
            internal.sprites.append(pixi.app.allocator, .{
                .origin = .{ @floatFromInt(sprite.origin[0]), @floatFromInt(sprite.origin[1]) },
            }) catch return error.FileLoadError;
        }

        for (ext.animations) |animation| {
            internal.animations.append(pixi.app.allocator, .{
                .name = try pixi.app.allocator.dupeZ(u8, animation.name),
                .start = animation.start,
                .length = animation.length,
                .fps = animation.fps,
            }) catch return error.FileLoadError;
        }
        pixi.editor.counter += 1;
        return internal;
    }

    return error.FileLoadError;
}

pub fn deinit(file: *File) void {
    file.history.deinit();
    file.buffers.deinit();

    for (file.layers.items(.name)) |name| {
        pixi.app.allocator.free(name);
    }

    file.layers.deinit(pixi.app.allocator);
    file.deleted_layers.deinit(pixi.app.allocator);
    file.deleted_heightmap_layers.deinit(pixi.app.allocator);
    file.sprites.deinit(pixi.app.allocator);
    file.selected_sprites.deinit();
    file.animations.deinit(pixi.app.allocator);
    file.deleted_animations.deinit(pixi.app.allocator);
    pixi.app.allocator.free(file.path);
}

pub fn dirty(self: File) bool {
    return self.history.bookmark != 0;
}

pub fn newID(file: *File) u64 {
    file.counter += 1;
    return file.counter;
}

pub const DrawLayer = enum {
    temporary,
    selected,
};

/// Draws a point on the selected (the point will be added to the stroke buffer) or temporary layer
/// If to_change is true, the point will be added to the stroke buffer and then the history will be appended
/// If invalidate is true, the layer will be invalidated
pub fn drawPoint(file: *File, point: dvui.Point, color: [4]u8, layer: DrawLayer, invalidate: bool, to_change: bool) void {
    var active_layer: Layer = switch (layer) {
        .temporary => file.temporary_layer,
        .selected => file.layers.get(file.selected_layer_index),
    };

    const size: u32 = @intCast(pixi.editor.tools.stroke_size);

    for (0..(size * size)) |stroke_index| {
        if (active_layer.getIndexShapeOffset(point, stroke_index)) |result| {
            if (layer == .selected) {
                file.buffers.stroke.append(result.index, result.color) catch {
                    std.log.err("Failed to append to stroke buffer", .{});
                };
            }
            active_layer.setPixelIndex(result.index, color);

            if (invalidate) {
                active_layer.invalidate();
            }
        }
    }

    if (to_change and layer == .selected) {
        const change_opt = file.buffers.stroke.toChange(active_layer.id) catch null;
        if (change_opt) |change| {
            file.history.append(change) catch {
                std.log.err("Failed to append to history", .{});
            };
        }
    }
}

pub fn drawLine(file: *File, point1: dvui.Point, point2: dvui.Point, color: [4]u8, layer: DrawLayer, invalidate: bool, to_change: bool) void {
    if (pixi.algorithms.brezenham.process(point1, point2) catch null) |points| {
        for (points, 0..) |point, index| {
            if (index == points.len - 1) {
                drawPoint(file, point, color, layer, invalidate, to_change);
            } else {
                drawPoint(file, point, color, layer, false, false);
            }
        }
    }
}

pub fn undo(self: *File) !void {
    return self.history.undoRedo(self, .undo);
}

pub fn redo(self: *File) !void {
    return self.history.undoRedo(self, .redo);
}
