//
//  RingRemixShaders.metal
//  shader-bg
//
//  Created on 2025-11-05.
//  Ring Remix - Simplex noise based ring effect
//  Forked from https://www.shadertoy.com/view/WtG3RD

#include <metal_stdlib>
using namespace metal;

struct RingRemixParams {
  float time;
  float2 resolution;
  float padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 texCoord;
};

constant float TAU = 6.2831852;
constant float3 MOD3 = float3(0.1031, 0.11369, 0.13787);
constant float3 BLACK_COL = float3(16, 21, 25) / 255.0;

// Vertex shader for full-screen triangle
vertex VertexOut ringRemixVertex(uint vertexID [[vertex_id]]) {
  VertexOut out;
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.texCoord = positions[vertexID] * 0.5 + 0.5;
  return out;
}

// Hash function
static float3 rrHash33(float3 p3) {
  p3 = fract(p3 * MOD3);
  p3 += dot(p3, p3.yxz + 19.19);
  return -1.0 + 2.0 * fract(float3((p3.x + p3.y) * p3.z, (p3.x + p3.z) * p3.y,
                                   (p3.y + p3.z) * p3.x));
}

// Simplex noise
static float rrSimplexNoise(float3 p) {
  const float K1 = 0.333333333;
  const float K2 = 0.166666667;

  float3 i = floor(p + (p.x + p.y + p.z) * K1);
  float3 d0 = p - (i - (i.x + i.y + i.z) * K2);

  float3 e = step(float3(0.0), d0 - d0.yzx);
  float3 i1 = e * (1.0 - e.zxy);
  float3 i2 = 1.0 - e.zxy * (1.0 - e);

  float3 d1 = d0 - (i1 - 1.0 * K2);
  float3 d2 = d0 - (i2 - 2.0 * K2);
  float3 d3 = d0 - (1.0 - 3.0 * K2);

  float4 h = max(
      0.6 - float4(dot(d0, d0), dot(d1, d1), dot(d2, d2), dot(d3, d3)), 0.0);
  float4 n = h * h * h * h *
             float4(dot(d0, rrHash33(i)), dot(d1, rrHash33(i + i1)),
                    dot(d2, rrHash33(i + i2)), dot(d3, rrHash33(i + 1.0)));

  return dot(float4(31.316), n);
}

fragment float4 ringRemixFragment(VertexOut in [[stage_in]],
                                  constant RingRemixParams &params
                                  [[buffer(0)]]) {
  float2 iResolution = params.resolution;
  float2 fragCoord = in.texCoord * iResolution;

  float2 uv = (fragCoord.xy - iResolution.xy * 0.5) / iResolution.y;

  float a = sin(atan2(uv.y, uv.x));
  float am = abs(a - 0.5) / 4.0;
  float l = length(uv);

  float m1 = clamp(0.1 / smoothstep(0.0, 1.75, l), 0.0, 1.0);
  float m2 = clamp(0.1 / smoothstep(0.42, 0.0, l), 0.0, 1.0);
  float s1 = (rrSimplexNoise(float3(uv * 2.0, 1.0 + params.time * 0.525)) *
                  (max(1.0 - l * 1.75, 0.0)) +
              0.9);
  float s2 = (rrSimplexNoise(float3(uv * 1.0, 15.0 + params.time * 0.525)) *
                  (max(0.0 + l * 1.0, 0.025)) +
              1.25);
  float s3 =
      (rrSimplexNoise(float3(float2(am, am * 100.0 + params.time * 3.0) * 0.15,
                             30.0 + params.time * 0.525)) *
           (max(0.0 + l * 1.0, 0.25)) +
       1.5);
  s3 *= smoothstep(0.0, 0.3345, l);

  float sh = smoothstep(0.15, 0.35, l);

  float m = m1 * m1 * m2 * ((s1 * s2 * s3) * (1.0 - l)) * sh;

  float3 col =
      mix(BLACK_COL,
          (0.5 + 0.5 * cos(params.time + uv.xyx * 3.0 + float3(0, 2, 4))), m);

  return float4(col, 1.0);
}
