//
//  WorldTreeShaders.metal
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/16.
//  Based on Shadertoy world tree effect
//  License: Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported
//  Forked from https://www.shadertoy.com/view/cl3BD7

#include <metal_stdlib>
using namespace metal;

struct WorldTreeData {
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
vertex VertexOut worldTree_vertex(uint vertexID [[vertex_id]]) {
  float2 positions[3] = {float2(-1, -1), float2(3, -1), float2(-1, 3)};

  VertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = positions[vertexID];
  return out;
}

// Random function
float worldTree_random(float2 uv) {
  return fract(sin(dot(uv, float2(12.959, 35.137)) + 12.42) * 127.421);
}

// Noise function
float worldTree_noise(float2 uv) {
  float2 ip = floor(uv);
  float2 fp = fract(uv);
  fp *= fp * (3.0 - 2.0 * fp);

  float a = worldTree_random(ip);
  float b = worldTree_random(ip + float2(1.0, 0.0));
  float c = worldTree_random(ip + float2(0.0, 1.0));
  float d = worldTree_random(ip + float2(1.0, 1.0));

  return mix(mix(a, b, fp.x), mix(c, d, fp.x), fp.y);
}

// Effect function
float3 worldTree_effect(float2 uv, float iTime) {
  float2 uv0 = uv;
  uv.y += 1.0;

  float n = worldTree_noise(uv * float2(uv.y * 150.0, 2.0) - iTime * 1.0);
  float3 c = pow(n, 6.0) * float3(0.5, 0.2, 0.8);

  return float3(c);
}

// 片段着色器
fragment float4 worldTree_fragment(VertexOut in [[stage_in]],
                                   constant WorldTreeData &params
                                   [[buffer(0)]]) {
  float2 fragCoord = (in.uv * 0.5 + 0.5) * params.resolution;
  float2 R = params.resolution;
  float iTime = params.time;

  // vec2 uv=(fragCoord-R*.5)/R.y;
  float2 uv = (fragCoord - R * 0.5) / R.y;

  // vec3 col=effect(uv);
  float3 col = worldTree_effect(uv, iTime);

  return float4(col, 1.0);
}
