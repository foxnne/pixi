const mach = @import("mach");
const pixi = @import("pixi.zig");

// The list of modules to be used in our application. Our game itself is implemented in our own
// module called pixi.
pub const App = mach.App(.{
    mach.Module,
    pixi,
});
