//
//  ApollianTwistShaders.metal
//  shader-bg
//
//  Created on 2025-10-30.
//  License CC0: Apollian with a twist
//  Playing around with apollian fractal
//  Forked from https://www.shadertoy.com/view/Wl3fzM

#include <metal_stdlib>
using namespace metal;

struct ApollianTwistParams {
  float2 resolution;
  float time;
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

#define TIME params.time
#define RESOLUTION params.resolution
#define PI 3.141592654
#define TAU (2.0 * PI)
#define L2(x) dot(x, x)
#define PSIN(x) (0.5 + 0.5 * sin(x))

// Rotation matrix
float2x2 rot(float a) {
  float c = cos(a);
  float s = sin(a);
  return float2x2(c, s, -s, c);
}

// HSV to RGB conversion
float3 hsv2rgb(float3 c) {
  const float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float apollian(float4 p, float s) {
  float scale = 1.0;

  for (int i = 0; i < 7; ++i) {
    p = -1.0 + 2.0 * fract(0.5 * p + 0.5);

    float r2 = dot(p, p);

    float k = s / r2;
    p *= k;
    scale *= k;
  }

  return abs(p.y) / scale;
}

float weird(float2 p, constant ApollianTwistParams &params) {
  float z = 4.0;
  p *= rot(TIME * 0.1);
  float tm = 0.2 * TIME;
  float r = 0.5;
  float4 off = float4(r * PSIN(tm * sqrt(3.0)), r * PSIN(tm * sqrt(1.5)),
                      r * PSIN(tm * sqrt(2.0)), 0.0);
  float4 pp = float4(p.x, p.y, 0.0, 0.0) + off;
  pp.w = 0.125 * (1.0 - tanh(length(pp.xyz)));
  pp.yz = rot(tm) * pp.yz;
  pp.xz = rot(tm * sqrt(0.5)) * pp.xz;
  pp /= z;
  float d = apollian(pp, 1.2);
  return d * z;
}

float df(float2 p, constant ApollianTwistParams &params) {
  const float zoom = 0.5;
  p /= zoom;
  float d0 = weird(p, params);
  return d0 * zoom;
}

float3 color(float2 p, constant ApollianTwistParams &params) {
  float aa = 2.0 / RESOLUTION.y;
  const float lw = 0.0235;
  const float lh = 1.25;

  const float3 lp1 = float3(0.5, lh, 0.5);
  const float3 lp2 = float3(-0.5, lh, 0.5);

  float d = df(p, params);

  float b = -0.125;
  float t = 10.0;

  float3 ro = float3(0.0, t, 0.0);
  float3 pp = float3(p.x, 0.0, p.y);

  float3 rd = normalize(pp - ro);

  float3 ld1 = normalize(lp1 - pp);
  float3 ld2 = normalize(lp2 - pp);

  float bt = -(t - b) / rd.y;

  float3 bp = ro + bt * rd;
  float3 srd1 = normalize(lp1 - bp);
  float3 srd2 = normalize(lp2 - bp);
  float bl21 = L2(lp1 - bp);
  float bl22 = L2(lp2 - bp);

  float st1 = (0.0 - b) / srd1.y;
  float st2 = (0.0 - b) / srd2.y;
  float3 sp1 = bp + srd1 * st1;
  float3 sp2 = bp + srd2 * st1;

  float bd = df(bp.xz, params);
  float sd1 = df(sp1.xz, params);
  float sd2 = df(sp2.xz, params);

  float3 col = float3(0.0);
  const float ss = 15.0;

  col += float3(1.0, 1.0, 1.0) *
         (1.0 - exp(-ss * (max((sd1 + 0.0 * lw), 0.0)))) / bl21;
  col += float3(0.5) * (1.0 - exp(-ss * (max((sd2 + 0.0 * lw), 0.0)))) / bl22;
  float l = length(p);
  float hue = fract(0.75 * l - 0.3 * TIME) + 0.3 + 0.15;
  float sat = 0.75 * tanh(2.0 * l);
  float3 hsv = float3(hue, sat, 1.0);
  float3 bcol = hsv2rgb(hsv);
  col *= (1.0 - tanh(0.75 * l)) * 0.5;
  col = mix(col, bcol, smoothstep(-aa, aa, -d));
  col += 0.5 * sqrt(bcol.zxy) * (exp(-(10.0 + 100.0 * tanh(l)) * max(d, 0.0)));

  return col;
}

float3 postProcess(float3 col, float2 q) {
  col = pow(clamp(col, 0.0, 1.0), float3(1.0 / 2.2));
  col = col * 0.6 + 0.4 * col * col * (3.0 - 2.0 * col); // contrast
  col = mix(col, float3(dot(col, float3(0.33))), -0.4);  // saturation
  col *= 0.5 + 0.5 * pow(19.0 * q.x * q.y * (1.0 - q.x) * (1.0 - q.y),
                         0.7); // vigneting
  return col;
}

// 顶点着色器
vertex VertexOut apollianTwistVertex(uint vertexID [[vertex_id]]) {
  float2 positions[6] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0),  float2(-1.0, -1.0),
                         float2(3.0, -1.0),  float2(-1.0, 3.0)};

  VertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = positions[vertexID];
  return out;
}

// 片段着色器
fragment float4 apollianTwistFragment(VertexOut in [[stage_in]],
                                      constant ApollianTwistParams &params
                                      [[buffer(0)]]) {
  float2 fragCoord = (in.uv * 0.5 + 0.5) * params.resolution;
  float2 q = fragCoord / RESOLUTION;
  float2 p = -1.0 + 2.0 * q;
  p.x *= RESOLUTION.x / RESOLUTION.y;

  float3 col = color(p, params);
  col = postProcess(col, q);

  return float4(col, 1.0);
}
