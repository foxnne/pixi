const std = @import("std");
const upaya = @import("upaya");

const editor = @import("../editor.zig");
const types = @import("../types/types.zig");
const canvas = editor.canvas;
const layers = editor.layers;

pub const HistoryItem = struct {
    layer_id: ?usize = null,
    layer_state: ?types.Layer = null,
    tag: HistoryTag,
};

pub const HistoryTag = enum {
    new_layer,
    delete_layer,
};

var undoStack: std.ArrayList(HistoryItem) = undefined;
var redoStack: std.ArrayList(HistoryItem) = undefined;

pub fn init() void {
    undoStack = std.ArrayList(HistoryItem).init(upaya.mem.allocator);
    redoStack = std.ArrayList(HistoryItem).init(upaya.mem.allocator);
}

pub fn push(item: HistoryItem) void {
    undoStack.append(item) catch unreachable;
    if (redoStack.items.len > 0)
        redoStack.clearAndFree();
}

pub fn undo() void {
    if (undoStack.popOrNull()) |item| {
        switch (item.tag) {
            .new_layer => undoNewLayer(item),
            .delete_layer => undoDeleteLayer(item),
        }
    }
}

pub fn redo() void {
    if (redoStack.popOrNull()) |item| {
        switch (item.tag) {
            .new_layer => redoNewLayer(item),
            .delete_layer => redoDeleteLayer(item),
        }
    }
}

fn undoNewLayer(item: HistoryItem) void {
    if (canvas.getActiveFile()) |file| {
        if (item.layer_id) |layer_id| {
            var layer: types.Layer = undefined;

            for (file.layers.items) |l, i| {
                if (l.id == layer_id)
                    layer = file.layers.swapRemove(i);
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

fn redoNewLayer(item: HistoryItem) void {
    if (canvas.getActiveFile()) |file| {
        if (item.layer_state) |layer| {
            file.layers.insert(0, layer) catch unreachable;
            var new_item = item;
            new_item.layer_state = null;
            undoStack.append(new_item) catch unreachable;
        }
    }
}

fn redoDeleteLayer(item: HistoryItem) void {
    if (canvas.getActiveFile()) |file| {
        if (item.layer_id) |layer_id| {
            var layer: types.Layer = undefined;

            for (file.layers.items) |l, i| {
                if (l.id == layer_id)
                    layer = file.layers.swapRemove(i);
            }

            var new_item = item;
            new_item.layer_state = layer;
            redoStack.append(new_item) catch unreachable;
        }
    }
}
