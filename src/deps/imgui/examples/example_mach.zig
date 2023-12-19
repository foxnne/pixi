const std = @import("std");
const build_options = @import("build-options");
const imgui = @import("imgui");
const imgui_mach = imgui.backends.mach;
const core = @import("mach-core");
const gpu = core.gpu;

pub const App = @This();

pub const mach_core_options = core.ComptimeOptions{
    .use_wgpu = !build_options.use_dusk,
    .use_dgpu = build_options.use_dusk,
};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator: std.mem.Allocator = undefined;

title_timer: core.Timer,
f: f32 = 0.0,

pub fn init(app: *App) !void {
    try core.init(.{});

    allocator = gpa.allocator();

    imgui.setZigAllocator(&allocator);
    _ = imgui.createContext(null);
    try imgui_mach.init(allocator, core.device, 3, .bgra8_unorm, .undefined); // TODO - use swap chain preferred format

    var io = imgui.getIO();
    io.config_flags |= imgui.ConfigFlags_NavEnableKeyboard;
    io.font_global_scale = 1.0 / io.display_framebuffer_scale.y;

    const font_data = @embedFile("Roboto-Medium.ttf");
    const size_pixels = 12 * io.display_framebuffer_scale.y;

    var font_cfg: imgui.FontConfig = std.mem.zeroes(imgui.FontConfig);
    font_cfg.font_data_owned_by_atlas = false;
    font_cfg.oversample_h = 2;
    font_cfg.oversample_v = 1;
    font_cfg.glyph_max_advance_x = std.math.floatMax(f32);
    font_cfg.rasterizer_multiply = 1.0;
    font_cfg.ellipsis_char = imgui.UNICODE_CODEPOINT_MAX;
    _ = io.fonts.?.addFontFromMemoryTTF(@constCast(@ptrCast(font_data.ptr)), font_data.len, size_pixels, &font_cfg, null);

    app.* = .{
        .title_timer = try core.Timer.start(),
    };
}

pub fn deinit(app: *App) void {
    _ = app;
    defer _ = gpa.deinit();
    defer core.deinit();

    imgui_mach.shutdown();
    imgui.destroyContext(null);
}

pub fn update(app: *App) !bool {
    var iter = core.pollEvents();
    while (iter.next()) |event| {
        _ = imgui_mach.processEvent(event);

        switch (event) {
            .close => return true,
            else => {},
        }
    }

    try app.render();

    // update the window title every second
    if (app.title_timer.read() >= 1.0) {
        app.title_timer.reset();
        try core.printTitle("ImGui [ {d}fps ] [ Input {d}hz ]", .{
            core.frameRate(),
            core.inputRate(),
        });
    }

    return false;
}

fn render(app: *App) !void {
    var io = imgui.getIO();

    imgui_mach.newFrame() catch return;
    imgui.newFrame();

    imgui.text("Hello, world!");
    _ = imgui.sliderFloat("float", &app.f, 0.0, 1.0);
    imgui.text("Application average %.3f ms/frame (%.1f FPS)", 1000.0 / io.framerate, io.framerate);
    imgui.showDemoWindow(null);

    imgui.render();

    const back_buffer_view = core.swap_chain.getCurrentTextureView().?;
    const color_attachment = gpu.RenderPassColorAttachment{
        .view = back_buffer_view,
        .clear_value = gpu.Color{ .r = 0.2, .g = 0.2, .b = 0.2, .a = 1.0 },
        .load_op = .clear,
        .store_op = .store,
    };

    const encoder = core.device.createCommandEncoder(null);
    const render_pass_info = gpu.RenderPassDescriptor.init(.{
        .color_attachments = &.{color_attachment},
    });

    const pass = encoder.beginRenderPass(&render_pass_info);
    imgui_mach.renderDrawData(imgui.getDrawData().?, pass) catch {};
    pass.end();
    pass.release();

    var command = encoder.finish(null);
    encoder.release();

    var queue = core.queue;
    queue.submit(&[_]*gpu.CommandBuffer{command});
    command.release();
    core.swap_chain.present();
    back_buffer_view.release();
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
