//
//  SurahRelaxShaders.metal
//  shader-bg
//
//  Created on 2025-11-12.
//  Surah Relax - Wavy gradient bars with relaxing motion
//  Speed reduced to 1/32 of original
//  Forked from https://www.shadertoy.com/view/NtSBR3

#include <metal_stdlib>
using namespace metal;

struct SurahRelaxParams {
  float time;
  float2 resolution;
  float padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 texCoord;
};

// Vertex shader for full-screen triangle
vertex VertexOut surahRelaxVertex(uint vertexID [[vertex_id]]) {
  VertexOut out;
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.texCoord = positions[vertexID] * 0.5 + 0.5;
  return out;
}

// Helper function: creates horizontal bar
float surahRelax_bar(float2 uv, float start, float height) {
  return step(uv.y, height + start) - step(uv.y, start);
}

fragment float4 surahRelaxFragment(VertexOut in [[stage_in]],
                                   constant SurahRelaxParams &params
                                   [[buffer(0)]]) {
  float2 iResolution = params.resolution;
  float iTime = params.time;
  float2 fragCoord = in.texCoord * iResolution;

  float2 uv = fragCoord / iResolution.xy;
  float3 col = float3(0.3, 0.0, 0.0);

  // Create layered wavy bars
  for (float i = -0.0; i < 1.3; i += 0.1) {
    // Calculate wave displacement with time animation
    float wave =
        sin((i * 12.0 + iTime * 2.0 + uv.x * 5.0) * 0.4) * 0.08 * (1.1 - i);
    uv.y += wave;

    // Add colored bar with gradient
    col += float3(0.1 + i * 0.005, i * 0.1, 0.003) *
           surahRelax_bar(uv, i + 0.1, i + 1.0);
  }

  // Add blue channel modulation with time
  float4 fragColor =
      float4(col + float3(0.0, 0.0, col.r * sin(0.3 + iTime) * 0.3), 1.0);

  return fragColor;
}
