const std = @import("std");
const path = std.fs.path;
const Step = std.Build.Step;

const Atlas = @import("../Atlas.zig");
const ProcessAssetsStep = @This();

step: Step,
builder: *std.Build,
assets_path: []const u8,
output_folder: []const u8,

pub fn init(builder: *std.Build, comptime assets_path: []const u8, comptime output_folder: []const u8) !*ProcessAssetsStep {
    const self = try builder.allocator.create(ProcessAssetsStep);
    self.* = .{
        .step = Step.init(.{ .id = .custom, .name = "process-assets", .owner = builder, .makeFn = process }),
        .builder = builder,
        .assets_path = assets_path,
        .output_folder = output_folder,
    };

    return self;
}

fn process(step: *Step, options: Step.MakeOptions) anyerror!void {
    const progress = options.progress_node.start("Processing assets...", 100);
    defer progress.end();
    const self = @as(*ProcessAssetsStep, @fieldParentPtr("step", step));
    const root = self.assets_path;
    const output_folder = self.output_folder;
    try generate(self.builder.allocator, root, output_folder);
}

pub fn generate(allocator: std.mem.Allocator, assets_root: []const u8, output_folder: []const u8) !void {
    var atlases: usize = 0;

    if (std.fs.cwd().openDir(assets_root, .{ .access_sub_paths = true })) |_| {
        // path passed is a directory
        const files = try getAllFiles(allocator, assets_root, true);

        if (files.len > 0) {
            var paths = std.ArrayList(u8).init(allocator);
            var paths_writer = paths.writer();

            // Disclaimer
            try paths_writer.writeAll("// This is a generated file, do not edit.\n");

            try paths_writer.print("// Paths \n\n", .{});

            // Top level assets declarations.
            //try assets_writer.writeAll("const std = @import(\"std\");\n\n");

            // Add root assets location as const.
            try paths_writer.print("pub const root = \"{s}/\";\n\n", .{assets_root});

            // Add palettes location as const.
            try paths_writer.print("pub const palettes = \"{s}/{s}/\";\n\n", .{ assets_root, "palettes" });

            // Add themes location as const.
            try paths_writer.print("pub const themes = \"{s}/{s}/\";\n\n", .{ assets_root, "themes" });

            // Iterate all files
            for (files) |file| {
                const ext = std.fs.path.extension(file);
                const base = std.fs.path.basename(file);
                const ext_ind = std.mem.lastIndexOf(u8, base, ".");
                const name = base[0..ext_ind.?];

                const path_fixed = try allocator.alloc(u8, file.len);
                _ = std.mem.replace(u8, file, "\\", "/", path_fixed);

                const name_fixed = try allocator.alloc(u8, name.len);
                _ = std.mem.replace(u8, name, "-", "_", name_fixed);

                try paths_writer.print("pub const @\"{s}\" = \"{s}\";\n", .{ base, path_fixed });

                // // Hex
                // if (std.mem.eql(u8, ext, ".hex")) {
                //     try paths_writer.print("pub const {s}{s} = struct {{\n", .{ name_fixed, "_hex" });
                //     try paths_writer.print("  pub const path = \"{s}\";\n", .{path_fixed});
                //     try paths_writer.print("}};\n\n", .{});
                // }

                // Atlases
                if (std.mem.eql(u8, ext, ".atlas")) {
                    atlases += 1;

                    var atlas_list = std.ArrayList(u8).init(allocator);
                    var atlas_writer = atlas_list.writer();

                    // Disclaimer
                    try atlas_writer.writeAll("// This is a generated file, do not edit.\n\n");

                    try atlas_writer.print("// Sprites \n\n", .{});

                    // try paths_writer.print("pub const {s}{s} = struct {{\n", .{ name, "_atlas" });
                    // try paths_writer.print("  pub const path = \"{s}\";\n", .{path_fixed});

                    var atlas = try Atlas.loadFromFile(allocator, file);

                    try atlas_writer.print("pub const sprites = struct {{\n", .{});

                    for (atlas.sprites, 0..) |_, i| {
                        const sprite_name = try atlas.spriteName(allocator, i);
                        // _ = std.mem.replace(u8, sprite.name, " ", "_", sprite_name);
                        // _ = std.mem.replace(u8, sprite_name, ".", "_", sprite_name);

                        try atlas_writer.print("    pub const {s} = {d};\n", .{ sprite_name, i });
                    }

                    try atlas_writer.print("}};\n\n", .{});

                    try atlas_writer.print("// Animations \n\n", .{});

                    // Write an animations file if animations are present in the atlas
                    if (atlas.animations.len > 0) {
                        try atlas_writer.print("pub const animations = struct {{\n", .{});

                        for (atlas.animations) |animation| {
                            const animation_name = try allocator.alloc(u8, animation.name.len);
                            _ = std.mem.replace(u8, animation.name, " ", "_", animation_name);
                            _ = std.mem.replace(u8, animation_name, ".", "_", animation_name);

                            try atlas_writer.print("     pub var {s} = [_]usize {{\n", .{animation_name});

                            var sprite_index = animation.start;
                            while (sprite_index < animation.start + animation.length) : (sprite_index += 1) {
                                //const sprite_name = try atlas.spriteName(allocator, animation_index);

                                try atlas_writer.print("        sprites.{s},\n", .{try atlas.spriteName(allocator, sprite_index)});
                            }
                            try atlas_writer.print("    }};\n", .{});
                        }

                        try atlas_writer.print("}};\n", .{});
                    }

                    if (atlases > 1) {
                        const atlas_name = try std.fmt.allocPrint(allocator, "{s}.zig", .{name});
                        const atlas_path = try std.fs.path.join(allocator, &[_][]const u8{ output_folder, atlas_name });

                        try std.fs.cwd().writeFile(.{
                            .sub_path = atlas_path,
                            .data = atlas_list.items,
                        });
                    } else {
                        try std.fs.cwd().writeFile(.{
                            .sub_path = try std.fs.path.join(allocator, &[_][]const u8{ output_folder, "atlas.zig" }),
                            .data = atlas_list.items,
                        });
                    }
                }
            }

            try std.fs.cwd().writeFile(.{
                .sub_path = try std.fs.path.join(allocator, &[_][]const u8{ output_folder, "paths.zig" }),
                .data = paths.items,
            });
        } else {
            std.debug.print("No assets found!", .{});
        }
    } else |err| {
        std.debug.print("Not a directory: {s}, err: {}", .{ assets_root, err });
    }
}

fn getAllFiles(allocator: std.mem.Allocator, root_directory: []const u8, recurse: bool) ![][:0]const u8 {
    var list = std.ArrayList([:0]const u8).init(allocator);

    const recursor = struct {
        fn search(alloc: std.mem.Allocator, directory: []const u8, recursive: bool, filelist: *std.ArrayList([:0]const u8)) !void {
            var dir = try std.fs.cwd().openDir(directory, .{ .access_sub_paths = true, .iterate = true });
            defer dir.close();

            var iter = dir.iterate();
            while (try iter.next()) |entry| {
                if (entry.kind == .file) {
                    const name_null_term = try std.mem.concat(alloc, u8, &[_][]const u8{ entry.name, "\x00" });
                    const abs_path = try std.fs.path.join(alloc, &[_][]const u8{ directory, name_null_term });
                    try filelist.append(abs_path[0 .. abs_path.len - 1 :0]);
                } else if (entry.kind == .directory) {
                    const abs_path = try std.fs.path.join(alloc, &[_][]const u8{ directory, entry.name });
                    try search(alloc, abs_path, recursive, filelist);
                }
            }
        }
    }.search;

    try recursor(allocator, root_directory, recurse, &list);

    std.mem.sort([:0]const u8, list.items, Context{}, compare);

    return try list.toOwnedSlice();
}

const Context = struct {};
fn compare(_: Context, a: [:0]const u8, b: [:0]const u8) bool {
    const base_a = std.fs.path.basename(a);
    const base_b = std.fs.path.basename(b);

    return std.mem.order(u8, base_a, base_b) == .lt;
}
