//
//  MobiusFlowShaders.metal
//  shader-bg
//
//  Created on 2025-11-02.
//
//  Adapted from Mobius Flow shader
//  Original from Shadertoy
//  CC0 License
//
//  Forked from https://www.shadertoy.com/view/dltXRn

#include <metal_stdlib>
using namespace metal;

struct MobiusFlowParams {
  float2 resolution;
  float time;
  float padding;
};

struct MobiusFlowVertexOut {
  float4 position [[position]];
  float2 uv;
};

vertex MobiusFlowVertexOut mobiusFlowVertex(uint vertexID [[vertex_id]]) {
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};
  float2 uvs[3] = {float2(0.0, 0.0), float2(2.0, 0.0), float2(0.0, 2.0)};

  MobiusFlowVertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = uvs[vertexID];
  return out;
}

// Helper: rotation matrix
static inline float2x2 RT(float a) {
  float angle = a * 1.5708;
  return float2x2(cos(angle), -sin(angle), sin(angle), cos(angle));
}

// Helper: grid function
static inline float G(float x, float t) {
  return (1.0 - abs(sin((x + t) * 3.1416))) / max(0.0, abs(x));
}

// Helper: point function
static inline float P(float2 u, float t, float2 fw) {
  float2 frac_val = fract(u + float2(t * round(u.y / 2.0), t) + 0.5) - 0.5;
  float len = length(frac_val / fw / 1.5);
  return 0.3 * min(2.0, 1.0 / len) / max(0.0, abs(u.y));
}

// Helper: color function (hue)
static inline float3 H(float a) {
  float3 angles = float3(0.0, 60.0, 120.0) * 0.0174533; // degrees to radians
  return cos(angles - (a * 6.2832)) * 0.5 + 0.5;
}

fragment float4 mobiusFlowFragment(MobiusFlowVertexOut in [[stage_in]],
                                   constant MobiusFlowParams &params
                                   [[buffer(0)]]) {
  float2 U = in.uv * params.resolution;
  float2 R = params.resolution;

  // Slow down time by factor of 8 (was /5., now /40.)
  float t = params.time / 40.0;
  float fov = 0.75;

  // Auto-rotate camera with time
  float2 m = float2(sin(t / 2.0) * 0.2, sin(t) * 0.1);

  float3 c = float3(0.0);
  float3 u = normalize(float3((U - 0.5 * R) / R.y, fov)) * 5.5;

  // Apply rotations
  u.yz = RT(m.y) * u.yz; // pitch
  u.xz = RT(m.x) * u.xz; // yaw

  // Transform
  float2 o = u.xy - float2(1.0, 0.0);
  float2 v = o / dot(o, o);
  v.x += 0.5;

  float len_v = length(v);
  float atan_v = atan2(v.y, v.x);
  u.xy = tan(log(len_v) + atan_v * float2(2.0, -4.0) / 2.0);

  // Speed
  float3 s = t * sign(u) * sign(abs(u) - 1.0);

  // Reflect
  u = max(abs(u), 1.0 / abs(u));

  // Calculate fwidth for anti-aliasing
  float2 fw_xy = fwidth(u.xy);
  float2 fw_yx = float2(fw_xy.y, fw_xy.x);
  float2 fw_zx = fwidth(float2(u.z, u.x));
  float2 fw_xz = float2(fw_zx.y, fw_zx.x);
  float2 fw_zy = fwidth(float2(u.z, u.y));
  float2 fw_yz = float2(fw_zy.y, fw_zy.x);

  // Grids
  c += max(max(G(u.x, s.x), G(u.y, s.y)), G(u.z, s.z));

  // Points
  c += P(u.yx, s.x, fw_yx) + P(float2(u.z, u.x), s.x, fw_zx);
  c += P(u.xy, s.y, fw_xy) + P(float2(u.z, u.y), s.y, fw_zy);
  c += P(u.yz, s.z, fw_yz) + P(float2(u.x, u.z), s.z, fw_xz);

  // Colors
  c = H(c.x + sin(t) * 0.1 + 0.1) * c + c * c;
  c += H(u.x) * 0.1;
  c += H(u.y + 0.5) * 0.1;

  float3 final_color = c * c + 0.1 * c;

  return float4(final_color, 1.0);
}
