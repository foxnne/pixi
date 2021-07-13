const std = @import("std");
const upaya = @import("upaya");

const editor = @import("../editor.zig");
const types = @import("../types/types.zig");
const canvas = editor.canvas;
const layers = editor.layers;

pub const HistoryItem = struct {
    layer_id: ?usize = null,
    layer_state: ?types.Layer = null,
    pixel_colors: ?[]u32 = null,
    pixel_indexes: ?[]usize = null,
    tag: HistoryTag,
};

pub const HistoryTag = enum {
    new_layer,
    delete_layer,
    stroke,
};

var undoStack: std.ArrayList(HistoryItem) = undefined;
var redoStack: std.ArrayList(HistoryItem) = undefined;

pub fn init() void {
    undoStack = std.ArrayList(HistoryItem).init(upaya.mem.allocator);
    redoStack = std.ArrayList(HistoryItem).init(upaya.mem.allocator);
}

pub fn push(item: HistoryItem) void {
    undoStack.append(item) catch unreachable;
    // do we free things inside of the stack?
    if (redoStack.items.len > 0)
        redoStack.clearAndFree();
}

pub fn undo() void {
    if (undoStack.popOrNull()) |item| {
        switch (item.tag) {
            .new_layer => undoNewLayer(item),
            .delete_layer => undoDeleteLayer(item),
            .stroke => undoStroke(item),
        }
    }
}

pub fn redo() void {
    if (redoStack.popOrNull()) |item| {
        switch (item.tag) {
            .new_layer => undoDeleteLayer(item), //reusing the same functions, maybe better names?
            .delete_layer => undoNewLayer(item),
            .stroke => redoStroke(item),
        }
    }
}

fn undoNewLayer(item: HistoryItem) void {
    if (canvas.getActiveFile()) |file| {
        if (item.layer_id) |layer_id| {
            var layer: types.Layer = undefined;

            for (file.layers.items) |l, i| {
                if (l.id == layer_id)
                    layer = file.layers.orderedRemove(i);
            }

            var new_item = item;
            new_item.layer_state = layer;
            redoStack.append(new_item) catch unreachable;
        }
    }
}

fn undoDeleteLayer(item: HistoryItem) void {
    if (canvas.getActiveFile()) |file| {
        if (item.layer_state) |layer| {
            file.layers.insert(0, layer) catch unreachable;
            var new_item = item;
            new_item.layer_state = null;
            undoStack.append(new_item) catch unreachable;
        }
    }
}

fn undoStroke(item: HistoryItem) void {
    if (canvas.getActiveFile()) |file| {
        if (item.pixel_indexes) |indexes| {
            if (item.pixel_colors) |colors| {
                if (item.layer_id) |layer_id| {
                    if (layers.getLayer(layer_id)) |layer| {
                        var new_item = item;

                        for (indexes) |index, i| {
                            var prev_color = layer.image.pixels[index];
                            
                            layer.image.pixels[index] = colors[i];
                            new_item.pixel_colors.?[i] = prev_color;
                        }
                        layer.dirty = true;

                        redoStack.append(new_item) catch unreachable;
                    }
                }
            }
        }
    }
}

fn redoStroke(item: HistoryItem) void {
    if (canvas.getActiveFile()) |file| {
        if (item.pixel_indexes) |indexes| {
            if (item.pixel_colors) |colors| {
                if (item.layer_id) |layer_id| {
                    if (layers.getLayer(layer_id)) |layer| {
                        var new_item = item;

                        for (indexes) |index, i| {
                            var prev_color = layer.image.pixels[index];
                            
                            layer.image.pixels[index] = colors[i];
                            new_item.pixel_colors.?[i] = prev_color;
                        }
                        layer.dirty = true;

                        undoStack.append(new_item) catch unreachable;
                    }
                }
            }
        }
    }
}
