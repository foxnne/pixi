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

pub fn floodfill(coords: imgui.ImVec2, image: upaya.Image, contiguous: bool) []usize {
    var output: std.ArrayList(usize) = std.ArrayList(usize).init(upaya.mem.allocator);

    var x = @floatToInt(i32, coords.x);
    var y = @floatToInt(i32, coords.y);

    var index = @intCast(usize, x) + @intCast(usize, y) *  image.w;

    if (contiguous){
        floodFillRecursive(x, y, image, image.pixels[index], &output);

    } else {
        for (image.pixels) |pixel, i|{
            if (pixel == image.pixels[index]) {
                output.append(i) catch unreachable;
            }
        }
    }
    
    return output.toOwnedSlice();
}

//TODO: this crashes with a stack overflow on canvases large enough...
fn floodFillRecursive(x: i32, y: i32, image: upaya.Image, previousColor: u32, output: *std.ArrayList(usize)) void {

    const index_check = x + y * @intCast(i32, image.w);
    var index = if (index_check >= 0) @intCast(usize, index_check) else 0;

    if (index >= image.pixels.len)
        return;

    if (image.pixels[index] != previousColor)
        return;

    // if already colored
    for (output.items) |i| {
        if (i == index)
            return;
    }

    output.append(index) catch unreachable;

    floodFillRecursive(x + 1, y, image, previousColor, output);
    floodFillRecursive(x, y + 1, image, previousColor, output);
    floodFillRecursive(x - 1, y, image, previousColor, output);
    floodFillRecursive(x, y - 1, image, previousColor, output);
}
