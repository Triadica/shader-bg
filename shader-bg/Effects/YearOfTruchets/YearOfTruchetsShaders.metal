//
//  YearOfTruchetsShaders.metal
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/14.
//  Based on "Year of Truchets #058" by byt3_m3chanic
//  License: Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported
//  Forked from https://www.shadertoy.com/view/msVfzR

#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265359

struct YearOfTruchetsParams {
  float time;
  float2 resolution;
  float2 mouse;
  float mousePressed;
  float padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

// 顶点着色器
vertex VertexOut yearOfTruchetsVertex(uint vertexID [[vertex_id]]) {
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};

  VertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = positions[vertexID] * 0.5 + 0.5;
  return out;
}

// 旋转矩阵
float2x2 yearOfTruchets_rot(float a) {
  return float2x2(cos(a), sin(a), -sin(a), cos(a));
}

// Hash 函数
float yearOfTruchets_hash21(float2 p) {
  return fract(sin(dot(p, float2(27.609, 57.583))) * 43758.5453);
}

// 色调函数
float3 yearOfTruchets_hue(float t) {
  return 0.5 + 0.5 * cos(6.5 * t + float3(0, 1, 2));
}

// 片段着色器
fragment float4 yearOfTruchetsFragment(VertexOut in [[stage_in]],
                                       constant YearOfTruchetsParams &params
                                       [[buffer(0)]]) {
  float2 R = params.resolution;
  float2 M = params.mouse;
  float T = params.time;
  float2 F = in.uv * R;

  float2 uv = (2.0 * F - R) / max(R.x, R.y);
  float2 xv = uv;

  // @stb transformation
  uv.x -= 0.25;
  uv /= uv.x * uv.x + uv.y * uv.y;
  uv.x += 2.0;

  uv = yearOfTruchets_rot(T * 0.15) * uv;
  uv = float2(log(length(uv)), atan2(uv.y, uv.x)) * 2.546;

  uv.x -= (params.mousePressed > 0.0) ? (M.x / R.x * 3.0 - 1.5) * PI
                                      : 1.5 * sin(T * 0.1);

  float tt = T * 0.08;
  float px = fwidth(uv.x);

  float2 dv = fract(uv) - 0.5;
  float2 id = floor(uv);

  float rnd = yearOfTruchets_hash21(id);
  float bnd = fract(rnd * 147.32 + (T * 0.05));

  float3 h = yearOfTruchets_hue(tt - uv.x * 0.015) * 0.85;
  float3 g = yearOfTruchets_hue(tt + bnd * 0.35 - uv.x * 0.075) * 0.5;

  if (rnd < 0.5)
    dv.x = -dv.x;
  rnd = fract(rnd * 147.32 + tt);

  float2 gx =
      length(dv - 0.5) < length(dv + 0.5) ? float2(dv - 0.5) : float2(dv + 0.5);
  // Metal 中标量使用 abs，向量使用 length
  float cx = (rnd > 0.75) ? min(abs(dv.x), abs(dv.y)) : length(gx) - 0.5;

  h = mix(h, h * 0.5, smoothstep(0.035 + px, -px, abs(cx) - 0.125));
  h = mix(h, g, smoothstep(px, -px, abs(cx) - 0.12));
  h = mix(h, float3(1), smoothstep(px, -px, abs(abs(cx) - 0.12) - 0.01));

  return float4(pow(h, float3(0.4545)), 1.0);
}
