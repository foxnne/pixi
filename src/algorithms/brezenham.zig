const std = @import("std");
const pixi = @import("../pixi.zig");
const dvui = @import("dvui"); 

pub fn process(start: dvui.Point, end: dvui.Point) ![]dvui.Point {
    const x0 = start.x;
    const y0 = start.y;
    const x1 = end.x;
    const y1 = end.y;

    if (@abs(y1 - y0) < @abs(x1 - x0)) {
        if (x0 > x1) {
            return try plotLineLow(end, start);
        } else {
            return try plotLineLow(start, end);
        }
    } else {
        if (y0 > y1) {
            return try plotLineHigh(end, start);
        } else {
            return try plotLineHigh(start, end);
        }
    }

    return error.PlotLineError;
}

fn plotLineLow(p1: dvui.Point, p2: dvui.Point) ![]dvui.Point {
    var output = std.ArrayList(dvui.Point).init(pixi.editor.arena.allocator());

    const x0 = p1.x;
    const y0 = p1.y;
    const x1 = p2.x;
    const y1 = p2.y;

    const dx = x1 - x0;
    var dy = y1 - y0;
    var yi: f32 = 1;
    if (dy < 0) {
        yi = -1;
        dy = -dy;
    }

    var D = 2 * dy - dx;
    var y = y0;
    var x = x0;

    while (x < x1) : (x += 1) {
        try output.append(.{ .x = @floor(x), .y = @floor(y) });

        if (D > 0) {
            y = y + yi;
            D = D + (2 * (dy - dx));
        } else {
            D = D + (2 * dy);
        }
    }

    return output.items;
}

fn plotLineHigh(p1: dvui.Point, p2: dvui.Point) ![]dvui.Point {
    var output = std.ArrayList(dvui.Point).init(pixi.editor.arena.allocator());

    const x0 = p1.x;
    const y0 = p1.y;
    const x1 = p2.x;
    const y1 = p2.y;

    var dx = x1 - x0;
    const dy = y1 - y0;
    var xi: f32 = 1;
    if (dx < 0) {
        xi = -1;
        dx = -dx;
    }

    var D = (2 * dx) - dy;
    var x = x0;
    var y = y0;

    while (y < y1) : (y += 1) {
        try output.append(.{ .x = @floor(x), .y = @floor(y) });

        if (D > 0) {
            x = x + xi;
            D = D + (2 * (dx - dy));
        } else {
            D = D + (2 * dx);
        }
    }

    return output.items;
}
