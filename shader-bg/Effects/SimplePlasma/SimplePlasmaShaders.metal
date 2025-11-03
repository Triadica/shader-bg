//
//  SimplePlasmaShaders.metal
//  shader-bg
//
//  Created on 2025-11-03.
//  Simple Plasma effect
//  Forked from https://www.shadertoy.com/view/XsVSzW

#include <metal_stdlib>
using namespace metal;

struct SimplePlasmaParams {
  float time;
  float2 resolution;
  float padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 texCoord;
};

// Vertex shader for full-screen triangle
vertex VertexOut simplePlasmaVertex(uint vertexID [[vertex_id]]) {
  VertexOut out;
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.texCoord = positions[vertexID] * 0.5 + 0.5;
  return out;
}

fragment float4 simplePlasmaFragment(VertexOut in [[stage_in]],
                                     constant SimplePlasmaParams &params
                                     [[buffer(0)]]) {
  float2 iResolution = params.resolution;
  float2 fragCoord = in.texCoord * iResolution;

  float time = params.time * 1.0;
  float2 uv = (fragCoord.xy / iResolution.xx - 0.5) * 8.0;
  float2 uv0 = uv;
  float i0 = 1.0;
  float i1 = 1.0;
  float i2 = 1.0;
  float i4 = 0.0;

  for (int s = 0; s < 7; s++) {
    float2 r;
    r = float2(cos(uv.y * i0 - i4 + time / i1),
               sin(uv.x * i0 - i4 + time / i1)) /
        i2;
    r += float2(-r.y, r.x) * 0.3;
    uv.xy += r;

    i0 *= 1.93;
    i1 *= 1.15;
    i2 *= 1.7;
    i4 += 0.05 + 0.1 * time * i1;
  }

  float r = sin(uv.x - time) * 0.5 + 0.5;
  float b = sin(uv.y + time) * 0.5 + 0.5;
  float g = sin((uv.x + uv.y + sin(time * 0.5)) * 0.5) * 0.5 + 0.5;

  return float4(r, g, b, 1.0);
}
