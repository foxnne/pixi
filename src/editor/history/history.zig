const std = @import("std");
const upaya = @import("upaya");

const editor = @import("../editor.zig");
const types = @import("../types/types.zig");
const toolbar = editor.toolbar;
const canvas = editor.canvas;
const layers = editor.layers;

pub const HistoryItem = struct {
    layer_id: ?usize = null,
    layer_state: ?types.Layer = null,
    layer_name: ?[]const u8 = null,
    layer_mode: ?toolbar.Mode = .diffuse,
    pixel_colors: ?[]u32 = null,
    pixel_indexes: ?[]usize = null,
    selection_colors: ?[]u32 = null,
    selection_indexes: ?[]usize = null,
    tag: HistoryTag,
};

pub const HistoryTag = enum {
    new_layer,
    delete_layer,
    rename_layer,
    stroke,
};

pub const History = struct {
    undoStack: std.ArrayList(HistoryItem),
    redoStack: std.ArrayList(HistoryItem),

    pub fn init() History {
        var history: History = .{
            .undoStack = std.ArrayList(HistoryItem).init(upaya.mem.allocator),
            .redoStack = std.ArrayList(HistoryItem).init(upaya.mem.allocator),
        };
        return history;
    }

    pub fn getNumberOfUndos(self: History) usize {
        return self.undoStack.items.len;
    }

    pub fn getNumberOfRedos(self: History) usize {
        return self.redoStack.items.len;
    }

    pub fn push(self: *History, item: HistoryItem) void {
        self.undoStack.append(item) catch unreachable;

        // anything that could change the file needs to be undoable,
        // so this should be a good place to catch all the things that dirty a file?
        if (canvas.getActiveFile()) |file| {
            file.dirty = true;
        }
        // do we free things inside of the stack?
        if (self.redoStack.items.len > 0)
            self.redoStack.clearAndFree();
    }

    pub fn undo(self: *History) void {
        if (self.undoStack.popOrNull()) |item| {
            switch (item.tag) {
                .new_layer => self.undoNewLayer(item),
                .delete_layer => self.undoDeleteLayer(item),
                .rename_layer => self.undoLayerRename(item),
                .stroke => self.undoStroke(item),
            }
        }
    }

    pub fn redo(self: *History) void {
        if (self.redoStack.popOrNull()) |item| {
            switch (item.tag) {
                .new_layer => self.undoDeleteLayer(item), //reusing the same functions, maybe better names?
                .delete_layer => self.undoNewLayer(item),
                .rename_layer => self.redoLayerRename(item),
                .stroke => self.redoStroke(item),
            }
        }
    }

    fn undoNewLayer(self: *History, item: HistoryItem) void {
        if (canvas.getActiveFile()) |file| {
            if (item.layer_id) |layer_id| {
                var layer: types.Layer = undefined;

                for (file.layers.items) |l, i| {
                    if (l.id == layer_id)
                        layer = file.layers.orderedRemove(i);
                }

                var new_item = item;
                new_item.layer_state = layer;
                self.redoStack.append(new_item) catch unreachable;
            }
        }
    }

    fn undoDeleteLayer(self: *History, item: HistoryItem) void {
        if (canvas.getActiveFile()) |file| {
            if (item.layer_state) |layer| {
                file.layers.insert(0, layer) catch unreachable;
                var new_item = item;
                new_item.layer_state = null;
                self.undoStack.append(new_item) catch unreachable;
            }
        }
    }

    fn undoLayerRename(self: *History, item: HistoryItem) void {
        if (canvas.getActiveFile()) |_| {
            if (item.layer_name) |name| {
                if (item.layer_id) |id| {
                    if (layers.getLayer(id)) |layer| {
                        var old_name = layer.name;
                        layer.name = name;

                        var new_item = item;
                        new_item.layer_name = old_name;
                        self.redoStack.append(new_item) catch unreachable;
                    }
                }
            }
        }
    }

    fn redoLayerRename(self: *History, item: HistoryItem) void {
        if (canvas.getActiveFile()) |_| {
            if (item.layer_name) |name| {
                if (item.layer_id) |id| {
                    if (layers.getLayer(id)) |layer| {
                        var old_name = layer.name;
                        layer.name = name;

                        var new_item = item;
                        new_item.layer_name = old_name;
                        self.undoStack.append(new_item) catch unreachable;
                    }
                }
            }
        }
    }

    fn undoStroke(self: *History, item: HistoryItem) void {
        if (canvas.getActiveFile()) |_| {
            if (item.pixel_indexes) |indexes| {
                if (item.pixel_colors) |colors| {
                    if (item.layer_id) |layer_id| {
                        if (layers.getLayer(layer_id)) |layer| {
                            var new_item = item;

                            for (indexes) |index, i| {
                                var prev_color = switch (item.layer_mode.?) {
                                    .diffuse => layer.image.pixels[index],
                                    .height => layer.heightmap_image.pixels[index],
                                };

                                switch (item.layer_mode.?) {
                                    .diffuse => layer.image.pixels[index] = colors[i],
                                    .height => layer.heightmap_image.pixels[index] = colors[i],
                                }
                                new_item.pixel_colors.?[i] = prev_color;
                            }
                            layer.dirty = true;

                            self.redoStack.append(new_item) catch unreachable;
                        }
                    }
                }
            }
        }
    }

    fn redoStroke(self: *History, item: HistoryItem) void {
        if (canvas.getActiveFile()) |_| {
            if (item.pixel_indexes) |indexes| {
                if (item.pixel_colors) |colors| {
                    if (item.layer_id) |layer_id| {
                        if (layers.getLayer(layer_id)) |layer| {
                            var new_item = item;

                            for (indexes) |index, i| {
                                var prev_color = switch (item.layer_mode.?) {
                                    .diffuse => layer.image.pixels[index],
                                    .height => layer.heightmap_image.pixels[index],
                                };

                                switch (item.layer_mode.?) {
                                    .diffuse => layer.image.pixels[index] = colors[i],
                                    .height => layer.heightmap_image.pixels[index] = colors[i],
                                }
                                new_item.pixel_colors.?[i] = prev_color;
                            }
                            layer.dirty = true;

                            self.undoStack.append(new_item) catch unreachable;
                        }
                    }
                }
            }
        }
    }
};
