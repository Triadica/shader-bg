//
//  PixellatedRainShaders.metal
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/15.
//  Based on "Pixellated Rain" - forked from
//  https://www.shadertoy.com/view/3sGyRc License: Creative Commons
//  Attribution-NonCommercial-ShareAlike 3.0 Unported
//  Forked from https://www.shadertoy.com/view/3sGyRc

#include <metal_stdlib>
using namespace metal;

#define tau 6.283

struct PixellatedRainData {
  float time;
  float2 resolution;
  float4 mouse;
  float padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

// 顶点着色器 - 全屏三角形
vertex VertexOut pixellatedRain_vertex(uint vertexID [[vertex_id]]) {
  float2 positions[3] = {float2(-1, -1), float2(3, -1), float2(-1, 3)};

  VertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = positions[vertexID];
  return out;
}

// uint to float conversion
float u2f(uint x) { return as_type<float>(0x3F800000u | (x >> 9)) - 1.0; }

// Hash function
uint pixellatedRain_hash(uint x, uint s) {
  x ^= s;
  x ^= x >> 16;
  x *= 0x7FEB352Du;
  x += s ^ 0x7FEB352Du;
  x ^= x >> 15;
  x *= 0x846CA68Bu;
  x ^= x >> 16;
  return x;
}

float hashf(uint x, uint s) { return u2f(pixellatedRain_hash(x, s)); }

// Noise function
float pixellatedRain_noise(float x, uint s) {
  float fx = fract(x);
  uint ix = uint(int(floor(x)));

  float mx = (3.0 - 2.0 * fx) * fx * fx;

  float l = hashf(ix + 0u, s);
  float h = hashf(ix + 1u, s);

  return mix(l, h, mx);
}

// cos and sin combined
float2 cossin(float a) { return float2(cos(a), sin(a)); }

// Rotation matrix
float2x2 pixellatedRain_rot(float a) {
  float2 cs = cossin(a);
  return float2x2(float2(cs.x, cs.y), float2(-cs.y, cs.x));
}

// 片段着色器
fragment float4 pixellatedRain_fragment(VertexOut in [[stage_in]],
                                        constant PixellatedRainData &params
                                        [[buffer(0)]]) {
  // 直接使用坐标，不翻转 Y
  float2 uv = in.uv * 0.5 + 0.5;
  float2 fragCoord = uv * params.resolution;
  float2 coord = fragCoord - 0.5 * params.resolution;

  float iTime = params.time;

  // Apply rotation
  coord = coord * pixellatedRain_rot(0.4);

  uint id = uint(int(floor(coord.x * 0.5)));

  float tmp = coord.y * 0.002;
  tmp += (iTime + pixellatedRain_noise(iTime * 0.2 + hashf(id, 0u), id) * 2.0) *
         2.0;
  tmp += pixellatedRain_noise(tmp, id) * 0.6;
  tmp *= 10.0;
  tmp += hashf(id, 1u);

  uint rand = pixellatedRain_hash(uint(int(floor(tmp))), id);

  float randf = u2f(rand);
  float3 col = mix(float3(0.1, 0.2, 0.6), float3(0.1, 0.3, 0.7), randf * randf);

  // Add bright spots
  if ((rand & 0xFFu) < 0x10u) {
    float a = fract(-tmp);
    a *= a;
    col *= 1.0 - a;
    col += float3(a);
  }

  return float4(col, 1.0);
}
