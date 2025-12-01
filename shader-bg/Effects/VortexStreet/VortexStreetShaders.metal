//
//  VortexStreetShaders.metal
//  shader-bg
//
//  Created on 2025-11-01.
//
//  Adapted from "Vortex Street" by dr2
//  License: Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported
//  License
//

#include <metal_stdlib>
using namespace metal;

struct VortexStreetParams {
  float2 resolution;
  float time;
  float padding;
};

struct VortexStreetVertexOut {
  float4 position [[position]];
  float2 uv;
};

vertex VortexStreetVertexOut vortexStreetVertex(uint vertexID [[vertex_id]]) {
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};

  VortexStreetVertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = positions[vertexID] * 0.5 + 0.5;
  return out;
}

constant float4 cHashA4 = float4(0.0, 1.0, 57.0, 58.0);
constant float3 cHashA3 = float3(1.0, 57.0, 113.0);
constant float cHashM = 43758.54;

inline float4 Hashv4f(float p) { return fract(sin(p + cHashA4) * cHashM); }

inline float Noisefv2(float2 p) {
  float2 i = floor(p);
  float2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float4 t = Hashv4f(dot(i, cHashA3.xy));
  return mix(mix(t.x, t.y, f.x), mix(t.z, t.w, f.x), f.y);
}

inline float Fbm2(float2 p) {
  float s = 0.0;
  float a = 1.0;
  for (int i = 0; i < 3; i++) {
    s += a * Noisefv2(p);
    a *= 0.5;
    p *= 2.0;
  }
  return s;
}

inline float2 VortF(float2 q, float2 c) {
  float2 d = q - c;
  return 0.25 * float2(d.y, -d.x) / (dot(d, d) + 0.05);
}

inline float2 FlowField(float2 q, float tCur) {
  float2 vr = float2(0.0);
  float dir = 1.0;
  // 使用 600 秒 (10 分钟) 的周期,避免太频繁的重置
  float2 c = float2(fmod(tCur, 600.0) - 20.0, 0.6 * dir);

  for (int k = 0; k < 15; k++) {
    vr += dir * VortF(4.0 * q, c);
    c = float2(c.x + 1.0, -c.y);
    dir = -dir;
  }
  return vr;
}

fragment float4 vortexStreetFragment(VortexStreetVertexOut in [[stage_in]],
                                     constant VortexStreetParams &params
                                     [[buffer(0)]]) {
  float2 fragCoord = in.uv * params.resolution;
  float2 uv = fragCoord / params.resolution - 0.5;
  uv.x *= params.resolution.x / params.resolution.y;

  float tCur = params.time * 0.125;
  float2 p = uv;

  for (int i = 0; i < 4; i++) {
    p -= FlowField(p, tCur) * 0.03;
  }

  float3 col = Fbm2(5.0 * p + float2(-0.1 * tCur, 0.0)) * float3(0.5, 0.5, 1.0);

  return float4(col, 1.0);
}