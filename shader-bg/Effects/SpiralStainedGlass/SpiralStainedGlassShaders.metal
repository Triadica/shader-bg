// Spiral Stained Glass effect
// Forked from https://www.shadertoy.com/view/w3f3DM

#include <metal_stdlib>
using namespace metal;

struct SpiralStainedGlassData {
  float time;
  float2 resolution;
  float2 padding;
};

#define PI 3.141592

// Squircle SDF (rounded square)
static float spiral_squirclesdf(float2 pos) {
  float sidelength = 0.9;
  float smoothrad = 0.3;
  float2 closestpoint = min(abs(pos), float2(sidelength - smoothrad));
  return length(abs(pos) - closestpoint) - smoothrad;
}

// Simple noise function
static float spiral_noise(float2 p) {
  return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

static float4 spiral_stained_glass_effect(float2 fragCoord, float time,
                                          float2 resolution) {
  // 降低速度到 1/10
  float slowTime = time * 0.1;

  // Change this value for different orders of symmetry
  const float sym = 5.0;
  const float scale = sym / 2.0;

  float screenscale = min(resolution.x, resolution.y);
  float2 uv = fragCoord - (resolution / 2.0);
  uv = 2.0 * uv / screenscale;

  float rad = length(uv);
  float lograd = log(rad);
  float angle = atan2(uv.y, uv.x);
  float2 coords = float2(lograd + angle, lograd - angle) / PI;
  coords -= float2(slowTime * 0.02, 0.0);
  float2 fcoords = floor(scale * coords);
  float2 tile = fract(scale * coords);
  float dist =
      screenscale * rad * spiral_squirclesdf(2.0 * tile - 1.0) / (4.0 * scale);

  // Base color with time animation
  float3 basecol =
      0.5 *
      (sin(float3(0.0, 2.0, 4.0) + fcoords.x + fcoords.y + slowTime) + 1.0);

  // Simulate texture with noise
  float texval = spiral_noise(coords * 0.5 + float2(slowTime * 0.01, 0.0));

  float val = smoothstep(-0.5, 0.5, -dist);

  float3 col = val * (basecol * (1.0 - 0.5 * texval));

  return float4(col, 1.0);
}

kernel void spiralStainedGlassCompute(texture2d<float, access::write> output
                                      [[texture(0)]],
                                      constant SpiralStainedGlassData &data
                                      [[buffer(0)]],
                                      uint2 gid [[thread_position_in_grid]]) {
  float2 resolution = data.resolution;
  float2 fragCoord = float2(gid);

  float4 col = spiral_stained_glass_effect(fragCoord, data.time, resolution);

  output.write(col, gid);
}
