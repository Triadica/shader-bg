//
//  ButterflyAIShaders.metal
//  shader-bg
//
//  Created on 2025-11-12.
//  Butterfly AI - Dynamic orb with gradient effects and particles
//  Speed reduced to 1/4 of original
// Forked from https://www.shadertoy.com/view/tfcGD8

#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265359
#define TAU 6.28318530718

struct ButterflyAIParams {
  float time;
  float2 resolution;
  float2 mouse;
  float padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 texCoord;
};

// Vertex shader for full-screen triangle
vertex VertexOut butterflyAIVertex(uint vertexID [[vertex_id]]) {
  VertexOut out;
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.texCoord = positions[vertexID] * 0.5 + 0.5;
  return out;
}

// Hash function
float butterfly_hash21(float2 p) {
  p = fract(p * float2(234.34, 435.345));
  p += dot(p, p + 34.23);
  return fract(p.x * p.y);
}

// Noise function
float butterfly_noise(float2 p) {
  float2 i = floor(p);
  float2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);

  float a = butterfly_hash21(i);
  float b = butterfly_hash21(i + float2(1.0, 0.0));
  float c = butterfly_hash21(i + float2(0.0, 1.0));
  float d = butterfly_hash21(i + float2(1.0, 1.0));

  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian Motion
float butterfly_fbm(float2 p) {
  float sum = 0.0;
  float amp = 0.5;
  float freq = 1.0;

  for (int i = 0; i < 6; i++) {
    sum += butterfly_noise(p * freq) * amp;
    amp *= 0.5;
    freq *= 2.0;
  }

  return sum;
}

fragment float4 butterflyAIFragment(VertexOut in [[stage_in]],
                                    constant ButterflyAIParams &params
                                    [[buffer(0)]]) {
  float2 iResolution = params.resolution;
  float iTime = params.time;
  float2 iMouse = params.mouse;
  float2 fragCoord = in.texCoord * iResolution;

  // Normalize coordinates
  float2 uv = fragCoord / iResolution.xy;
  float2 aspect = float2(iResolution.x / iResolution.y, 1.0);
  uv = (uv - 0.5) * aspect;

  // Scale to 2/3 size (multiply by 1.5 to make pattern smaller)
  uv *= 1.5;

  // Mouse position
  float2 mouse = (iMouse / iResolution.xy - 0.5) * aspect * 1.5;
  float mouseDist = length(uv - mouse);

  float3 col = float3(0.0);

  // Animated radius
  float radius = 0.3 + sin(iTime * 0.5) * 0.02;
  float d = length(uv);

  // Angular waves
  float angle = atan2(uv.y, uv.x);
  float wave = sin(angle * 3.0 + iTime) * 0.1;
  float wave2 = cos(angle * 5.0 - iTime * 1.3) * 0.08;

  // Noise layers
  float noise1 = butterfly_fbm(uv * 3.0 + iTime * 0.1);
  float noise2 = butterfly_fbm(uv * 5.0 - iTime * 0.2);

  // Orb color
  float3 orbColor = float3(0.2, 0.6, 1.0);
  float orb = smoothstep(radius + wave + wave2, radius - 0.1 + wave + wave2, d);

  // Color gradients
  float3 gradient1 = float3(0.8, 0.2, 0.5) * sin(angle + iTime);
  float3 gradient2 = float3(0.2, 0.5, 1.0) * cos(angle - iTime * 0.7);

  // Animated particles
  float particles = 0.0;
  for (float i = 0.0; i < 3.0; i += 1.0) {
    float2 particlePos = float2(sin(iTime * (0.5 + i * 0.2)) * 0.5,
                                cos(iTime * (0.3 + i * 0.2)) * 0.5);
    particles += smoothstep(0.05, 0.0, length(uv - particlePos));
  }

  // Combine effects
  col += orb * mix(orbColor, gradient1, noise1);
  col += orb * mix(gradient2, orbColor, noise2) * 0.5;
  col += particles * float3(0.5, 0.8, 1.0);
  col += exp(-d * 4.0) * float3(0.2, 0.4, 0.8) * 0.5;
  col += exp(-mouseDist * 8.0) * float3(0.5, 0.7, 1.0) * 0.2;

  return float4(col, 1.0);
}
