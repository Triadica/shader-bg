// Neon Parallax effect
// Based on Neon parallax by nimitz (twitter: @stormoid)
// https://www.shadertoy.com/view/XssXz4
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported
// License
// Forked from https://www.shadertoy.com/view/XssXz4

#include <metal_stdlib>
using namespace metal;

struct NeonParallaxData {
  float time;
  float2 resolution;
  float2 padding;
};

static float neon_pulse(float cn, float wi, float x) {
  return 1.0 - smoothstep(0.0, wi, abs(x - cn));
}

static float neon_hash11(float n) { return fract(sin(n) * 43758.5453); }

static float2 neon_hash22(float2 p) {
  p = float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)));
  return fract(sin(p) * 43758.5453);
}

static float2 neon_field(float2 p) {
  float2 n = floor(p);
  float2 f = fract(p);
  float2 m = float2(1.0);
  float2 o = neon_hash22(n) * 0.17;
  float2 r = f + o - 0.5;
  float d = abs(r.x) + abs(r.y);
  if (d < m.x) {
    m.x = d;
    m.y = neon_hash11(dot(n, float2(1.0, 2.0)));
  }
  return float2(m.x, m.y);
}

static float4 neon_parallax_effect(float2 fragCoord, float time,
                                   float2 resolution) {
  // 减慢动画速度到 1/64 (原来 1/8 的 1/8)
  float t = time * 0.015625;

  float2 uv = fragCoord.xy / resolution.xy - 0.5;
  uv.x *= resolution.x / resolution.y * 0.9;
  uv *= 4.0;

  float2 p = uv * 0.01;
  p *= 1.0 / (p - 1.0);

  // global movement
  uv.y += t * 1.2;
  uv.x += sin(t * 0.3) * 0.8;
  float2 buv = uv;

  float3 col = float3(0.0);
  for (float i = 1.0; i <= 26.0; i++) {
    float2 rn = neon_field(uv);
    uv -= p * (i - 25.0) * 0.2;
    rn.x = neon_pulse(0.35, 0.02, rn.x + rn.y * 0.15);
    col += rn.x * float3(sin(rn.y * 10.0), cos(rn.y) * 0.2, sin(rn.y) * 0.5);
  }

  // animated grid
  // mat2(0.707,-0.707,0.707,0.707) rotation matrix
  float2 buv_rot =
      float2(buv.x * 0.707 - buv.y * 0.707, buv.x * 0.707 + buv.y * 0.707);
  buv = buv_rot;

  float rz2 = 0.4 * (sin(buv.x * 10.0 + 1.0) * 40.0 - 39.5) *
              (sin(uv.x * 10.0) * 0.5 + 0.5);
  float3 col2 = float3(0.2, 0.4, 2.0) * rz2 *
                (sin(2.0 + t * 2.1 + (uv.y * 2.0 + uv.x * 10.0)) * 0.5 + 0.5);

  float rz3 = 0.3 * (sin(buv.y * 10.0 + 4.0) * 40.0 - 39.5) *
              (sin(uv.x * 10.0) * 0.5 + 0.5);
  float3 col3 = float3(1.9, 0.4, 2.0) * rz3 *
                (sin(t * 4.0 - (uv.y * 10.0 + uv.x * 2.0)) * 0.5 + 0.5);

  col = max(max(col, col2), col3);

  return float4(col, 1.0);
}

kernel void neonParallaxCompute(texture2d<float, access::write> output
                                [[texture(0)]],
                                constant NeonParallaxData &data [[buffer(0)]],
                                uint2 gid [[thread_position_in_grid]]) {
  float2 resolution = data.resolution;
  float2 fragCoord = float2(gid);

  float4 col = neon_parallax_effect(fragCoord, data.time, resolution);

  output.write(col, gid);
}
