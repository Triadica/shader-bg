//
//  SinsAndStepsShaders.metal
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/13.
//  Forked from https://www.shadertoy.com/view/lfBSWd

#include <metal_stdlib>
using namespace metal;

struct SinsAndStepsParams {
  float time;
  float2 resolution;
  float2 padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

// 顶点着色器
vertex VertexOut sinsAndStepsVertex(uint vertexID [[vertex_id]]) {
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};

  VertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = positions[vertexID] * 0.5 + 0.5;
  return out;
}

// Line function - creates a single wave line
float sinsAndSteps_Line(float2 uv, float speed, float height, float time) {
  // Actual wave
  float wave = sin(uv.x * height + time * (1.5 + speed)) *
               smoothstep(1.0, 0.0, abs(uv.x)) * 0.45; // amplitude ramp

  // Creates the line with modulating thickness and value fade
  float line = smoothstep(0.1 * smoothstep(0.0, 1.0, abs(uv.x)) + 0.016, 0.0015,
                          abs(uv.y + wave))       // modulating thickness
               * smoothstep(1.1, 0.5, abs(uv.x)); // value fade

  return line;
}

// 片段着色器
fragment float4 sinsAndStepsFragment(VertexOut in [[stage_in]],
                                     constant SinsAndStepsParams &params
                                     [[buffer(0)]]) {
  // Normalized pixel coordinates (from 0 to 1)
  float2 uv = in.uv;
  uv = uv * 2.0 - 1.0;

  float value = 0.0;

  // Create multiple wave lines
  for (float i = 0.0; i <= 6.0; i += 1.0) {
    value += sinsAndSteps_Line(uv, i * 0.1, i + 4.0, params.time) *
             (1.1 - (i * 0.15));
  }

  // Color gradient based on horizontal position
  float3 col = float3(
      value * mix(float3(0.6, 0.4, 0.45), float3(0.05, 0.18, 0.6), abs(uv.x)));
  col += 0.1;

  return float4(col, 1.0);
}
