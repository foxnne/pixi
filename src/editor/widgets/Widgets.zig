const std = @import("std");

const pixi = @import("../../pixi.zig");
const dvui = @import("dvui");

pub const Widgets = @This();

pub const FileWidget = @import("FileWidget.zig");
pub const ImageWidget = @import("ImageWidget.zig");
pub const CanvasWidget = @import("CanvasWidget.zig");
pub const ReorderWidget = @import("ReorderWidget.zig");
pub const PanedWidget = @import("PanedWidget.zig");
pub const FloatingWindowWidget = @import("FloatingWindowWidget.zig");
