const std = @import("std");
const path = std.fs.path;
const Builder = std.build.Builder;
const Step = std.build.Step;

const Atlas = @import("../gfx/atlas.zig").Atlas;

pub const ProcessAssetsStep = struct {
    step: Step,
    builder: *Builder,
    assets_root_path: []const u8,
    assets_output_path: []const u8,
    animations_output_path: []const u8,

    pub fn init(builder: *Builder, comptime assets_path: []const u8, comptime assets_output_path: []const u8, comptime animations_output_path: []const u8) *ProcessAssetsStep {
        const self = builder.allocator.create(ProcessAssetsStep) catch unreachable;
        self.* = .{
            .step = Step.init(.{ .id = .custom, .name = "process-assets", .owner = builder, .makeFn = process }),
            .builder = builder,
            .assets_root_path = assets_path,
            .assets_output_path = assets_output_path,
            .animations_output_path = animations_output_path,
        };

        return self;
    }

    fn process(step: *Step, prog_node: *std.Progress.Node) anyerror!void {
        _ = prog_node;
        const self = @fieldParentPtr(ProcessAssetsStep, "step", step);
        const root = self.assets_root_path;
        const assets_output = self.assets_output_path;
        const animations_output = self.animations_output_path;

        if (std.fs.cwd().openDir(root, .{ .access_sub_paths = true })) |_| {
            // path passed is a directory
            var files = getAllFiles(self.builder.allocator, root, true);

            if (files.len > 0) {
                var assets_array_list = std.ArrayList(u8).init(self.builder.allocator);
                var assets_writer = assets_array_list.writer();

                // Disclaimer
                try assets_writer.writeAll("// This is a generated file, do not edit.\n");

                // Top level assets declarations.
                try assets_writer.writeAll("const std = @import(\"std\");\n\n");

                // Add root assets location as const.
                try assets_writer.print("pub const root = \"{s}/\";\n\n", .{root});

                // Iterate all files
                for (files) |file| {
                    const ext = std.fs.path.extension(file);
                    const base = std.fs.path.basename(file);
                    const ext_ind = std.mem.lastIndexOf(u8, base, ".");
                    const name = base[0..ext_ind.?];

                    var path_fixed = try self.builder.allocator.alloc(u8, file.len);
                    _ = std.mem.replace(u8, file, "\\", "/", path_fixed);

                    // Pngs
                    if (std.mem.eql(u8, ext, ".png")) {
                        try assets_writer.print("pub const {s}{s} = struct {{\n", .{ name, "_png" });
                        try assets_writer.print("  pub const path = \"{s}\";\n", .{path_fixed});
                        try assets_writer.print("}};\n\n", .{});
                    }

                    // Hex
                    if (std.mem.eql(u8, ext, ".hex")) {
                        try assets_writer.print("pub const {s}{s} = struct {{\n", .{ name, "_hex" });
                        try assets_writer.print("  pub const path = \"{s}\";\n", .{path_fixed});
                        try assets_writer.print("}};\n\n", .{});
                    }

                    // Atlases
                    if (std.mem.eql(u8, ext, ".atlas")) {
                        try assets_writer.print("pub const {s}{s} = struct {{\n", .{ name, "_atlas" });
                        try assets_writer.print("  pub const path = \"{s}\";\n", .{path_fixed});

                        var atlas = Atlas.initFromFile(self.builder.allocator, file) catch unreachable;

                        for (atlas.sprites, 0..) |sprite, i| {
                            var sprite_name = try self.builder.allocator.alloc(u8, sprite.name.len);
                            _ = std.mem.replace(u8, sprite.name, " ", "_", sprite_name);
                            _ = std.mem.replace(u8, sprite_name, ".", "_", sprite_name);

                            try assets_writer.print("  pub const {s} = {};\n", .{ sprite_name, i });
                        }

                        try assets_writer.print("}};\n\n", .{});

                        // Write an animations file if animations are present in the atlas
                        if (atlas.animations.len > 0) {
                            var animations_array_list = std.ArrayList(u8).init(self.builder.allocator);
                            var animations_writer = animations_array_list.writer();

                            // Disclaimer
                            try animations_writer.writeAll("// This is a generated file, do not edit.\n");

                            // Top level animations declarations
                            try animations_writer.writeAll("const std = @import(\"std\");\n");
                            try animations_writer.writeAll("const assets = @import(\"assets.zig\");\n\n");

                            for (atlas.animations) |animation| {
                                var animation_name = try self.builder.allocator.alloc(u8, animation.name.len);
                                _ = std.mem.replace(u8, animation.name, " ", "_", animation_name);
                                _ = std.mem.replace(u8, animation_name, ".", "_", animation_name);

                                try animations_writer.print("pub var {s} = [_]usize {{\n", .{animation_name});
                                for (animation.indexes) |index| {
                                    var sprite_name = try self.builder.allocator.alloc(u8, atlas.sprites[index].name.len);
                                    _ = std.mem.replace(u8, atlas.sprites[index].name, " ", "_", sprite_name);
                                    _ = std.mem.replace(u8, sprite_name, ".", "_", sprite_name);

                                    try animations_writer.print("    assets.{s}_atlas.{s},\n", .{ name, sprite_name });
                                }
                                try animations_writer.print("}};\n", .{});
                            }

                            try std.fs.cwd().writeFile(animations_output, animations_array_list.items);
                        }
                    }
                }

                try std.fs.cwd().writeFile(assets_output, assets_array_list.items);
            } else {
                std.debug.print("No assets found!", .{});
            }
        } else |err| {
            std.debug.print("Not a directory: {s}, err: {}", .{ root, err });
        }
    }

    fn getAllFiles(allocator: std.mem.Allocator, root_directory: []const u8, recurse: bool) [][:0]const u8 {
        var list = std.ArrayList([:0]const u8).init(allocator);

        const recursor = struct {
            fn search(alloc: std.mem.Allocator, directory: []const u8, recursive: bool, filelist: *std.ArrayList([:0]const u8)) void {
                var dir = std.fs.cwd().openIterableDir(directory, .{ .access_sub_paths = true }) catch unreachable;
                defer dir.close();

                var iter = dir.iterate();
                while (iter.next() catch unreachable) |entry| {
                    if (entry.kind == .file) {
                        const name_null_term = std.mem.concat(alloc, u8, &[_][]const u8{ entry.name, "\x00" }) catch unreachable;
                        const abs_path = std.fs.path.join(alloc, &[_][]const u8{ directory, name_null_term }) catch unreachable;
                        filelist.append(abs_path[0 .. abs_path.len - 1 :0]) catch unreachable;
                    } else if (entry.kind == .directory) {
                        const abs_path = std.fs.path.join(alloc, &[_][]const u8{ directory, entry.name }) catch unreachable;
                        search(alloc, abs_path, recursive, filelist);
                    }
                }
            }
        }.search;

        recursor(allocator, root_directory, recurse, &list);

        return list.toOwnedSlice() catch unreachable;
    }
};
