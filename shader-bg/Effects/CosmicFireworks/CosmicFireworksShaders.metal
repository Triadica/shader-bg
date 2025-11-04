//
//  CosmicFireworksShaders.metal
//  shader-bg
//
//  Created on 2025-11-05.
//  Cosmic Fireworks fractal effect with particle bursts
//

#include <metal_stdlib>
using namespace metal;

struct CosmicFireworksParams {
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
vertex VertexOut cosmicFireworksVertex(uint vertexID [[vertex_id]]) {
  VertexOut out;
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.texCoord = positions[vertexID] * 0.5 + 0.5;
  return out;
}

// Noise function (static to avoid symbol conflicts)
static float cfNoise(float2 p) {
  return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

// Smooth noise
static float cfSmoothNoise(float2 p) {
  float2 i = floor(p);
  float2 f = fract(p);
  float2 u = f * f * (3.0 - 2.0 * f);
  return mix(
      mix(cfNoise(i + float2(0.0, 0.0)), cfNoise(i + float2(1.0, 0.0)), u.x),
      mix(cfNoise(i + float2(0.0, 1.0)), cfNoise(i + float2(1.0, 1.0)), u.x),
      u.y);
}

// Distance field
static float cfDistanceField(float2 p, float time) {
  return length(p) - 0.5 + 0.3 * sin(time * 0.5);
}

// Rotation function
static float2 cfRotate(float2 p, float angle) {
  float s = sin(angle);
  float c = cos(angle);
  return float2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// Fractal function
static float3 cfFractal(float2 p, float2 mouse, float time) {
  float2 uv = cfRotate(p - mouse, time * 0.1);
  float t = time * 0.5;
  float3 col = float3(0.0);
  float scale = 1.0;

  for (int i = 0; i < 5; i++) {
    uv = abs(uv) / dot(uv, uv) - 0.6;
    uv = uv * 1.5 + float2(sin(t), cos(t)) * 0.2;
    float d = length(uv) * scale;
    float n = cfSmoothNoise(uv * 2.0);
    float3 color = mix(float3(0.8, 0.2, 0.1), float3(1.0, 0.7, 0.2), n);
    col += n * exp(-d * 0.5) * color;
    scale *= 0.5;
  }

  float df = cfDistanceField(uv, time);
  col *= 1.0 / (1.0 + df * df * 2.0);

  // Sparkle effect
  float sparkle = cfSmoothNoise(uv * 10.0 + time * 2.0);
  if (sparkle > 0.95) {
    col += float3(1.0, 0.9, 0.7) * (sparkle - 0.95) * 20.0;
  }

  return col * 0.5;
}

// Particle burst effect
static float3 cfParticleBurst(float2 uv, float2 mouse, float time) {
  float2 dir = uv - mouse;
  float dist = length(dir);
  float intensity =
      dist < 0.5 ? 0.5 * exp(-dist * 10.0) * sin(time * 5.0 + dist * 20.0)
                 : 0.0;
  return float3(1.0, 0.8, 0.5) * intensity;
}

// Nebula background
static float3 cfNebula(float2 uv, float time) {
  float n = cfSmoothNoise(uv * 0.1 + time * 0.05);
  return float3(0.1, 0.2, 0.3) * n * 0.3;
}

fragment float4 cosmicFireworksFragment(VertexOut in [[stage_in]],
                                        constant CosmicFireworksParams &params
                                        [[buffer(0)]]) {
  float2 iResolution = params.resolution;
  float2 fragCoord = in.texCoord * iResolution;

  float2 uv = fragCoord.xy / iResolution.xy;
  uv = uv * 2.0 - 1.0;
  uv.x *= iResolution.x / iResolution.y;

  float2 mouse = params.mouse / iResolution.xy * 2.0 - 1.0;
  mouse.x *= iResolution.x / iResolution.y;

  // Combine effects
  float3 col = cfNebula(uv, params.time);
  col += cfFractal(uv, mouse, params.time);
  col += cfParticleBurst(uv, mouse, params.time);

  // Dynamic glow color
  float3 glowColor = mix(
      mix(float3(0.8, 0.2, 0.1), float3(1.0, 0.7, 0.2), sin(params.time * 2.0)),
      mix(float3(0.5, 0.1, 0.8), float3(0.2, 0.7, 1.0), cos(params.time * 1.5)),
      0.5 + 0.5 * sin(params.time * 0.5));
  col += 0.3 * glowColor * sin(length(uv) * 5.0 - params.time * 2.0);

  return float4(col, 1.0);
}
