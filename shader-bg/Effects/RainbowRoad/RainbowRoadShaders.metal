//
//  RainbowRoadShaders.metal
//  shader-bg
//
//  Rainbow Road effect by @XorDev
//  Ported to Metal for macOS
//  Forked from https://www.shadertoy.com/view/NlGfzz

#include <metal_stdlib>
using namespace metal;

struct RainbowRoadParams {
  float time;
  float2 resolution;
  int padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

vertex VertexOut rainbowRoadVertex(uint vertexID [[vertex_id]]) {
  // 全屏三角形
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};

  VertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = positions[vertexID] * 0.5 + 0.5;
  return out;
}

fragment float4 rainbowRoadFragment(VertexOut in [[stage_in]],
                                    constant RainbowRoadParams &params
                                    [[buffer(0)]]) {
  // Fragment coordinates
  float2 fragCoord = in.uv * params.resolution;
  // Flip Y coordinate to match shadertoy convention (origin at bottom-left)
  fragCoord.y = params.resolution.y - fragCoord.y;

  // Resolution for scaling
  float2 r = params.resolution;
  float2 o;

  // Clear fragcolor
  float4 O = float4(0.0);

  // Render 30 lightbars (reduced from 50 for performance)
  // i += 0.8 instead of 0.5 to reduce iterations
  for (float i = fract(-params.time); i < 15.0; i += 0.6) {
    // Offset coordinates (center of bar)
    o = (fragCoord + fragCoord - r) / r.y * i +
        cos(i * float2(0.8, 0.5) + params.time);

    // Calculate distance to line segment
    // Note: (4.0 - i) makes bars move from top to bottom
    float2 linePoint =
        float2(clamp(o.x, -4.0, 4.0), (4.0 - i) + o.y * sin(i) * 0.1);
    float dist = length(o - linePoint) / i;

    // Light color (rainbow based on iteration)
    float4 color =
        (cos(i + float4(0.0, 2.0, 4.0, 0.0)) + 1.0) / max(i * i, 5.0) * 0.1;

    // Attenuation
    O += color / (i / 1000.0 + dist);
  }

  return O;
}
