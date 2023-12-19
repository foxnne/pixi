const std = @import("std");

var allocator: std.mem.Allocator = undefined;

const hash = std.hash.Fnv1a_32.hash;

// common defines - TODO make command line option
// - IMGUI_USE_WCHAR32
// - IMGUI_USE_BGRA_PACKED_COLOR
// - IMGUI_DISABLE_OBSOLETE_KEYIO
// - IMGUI_DISABLE_OBSOLETE_FUNCTIONS

const defines = [_][]const u8{
    "IMGUI_DISABLE_OBSOLETE_KEYIO",
    "IMGUI_DISABLE_OBSOLETE_FUNCTIONS",
};
const skip_defines = [_][]const u8{"IMGUI_IMPL_API"};
const type_aliases = [_][2][]const u8{
    .{ "va_list", "c.va_list" },
    .{ "size_t", "usize" },

    // maybe make a system for templates?
    .{ "ImVector_char", "Vector(u8)" },
    .{ "ImVector_float", "Vector(f32)" },
    .{ "ImVector_ImDrawChannel", "Vector(DrawChannel)" },
    .{ "ImVector_ImDrawCmd", "Vector(DrawCmd)" },
    .{ "ImVector_ImDrawIdx", "Vector(DrawIdx)" },
    .{ "ImVector_ImDrawListPtr", "Vector(*DrawList)" },
    .{ "ImVector_ImDrawVert", "Vector(DrawVert)" },
    .{ "ImVector_ImFontAtlasCustomRect", "Vector(FontAtlasCustomRect)" },
    .{ "ImVector_ImFontConfig", "Vector(FontConfig)" },
    .{ "ImVector_ImFontGlyph", "Vector(FontGlyph)" },
    .{ "ImVector_ImFontPtr", "Vector(*Font)" },
    .{ "ImVector_ImGuiStorage_ImGuiStoragePair", "Vector(Storage_ImGuiStoragePair)" },
    .{ "ImVector_ImGuiTextFilter_ImGuiTextRange", "Vector(TextFilter_ImGuiTextRange)" },
    .{ "ImVector_ImTextureID", "Vector(TextureID)" },
    .{ "ImVector_ImU32", "Vector(U32)" },
    .{ "ImVector_ImVec2", "Vector(Vec2)" },
    .{ "ImVector_ImVec4", "Vector(Vec4)" },
    .{ "ImVector_ImWchar", "Vector(Wchar)" },
    .{ "ImVector_ImGuiPlatformMonitor", "Vector(PlatformMonitor)" },
    .{ "ImVector_ImGuiViewportPtr", "Vector(*Viewport)" },
};
const bounds_aliases = [_][2][]const u8{
    .{ "(IM_UNICODE_CODEPOINT_MAX +1)/4096/8", "(UNICODE_CODEPOINT_MAX+1)/4096/8" },
    .{ "IM_DRAWLIST_TEX_LINES_WIDTH_MAX+1", "DRAWLIST_TEX_LINES_WIDTH_MAX+1" },
};
const namespaces = [_][]const u8{
    "IMGUI",
    "IM",
    "ImGui",
    "Im",
};
const is_many_item_field = [_][2][]const u8{
    .{ "TableSortSpecs", "Specs" },
    .{ "DrawList", "_VtxWritePtr" },
    .{ "DrawList", "_IdxWritePtr" },
    .{ "FontConfig", "GlyphRanges" },
    .{ "FontAtlas", "TexPixelsAlpha8" },
    .{ "FontAtlas", "TexPixelsRGBA32" },
};

var defines_set: std.StringHashMapUnmanaged(void) = .{};
var skip_defines_set: std.StringHashMapUnmanaged(void) = .{};
var type_aliases_map: std.StringHashMapUnmanaged([]const u8) = .{};
var bounds_aliases_map: std.StringHashMapUnmanaged([]const u8) = .{};
var is_many_item_field_set: std.StringHashMapUnmanaged(std.StringHashMapUnmanaged(void)) = .{};
var known_structs: std.StringHashMapUnmanaged(void) = .{};
var aligned_content: ?std.ArrayListUnmanaged(u8) = null;
var aligned_fields: std.ArrayListUnmanaged(struct { x: std.json.Value, content: []const u8 }) = .{};

fn trimPrefixOpt(name: []const u8, prefix: []const u8) ?[]const u8 {
    return if (std.mem.startsWith(u8, name, prefix))
        name[prefix.len..]
    else
        null;
}

fn trimPrefix(name: []const u8, prefix: []const u8) []const u8 {
    return if (std.mem.startsWith(u8, name, prefix))
        name[prefix.len..]
    else
        name;
}

fn trimNamespace(name: []const u8) []const u8 {
    for (namespaces) |prefix| {
        if (std.mem.startsWith(u8, name, prefix)) {
            return name[prefix.len..];
        }
    }

    return name;
}

fn trimLeadingUnderscore(name: []const u8) []const u8 {
    return if (name.len > 2 and name[0] == '_' and (std.ascii.isAlphanumeric(name[1]) or name[1] == '_')) name[1..name.len] else name;
}

fn trimTrailingUnderscore(name: []const u8) []const u8 {
    return if (name.len > 1 and name[name.len - 1] == '_') name[0 .. name.len - 1] else name;
}

fn evaluateConditional(x: std.json.Value) bool {
    const condition = x.object.get("condition").?.string;
    const expression = x.object.get("expression").?.string;
    return switch (hash(condition)) {
        hash("ifdef") => defines_set.contains(expression),
        hash("ifndef") => !defines_set.contains(expression),
        else => false,
    };
}

fn evaluateConditionals(x: std.json.Value) bool {
    for (x.array.items) |item| {
        if (!evaluateConditional(item))
            return false;
    }

    return true;
}

fn keepElement(x: std.json.Value) bool {
    if (x.object.get("conditionals")) |conditionals| {
        return evaluateConditionals(conditionals);
    }

    return true;
}

fn writeByte(ch: u8) void {
    if (aligned_content) |*ac| {
        ac.writer(allocator).writeByte(ch) catch unreachable;
    } else {
        std.io.getStdOut().writer().writeByte(ch) catch unreachable;
    }
}

fn write(str: []const u8) void {
    if (aligned_content) |*ac| {
        ac.writer(allocator).writeAll(str) catch unreachable;
    } else {
        std.io.getStdOut().writer().writeAll(str) catch unreachable;
    }
}

fn print(comptime format: []const u8, args: anytype) void {
    if (aligned_content) |*ac| {
        std.fmt.format(ac.writer(allocator), format, args) catch unreachable;
    } else {
        std.fmt.format(std.io.getStdOut().writer(), format, args) catch unreachable;
    }
}

fn emitSnakeCase(name: []const u8) void {
    var last_is_upper = true;
    var last_is_underscore = false;
    for (name) |ch| {
        const is_upper = std.ascii.isUpper(ch);
        if (is_upper and last_is_upper != is_upper and !last_is_underscore) {
            writeByte('_');
        }
        last_is_upper = is_upper;
        last_is_underscore = ch == '_';
        writeByte(std.ascii.toLower(ch));
    }
}

fn emitCamelCase(name: []const u8) void {
    if (name.len > 0) {
        writeByte(std.ascii.toLower(name[0]));
        write(name[1..name.len]);
    }
}

fn emitPrecedingComments(x: std.json.Value, indent: usize) void {
    if (x.object.get("comments")) |comments| {
        if (comments.object.get("preceding")) |preceding| {
            for (preceding.array.items) |comment| {
                for (0..indent) |_|
                    writeByte(' ');
                write(comment.string);
                write("\n");
            }
        }
    }
}

fn hasAttachedComment(x: std.json.Value) bool {
    if (x.object.get("comments")) |comments| {
        if (comments.object.get("attached")) |comment| {
            _ = comment;
            return true;
        }
    }
    return false;
}

fn emitAttachedComment(x: std.json.Value) void {
    if (x.object.get("comments")) |comments| {
        if (comments.object.get("attached")) |comment| {
            write(" ");
            write(comment.string);
        }
    }
}

fn beginAlignedFields() void {
    aligned_content = .{};
}

fn appendAlignedField(x: std.json.Value) void {
    const slice = aligned_content.?.toOwnedSlice(allocator) catch unreachable;
    aligned_fields.append(allocator, .{ .x = x, .content = slice }) catch unreachable;
}

fn endAlignedFields(indent: usize) void {
    aligned_content.?.deinit(allocator);
    aligned_content = null;

    var max_size: usize = 0;
    for (aligned_fields.items) |entry| {
        max_size = @max(max_size, entry.content.len);
    }

    for (aligned_fields.items) |entry| {
        emitPrecedingComments(entry.x, indent);
        write(entry.content);
        if (hasAttachedComment(entry.x)) {
            for (0..max_size - entry.content.len) |_|
                writeByte(' ');
            emitAttachedComment(entry.x);
        }
        write("\n");
        allocator.free(entry.content);
    }
    aligned_fields.clearRetainingCapacity();
}

fn emitDefine(x: std.json.Value) void {
    if (!keepElement(x)) return;
    const full_name = x.object.get("name").?.string;
    if (skip_defines_set.contains(full_name)) return;
    const name = trimLeadingUnderscore(trimNamespace(full_name));
    if (x.object.get("content")) |content| {
        print("pub const {s} = {s};", .{ name, content.string });
        appendAlignedField(x);
    }
}

fn emitDefines(x: std.json.Value) void {
    beginAlignedFields();
    for (x.array.items) |item| emitDefine(item);
    endAlignedFields(0);
}

fn emitEnumElement(x: std.json.Value) void {
    if (!keepElement(x)) return;
    const full_name = x.object.get("name").?.string;
    const name = trimNamespace(full_name);

    if (x.object.get("value")) |value| {
        print("pub const {s} = {};", .{ name, value.integer });
    } else {
        print("pub const {s};", .{name});
    }
    appendAlignedField(x);
}

pub fn emitEnumElements(x: std.json.Value) void {
    beginAlignedFields();
    for (x.array.items) |item| emitEnumElement(item);
    endAlignedFields(0);
}

fn emitEnum(x: std.json.Value) void {
    if (!keepElement(x)) return;

    write("\n");
    emitPrecedingComments(x, 0);
    emitEnumElements(x.object.get("elements").?);
}

fn emitEnums(x: std.json.Value) void {
    write("\n");
    write("//-----------------------------------------------------------------------------\n");
    write("// Enumerations\n");
    write("//-----------------------------------------------------------------------------\n");

    for (x.array.items) |item| emitEnum(item);
}

fn emitStorageClass(x: std.json.Value) void {
    write(switch (hash(x.string)) {
        hash("const") => "const ",
        else => "",
    });
}

fn emitStorageClasses(x: std.json.Value) void {
    for (x.array.items) |item| emitStorageClass(item);
}

fn emitBuiltinType(x: std.json.Value) void {
    const builtin_type = x.object.get("builtin_type").?.string;
    write(switch (hash(builtin_type)) {
        hash("void") => "void",
        hash("char") => "c_char",
        hash("unsigned_char") => "c_char", // ???
        hash("short") => "c_short",
        hash("unsigned_short") => "c_ushort",
        hash("int") => "c_int",
        hash("unsigned_int") => "c_uint",
        hash("long") => "c_long",
        hash("unsigned_long") => "c_ulong",
        hash("long_long") => "c_longlong",
        hash("unsigned_long_long") => "c_ulonglong",
        hash("float") => "f32",
        hash("double") => "f64",
        hash("long_double") => "c_longdouble",
        hash("bool") => "bool",
        else => std.debug.panic("unknown builtin_type {s}", .{builtin_type}),
    });
}

fn emitUserType(x: std.json.Value) void {
    const full_name = x.object.get("name").?.string;
    if (type_aliases_map.get(full_name)) |alias| {
        write(alias);
    } else {
        const name = trimNamespace(full_name);
        write(name);
    }
}

fn isNullable(x: std.json.Value) bool {
    if (x.object.get("is_nullable")) |is_nullable| {
        return is_nullable.bool;
    }

    return true;
}

fn emitPointerType(x: std.json.Value, is_many_item: bool) void {
    if (isNullable(x))
        write("?");

    const inner_type = x.object.get("inner_type").?;
    if (is_many_item) {
        write("[*]");
        emitTypeDesc(inner_type, false);
    } else {
        const inner_type_kind = inner_type.object.get("kind").?.string;
        switch (hash(inner_type_kind)) {
            hash("Builtin") => {
                const builtin_type = inner_type.object.get("builtin_type").?.string;
                switch (hash(builtin_type)) {
                    hash("void") => {
                        write("*anyopaque");
                        return;
                    },
                    hash("char") => {
                        write("[*:0]const u8");
                        return;
                    },
                    else => {},
                }
            },
            else => {},
        }

        write("*");
        emitTypeDesc(inner_type, false);
    }
}

fn emitFunctionParameters(x: std.json.Value) void {
    for (x.array.items, 0..) |item, i| {
        if (i > 0) write(", ");
        emitTypeDesc(item, false);
    }
}

fn emitFunctionType(x: std.json.Value) void {
    write("const fn (");
    emitFunctionParameters(x.object.get("parameters").?);
    write(") callconv(.C) ");
    emitTypeDesc(x.object.get("return_type").?, false);
}

fn emitArrayType(x: std.json.Value) void {
    write("[");
    if (x.object.get("bounds")) |bounds| {
        if (bounds_aliases_map.get(bounds.string)) |alias| {
            write(alias);
        } else {
            if (trimPrefixOpt(bounds.string, "ImGui")) |name| {
                write(name);
            } else {
                write(bounds.string);
            }
        }
    } else {
        write("*");
    }
    write("]");
    emitTypeDesc(x.object.get("inner_type").?, false);
}

fn emitTypeDesc(x: std.json.Value, is_many_item: bool) void {
    if (x.object.get("storage_classes")) |storage_classes| {
        emitStorageClasses(storage_classes);
    }

    const kind = x.object.get("kind").?.string;
    switch (hash(kind)) {
        hash("Builtin") => emitBuiltinType(x),
        hash("User") => emitUserType(x),
        hash("Pointer") => emitPointerType(x, is_many_item),
        hash("Type") => emitTypeDesc(x.object.get("inner_type").?, false),
        hash("Function") => emitFunctionType(x),
        hash("Array") => emitArrayType(x),
        else => std.debug.panic("unknown type kind {s}", .{kind}),
    }
}

fn emitType(x: std.json.Value, is_many_item: bool) void {
    const description = x.object.get("description").?;
    emitTypeDesc(description, is_many_item);
}

fn emitTypedef(x: std.json.Value) void {
    if (!keepElement(x)) return;
    const full_name = x.object.get("name").?.string;
    const name = trimNamespace(full_name);
    print("pub const {s} = ", .{name});
    emitType(x.object.get("type").?, false);
    write(";");
    appendAlignedField(x);
}

fn emitTypedefs(x: std.json.Value) void {
    write("\n");
    write("//-----------------------------------------------------------------------------\n");
    write("// Types\n");
    write("//-----------------------------------------------------------------------------\n");
    write("\n");

    beginAlignedFields();
    for (x.array.items) |item| emitTypedef(item);
    endAlignedFields(0);
}

fn isManyItem(struct_name: []const u8, field_name: []const u8) bool {
    if (is_many_item_field_set.get(struct_name)) |struct_field_set|
        return struct_field_set.contains(field_name);
    return false;
}

fn emitStructField(x: std.json.Value, struct_name: []const u8) void {
    if (!keepElement(x)) return;
    const full_name = x.object.get("name").?.string;
    const name = full_name;
    const is_many_item = isManyItem(struct_name, name);
    write("    ");
    emitSnakeCase(name);
    write(": ");
    emitType(x.object.get("type").?, is_many_item);
    write(",");
    appendAlignedField(x);
}

fn emitStructFields(x: std.json.Value, struct_name: []const u8) void {
    beginAlignedFields();
    for (x.array.items) |item| emitStructField(item, struct_name);
    endAlignedFields(4);
}

fn emitStructFunction(x: std.json.Value, struct_name: []const u8) void {
    if (!keepElement(x)) return;
    const full_name = x.object.get("name").?.string;
    if (std.mem.indexOfScalar(u8, full_name, '_')) |i| {
        const func_struct_name = full_name[0..i];
        const name = full_name[i + 1 .. full_name.len];
        if (std.mem.eql(u8, func_struct_name, struct_name)) {
            print("    pub const ", .{});
            emitCamelCase(trimLeadingUnderscore(name));
            print(" = {s};", .{full_name});
            appendAlignedField(x);
        }
    }
}

fn emitStructFunctions(x: std.json.Value, struct_name: []const u8) void {
    beginAlignedFields();
    for (x.array.items) |item| emitStructFunction(item, struct_name);
    endAlignedFields(4);
}

fn emitStruct(x: std.json.Value, functions: std.json.Value) void {
    if (!keepElement(x)) return;
    const full_name = x.object.get("name").?.string;
    if (type_aliases_map.contains(full_name)) return;
    const name = trimNamespace(full_name);

    write("\n");
    emitPrecedingComments(x, 0);
    print("pub const {s} = extern struct {{\n", .{name});
    if (hasAttachedComment(x)) {
        write("    ");
        emitAttachedComment(x);
        write("\n");
    }
    emitStructFields(x.object.get("fields").?, name);
    emitStructFunctions(functions, full_name);
    write("};\n");

    known_structs.put(allocator, full_name, {}) catch unreachable;
}

fn emitStructs(x: std.json.Value, functions: std.json.Value) void {
    write("\n");
    write("//-----------------------------------------------------------------------------\n");
    write("// Structs\n");
    write("//-----------------------------------------------------------------------------\n");
    write("\n");
    write("pub fn Vector(comptime T: type) type {\n");
    write("    return extern struct {\n");
    write("        size: c_int,\n");
    write("        capacity: c_int,\n");
    write("        data: [*]T,\n");
    write("    };\n");
    write("}\n");

    for (x.array.items) |item| emitStruct(item, functions);
}

fn emitFunctionArgument(x: std.json.Value) void {
    if (x.object.get("is_varargs").?.bool) {
        write("...");
    } else {
        const full_name = x.object.get("name").?.string;
        const name = full_name;
        print("{s}: ", .{name});
        if (x.object.get("type")) |_| {
            emitType(x.object.get("type").?, false);
        } else {
            std.debug.print("no type {s}\n", .{full_name});
        }
    }
}

fn emitFunctionArguments(x: std.json.Value) void {
    for (x.array.items, 0..) |item, i| {
        if (i > 0) write(", ");
        emitFunctionArgument(item);
    }
}

fn emitExternFunction(x: std.json.Value) void {
    if (!keepElement(x)) return;
    const full_name = x.object.get("name").?.string;

    print("extern fn {s}(", .{full_name});
    emitFunctionArguments(x.object.get("arguments").?);
    write(") ");
    emitType(x.object.get("return_type").?, false);
    write(";\n");
}

fn emitPubFunction(x: std.json.Value) void {
    if (!keepElement(x)) return;
    const full_name = x.object.get("name").?.string;

    if (std.mem.indexOfScalar(u8, full_name, '_')) |i| {
        const func_struct_name = full_name[0..i];
        if (!known_structs.contains(func_struct_name)) {
            const name = trimLeadingUnderscore(trimNamespace(full_name));
            print("pub const ", .{});
            emitCamelCase(name);
            print(" = {s};", .{full_name});
            appendAlignedField(x);
        }
    } else {
        const name = trimLeadingUnderscore(trimNamespace(full_name));
        print("pub const ", .{});
        emitCamelCase(name);
        print(" = {s};", .{full_name});
        appendAlignedField(x);
    }
}

fn emitFunctions(x: std.json.Value) void {
    write("\n");
    write("//-----------------------------------------------------------------------------\n");
    write("// API functions\n");
    write("//-----------------------------------------------------------------------------\n");
    write("\n");

    write("pub fn setZigAllocator(allocator: *std.mem.Allocator) void {\n");
    write("    setAllocatorFunctions(zigAlloc, zigFree, allocator);\n");
    write("}\n");

    beginAlignedFields();
    for (x.array.items) |item| emitPubFunction(item);
    endAlignedFields(0);

    write("\n");
    write("//-----------------------------------------------------------------------------\n");
    write("// Extern declarations\n");
    write("//-----------------------------------------------------------------------------\n");
    write("\n");

    for (x.array.items) |item| emitExternFunction(item);
}

fn emit(x: std.json.Value) void {
    const header = @embedFile("generate_header.zig");
    const footer = @embedFile("generate_footer.zig");
    write(header);
    write("\n");

    const functions = x.object.get("functions").?;
    emitDefines(x.object.get("defines").?);
    emitEnums(x.object.get("enums").?);
    emitTypedefs(x.object.get("typedefs").?);
    emitStructs(x.object.get("structs").?, functions);
    emitFunctions(functions);
    write("\n");
    write(footer);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    allocator = gpa.allocator();

    for (defines) |entry| try defines_set.put(allocator, entry, {});
    for (skip_defines) |entry| try skip_defines_set.put(allocator, entry, {});
    for (type_aliases) |entry| try type_aliases_map.put(allocator, entry[0], entry[1]);
    for (bounds_aliases) |entry| try bounds_aliases_map.put(allocator, entry[0], entry[1]);
    for (is_many_item_field) |entry| {
        var struct_entry = try is_many_item_field_set.getOrPut(allocator, entry[0]);
        if (!struct_entry.found_existing)
            struct_entry.value_ptr.* = .{};
        try struct_entry.value_ptr.*.put(allocator, entry[1], {});
    }

    defer defines_set.deinit(allocator);
    defer skip_defines_set.deinit(allocator);
    defer type_aliases_map.deinit(allocator);
    defer bounds_aliases_map.deinit(allocator);
    defer {
        var it = is_many_item_field_set.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit(allocator);
        }
        is_many_item_field_set.deinit(allocator);
    }
    defer known_structs.deinit(allocator);
    defer aligned_fields.deinit(allocator);

    var file = try std.fs.cwd().openFile("cimgui.json", .{});
    defer file.close();

    const file_data = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(file_data);

    var valueTree = try std.json.parseFromSlice(std.json.Value, allocator, file_data, .{});
    defer valueTree.deinit();

    emit(valueTree.value);
}
