const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

pub fn brezenham(start: imgui.ImVec2, end: imgui.ImVec2) []imgui.ImVec2 {
    var output = std.ArrayList(imgui.ImVec2).init(upaya.mem.allocator);

    var x1 = start.x;
    var y1 = start.y;
    var x2 = end.x;
    var y2 = end.y;

    const steep = std.math.absFloat(y2 - y1) > std.math.absFloat(x2 - x1);
    if (steep) {
        std.mem.swap(f32, &x1, &y1);
        std.mem.swap(f32, &x2, &y2);
    }

    if (x1 > x2) {
        std.mem.swap(f32, &x1, &x2);
        std.mem.swap(f32, &y1, &y2);
    }

    const dx: f32 = x2 - x1;
    const dy: f32 = std.math.absFloat(y2 - y1);

    var err: f32 = dx / 2.0;
    var ystep: i32 = if (y1 < y2) 1 else -1;
    var y: i32 = @floatToInt(i32, y1);

    const maxX: i32 = @floatToInt(i32, x2);

    var x: i32 = @floatToInt(i32, x1);
    while (x <= maxX) : (x += 1) {
        if (steep) {
            output.append(.{ .x = @intToFloat(f32, y), .y = @intToFloat(f32, x) }) catch unreachable;
        } else {
            output.append(.{ .x = @intToFloat(f32, x), .y = @intToFloat(f32, y) }) catch unreachable;
        }

        err -= dy;
        if (err < 0) {
            y += ystep;
            err += dx;
        }
    }

    return output.toOwnedSlice();
}


pub fn floodfill (coords: imgui.ImVec2, image: upaya.Image) []usize {

    var output: std.ArrayList(usize) = std.ArrayList(usize).init(upaya.mem.allocator);

    var x = @floatToInt(usize, coords.x);
    var y = @floatToInt(usize, coords.y);

    var index = x + y * image.w;

    //output.append(index) catch unreachable;

    floodFillRecursive(x,y, image, image.pixels[index], &output );

    return output.toOwnedSlice();
}

fn floodFillRecursive (x: usize, y: usize, image: upaya.Image, previousColor: u32, output: *std.ArrayList(usize)) void {

    var index = x + y * image.w;

    // if out of bounds
    if (x < 0 or x > image.w or y < 0 or y > image.h)
        return;

    if (image.pixels[index] != previousColor)
        return;
    
    for (output.items) |i| {
        if (i == index)
            return;
    }

    output.append(index) catch unreachable;

    floodFillRecursive(x+1, y, image, previousColor, output);
    floodFillRecursive(x, y+1, image, previousColor, output);
    floodFillRecursive(x-1, y, image, previousColor, output);
    floodFillRecursive(x, y-1, image, previousColor, output);
}