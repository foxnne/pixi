const std = @import("std");
const pixi = @import("../pixi.zig");

const Project = @This();

pub var parsed: ?std.json.Parsed(Project) = null;
pub var read: ?[]u8 = null;

/// Path for the final packed texture to save
packed_texture_output: ?[]const u8 = null,

/// Path for the final packed heightmap to save
packed_heightmap_output: ?[]const u8 = null,

/// Path for the final packed atlas to save
packed_atlas_output: ?[]const u8 = null,

/// If a valid path is present, pixi will generate a zig struct containing useful indexes and names
generated_zig_output: ?[]const u8 = null,

/// If true, the entire project will be repacked and exported on any project file save
pack_on_save: bool = true,

pub fn load() !?Project {
    if (pixi.editor.project_folder) |folder| {
        const file = try std.fs.path.join(pixi.editor.arena.allocator(), &.{ folder, ".pixiproject" });

        if (pixi.fs.read(pixi.app.allocator, file) catch null) |r| {
            read = r;

            const options = std.json.ParseOptions{ .duplicate_field_behavior = .use_first, .ignore_unknown_fields = true };
            if (std.json.parseFromSlice(Project, pixi.app.allocator, r, options) catch null) |p| {
                parsed = p;

                if (p.value.packed_atlas_output) |packed_atlas_output| {
                    @memcpy(pixi.editor.buffers.atlas_path[0..packed_atlas_output.len], packed_atlas_output);
                }

                if (p.value.packed_texture_output) |packed_texture_output| {
                    @memcpy(pixi.editor.buffers.texture_path[0..packed_texture_output.len], packed_texture_output);
                }

                if (p.value.packed_heightmap_output) |packed_heightmap_output| {
                    @memcpy(pixi.editor.buffers.heightmap_path[0..packed_heightmap_output.len], packed_heightmap_output);
                }

                if (p.value.generated_zig_output) |generated_zig_output| {
                    @memcpy(pixi.editor.buffers.generated_zig_path[0..generated_zig_output.len], generated_zig_output);
                }

                return p.value;
            } else {
                std.log.debug("Failed to parse project file!", .{});
            }
        }
    }

    return null;
}

pub fn save(project: *Project) !void {
    if (pixi.editor.project_folder) |folder| {
        const file = try std.fs.path.join(pixi.editor.arena.allocator(), &.{ folder, ".pixiproject" });
        var handle = try std.fs.createFileAbsolute(file, .{});
        defer handle.close();

        const out_stream = handle.writer();
        const options = std.json.StringifyOptions{};

        try std.json.stringify(Project{
            .packed_atlas_output = project.packed_atlas_output,
            .packed_texture_output = project.packed_texture_output,
            .packed_heightmap_output = project.packed_heightmap_output,
            .generated_zig_output = project.generated_zig_output,
            .pack_on_save = project.pack_on_save,
        }, options, out_stream);

        return;
    }

    return error.FailedToSaveProject;
}

pub fn deinit(project: *Project) void {
    if (read) |r| pixi.app.allocator.free(r);

    if (parsed) |p| {
        p.deinit();
        parsed = null;
    } else {
        if (project.packed_atlas_output) |atlas| {
            pixi.app.allocator.free(atlas);
        }
        if (project.packed_texture_output) |texture| {
            pixi.app.allocator.free(texture);
        }
        if (project.packed_heightmap_output) |heightmap| {
            pixi.app.allocator.free(heightmap);
        }
        if (project.generated_zig_output) |generated| {
            pixi.app.allocator.free(generated);
        }
    }
}
