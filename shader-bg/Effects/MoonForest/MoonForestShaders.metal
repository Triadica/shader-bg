//
//  MoonForestShaders.metal
//  shader-bg
//
//  Created on 2025-11-07.
//
//  Forked from "Over the Moon" by Martijn Steinrucken aka BigWings
//  License Creative Commons Attribution-NonCommercial-ShareAlike 3.0
//  Forked from https://www.shadertoy.com/view/ltSyWt

#include <metal_stdlib>
using namespace metal;

#define PI 3.1415
#define MOD3 float3(0.1031, 0.11369, 0.13787)
#define MOONPOS float2(1.3, 0.8)

struct MoonForestParams {
  float time;
  float2 resolution;
  int padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 texCoord;
};

// Vertex shader
vertex VertexOut moonForestVertex(uint vertexID [[vertex_id]]) {
  VertexOut out;
  float2 pos = float2((vertexID << 1) & 2, vertexID & 2);
  out.position = float4(pos * 2.0 - 1.0, 0.0, 1.0);
  out.texCoord = pos;
  return out;
}

// Hash functions
static float mfHash11(float p) {
  float3 p3 = fract(float3(p) * MOD3);
  p3 += dot(p3, p3.yzx + 19.19);
  return fract((p3.x + p3.y) * p3.z);
}

static float mfHash12(float2 p) {
  float3 p3 = fract(float3(p.xyx) * MOD3);
  p3 += dot(p3, p3.yzx + 19.19);
  return fract((p3.x + p3.y) * p3.z);
}

static float mfBand(float t, float start, float end, float blur) {
  float step1 = smoothstep(start - blur, start + blur, t);
  float step2 = smoothstep(end + blur, end - blur, t);
  return step1 * step2;
}

static float mfWithin(float a, float b, float t) { return (t - a) / (b - a); }

static float mfSkewbox(float2 uv, float3 top, float3 bottom, float blur) {
  float y = mfWithin(top.z, bottom.z, uv.y);
  float left = mix(top.x, bottom.x, y);
  float right = mix(top.y, bottom.y, y);

  float horizontal =
      mfBand(uv.x, left, right, blur) * mfBand(uv.x, left, right, blur);
  float vertical = mfBand(uv.y, bottom.z, top.z, blur);
  return horizontal * vertical;
}

// Pine tree
static float4 mfPine(float2 uv, float focus) {
  uv.x -= 0.5;
  float c =
      mfSkewbox(uv, float3(0.0, 0.0, 1.0), float3(-0.14, 0.14, 0.65), focus);
  c += mfSkewbox(uv, float3(-0.10, 0.10, 0.65), float3(-0.18, 0.18, 0.43),
                 focus);
  c +=
      mfSkewbox(uv, float3(-0.13, 0.13, 0.43), float3(-0.22, 0.22, 0.2), focus);
  c +=
      mfSkewbox(uv, float3(-0.04, 0.04, 0.2), float3(-0.04, 0.04, -0.1), focus);

  float4 col = float4(1.0, 1.0, 1.0, 0.0);
  col.a = c;

  float shadow = mfSkewbox(uv.yx, float3(0.6, 0.65, 0.13),
                           float3(0.65, 0.65, -0.1), focus);
  shadow += mfSkewbox(uv.yx, float3(0.43, 0.43, 0.13), float3(0.36, 0.43, -0.2),
                      focus);
  shadow += mfSkewbox(uv.yx, float3(0.15, 0.2, 0.08), float3(0.17, 0.2, -0.08),
                      focus);

  col.rgb = mix(col.rgb, col.rgb * 0.8, shadow);

  return col;
}

// Landscape height
static float mfGetHeight(float x) {
  return sin(x) + sin(x * 2.234 + 0.123) * 0.5 + sin(x * 4.45 + 2.2345) * 0.25;
}

// Landscape with trees
static float4 mfLandscape(float2 uv, float d, float p, float f, float a,
                          float y, float seed, float focus) {
  uv *= d;
  float x = uv.x * PI * f + p;
  float c = mfGetHeight(x) * a + y;

  float b = floor(x * 5.0) / 5.0 + 0.1;
  float h = mfGetHeight(b) * a + y;

  float e = fwidth(uv.y);

  float4 col = float4(smoothstep(c + e, c - e, uv.y));

  x *= 5.0;
  float id = floor(x);
  float n = mfHash11(id + seed);

  x = fract(x);

  float treeY = (uv.y - h) * mix(5.0, 3.0, n) * 3.5;
  float treeHeight = (0.07 / d) * mix(1.3, 0.5, n);
  treeY = mfWithin(h, h + treeHeight, uv.y);
  x += (n - 0.5) * 0.6;
  float4 pineCol = mfPine(float2(x, treeY / d), focus);

  col.rgb = mix(col.rgb, pineCol.rgb, pineCol.a);
  col.a = max(col.a, pineCol.a);

  return clamp(col, 0.0, 1.0);
}

// Gradient
static float4 mfGradient(float2 uv) {
  float c = 1.0 - length(MOONPOS - uv) / 1.4;
  return float4(c);
}

// Circle
static float mfCirc(float2 uv, float2 pos, float radius, float blur) {
  float dist = length(uv - pos) + mfHash11(pos.x) * 0.02;
  return smoothstep(radius + blur, radius - blur, dist);
}

// Moon
static float4 mfMoon(float2 uv) {
  float c = mfCirc(uv, MOONPOS, 0.07, 0.001);
  c *= 1.0 - mfCirc(uv, MOONPOS + float2(0.03), 0.07, 0.001) * 0.95;
  c = clamp(c, 0.0, 1.0);

  float4 col = float4(c);
  col.rgb *= 0.8;

  return col;
}

// Moon glow
static float4 mfMoonglow(float2 uv) {
  float c = mfCirc(uv, MOONPOS, 0.1, 0.2);

  float4 col = float4(c);
  col.rgb *= 0.2;

  return col;
}

// Stars
static float mfStars(float2 uv, float t, float2 moonUV) {
  t *= 3.0;

  float n1 = mfHash12(uv * 10000.0);
  float n2 = mfHash12(uv * 11234.0);
  float alpha1 = pow(n1, 20.0);
  float alpha2 = pow(n2, 20.0);

  float twinkle = sin((uv.x - t + cos(uv.y * 20.0 + t)) * 10.0);
  twinkle *=
      cos((uv.y * 0.234 - t * 3.24 + sin(uv.x * 12.3 + t * 0.243)) * 7.34);
  twinkle = (twinkle + 1.0) / 2.0;

  float4 m = mfMoon(moonUV);
  return m.a > 0.0 ? 0.0 : (alpha1 * alpha2 * twinkle);
}

// Fragment shader
fragment float4 moonForestFragment(VertexOut in [[stage_in]],
                                   constant MoonForestParams &params
                                   [[buffer(0)]]) {
  float2 uv = in.texCoord;
  float t = params.time;

  float2 bgUV = uv * float2(params.resolution.x / params.resolution.y, 1.0);
  float2 uvBasic = uv;

  // Moon trajectory
  bgUV.y += 0.43;
  bgUV.x += PI * sin((t / 6.0 + 3090.0) / 1.76) / 5.0;
  bgUV.y += (PI / 1.12) * cos((t / 6.0 + 3090.0) / 1.76) / 5.0;
  bgUV.x += 0.5;

  // Sky gradient and moon
  float4 col = mfGradient(bgUV) * 0.8;
  col += mfMoon(bgUV);

  // Stars
  col.rgb += float3(mfStars(uv, t, bgUV));

  // Landscape layers
  float dist = 1.0;
  float height = 0.55;
  float amplitude = 0.02;

  float horizon = 0.25;
  float brightness = 1.0 + horizon - bgUV.y;

  float4 trees = float4(0.0);
  for (float i = 0.0; i < 10.0; i += 1.0) {
    float4 layer =
        mfLandscape(uv, dist, t * 0.66 + i, 3.0, amplitude, height, i, 0.01);

    layer.rgb *=
        mix(float3(0.1, 0.1, 0.2),
            float3(0.1) + clamp(mfGradient(uv).x * brightness, 0.0, 1.5) * 2.0,
            1.0 - i / 10.0);

    trees = mix(trees, layer, layer.a);

    dist -= 0.1;
    height -= 0.06;
  }

  // Combine
  float4 mask = mix(col, trees, trees.a) * (1.0 - trees.a);
  col = max(mask, trees);

  // Moon glow
  col += mfMoonglow(bgUV) * (1.0 - trees.a);

  col = clamp(col, 0.0, 1.0);

  // Foreground
  float4 foreground =
      mfLandscape(uv, 0.02, t * 0.66, 3.0, 0.0, -0.04, 1.0, 0.1);
  foreground.rgb *= float3(0.1, 0.1, 0.2) * 0.5;

  col = mix(col, foreground, foreground.a);

  return col;
}
