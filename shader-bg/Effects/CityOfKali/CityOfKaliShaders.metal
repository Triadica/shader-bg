// CC0: City of Kali
//  Wanted to created some kind of abstract city of light
//  Had the idea that Kali fractal might be a good start.
//  10/10 - would use Kali fractal again :).
// Kali fractal source:
// http://www.fractalforums.com/new-theories-and-research/very-simple-formula-for-fractal-patterns/

#include <metal_stdlib>
using namespace metal;

#define PI 3.141592654
#define TAU (2.0 * PI)

struct CityOfKaliParams {
  float time;
  float2 resolution;
  float padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

// License: WTFPL, author: sam hocevar, found:
// https://stackoverflow.com/a/17897228/418488
constant float4 hsv2rgb_K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
static float3 hsv2rgb(float3 c) {
  float3 p = abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www);
  return c.z * mix(hsv2rgb_K.xxx, clamp(p - hsv2rgb_K.xxx, 0.0, 1.0), c.y);
}

// License: Unknown, author: nmz (twitter: @stormoid), found:
// https://www.shadertoy.com/view/NdfyRM
static float3 sRGB(float3 t) {
  return mix(1.055 * pow(t, float3(1.0 / 2.4)) - 0.055, 12.92 * t,
             step(t, float3(0.0031308)));
}

// License: Unknown, author: Matt Taylor (https://github.com/64), found:
// https://64.github.io/tonemapping/
static float3 aces_approx(float3 v) {
  v = max(v, 0.0);
  v *= 0.6;
  float a = 2.51;
  float b = 0.03;
  float c = 2.43;
  float d = 0.59;
  float e = 0.14;
  return clamp((v * (a * v + b)) / (v * (c * v + d) + e), 0.0, 1.0);
}

static float3 effect(float2 p, float2 pp, float iTime) {
  float2 c = -float2(0.5, 0.5) * 1.05;

  float s = 3.0;
  float2 kp = p / s;
  kp += sin(0.05 * (iTime + 100.0) * float2(1.0, sqrt(0.5)));

  const float a = PI / 4.0;
  const float2 n = float2(cos(a), sin(a));

  float ot2 = 1E6;
  float ot3 = 1E6;
  float n2 = 0.0;
  float n3 = 0.0;

  const float mx = 15.0;
  for (float i = 0.0; i < mx; ++i) {
    float m = dot(kp, kp);
    s *= m;
    kp = abs(kp) / m + c;
    float d2 = abs(dot(kp, n)) * s;
    if (d2 < ot2) {
      n2 = i;
      ot2 = d2;
    }
    float d3 = dot(kp, kp);
    if (d3 < ot3) {
      n3 = i;
      ot3 = d3;
    }
  }

  float3 col = float3(0.0);
  n2 /= mx;
  n3 /= mx;
  col += hsv2rgb(float3(0.55 + 0.2 * n2, 0.90, 0.00125)) / (ot2 + 0.001);
  col += hsv2rgb(float3(0.05 - 0.1 * n3, 0.85, 0.0025)) /
         (ot3 + 0.000025 + 0.005 * n3 * n3);
  col -= 0.1 * float3(0.0, 1.0, 2.0).zxy;
  col *= smoothstep(1.5, 0.5, length(pp));
  col = aces_approx(col);
  col = sRGB(col);
  return col;
}

// 顶点着色器
vertex VertexOut cityOfKaliVertex(uint vertexID [[vertex_id]]) {
  const float2 positions[3] = {
      float2(-1.0, -1.0),
      float2(3.0, -1.0),
      float2(-1.0, 3.0),
  };
  const float2 uvs[3] = {
      float2(0.0, 0.0),
      float2(2.0, 0.0),
      float2(0.0, 2.0),
  };

  VertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = uvs[vertexID];
  return out;
}

// 片段着色器
fragment float4 cityOfKaliFragment(VertexOut in [[stage_in]],
                                   constant CityOfKaliParams &params
                                   [[buffer(0)]]) {
  float2 resolution = params.resolution;
  float iTime = params.time;
  float2 fragCoord = in.uv * resolution;

  float2 q = fragCoord / resolution;
  float2 p = -1.0 + 2.0 * q;
  float2 pp = p;
  p.x *= resolution.x / resolution.y;

  float3 col = effect(p, pp, iTime);
  return float4(col, 1.0);
}
