//
//  StainedLightsShaders.metal
//  shader-bg
//
//  Created on 2025-11-03.
//  Based on Shadertoy shader with disco/stained glass effect
//  Credits: Dave_Hoskins Hash functions
//  Forked from https://www.shadertoy.com/view/WlsSzM

#include <metal_stdlib>
using namespace metal;

struct StainedLightsParams {
  float time;
  float2 resolution;
  float padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 texCoord;
};

// Vertex shader for full-screen triangle
vertex VertexOut stainedLightsVertex(uint vertexID [[vertex_id]]) {
  VertexOut out;
  // Generate full-screen triangle
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.texCoord = positions[vertexID] * 0.5 + 0.5;
  return out;
}

// Hash function (credits: Dave_Hoskins)
float3 hash32(float2 p) {
  float3 p3 = fract(float3(p.x, p.y, p.x) * float3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yxz + 19.19);
  return fract((p3.xxy + p3.yzz) * p3.zyx);
}

// Disco/stained glass pattern
// returns { RGB, dist to edge (0 = edge, 1 = center) }
float4 disco(float2 uv) {
  float v = abs(cos(uv.x * M_PI_F * 2.0) + cos(uv.y * M_PI_F * 2.0)) * 0.5;
  uv.x -= 0.5;
  float3 cid2 = hash32(float2(floor(uv.x - uv.y), floor(uv.x + uv.y)));
  return float4(cid2, v);
}

fragment float4 stainedLightsFragment(VertexOut in [[stage_in]],
                                      constant StainedLightsParams &params
                                      [[buffer(0)]]) {
  float2 R = params.resolution;
  float2 fragCoord = in.texCoord * R;
  fragCoord.y = R.y - fragCoord.y; // Flip Y coordinate

  float2 uv = fragCoord / R;
  uv.x *= R.x / R.y; // aspect correct

  float t = params.time * 0.6;
  uv *= 8.0;
  uv -= float2(t * 0.5, -t * 0.3);

  float4 o = float4(1.0);
  for (float i = 1.0; i <= 4.0; ++i) {
    uv /= i * 0.9;
    float4 d = disco(uv);
    float curv = pow(d.a, 0.44 - ((1.0 / i) * 0.3));
    curv = pow(curv, 0.8 + (d.b * 2.0));
    o *= clamp(d * curv, 0.35, 1.0);
    uv += t * (i + 0.3);
  }

  // Post processing
  o = clamp(o, 0.0, 1.0);
  float2 N = (fragCoord / R) - 0.5;
  o = 1.0 - pow(1.0 - o, float4(30.0));              // curve
  o.rgb += hash32(fragCoord + params.time).r * 0.07; // noise
  // 移除扫描线效果以消除上下黑边
  // o *= 1.1 - smoothstep(0.4, 0.405, abs(N.y));
  o *= 1.0 - dot(N, N * 1.7); // vignette
  o.a = 1.0;

  return o;
}
