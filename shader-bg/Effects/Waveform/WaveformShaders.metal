//
//  WaveformShaders.metal
//  shader-bg
//
//  Created on 2025-11-01.
//
//  Adapted from "Waveform" by XorDev (original ShaderToy implementation).
//  Forked from https://www.shadertoy.com/view/Wcc3z2
//

#include <metal_stdlib>
using namespace metal;

struct WaveformParams {
  float2 resolution;
  float time;
  float padding;
};

struct WaveformVertexOut {
  float4 position [[position]];
  float2 uv;
};

vertex WaveformVertexOut waveformVertex(uint vertexID [[vertex_id]]) {
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};

  WaveformVertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = positions[vertexID] * 0.5 + 0.5;
  return out;
}

fragment float4 waveformFragment(WaveformVertexOut in [[stage_in]],
                                 constant WaveformParams &params
                                 [[buffer(0)]]) {
  float2 fragCoord = in.uv * params.resolution;
  // Normalize coordinates to [-1, 1] with aspect correction.
  float2 uv = (fragCoord / params.resolution) * 2.0 - 1.0;
  float aspect = params.resolution.x / params.resolution.y;
  uv.x *= aspect;

  // Build a simplified waveform using a few sine layers.
  float time = params.time * 0.8;
  float wave = fast::sin(uv.x * 5.0 + time) * 0.55 +
               fast::sin(uv.x * 11.0 - time * 0.6) * 0.25 +
               fast::sin(uv.x * 17.0 + time * 1.6) * 0.12;

  // Distance from the waveform and falloff.
  float dist = fabs(uv.y - wave * 0.6);
  float core = fast::exp(-dist * 10.0);
  float glow = fast::exp(-dist * 2.4) * 0.35;

  // Subtle background bands.
  float background = 0.12 + 0.05 * fast::sin(uv.x * 3.5 + time * 0.4);

  float3 color = core * float3(0.45, 0.78, 1.0) +
                 glow * float3(0.1, 0.2, 0.35) +
                 background * float3(0.02, 0.03, 0.05);

  // Soft bloom based on the derivative for a sharper crest.
  float slope = fast::cos(uv.x * 5.0 + time) * 5.0;
  color += float3(0.15, 0.25, 0.35) * core * fast::min(fabs(slope) * 0.12, 0.3);

  // Gentle dithering to avoid banding.
  float dither =
      fract(fast::sin(dot(fragCoord, float2(12.9898, 78.233))) * 43758.5453);
  color += (dither - 0.5) * 0.004;

  return float4(saturate(color), 1.0);
}
