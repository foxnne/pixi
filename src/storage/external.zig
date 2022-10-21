pub const PixiFile = struct {
    width: u32,
    height: u32,
    tile_width: u32,
    tile_height: u32,
};

pub const Layer = struct {
    name: [:0]const u8,
};

pub const Sprite = struct {
    name: [:0]const u8,
};
