pub fn MachImgui(comptime mach: anytype) type {
    return struct {
        pub usingnamespace @import("gui.zig");
        pub const mach_backend = @import("zgui_mach.zig").MachBackend(mach);
    };
}
