//
//  SpiralForWindowsShaders.metal
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/13.
//  CC0: Spirals for windows terminal
//  Forked from https://www.shadertoy.com/view/DsG3Dm

#include <metal_stdlib>
using namespace metal;

#define PI 3.141592654
#define TAU (2.0 * PI)

struct SpiralForWindowsParams {
  float time;
  float2 resolution;
  float2 padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

// 顶点着色器
vertex VertexOut spiralForWindowsVertex(uint vertexID [[vertex_id]]) {
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};

  VertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = positions[vertexID] * 0.5 + 0.5;
  return out;
}

// 旋转矩阵
float2x2 spiralForWindows_ROT(float a) {
  float c = cos(a);
  float s = sin(a);
  return float2x2(c, s, -s, c);
}

// sRGB color correction
float3 spiralForWindows_sRGB(float3 t) {
  return mix(1.055 * pow(t, float3(1.0 / 2.4)) - 0.055, 12.92 * t,
             step(t, float3(0.0031308)));
}

// ACES tone mapping
float3 spiralForWindows_aces_approx(float3 v) {
  v = max(v, 0.0);
  v *= 0.6;
  float a = 2.51;
  float b = 0.03;
  float c = 2.43;
  float d = 0.59;
  float e = 0.14;
  return clamp((v * (a * v + b)) / (v * (c * v + d) + e), 0.0, 1.0);
}

// Hash function
float spiralForWindows_hash(float co) {
  return fract(sin(co * 12.9898) * 13758.5453);
}

// Modulo function
// GLSL mod() always returns positive, while fmod() can return negative
float spiralForWindows_mod1(thread float &p, float size) {
  float halfsize = size * 0.5;
  float c = floor((p + halfsize) / size);
  // Use GLSL-style mod: result = x - y * floor(x/y)
  float temp = p + halfsize;
  p = temp - size * floor(temp / size) - halfsize;
  return c;
}

// Ray-cylinder intersection
float2 spiralForWindows_rayCylinder(float3 ro, float3 rd, float3 cb, float3 ca,
                                    float cr) {
  float3 oc = ro - cb;
  float card = dot(ca, rd);
  float caoc = dot(ca, oc);
  float a = 1.0 - card * card;
  float b = dot(oc, rd) - caoc * card;
  float c = dot(oc, oc) - caoc * caoc - cr * cr;
  float h = b * b - a * c;
  if (h < 0.0)
    return float2(-1.0);
  h = sqrt(h);
  return float2(-b - h, -b + h) / a;
}

// Sky color
float3 spiralForWindows_skyColor(float3 ro, float3 rd) {
  const float3 l = normalize(float3(0.0, 0.0, -1.0));
  const float3 baseCol = 0.005 * float3(0.05, 0.33, 1.0);
  return baseCol / (1.00025 + dot(rd, l));
}

// Main color function
float3 spiralForWindows_color(float3 ww, float3 uu, float3 vv, float3 ro,
                              float2 p) {
  const float rdd = 2.0;
  const float mm = 3.0;
  const float rep = 27.0;

  float3 rd = normalize(-p.x * uu + p.y * vv + rdd * ww);

  float3 skyCol = spiralForWindows_skyColor(ro, rd);

  float2 etc =
      spiralForWindows_rayCylinder(ro, rd, ro, float3(0.0, 0.0, 1.0), 1.0);
  float3 etcp = ro + rd * etc.y;
  float2 rdyx = rd.yx * spiralForWindows_ROT(0.3 * etcp.z);
  rd.y = rdyx.x;
  rd.x = rdyx.y;

  float3 col = skyCol;

  float a = atan2(rd.y, rd.x);
  for (float i = 0.0; i < mm; i += 1.0) {
    float ma = a;
    float sz = rep + i * 6.0;
    float slices = TAU / sz;
    float ma_temp = ma;
    float na = spiralForWindows_mod1(ma_temp, slices);
    ma = ma_temp;

    float h1 = spiralForWindows_hash(na + 13.0 * i + 123.4);
    float h2 = fract(h1 * 3677.0);
    float h3 = fract(h1 * 8677.0);

    float tr = mix(0.5, 3.0, h1);
    float2 tc =
        spiralForWindows_rayCylinder(ro, rd, ro, float3(0.0, 0.0, 1.0), tr);
    float3 tcp = ro + tc.y * rd;
    float2 tcp2 = float2(tcp.z, atan2(tcp.y, tcp.x));

    float zz = mix(0.025, 0.05, sqrt(h1)) * rep / sz;
    float tcp2y = tcp2.y;
    float tnpy = spiralForWindows_mod1(tcp2y, slices);
    tcp2.y = tcp2y;
    float fo = smoothstep(0.5 * slices, 0.25 * slices, abs(tcp2.y));
    tcp2.x += -h2 * ro.z; // Use ro.z as time equivalent
    tcp2.y *= tr * PI / 3.0;
    float w =
        mix(0.2, 1.0, h2); // Width parameter (defined but not used in original)

    tcp2 /= zz;
    float d = abs(tcp2.y);
    d *= zz;

    float3 bcol =
        (1.0 + cos(float3(0.0, 1.0, 2.0) + TAU * h3 + 0.5 * h2 * h2 * tcp.z)) *
        0.00005;
    bcol /= max(d * d, 5E-7 * tc.y * tc.y);
    bcol *= exp(-0.04 * tc.y * tc.y);
    bcol *= smoothstep(-0.5, 1.0, sin(mix(0.125, 1.0, h2) * tcp.z));
    bcol *= fo;
    col += bcol;
  }

  return col;
}

// Effect function
float3 spiralForWindows_effect(float2 p, float2 pp, float tm) {
  float3 ro = float3(0.0, 0.0, tm);
  float3 dro = normalize(float3(1.0, 0.0, 3.0));
  float2 droxz = dro.xz * spiralForWindows_ROT(0.2 * sin(0.05 * tm));
  dro.x = droxz.x;
  dro.z = droxz.y;
  float2 droyz =
      dro.yz * spiralForWindows_ROT(0.2 * sin(0.05 * tm * sqrt(0.5)));
  dro.y = droyz.x;
  dro.z = droyz.y;
  const float3 up = float3(0.0, 1.0, 0.0);
  float3 ww = normalize(dro);
  float3 uu = normalize(cross(up, ww));
  float3 vv = cross(ww, uu);
  float3 col = spiralForWindows_color(ww, uu, vv, ro, p);
  col -= 0.125 * float3(0.0, 1.0, 2.0).yzx * length(pp);
  col = spiralForWindows_aces_approx(col);
  col = spiralForWindows_sRGB(col);
  return col;
}

// 片段着色器
fragment float4 spiralForWindowsFragment(VertexOut in [[stage_in]],
                                         constant SpiralForWindowsParams &params
                                         [[buffer(0)]]) {
  float2 fragCoord = in.uv * params.resolution;
  float2 q = fragCoord / params.resolution;
  float2 p = -1.0 + 2.0 * q;
  float2 pp = p;
  p.x *= params.resolution.x / params.resolution.y;

  float3 col = spiralForWindows_effect(p, pp, params.time);

  return float4(col, 1.0);
}
