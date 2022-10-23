const zip = @import("zip");

pub const Internal = struct {
    pub usingnamespace @import("internal.zig");
};

pub const External = struct {
    pub usingnamespace @import("external.zig");
};
