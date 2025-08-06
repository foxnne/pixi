const std = @import("std");

const pixi = @import("../pixi.zig");
const dvui = @import("dvui");

pub const Widgets = @This();

pub const TabsWidget = @import("widgets/TabsWidget.zig");
pub const FileWidget = @import("widgets/FileWidget.zig");
pub const ImageWidget = @import("widgets/ImageWidget.zig");
pub const CanvasWidget = @import("widgets/CanvasWidget.zig");
pub const ReorderWidget = @import("widgets/ReorderWidget.zig");
pub const PanedWidget = @import("widgets/PanedWidget.zig");
pub const DynamicPanedWidget = @import("widgets/DynamicPanedWidget.zig");
