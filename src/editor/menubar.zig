const std = @import("std");
const upaya = @import("upaya");
const imgui = @import("imgui");
const sokol = @import("sokol");

const editor = @import("editor.zig");
const canvas = editor.canvas;
const pack = editor.pack;

pub var new_file_popup: bool = false;
pub var close_file_popup: bool = false;
pub var slice_popup: bool = false;
pub var pack_popup: bool = false;
pub var demo_window: bool = false;

pub fn draw() void {
    if (imgui.igBeginMenuBar()) {
        defer imgui.igEndMenuBar();

        const mod_name = if (std.builtin.os.tag == .windows) "ctrl" else if (std.builtin.os.tag == .linux) "super" else "cmd";

        if (imgui.igBeginMenu("File", true)) {
            defer imgui.igEndMenu();

            if (imgui.igMenuItemBool(imgui.icons.file ++ "  New", mod_name ++ "+n", false, true))
                new_file_popup = true;

            if (imgui.igMenuItemBool(imgui.icons.box_open ++ " Open...", "", false, true)) {
                // Temporary flags that get reset on next update.
                // Needed for file dialogs.
                upaya.inputBlocked = true;
                upaya.inputClearRequired = true;
                var path: [*c]u8 = null;
                if (std.builtin.os.tag == .macos) {
                    path = upaya.filebrowser.openFileDialog("Choose a file to open...", ".pixi", "");
                } else {
                    path = upaya.filebrowser.openFileDialog("Choose a file to open...", ".pixi", "*.pixi");
                }

                if (path != null) {
                    var in_path = path[0..std.mem.len(path)];
                    if (std.mem.endsWith(u8, in_path, ".pixi")) {
                        editor.load(in_path);
                    }
                }
            }

            if (imgui.igMenuItemBool("Save", mod_name ++ "+s", false, true)) {
                _ = editor.save();
            }
            if (imgui.igMenuItemBool("Save As...", mod_name ++ "+shift+s", false, true)) {
                if (canvas.getActiveFile()) |file| {
                    file.path = null;
                }
                _ = editor.save();
            }

            imgui.igSeparator();

            if (imgui.igBeginMenu("Export", canvas.getNumberOfFiles() > 0)) {
                defer imgui.igEndMenu();

                if (imgui.igMenuItemBool("Image", "", false, true)) {}
            }

            if (imgui.igBeginMenu("Import", canvas.getNumberOfFiles() > 0)) {
                defer imgui.igEndMenu();

                if (imgui.igMenuItemBool("Image", "", false, true)) {}
            }

            imgui.igSeparator();

            if (imgui.igMenuItemBool(imgui.icons.door_closed ++ " Close", if (std.builtin.os.tag == .windows) "alt+f4" else mod_name ++ "+q", false, true)) {
                editor.shutdown();
            }
        }

        if (imgui.igBeginMenu("Edit", true)) {
            defer imgui.igEndMenu();

            var numUndos: usize = 0;
            var numRedos: usize = 0;

            if (canvas.getActiveFile()) |file| {
                numUndos = file.history.getNumberOfUndos();
                numRedos = file.history.getNumberOfRedos();
            }

            if (imgui.igMenuItemBool(imgui.icons.undo ++ " Undo", mod_name ++ "+z", false, numUndos > 0)) {
                if (canvas.getActiveFile()) |file| {
                    file.history.undo();
                }
            }

            if (imgui.igMenuItemBool(imgui.icons.redo ++ " Redo", mod_name ++ "+shift+z", false, numRedos > 0)) {
                if (canvas.getActiveFile()) |file| {
                    file.history.redo();
                }
            }
            imgui.igSeparator();
        }

        if (imgui.igBeginMenu("Document", true)) {
            defer imgui.igEndMenu();

            if (imgui.igMenuItemBool(imgui.icons.tape ++ " Pack...", "", false, canvas.getNumberOfFiles() > 0)) {
                pack.pack();
                pack_popup = true;
            }

            var sliceable: bool = false;
            if (canvas.getActiveFile()) |file| {
                if (file.width == file.tileWidth and file.height == file.tileHeight)
                    sliceable = true;
            }

            if (imgui.igMenuItemBool(imgui.icons.pizza_slice ++ " Slice...", "", false, sliceable))
                slice_popup = true;

            if (imgui.igMenuItemBool(imgui.icons.file_upload ++ " Generate Heightmaps", "", false, canvas.getNumberOfFiles() > 0)) {
                if (canvas.getActiveFile()) |file| {
                    const tiles_wide = @divExact(file.width, file.tileWidth);

                    for (file.sprites.items) |_, sprite_index| {
                        const column = @mod(@intCast(i32, sprite_index), tiles_wide);
                        const row = @divTrunc(@intCast(i32, sprite_index), tiles_wide);

                        const src_x = @intCast(usize, column * file.tileWidth);
                        const src_y = @intCast(usize, row * file.tileHeight);

                        var lowest: usize = src_y + @intCast(usize, file.tileHeight) - 1;

                        for (file.layers.items) |*layer| {
                            var y: usize = src_y + @intCast(usize, file.tileHeight) - 1;

                            blk: {
                                while (y > src_y) : (y -= 1) {
                                    
                                    var read_slice = layer.image.pixels[src_x + y * @intCast(usize, file.width) .. src_x + y * @intCast(usize, file.width) + @intCast(usize, file.tileWidth)];

                                    for (read_slice) |p| {
                                        if (p & 0xFF000000 != 0) {
                                            if (y < lowest) {
                                                lowest = y;
                                                break :blk;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        var height: u8 = 0;

                        for (file.layers.items) |*layer| {
                            var y: usize = src_y + @intCast(usize, file.tileHeight) - 1;
                            while (y > src_y) : (y -= 1){
                                if (y <= lowest) {
                                    var read_slice = layer.image.pixels[src_x + y * @intCast(usize, file.width) .. src_x + y * @intCast(usize, file.width) + @intCast(usize, file.tileWidth)];
                                    var write_slice = layer.heightmap_image.pixels[src_x + y * @intCast(usize, file.width) .. src_x + y * @intCast(usize, file.width) + @intCast(usize, file.tileWidth)];

                                    for (read_slice) |p, i| {
                                        if (p & 0xFF000000 != 0) {
                                            write_slice[i] = upaya.math.Color.fromBytes(height, 0, 0, 255).value;
                                        } else
                                            write_slice[i] = 0x00000000;
                                    }

                                    if (height < 255)
                                        height += 1;
                                }
                            }

                            layer.dirty = true;
                        }
                    }
                }
            }
        }

        if (imgui.igBeginMenu("View", true)) {
            defer imgui.igEndMenu();

            const fullscreen_hotkey = if (std.builtin.os.tag == .macos) "cmd+ctrl+f" else "f11";
            if (imgui.igMenuItemBool(imgui.icons.tv ++ " Fullscreen", fullscreen_hotkey, false, true))
                sokol.sapp_toggle_fullscreen();

            imgui.igSeparator();

            if (imgui.igMenuItemBool(imgui.icons.undo ++ "  Reset Views", 0, false, true))
                editor.resetDockLayout();

            if (imgui.igMenuItemBool(imgui.icons.question ++ "  IMGUI Demo Window", 0, false, true))
                demo_window = !demo_window;
        }
    }

    if (new_file_popup)
        imgui.igOpenPopup("New File");

    if (slice_popup)
        imgui.igOpenPopup("Slice");

    if (pack_popup) {
        imgui.igOpenPopup("Pack");
    } else {
        pack.clear();
    }

    if (demo_window)
        imgui.igShowDemoWindow(&demo_window);
}

fn containsColor(pixels: []u32) bool {
    for (pixels) |p| {
        if (p & 0xFF000000 != 0) {
            return true;
        }
    }

    return false;
}
