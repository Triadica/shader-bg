//
//  KorotkoeShaders.metal
//  shader-bg
//
//  Created on 2025-11-12.
//  Korotkoe - Mathematical rotating pattern
//  Speed reduced to 1/10 of original
//  Original by Zerothehero of Topopiccione (25/jul/2012)
//  Modified by mojovideotech
//  Forked from https://www.shadertoy.com/view/wtSSRW

#include <metal_stdlib>
using namespace metal;

struct KorotkoeParams {
  float time;
  float2 resolution;
  float padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 texCoord;
};

// Vertex shader for full-screen triangle
vertex VertexOut korotkoeVertex(uint vertexID [[vertex_id]]) {
  VertexOut out;
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.texCoord = positions[vertexID] * 0.5 + 0.5;
  return out;
}

// Mathematical constants
constant float di = 0.5772156649; // Euler-Mascheroni constant
constant float dh = 0.69314718;   // ln(2)
constant float twpi = 6.2831853;  // 2 * PI

// 2D rotation matrix
float2x2 korotkoe_rotate2d(float angle) {
  float c = cos(angle);
  float s = sin(angle);
  return float2x2(c, -s, s, c);
}

fragment float4 korotkoeFragment(VertexOut in [[stage_in]],
                                 constant KorotkoeParams &params
                                 [[buffer(0)]]) {
  float2 iResolution = params.resolution;
  float iTime = params.time;
  float2 fragCoord = in.texCoord * iResolution;

  float t = iTime * 12.0;
  float tt = iTime * 0.005;
  float2 p = ((fragCoord.xy / iResolution.xy) - 0.5) * 27.0;
  p.x *= iResolution.x / iResolution.y;

  float a = 0.0, b = 0.0, c = 0.0, d = 0.0, e = 0.0;

  for (int i = -4; i < 4; i++) {
    p = korotkoe_rotate2d(tt * -twpi) * p;
    float x = (p.x * di - p.y * dh * 0.125);
    float y = (p.x * di * 0.125 + p.y * dh);
    c = (sin(x + t * (float(i)) / 18.0) + b + y + 4.0);
    d = (cos(y + t * (float(i)) / 20.0) + x + a + 3.0);
    e = (sin(y + t * (float(i)) / 17.5) + x - e + 1.0);
    a -= 0.25 / (c * c);
    b += 0.5 / (d * d);
    e += 0.125;
  }

  float4 fragColor = float4(log(-e + a + b - 1.0) / 8.0 - 0.2,
                            log(-e - a - b - 1.0) / 8.0 - 0.2,
                            log(e - a + b - 1.0) / 5.0 - 0.1, 1.0);

  return fragColor;
}
