const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");

pub const Camera = @import("../utils/camera.zig").Camera;

const input = @import("../input/input.zig");
const types = @import("../types/types.zig");
const toolbar = @import("../windows/toolbar.zig");

const File = types.File;
const Layer = types.Layer;
const Animation = types.Animation;

var camera: Camera = .{ .zoom = 2 };
var screen_pos: imgui.ImVec2 = undefined;

const gridColor: upaya.math.Color = .{ .value = 0xFF999999 };
var logo: ?upaya.Texture = null;

var active_file_index: usize = 0;
var files: std.ArrayList(File) = undefined;

pub fn init() void {
    files = std.ArrayList(File).init(upaya.mem.allocator);
    logo = upaya.Texture.initFromFile("assets/pixi.png", .nearest) catch unreachable;
}

pub fn newFile(file: File) void {
    files.insert(0, file) catch unreachable;
    active_file_index = 0;
}

pub fn getNumberOfFiles() usize {
    return files.items.len;
}

pub fn getActiveFile() ?*File {
    if (files.items.len == 0)
        return null;

    return &files.items[active_file_index];
}

pub fn draw() void {

    if (!imgui.igBegin("Canvas", null, imgui.ImGuiWindowFlags_None)) return;
    defer imgui.igEnd();

    // setup screen position and size
    screen_pos = imgui.ogGetCursorScreenPos();
    const window_size = imgui.ogGetContentRegionAvail();
    if (window_size.x == 0 or window_size.y == 0) return;

    if (files.items.len > 0) {
        var background_pos = .{
            .x = -@intToFloat(f32, files.items[active_file_index].background.width) / 2,
            .y = -@intToFloat(f32, files.items[active_file_index].background.height) / 2,
        };


        // draw background texture
        drawTexture(files.items[active_file_index].background, background_pos);
        // draw tile grid
        drawGrid(files.items[active_file_index], background_pos);

        // draw open files tabs
        if (imgui.igBeginTabBar("Canvas Tab Bar", imgui.ImGuiTabBarFlags_Reorderable)) {
            defer imgui.igEndTabBar();

            for (files.items) |file, i| {
                var open: bool = true;

                //var name = std.fmt.allocPrint(upaya.mem.allocator, "{s}\u{0}", .{file.name}) catch unreachable;
                //TODO: this crashes on windows unless 0 terminated as above, but then it crashes when closing non-active tabs

                var namePtr = @ptrCast([*c]const u8, file.name);
                if (imgui.igBeginTabItem(namePtr, &open, imgui.ImGuiTabItemFlags_UnsavedDocument)) {
                    defer imgui.igEndTabItem();
                    active_file_index = i;
                }

                if (!open) {
                    // TODO: do i need to deinit all the layers and background?
                    active_file_index = 0;
                    var f = files.swapRemove(i);
                }
            }
        }

        // handle inputs
        if (imgui.igIsWindowHovered(imgui.ImGuiHoveredFlags_None)) {
            if (toolbar.selected_tool == .hand and imgui.igIsMouseDragging(imgui.ImGuiMouseButton_Left, 0)){
                input.pan(&camera, imgui.ImGuiMouseButton_Left);
            }


            if (imgui.igIsMouseDragging(imgui.ImGuiMouseButton_Middle, 0)) {
                input.pan(&camera, imgui.ImGuiMouseButton_Middle);
            }

            if (imgui.igIsMouseDragging(imgui.ImGuiMouseButton_Left, 0) and imgui.ogKeyDown(@intCast(usize, imgui.igGetKeyIndex(imgui.ImGuiKey_Space)))) {
                input.pan(&camera, imgui.ImGuiMouseButton_Left);
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

fn drawGrid(file: File, position: imgui.ImVec2) void {
    var tilesWide = @divExact(file.width, file.tileWidth);
    var tilesTall = @divExact(file.height, file.tileHeight);

    var x: i32 = 0;
    while (x <= tilesWide) : (x += 1) {
        var top = position.add(.{ .x = @intToFloat(f32, x * file.tileWidth), .y = 0 });
        var bottom = position.add(.{ .x = @intToFloat(f32, x * file.tileWidth), .y = @intToFloat(f32, file.height) });

        top = camera.matrix().transformImVec2(top).add(screen_pos);
        bottom = camera.matrix().transformImVec2(bottom).add(screen_pos);

        imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), top, bottom, gridColor.value, 1);
    }

    var y: i32 = 0;
    while (y <= tilesTall) : (y += 1) {
        var left = position.add(.{ .x = 0, .y = @intToFloat(f32, y * file.tileHeight) });
        var right = position.add(.{ .x = @intToFloat(f32, file.width), .y = @intToFloat(f32, y * file.tileHeight) });

        left = camera.matrix().transformImVec2(left).add(screen_pos);
        right = camera.matrix().transformImVec2(right).add(screen_pos);

        imgui.ogImDrawList_AddLine(imgui.igGetWindowDrawList(), left, right, gridColor.value, 1);
    }
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
    for (files.items) |file|
        file.background.deinit();
}
