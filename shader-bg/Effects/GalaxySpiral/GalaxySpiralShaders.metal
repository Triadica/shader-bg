//
//  GalaxySpiralShaders.metal
//  shader-bg
//
//  Created on 2025-11-04.
//  Galaxy Spiral morphology effect
//  Based on shader by S.Guillitte
//  License: Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported
//  License
//  Forked from https://www.shadertoy.com/view/llSGR1

#include <metal_stdlib>
using namespace metal;

struct GalaxySpiralParams {
  float time;
  float2 resolution;
  float padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 texCoord;
};

constant float pi = 3.141592;
constant float2x2 m2 = float2x2(0.8, 0.6, -0.6, 0.8);

// Vertex shader for full-screen triangle
vertex VertexOut galaxySpiralVertex(uint vertexID [[vertex_id]]) {
  VertexOut out;
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.texCoord = positions[vertexID] * 0.5 + 0.5;
  return out;
}

// Noise function
float noise(float2 p) {
  float res = 0.0;
  float f = 2.0;
  for (int i = 0; i < 4; i++) {
    p = m2 * p * f + 0.6;
    f *= 1.0;
    res += sin(p.x + sin(2.0 * p.y));
  }
  return res / 4.0;
}

// FBM absolute value
float fbmabs(float2 p) {
  float f = 1.0;
  float r = 0.0;
  for (int i = 0; i < 8; i++) {
    r += abs(noise(p * f)) / f;
    f *= 2.0;
    p -= float2(-0.01, 0.08) * r;
  }
  return r;
}

// FBM stars
float fbmstars(float2 p) {
  p = floor(p * 50.0) / 50.0;

  float f = 1.0;
  float r = 0.0;
  for (int i = 1; i < 5; i++) {
    r += noise(p * (20.0 + 3.0 * f)) / f;
    p *= m2;
    f += 1.0;
  }
  return pow(r, 8.0);
}

// FBM disk
float fbmdisk(float2 p) {
  float f = 1.0;
  float r = 0.0;
  for (int i = 1; i < 7; i++) {
    r += abs(noise(p * f)) / f;
    f += 1.0;
  }
  return 1.0 / r;
}

// FBM dust
float fbmdust(float2 p) {
  float f = 1.0;
  float r = 0.0;
  for (int i = 1; i < 7; i++) {
    r += 1.0 / abs(noise(p * f)) / f;
    f += 1.0;
  }
  return pow(1.0 - 1.0 / r, 4.0);
}

// Theta function for spiral arm
float theta(float r, float wb, float wn) {
  return atan(exp(1.0 / r) / wb) * 2.0 * wn;
}

// Spiral arm function
float arm(float n, float aw, float wb, float wn, float2 p) {
  float t = atan2(p.y, p.x);
  float r = length(p);
  return pow(1.0 - 0.15 * sin((theta(r, wb, wn) - t) * n), aw) * exp(-r * r) *
         exp(-0.07 / r);
}

// Galaxy bulb (center)
float bulb(float2 p) {
  float r = exp(-dot(p, p) * 1.2);
  p.y -= 0.2;
  return r + 0.5 * exp(-dot(p, p) * 12.0);
}

// Main galaxy map function
float galaxyMap(float2 p, float2 m) {
  float a = arm(m.x, 6.0, 0.7, m.y, p);
  float d = fbmdust(p);
  float r = max(a * (0.4 + 0.1 * arm(m.x + 1.0, 4.0, 0.7, m.y, p * m2)) *
                    (0.1 + 0.6 * d + 0.4 * fbmdisk(p)),
                bulb(p) * (0.7 + 0.2 * d + 0.2 * fbmabs(p)));
  return max(r, a * fbmstars(p * 4.0));
}

// Rotation function
float2 rotate(float2 p, float t) {
  return p * cos(-t) + float2(p.y, -p.x) * sin(-t);
}

fragment float4 galaxySpiralFragment(VertexOut in [[stage_in]],
                                     constant GalaxySpiralParams &params
                                     [[buffer(0)]]) {
  float2 iResolution = params.resolution;
  float2 fragCoord = in.texCoord * iResolution;

  float2 p = 2.0 * fragCoord.xy / iResolution.xy - 1.0;
  p *= 2.0;

  // Rotate the galaxy
  p = rotate(p, -0.02 * params.time);

  // Galaxy parameters
  float2 m = float2(2.0, 6.0);
  m.y *= 2.0;

  float k = 1.5 * galaxyMap(p, m);
  float b = 0.3 * galaxyMap(p * m2, m) + 0.4;
  float r = 0.2;

  float4 color =
      clamp(float4(r * k * k, r * k, k * 0.5 + b * 0.4, 1.0), 0.0, 1.0);
  return color;
}
