pub const PixiFile = struct {
    path: [:0]const u8,
    width: u32,
    height: u32,
    dirty: bool = false,
};

pub const Layer = struct {
    name: [:0]const u8,
};

pub const Sprite = struct {
    name: [:0]const u8,
};
