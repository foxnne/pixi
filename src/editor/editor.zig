const std = @import("std");

const upaya = @import("upaya");
const imgui = @import("imgui");
const sokol = @import("sokol");

pub const types = @import("types/types.zig");
pub const history = @import("history/history.zig");
pub const input = @import("input/input.zig");

//windows and bars
pub const menubar = @import("menubar.zig");
pub const toolbar = @import("windows/toolbar.zig");
pub const layers = @import("windows/layers.zig");
pub const animations = @import("windows/animations.zig");
pub const canvas = @import("windows/canvas.zig");
pub const sprites = @import("windows/sprites.zig");
pub const spriteedit = @import("windows/spriteedit.zig");

// popups
pub const newfile = @import("windows/newfile.zig");
pub const closefile = @import("windows/closefile.zig");
pub const slice = @import("windows/slice.zig");
pub const pack = @import("windows/pack.zig");

//editor colors
pub var background_color: imgui.ImVec4 = undefined;
pub var foreground_color: imgui.ImVec4 = undefined;
pub var text_color: imgui.ImVec4 = undefined;
pub var highlight_color_green: imgui.ImVec4 = undefined;
pub var highlight_hover_color_green: imgui.ImVec4 = undefined;
pub var highlight_color_red: imgui.ImVec4 = undefined;
pub var highlight_hover_color_red: imgui.ImVec4 = undefined;

pub var pixi_green: imgui.ImVec4 = undefined;
pub var pixi_green_hover: imgui.ImVec4 = undefined;
pub var pixi_blue: imgui.ImVec4 = undefined;
pub var pixi_blue_hover: imgui.ImVec4 = undefined;
pub var pixi_orange: imgui.ImVec4 = undefined;
pub var pixi_orange_hover: imgui.ImVec4 = undefined;

pub const checker_color_1: upaya.math.Color = .{ .value = 0xFFDDDDDD };
pub const checker_color_2: upaya.math.Color = .{ .value = 0xFFEEEEEE };

pub const grid_color: upaya.math.Color = .{ .value = 0xFF999999 };
pub var selection_feedback_color: upaya.math.Color = upaya.math.Color.red;
pub var selection_color: upaya.math.Color = upaya.math.Color.red;

pub var enable_hotkeys: bool = true;

pub fn init() void {
    background_color = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(30, 31, 39, 255));
    foreground_color = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(42, 44, 54, 255));
    text_color = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(230, 175, 137, 255));

    highlight_color_green = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(47, 179, 135, 255));
    highlight_hover_color_green = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(76, 148, 123, 255));

    highlight_color_red = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(76, 48, 67, 255));
    highlight_hover_color_red = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(105, 50, 68, 255));

    pixi_green = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(103, 193, 123, 150));
    pixi_green_hover = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(64, 133, 103, 150));
    pixi_blue = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(74, 143, 167, 150));
    pixi_blue_hover = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(49, 69, 132, 150));
    pixi_orange = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(194, 109, 92, 150));
    pixi_orange_hover = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(140, 80, 88, 150));

    imgui.igGetIO().ConfigWindowsMoveFromTitleBarOnly = true;

    // set colors, move this to its own file soon?
    var style = imgui.igGetStyle();
    style.TabRounding = 2;
    style.FrameRounding = 8;
    style.WindowBorderSize = 1;
    if (std.builtin.os.tag == .macos) {
        style.WindowRounding = 8;
    } else style.WindowRounding = 0;
    style.WindowMinSize = .{ .x = 100, .y = 100 };
    style.WindowMenuButtonPosition = imgui.ImGuiDir_None;
    style.PopupRounding = 8;
    style.WindowTitleAlign = .{ .x = 0.5, .y = 0.5 };
    style.Colors[imgui.ImGuiCol_WindowBg] = background_color;
    style.Colors[imgui.ImGuiCol_Border] = foreground_color;
    style.Colors[imgui.ImGuiCol_MenuBarBg] = foreground_color;
    style.Colors[imgui.ImGuiCol_DockingEmptyBg] = background_color;
    style.Colors[imgui.ImGuiCol_Separator] = foreground_color;
    style.Colors[imgui.ImGuiCol_TitleBg] = background_color;
    style.Colors[imgui.ImGuiCol_Tab] = background_color;
    style.Colors[imgui.ImGuiCol_TabUnfocused] = background_color;
    style.Colors[imgui.ImGuiCol_TabUnfocusedActive] = background_color;
    style.Colors[imgui.ImGuiCol_TitleBgActive] = foreground_color;
    style.Colors[imgui.ImGuiCol_TabActive] = foreground_color;
    style.Colors[imgui.ImGuiCol_TabHovered] = foreground_color;
    style.Colors[imgui.ImGuiCol_PopupBg] = background_color;
    style.Colors[imgui.ImGuiCol_Text] = text_color;
    style.Colors[imgui.ImGuiCol_ResizeGrip] = highlight_color_green;
    style.Colors[imgui.ImGuiCol_ScrollbarGrabActive] = highlight_color_green;
    style.Colors[imgui.ImGuiCol_ScrollbarGrabHovered] = highlight_hover_color_green;

    style.Colors[imgui.ImGuiCol_Header] = highlight_color_red;
    style.Colors[imgui.ImGuiCol_HeaderHovered] = highlight_hover_color_red;
    style.Colors[imgui.ImGuiCol_HeaderActive] = highlight_color_red;
    style.Colors[imgui.ImGuiCol_ScrollbarBg] = background_color;
    style.Colors[imgui.ImGuiCol_ScrollbarGrab] = foreground_color;
    style.Colors[imgui.ImGuiCol_DockingPreview] = highlight_color_green;
    style.Colors[imgui.ImGuiCol_ModalWindowDimBg] = imgui.ogColorConvertU32ToFloat4(upaya.colors.rgbaToU32(10, 10, 15, 100));

    canvas.init();
    sprites.init();
    pack.init();
}

pub fn setupDockLayout(id: imgui.ImGuiID) void {
    var dock_main_id = id;

    var bottom_id = imgui.igDockBuilderSplitNode(dock_main_id, imgui.ImGuiDir_Down, 0.3, null, &dock_main_id);
    var left_id = imgui.igDockBuilderSplitNode(dock_main_id, imgui.ImGuiDir_Left, 0.11, null, &dock_main_id);
    var mid_id: imgui.ImGuiID = 0;
    var right_id = imgui.igDockBuilderSplitNode(dock_main_id, imgui.ImGuiDir_Right, 0.15, null, &mid_id);

    imgui.igDockBuilderDockWindow("Canvas", mid_id);
    imgui.igDockBuilderDockWindow("Toolbar", left_id);
    imgui.igDockBuilderDockWindow("Layers", right_id);

    var bottom_right_id = imgui.igDockBuilderSplitNode(bottom_id, imgui.ImGuiDir_Right, 0.15, null, &bottom_id);
    var bottom_mid_id = imgui.igDockBuilderSplitNode(bottom_id, imgui.ImGuiDir_Right, 0.85, null, &bottom_id);

    imgui.igDockBuilderDockWindow("Animations", bottom_right_id);
    imgui.igDockBuilderDockWindow("SpriteEdit", bottom_mid_id);
    imgui.igDockBuilderDockWindow("Sprites", bottom_id);

    imgui.igDockBuilderFinish(id);
}

pub fn resetDockLayout() void {
    imgui.igDockContextClearNodes(imgui.igGetCurrentContext(), 0, true);
}

pub fn isModKeyDown() bool {
    if (std.builtin.os.tag == .windows) {
        return imgui.ogKeyDown(sokol.SAPP_KEYCODE_LEFT_CONTROL) or imgui.ogKeyDown(sokol.SAPP_KEYCODE_RIGHT_CONTROL);
    } else {
        const io = imgui.igGetIO();
        return io.KeySuper;
    }
}

pub fn isMouseDoubleClickReleased () bool {
    if (imgui.igIsMouseReleased(imgui.ImGuiMouseButton_Left) and release_double_clicked){
        return true;
    }
    return false;
}
var release_double_clicked: bool = false;

pub fn update() void {

    if (imgui.igIsMouseDoubleClicked(imgui.ImGuiMouseButton_Left)){
        release_double_clicked = true;
    }

    const color_update = imgui.igGetIO().DeltaTime / 5;
    selection_color.value = imgui.ogColorConvertFloat4ToU32(upaya.colors.hsvShiftColor(imgui.ogColorConvertU32ToFloat4(selection_color.value), color_update, 0, 0));
    selection_feedback_color.value = imgui.ogColorConvertFloat4ToU32(upaya.colors.hsvShiftColor(imgui.ogColorConvertU32ToFloat4(selection_feedback_color.value), color_update, 0, 0));

    input.update();
    menubar.draw();
    canvas.draw();
    layers.draw();
    toolbar.draw();
    animations.draw();
    sprites.draw();
    spriteedit.draw();
    newfile.draw();
    closefile.draw();
    slice.draw();
    pack.draw();

    if (enable_hotkeys) {
        const io = imgui.igGetIO();
        const mod = isModKeyDown();

        // global hotkeys
        if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_ESCAPE))
            toolbar.selected_tool = .arrow;

        if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_D))
            toolbar.selected_tool = .pencil;

        if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_E))
            toolbar.selected_tool = .eraser;

        if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_F))
            toolbar.selected_tool = .bucket;

        if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_S) and !mod)
            toolbar.selected_tool = .selection;

        if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_A) and !mod)
            toolbar.selected_tool = .animation;

        if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_W))
            toolbar.selected_tool = .wand;

        if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_N) and mod)
            menubar.new_file_popup = true;

        if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_Z) and mod and !io.KeyShift) {
            if (canvas.getActiveFile()) |file| {
                file.history.undo();
            }
        }
        if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_Z) and mod and io.KeyShift) {
            if (canvas.getActiveFile()) |file| {
                file.history.redo();
            }
        }
        if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_S) and mod and !io.KeyShift) {
            _ = save();
        }
        if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_S) and mod and io.KeyShift) {
            if (canvas.getActiveFile()) |file| {
                file.path = null;
            }
            _ = save();
        }

        if (std.builtin.os.tag == .macos) {
            if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_F) and io.KeyCtrl and io.KeySuper)
                sokol.sapp_toggle_fullscreen();
        } else {
            if (imgui.ogKeyPressed(sokol.SAPP_KEYCODE_F11))
                sokol.sapp_toggle_fullscreen();
        }
    }

    enable_hotkeys = true;

    if (imgui.igIsMouseReleased(imgui.ImGuiMouseButton_Left) and release_double_clicked)
        release_double_clicked = false;
}

pub fn onFileDropped(file: []const u8) void {
    if (menubar.pack_popup) {
        const ext = std.fs.path.extension(file);

        if (std.mem.eql(u8, ext, ".pixi")) {
            if (importPixi(file)) |pixi| {
                pack.addFile(pixi);
            }
        }
    } else {
        load(file);
    }
}

pub fn save() bool {
    if (canvas.getActiveFile()) |file| {
        if (file.path) |path| {
            return saveAs(path);
        } else {
            // Temporary flags that get reset on next update.
            // Needed for file dialogs.
            upaya.inputBlocked = true;
            upaya.inputClearRequired = true;

            var path: [*c]u8 = null;
            if (std.builtin.os.tag == .macos) {
                path = upaya.filebrowser.saveFileDialog("Choose a file name...", ".pixi", "");
            } else {
                path = upaya.filebrowser.saveFileDialog("Choose a file name...", ".pixi", "*.pixi");
            }
            if (path != null) {
                var out_path = path[0..std.mem.len(path)];
                var out_name = std.fs.path.basename(out_path);
                if (!std.mem.endsWith(u8, out_path, ".pixi")) {
                    out_path = std.mem.concat(upaya.mem.tmp_allocator, u8, &[_][]const u8{ out_path, ".pixi" }) catch unreachable;
                }

                var end = std.mem.indexOf(u8, out_name, ".");

                if (end) |end_index| {
                    file.name = out_name[0..end_index];
                    sprites.resetNames();
                    _ = saveAs(out_path);
                }

                file.path = std.mem.dupeZ(upaya.mem.allocator, u8, out_path) catch unreachable;
                return true;
            } else return false;
        }
    }
    return false;
}

pub fn saveAs(file_path: ?[]const u8) bool {
    if (canvas.getActiveFile()) |file| {
        // create a saveable copy of the current file
        var ioFile = file.toIOFile();
        if (file_path) |path| {
            const zip_filename = std.mem.concat(upaya.mem.tmp_allocator, u8, &[_][]const u8{ path, "\u{0}" }) catch unreachable;

            var zip = upaya.zip.zip_open(@ptrCast([*c]const u8, zip_filename), upaya.zip.ZIP_DEFAULT_COMPRESSION_LEVEL, 'w');

            var json: std.ArrayList(u8) = std.ArrayList(u8).init(upaya.mem.allocator);

            const out_stream = json.writer();
            const options = std.json.StringifyOptions{ .whitespace = .{} };

            std.json.stringify(ioFile, options, out_stream) catch unreachable;

            var j = json.toOwnedSlice();
            defer upaya.mem.allocator.free(j);

            if (zip) |z| {
                _ = upaya.zip.zip_entry_open(z, "pixidata.json");

                _ = upaya.zip.zip_entry_write(z, j.ptr, j.len);
                _ = upaya.zip.zip_entry_close(z);

                for (file.layers.items) |layer| {
                    var bytes = std.mem.sliceAsBytes(layer.image.pixels);
                    var stride = @intCast(c_int, layer.image.w * 4);

                    var layer_name = std.fmt.allocPrintZ(upaya.mem.allocator, "{s}.png\u{0}", .{layer.name}) catch unreachable;
                    defer upaya.mem.allocator.free(layer_name);

                    _ = upaya.zip.zip_entry_open(z, @ptrCast([*c]const u8, layer_name));

                    _ = upaya.stb.stbi_write_png_to_func(writePng, z, @intCast(c_int, layer.image.w), @intCast(c_int, layer.image.h), 4, bytes.ptr, stride);
                    _ = upaya.zip.zip_entry_close(z);
                }

                upaya.zip.zip_close(z);
            }

            file.dirty = false;
            return true;
        }
    }
    return false;
}

fn writePng(context: ?*c_void, data: ?*c_void, size: c_int) callconv(.C) void {
    const zip = @ptrCast(?*upaya.zip.struct_zip_t, context);

    if (zip) |z| {
        _ = upaya.zip.zip_entry_write(z, data, @intCast(usize, size));
    }
}

pub fn load(file: []const u8) void {
    if (canvas.getNumberOfFiles() > 0) {
        var i: usize = 0;
        while (i < canvas.getNumberOfFiles()) : (i += 1) {
            if (canvas.getFile(i)) |active_file| {
                if (active_file.path) |path| {
                    if (std.mem.eql(u8, path, file))
                        return; //do nothing if we already have this file loaded
                }
            }
        }
    }

    const ext = std.fs.path.extension(file);

    if (std.mem.eql(u8, ext, ".pixi")) {
        if (importPixi(file)) |pixi| {
            canvas.addFile(pixi);
            sprites.resetNames();
        }
    }

    if (std.mem.eql(u8, ext, ".png")) {
        if (importPng(file)) |png| {
            canvas.addFile(png);
        }
    }
}

pub fn importPixi(file: []const u8) ?types.File {
    @setEvalBranchQuota(2000);

    var name = std.fs.path.basename(file);
    name = name[0 .. name.len - 5]; //trim off .pixi

    var zip_path = file;
    var zip_path_z = std.cstr.addNullByte(upaya.mem.tmp_allocator, zip_path) catch unreachable;

    // open zip for reading
    var zip = upaya.zip.zip_open(@ptrCast([*c]const u8, zip_path_z), 0, 'r');
    var new_file: types.File = undefined;

    if (zip) |z| {
        defer upaya.zip.zip_close(z);

        var buf: ?*c_void = null;
        var size: u64 = 0;
        _ = upaya.zip.zip_entry_open(z, "pixidata.json");
        _ = upaya.zip.zip_entry_read(z, &buf, &size);
        _ = upaya.zip.zip_entry_close(z);

        var content: []const u8 = @ptrCast([*]const u8, buf)[0..size];

        const options = std.json.ParseOptions{ .allocator = upaya.mem.allocator, .duplicate_field_behavior = .UseFirst, .ignore_unknown_fields = true, .allow_trailing_data = true };

        const ioFile = std.json.parse(types.IOFile, &std.json.TokenStream.init(content), options) catch unreachable;
        defer std.json.parseFree(types.IOFile, ioFile, options);

        var temporary_image: upaya.Image = upaya.Image.init(@intCast(usize, ioFile.width), @intCast(usize, ioFile.height));
        temporary_image.fillRect(.{ .x = 0, .y = 0, .width = ioFile.width, .height = ioFile.height }, upaya.math.Color.transparent);
        var temporary: types.Layer = .{
            .name = "Temporary",
            .texture = temporary_image.asTexture(.nearest),
            .image = temporary_image,
            .id = layers.getNewID(),
            .hidden = false,
            .dirty = false,
        };

        var new_layers: std.ArrayList(types.Layer) = std.ArrayList(types.Layer).init(upaya.mem.allocator);
        var new_sprites: std.ArrayList(types.Sprite) = std.ArrayList(types.Sprite).init(upaya.mem.allocator);
        var new_animations: std.ArrayList(types.Animation) = std.ArrayList(types.Animation).init(upaya.mem.allocator);

        for (ioFile.layers) |layer| {
            const layer_name_z = std.fmt.allocPrintZ(upaya.mem.allocator, "{s}.png\u{0}", .{layer.name}) catch unreachable;

            var img_buf: ?*c_void = null;
            var img_len: u64 = 0;
            _ = upaya.zip.zip_entry_open(z, @ptrCast([*c]const u8, layer_name_z));
            _ = upaya.zip.zip_entry_read(z, &img_buf, &img_len);

            var new_image: upaya.Image = upaya.Image.initFromData(@ptrCast([*c]const u8, img_buf), img_len);

            _ = upaya.zip.zip_entry_close(z);

            var new_layer: types.Layer = .{
                .name = std.mem.dupe(upaya.mem.allocator, u8, layer.name) catch unreachable,
                .texture = new_image.asTexture(.nearest),
                .image = new_image,
                .id = layers.getNewID(),
                .hidden = false,
                .dirty = false,
            };

            new_layers.append(new_layer) catch unreachable;
        }

        for (ioFile.sprites) |sprite, i| {
            var new_sprite: types.Sprite = .{
                .name = std.mem.dupe(upaya.mem.allocator, u8, sprite.name) catch unreachable,
                .index = i,
                .origin_x = sprite.origin_x,
                .origin_y = sprite.origin_y,
            };

            new_sprites.append(new_sprite) catch unreachable;
        }

        for (ioFile.animations) |animation| {
            var new_animation: types.Animation = .{
                .name = std.mem.dupe(upaya.mem.allocator, u8, animation.name) catch unreachable,
                .start = animation.start,
                .length = animation.length,
                .fps = animation.fps,
            };

            new_animations.append(new_animation) catch unreachable;
        }

        new_file = .{
            .name = std.mem.dupe(upaya.mem.allocator, u8, name) catch unreachable,
            .path = std.mem.dupe(upaya.mem.allocator, u8, file) catch unreachable,
            .width = ioFile.width,
            .height = ioFile.height,
            .tileWidth = ioFile.tileWidth,
            .tileHeight = ioFile.tileHeight,
            .background = upaya.Texture.initChecker(ioFile.width, ioFile.height, checker_color_1, checker_color_2),
            .temporary = temporary,
            .layers = new_layers,
            .sprites = new_sprites,
            .animations = new_animations,
            .history = history.History.init(),
            .dirty = false,
        };
    } else {
        return null;
    }

    //TODO: free memory

    @setEvalBranchQuota(1000);

    return new_file;
}

pub fn importPng(file: []const u8) ?types.File {
    var name = std.fs.path.basename(file);
    name = name[0 .. name.len - 4]; //trim off .png extension
    const sprite_name = std.fmt.allocPrintZ(upaya.mem.tmp_allocator, "{s}_0", .{name}) catch unreachable;
    const file_image = upaya.Image.initFromFile(file);
    const image_width: i32 = @intCast(i32, file_image.w);
    const image_height: i32 = @intCast(i32, file_image.h);
    var temp_image = upaya.Image.init(@intCast(usize, image_width), @intCast(usize, image_height));
    temp_image.fillRect(.{ .x = 0, .y = 0, .width = image_width, .height = image_height }, upaya.math.Color.transparent);

    var new_file: types.File = .{
        .name = name,
        .width = image_width,
        .height = image_height,
        .tileWidth = image_width,
        .tileHeight = image_height,
        .background = upaya.Texture.initChecker(image_width, image_height, checker_color_1, checker_color_2),
        .temporary = .{
            .name = "Temporary",
            .id = layers.getNewID(),
            .texture = temp_image.asTexture(.nearest),
            .image = temp_image,
        },
        .layers = std.ArrayList(types.Layer).init(upaya.mem.allocator),
        .sprites = std.ArrayList(types.Sprite).init(upaya.mem.allocator),
        .animations = std.ArrayList(types.Animation).init(upaya.mem.allocator),
        .history = history.History.init(),
    };

    new_file.layers.append(.{ .name = "Layer 0", .id = layers.getNewID(), .texture = file_image.asTexture(.nearest), .image = file_image }) catch unreachable;

    new_file.sprites.append(.{
        .name = sprite_name,
        .index = 0,
        .origin_x = 0,
        .origin_y = 0,
    }) catch unreachable;

    return new_file;
}

pub fn shutdown() void {
    canvas.close();
}
