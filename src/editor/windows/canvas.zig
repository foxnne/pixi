const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

pub const Camera = @import("../utils/camera.zig").Camera;

const input = @import("../input/input.zig");

//todo: move these structs to own files
pub const Canvas = struct {
    width: i32,
    height: i32,
    tileWidth: i32,
    tileHeight: i32,
};

pub const File = struct {
    name: []const u8,
    canvas: Canvas,
};

var camera: Camera = .{ .zoom = 2 };
var screen_pos: imgui.ImVec2 = undefined;

const checkerColor1: upaya.math.Color = .{ .value = 0xFFDDDDDD };
const checkerColor2: upaya.math.Color = .{ .value = 0xFFEEEEEE };
const gridColor: upaya.math.Color = .{ .value = 0xFF999999 };
var logo: ?upaya.Texture = null;

var active_file_index: usize = 0;
var files: std.ArrayList(File) = undefined;
var backgrounds: std.ArrayList(upaya.Texture) = undefined;

pub fn init() void {
    files = std.ArrayList(File).init(upaya.mem.allocator);
    backgrounds = std.ArrayList(upaya.Texture).init(upaya.mem.allocator);
    logo = upaya.Texture.initFromFile("assets/pixi.png", .nearest) catch unreachable;
}

pub fn newFile(name: []const u8, canvas: Canvas) void {
    files.insert(0, .{ .name = name, .canvas = canvas }) catch unreachable;
    backgrounds.insert(0, upaya.Texture.initChecker(files.items[active_file_index].canvas.width, files.items[active_file_index].canvas.height, checkerColor1, checkerColor2)) catch unreachable;
    active_file_index = 0;

}

pub fn getNumberOfFiles() usize {
    return files.items.len;
}

pub fn draw() void {
    if (!imgui.igBegin("Canvas", null, imgui.ImGuiWindowFlags_None)) return;
    defer imgui.igEnd();

    // setup screen position and size
    screen_pos = imgui.ogGetCursorScreenPos();
    const window_size = imgui.ogGetContentRegionAvail();
    if (window_size.x == 0 or window_size.y == 0) return;

    if (files.items.len > 0) {

        // draw open files tabs
        if (imgui.igBeginTabBar("Canvas Tab Bar", imgui.ImGuiTabBarFlags_Reorderable)) {
            defer imgui.igEndTabBar();

            for (files.items) |file, i| {
                var open: bool = true;
                var name = @ptrCast([*c]const u8, file.name);
                if (imgui.igBeginTabItem(name, &open, imgui.ImGuiTabBarFlags_IsFocused)) {
                    defer imgui.igEndTabItem();
                    active_file_index = i;

                    var background_pos = .{ 
                        .x = -@intToFloat(f32, backgrounds.items[active_file_index].width) / 2, 
                        .y = -@intToFloat(f32, backgrounds.items[active_file_index].height) / 2, 
                    };

                    // draw background texture
                    drawTexture(backgrounds.items[active_file_index], background_pos);

                    // draw tile grid
                    drawGrid(files.items[active_file_index].canvas, background_pos);
                }

                if (!open) {
                    active_file_index = 0;
                    _ = files.swapRemove(i);
                    _ = backgrounds.swapRemove(i);
                }
            }
        }

        // handle inputs
        if (imgui.igIsWindowHovered(imgui.ImGuiHoveredFlags_None)) {
            if (imgui.igIsMouseDragging(imgui.ImGuiMouseButton_Middle, 0)) {
                input.pan(&camera);
            }

            if (imgui.igIsMouseDragging(imgui.ImGuiMouseButton_Left, 0) and imgui.ogKeyDown(@intCast(usize, imgui.igGetKeyIndex(imgui.ImGuiKey_Space)))) {
                input.pan(&camera);
            }

            if (imgui.igGetIO().MouseWheel != 0) {
                input.zoom(&camera);
            }
        }
    } else {
        camera.position = .{ .x = 0, .y = 0 };
        camera.zoom = 2;

        var logo_pos = .{ .x = -@intToFloat(f32, logo.?.width) / 2, .y = -@intToFloat(f32, logo.?.height) / 2 };
        // draw background texture
        drawTexture(logo.?, logo_pos);
    }
}

fn drawGrid(canvas: Canvas, position: imgui.ImVec2) void {
    var tilesWide = @divExact(canvas.width, canvas.tileWidth);
    var tilesTall = @divExact(canvas.height, canvas.tileHeight);

    var x: i32 = 0;
    while (x <= tilesWide) : (x += 1) {
        var top = position.add(.{ .x = @intToFloat(f32, x * canvas.tileWidth), .y = 0 });
        var bottom = position.add(.{ .x = @intToFloat(f32, x * canvas.tileWidth), .y = @intToFloat(f32, canvas.height) });

        top = camera.matrix().transformImVec2(top).add(screen_pos);
        bottom = camera.matrix().transformImVec2(bottom).add(screen_pos);

        imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), top, bottom, gridColor.value, 1);
    }

    var y: i32 = 0;
    while (y <= tilesTall) : (y += 1) {
        var left = position.add(.{ .x = 0, .y = @intToFloat(f32, y * canvas.tileHeight) });
        var right = position.add(.{ .x = @intToFloat(f32, canvas.width), .y = @intToFloat(f32, y * canvas.tileHeight) });

        left = camera.matrix().transformImVec2(left).add(screen_pos);
        right = camera.matrix().transformImVec2(right).add(screen_pos);

        imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), left, right, gridColor.value, 1);
    }

    var textPos = .{ .x = position.x + @intToFloat(f32, canvas.width) / 2, .y = position.y };
}

fn drawTexture(texture: upaya.Texture, position: imgui.ImVec2) void {
    const tl = camera.matrix().transformImVec2(position);
    var br = position;
    br.x += @intToFloat(f32, texture.width);
    br.y += @intToFloat(f32, texture.height);
    br = camera.matrix().transformImVec2(br);

    imgui.ogImDrawList_AddImage(
        imgui.igGetWindowDrawList(),
        texture.imTextureID(),
        tl.add(screen_pos),
        br.add(screen_pos),
        .{},
        .{ .x = 1, .y = 1 },
        0xFFFFFFFF,
    );
}

pub fn close() void {
    logo.?.deinit();
    for (backgrounds.items) |bg|
        bg.deinit();

    //background.?.deinit();
}
