@group(0) @binding(0) var tex: texture_2d<f32>;
@group(0) @binding(1) var<storage,read_write> buf: array<vec4<f32>>;

@compute @workgroup_size(1)
fn copyTextureToBuffer(@builtin(global_invocation_id) id: vec3<u32>) {
    let size = textureDimensions(tex);
    buf[id.y * size.x + id.x] = textureLoad(tex, id.xy, 0);
}