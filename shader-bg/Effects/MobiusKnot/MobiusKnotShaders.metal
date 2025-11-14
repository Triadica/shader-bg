//
//  MobiusKnotShaders.metal
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/15.
//  Based on "Cosmic knot" by ChunderFPV
//  https://shadertoy.com/view/DtscRB
//  License: Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported
//  Forked from https://www.shadertoy.com/view/mlfyWl

#include <metal_stdlib>
using namespace metal;

struct MobiusKnotData {
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
vertex VertexOut mobiusKnot_vertex(uint vertexID [[vertex_id]]) {
  float2 positions[3] = {float2(-1, -1), float2(3, -1), float2(-1, 3)};

  VertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = positions[vertexID];
  return out;
}

// points: xy, overlap, value, size
float mobiusKnot_P(float2 u, float l, float t, float r) {
  float i = 0.0, f = 0.0, c = 0.0;
  float2 w = fwidth(u);
  float2 p;

  for (int idx = 0; idx < int(l); idx++) {
    i = float(idx) + 1.0;
    p.x = round((u.x - i) / l) * l + i; // skip i rows
    f = fmod(trunc(p.x) * t, 1.0);      // multiply ints with value
    p.y = round(u.y - f) + f;           // set as y
    c = max(c, r / length((u - p) / w));
  }

  c /= sqrt(max(1.0, min(abs(u.x), abs(u.y)))); // darken
  return c;
}

// grid: xy, value, scale
float mobiusKnot_G(float2 u, float t, float s) {
  float2 l, g, v;
  l = max(float2(0.0),
          1.0 - abs(fract(u + 0.5) - 0.5) / fwidth(u) / 1.5); // lines
  g = 1.0 - abs(sin(3.1416 * u));                             // glow
  v = (l + g * 0.5) *
      max(float2(0.0), 1.0 - abs(sin(3.1416 * round(u) * t)) * s); // blend
  return v.x + v.y;
}

// 片段着色器
fragment float4 mobiusKnot_fragment(VertexOut in [[stage_in]],
                                    constant MobiusKnotData &params
                                    [[buffer(0)]]) {
  // Shadertoy uses bottom-left origin, so we need to flip Y
  float2 uv = in.uv * 0.5 + 0.5;
  uv.y = 1.0 - uv.y; // Flip Y coordinate
  float2 fragCoord = uv * params.resolution;
  float2 R = params.resolution;
  float iTime = params.time;
  float4 iMouse = params.mouse;

  float t = 0.1 + iTime / 120.0;
  float pi_2 = 1.5708;
  float pi = 3.1416;
  float pi2 = 6.2832;
  float s = 4.0 + cos(t * pi2); // scale
  float l = 10.0;               // overlap loop (detail)

  float2 h = float2(2.0, -3.0); // spiral arms
  float2 m = (iMouse.xy - 0.5 * R) / R.y * 4.0;
  float2 o, v;

  float3 u = normalize(float3((fragCoord - 0.5 * R) / R.y, 1.0)) * s;
  float3 c = float3(0.1);

  if (iMouse.z < 1.0) {
    m = 4.0 * cos(t * pi - float2(0.0, pi_2)); // circle movement
  }

  // rotate - GLSL mat2 is column-major: mat2(col0, col1)
  // Original: mat2(cos(t*pi2+vec4(0, -pi_2, pi_2, 0)))
  // = mat2(cos(t*pi2), cos(t*pi2-pi_2), cos(t*pi2+pi_2), cos(t*pi2))
  // = mat2(cos(angle), sin(angle), -sin(angle), cos(angle))
  float angle = t * pi2;
  float2x2 rotMat = float2x2(float2(cos(angle), sin(angle)),   // column 0
                             float2(-sin(angle), cos(angle))); // column 1
  u.xy = u.xy * rotMat;

  // transform
  o = u.xy - float2(1.0, 0.0);
  v = o / dot(o, o);
  v.x += 0.5;
  u.xy = tan(log(length(v)) + atan2(v.y, v.x) * h / 2.0) + m * 10.0;
  u.z = max(u.x / u.y, u.y / u.x);

  // points - QP macro expanded
  float r = R.y / 800.0;
  c += mobiusKnot_P(u.xy, l, t, r) * 0.7; // xy
  c += mobiusKnot_P(u.yx, l, t, r) * 0.7; // yx
  c += mobiusKnot_P(u.yz, l, t, r) * 0.7; // yz
  c += mobiusKnot_P(u.zy, l, t, r) * 0.7; // zy
  c += mobiusKnot_P(u.zx, l, t, r) * 0.7; // zx
  c += mobiusKnot_P(u.xz, l, t, r) * 0.7; // xz

  // grid
  c += mobiusKnot_G(u.xy, t, s) * 0.2;

  // color
  // radians = degrees * pi/180
  float3 colorOffset =
      cos(float3(-30.0, 60.0, 120.0) * (pi / 180.0) + (u.z + t) * pi2) * 0.5 +
      0.5;
  c += colorOffset * c;

  // oscillate contrast
  float contrast = cos(t * pi2 * 2.0) * 0.2 + 0.3;
  c *= pow(c, float3(contrast));

  return float4(tanh(c), 1.0);
}
