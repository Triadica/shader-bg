//
//  StarTravellingShaders.metal
//  shader-bg
//
//  Created on 2025-11-01.
//
//  Adapted from "Colorful star travelling"
//  Original: https://www.shadertoy.com/view/
//  CC0 License
//  Forked from https://www.shadertoy.com/view/DtBSRh

#include <metal_stdlib>
using namespace metal;

struct StarTravellingParams {
  float2 resolution;
  float time;
  float padding;
};

struct StarTravellingVertexOut {
  float4 position [[position]];
  float2 uv;
};

vertex StarTravellingVertexOut starTravellingVertex(uint vertexID
                                                    [[vertex_id]]) {
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};

  StarTravellingVertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = positions[vertexID] * 0.5 + 0.5;
  return out;
}

#define PI 3.141592654
#define TAU (2.0 * PI)
#define BPM (145.0 * 0.5 * 0.08) // 速度进一步降低，每帧移动更短距离

constant float planeDist = 1.0 - 0.82;
constant float4 hsv2rgb_K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);

// HSV to RGB conversion
static inline float3 hsv2rgb_star(float3 c) {
  float3 p = abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www);
  return c.z * mix(hsv2rgb_K.xxx, clamp(p - hsv2rgb_K.xxx, 0.0, 1.0), c.y);
}

// sRGB conversion
static inline float3 sRGB(float3 t) {
  return mix(1.055 * pow(t, float3(1.0 / 2.4)) - 0.055, 12.92 * t,
             step(t, float3(0.0031308)));
}

// ACES tone mapping
static inline float3 aces_approx(float3 v) {
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
static inline float hash3(float3 r) {
  return fract(sin(dot(r.xy, float2(1.38984 * sin(r.z), 1.13233 * cos(r.z)))) *
               653758.5453);
}

// Modulo for grid cells
static inline float2 mod2(thread float2 &p, float2 size) {
  float2 c = floor((p + size * 0.5) / size);
  p = fmod(p + size * 0.5, size) - size * 0.5;
  return c;
}

// Random offset
static inline float2 soff(float h0) {
  float h1 = fract(h0 * 8677.0);
  return -1.0 + 2.0 * float2(h0, h1);
}

// Camera path offset
static inline float3 offset(float z) {
  float a = z;
  float2 p = 0.1 * (float2(cos(a), sin(a * sqrt(2.0))) +
                    float2(cos(a * sqrt(0.75)), sin(a * sqrt(0.5))));
  return float3(p, z);
}

// Derivative of offset
static inline float3 doffset(float z) {
  float eps = 0.05;
  return (offset(z + eps) - offset(z - eps)) / (2.0 * eps);
}

// Second derivative of offset
static inline float3 ddoffset(float z) {
  float eps = 0.05;
  return (doffset(z + eps) - doffset(z - eps)) / (2.0 * eps);
}

// Sky color - 背景光源
static inline float3 skyColor(float3 ro, float3 rd) {
  const float3 gcol = hsv2rgb_star(float3(0.55, 0.9, 0.035));
  float2 pp = rd.xy;
  // 降低光源亮度到 35%，避免过曝
  return gcol / dot(pp, pp) * 0.35;
}

// 2D rotation matrix
static inline float2x2 ROT(float a) {
  return float2x2(cos(a), sin(a), -sin(a), cos(a));
}

// Render plane with stars
static inline float3 plane(float3 ro, float3 rd, float3 pp, float3 off,
                           float aa, float n) {
  float l = distance(ro, pp);
  float2 p = (pp - off * float3(1.0, 1.0, 0.0)).xy;

  p *= 1.0 + l * l;

  const float csz = 0.15;
  const float co = 0.33 * csz;

  float3 col = float3(0.0);

  // 减少迭代次数从5次到3次以提高性能
  const float cnt = 3.0;
  const float icnt = 1.0 / cnt;

  for (float i = 0.0; i < 1.0; i += icnt) {
    float2 cp = p;
    float2 cn = mod2(cp, float2(csz));

    float h0 = hash3(float3(cn, n) + 123.4 + i);
    float h1 = fract(3677.0 * h0);

    cp += soff(h0) * co;

    float cl = length(cp);
    float d = (cl - 0.0005);
    d = max(d, 0.0001);

    float3 bcol = 0.000005 * (1.0 + sin(float3(0.0, 1.0, 2.0) + TAU * h1));
    // 减少光晕范围：增加距离衰减系数，减少近距离时的亮度
    bcol *= smoothstep(0.17 * csz, 0.05 * csz, cl) * 0.08 /
            (d * d * (l * l + 0.05));

    // 根据距离降低不透明度，近距离星星更透明，避免太亮
    float distanceOpacity = smoothstep(0.0, 2.0, l);
    bcol *= distanceOpacity;

    col += bcol;
    p += icnt;
    p *= ROT(1.0);
  }

  return col;
}

// Main color calculation
static inline float3 color(float3 ww, float3 uu, float3 vv, float3 ro, float2 p,
                           float2 resolution) {
  float lp = length(p);
  float2 np = p + 1.0 / resolution;
  float rdd = 3.0;

  float3 rd = normalize(-p.x * uu + p.y * vv + rdd * ww);
  float3 nrd = normalize(-np.x * uu + np.y * vv + rdd * ww);

  // 减少渲染层数从9层到6层以提高性能
  const int furthest = 6;
  const int fadeFrom = max(furthest - 2, 0);

  const float fadeDist = planeDist * float(furthest - fadeFrom);
  float nz = floor(ro.z / planeDist);

  float3 col = skyColor(ro, rd);

  // Render planes from nearest to furthest
  for (int i = 1; i <= furthest; ++i) {
    float pz = planeDist * nz + planeDist * float(i);
    float pd = (pz - ro.z) / rd.z;

    if (pd > 0.0) {
      float3 pp = ro + rd * pd;
      float3 npp = ro + nrd * pd;

      float aa = 3.0 * length(pp - npp);

      float3 off = offset(pp.z);
      float3 pcol = plane(ro, rd, pp, off, aa, nz + float(i));

      float nz_val = pp.z - ro.z;
      float fadeIn = smoothstep(planeDist * float(furthest),
                                planeDist * float(fadeFrom), nz_val);
      float fadeOut = smoothstep(0.0, planeDist * 0.1, nz_val);
      pcol *= fadeOut * fadeIn;

      col += pcol;
    }
  }

  return col;
}

// Main effect
static inline float3 effect(float2 p, float2 pp, float time,
                            float2 resolution) {
  float tm = planeDist * time * BPM / 60.0;
  float3 ro = offset(tm);
  float3 dro = doffset(tm);
  float3 ddro = ddoffset(tm);

  float3 ww = normalize(dro);
  float3 uu = normalize(cross(normalize(float3(0.0, 1.0, 0.0) + ddro), ww));
  float3 vv = cross(ww, uu);

  float3 col = color(ww, uu, vv, ro, p, resolution);
  col -= 0.1 * float3(0.0, 1.0, 2.0).zyx * length(pp);
  col *= smoothstep(1.5, 0.5, length(pp));
  col = aces_approx(col);
  col = sRGB(col);

  return col;
}

fragment float4 starTravellingFragment(StarTravellingVertexOut in [[stage_in]],
                                       constant StarTravellingParams &params
                                       [[buffer(0)]]) {
  float2 fragCoord = in.uv * params.resolution;
  float2 q = fragCoord / params.resolution;
  float2 p = -1.0 + 2.0 * q;
  float2 pp = p;
  p.x *= params.resolution.x / params.resolution.y;

  float3 col = effect(p, pp, params.time, params.resolution);

  return float4(col, 1.0);
}
