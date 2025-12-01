name: []const u8,
frames: []usize,
fps: f32,

pub const OldAnimation = struct {
    name: []const u8,
    start: usize,
    length: usize,
    fps: f32,
};
