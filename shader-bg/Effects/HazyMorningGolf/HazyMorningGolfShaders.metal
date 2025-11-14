//
//  HazyMorningGolfShaders.metal
//  shader-bg
//
//  Created on 2025-11-12.
//  Hazy Morning Golf - Procedural layered landscape
//  Speed reduced to 1/8 of original
//  Forked from https://www.shadertoy.com/view/XfSczV

#include <metal_stdlib>
using namespace metal;

struct HazyMorningGolfParams {
  float time;
  float2 resolution;
  float padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 texCoord;
};

// Vertex shader for full-screen triangle
vertex VertexOut hazyMorningGolfVertex(uint vertexID [[vertex_id]]) {
  VertexOut out;
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.texCoord = positions[vertexID] * 0.5 + 0.5;
  return out;
}

fragment float4 hazyMorningGolfFragment(VertexOut in [[stage_in]],
                                        constant HazyMorningGolfParams &params
                                        [[buffer(0)]]) {
  float2 iResolution = params.resolution;
  float iTime = params.time;
  float2 fragCoord = in.texCoord * iResolution;

  float2 u = fragCoord;
  float4 o = float4(0.0);

  // Normalize y coordinate by screen height
  u /= iResolution.y;

  // Main rendering loop
  for (float l = 3.0, d = 1.0, x, a, b, f, i = 0.0; i < 1.0 && l > 2.0;
       i += 0.1) {
    // Calculate horizontal position with time animation
    x = u.x / d + 0.4 * iTime + 71.0 * i;

    // Fractal noise generation
    for (a = 0.0, b = 0.5; b > 0.001; b *= 0.5) {
      f = fract(x);
      // Mix between two noise values
      a += mix(fract((x - f) * 0.37), fract((x - f + 1.0) * 0.37), f) * b;
      x *= 2.0;
    }

    // Check if pixel is below the landscape curve
    if (u.y < d * a + i - 0.2) {
      l = i + 0.3;
    }

    // Scale down for next layer
    d *= 0.8;

    // Apply color - Hazy Morning color scheme
    o = float4(0.2, 0.3, 0.4, 0.0) * l;
  }

  return float4(o.rgb, 1.0);
}
