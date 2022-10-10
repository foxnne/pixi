@group(0) @binding(1) var diffuse: texture_2d<f32>;
@group(0) @binding(2) var diffuse_sampler: sampler;
@stage(fragment) fn main(
    @location(0) uv: vec2<f32>,
    @location(1) color: vec4<f32>,
    @location(2) data: vec3<f32>,
) -> @location(0) vec4<f32> {
    return textureSample(diffuse, diffuse_sampler, uv) * color;
}