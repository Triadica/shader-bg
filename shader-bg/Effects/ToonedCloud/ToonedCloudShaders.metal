//
//  ToonedCloudShaders.metal
//  shader-bg
//
//  Created on 2025-11-03.
//  Based on "Toon Cloud" by Antoine Clappier - March 2015
//  Licensed under: CC BY-NC-SA 4.0
//  Forked from https://www.shadertoy.com/view/4t23RR

#include <metal_stdlib>
using namespace metal;

#define TAU 6.28318530718

struct ToonedCloudParams {
  float time;
  float2 resolution;
  float padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 texCoord;
};

constant float3 BackColor = float3(0.0, 0.4, 0.58);
constant float3 CloudColor = float3(0.18, 0.70, 0.87);

// Vertex shader for full-screen triangle
vertex VertexOut toonedCloudVertex(uint vertexID [[vertex_id]]) {
  VertexOut out;
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.texCoord = positions[vertexID] * 0.5 + 0.5;
  return out;
}

float Func(float pX) {
  return 0.6 *
         (0.5 * sin(0.1 * pX) + 0.5 * sin(0.553 * pX) + 0.7 * sin(1.2 * pX));
}

float FuncR(float pX) { return 0.5 + 0.25 * (1.0 + sin(fmod(40.0 * pX, TAU))); }

float Layer(float2 pQ, float pT) {
  float2 Qt = 3.5 * pQ;
  pT *= 0.5;
  Qt.x += pT;

  float Xi = floor(Qt.x);
  float Xf = Qt.x - Xi - 0.5;

  float2 C;
  float Yi;
  float D = 1.0 - step(Qt.y, Func(Qt.x));

  // Disk:
  Yi = Func(Xi + 0.5);
  C = float2(Xf, Qt.y - Yi);
  D = min(D, length(C) - FuncR(Xi + pT / 80.0));

  // Previous disk:
  Yi = Func(Xi + 1.0 + 0.5);
  C = float2(Xf - 1.0, Qt.y - Yi);
  D = min(D, length(C) - FuncR(Xi + 1.0 + pT / 80.0));

  // Next Disk:
  Yi = Func(Xi - 1.0 + 0.5);
  C = float2(Xf + 1.0, Qt.y - Yi);
  D = min(D, length(C) - FuncR(Xi - 1.0 + pT / 80.0));

  return min(1.0, D);
}

fragment float4 toonedCloudFragment(VertexOut in [[stage_in]],
                                    constant ToonedCloudParams &params
                                    [[buffer(0)]]) {
  float2 iResolution = params.resolution;
  float2 fragCoord = in.texCoord * iResolution;
  // 不翻转 Y 坐标，保持云朵正确的方向

  // Setup:
  float2 UV = 2.0 * (fragCoord.xy - iResolution.xy / 2.0) /
              min(iResolution.x, iResolution.y);

  // Render:
  float3 Color = BackColor;

  for (float J = 0.0; J <= 1.0; J += 0.2) {
    // Cloud Layer:
    float Lt =
        params.time * (0.5 + 2.0 * J) * (1.0 + 0.1 * sin(226.0 * J)) + 17.0 * J;
    float2 Lp = float2(0.0, 0.3 + 1.5 * (J - 0.5));
    float L = Layer(UV + Lp, Lt);

    // Blur and color:
    float Blur = 4.0 * (0.5 * abs(2.0 - 5.0 * J)) / (11.0 - 5.0 * J);

    float V = mix(0.0, 1.0, 1.0 - smoothstep(0.0, 0.01 + 0.2 * Blur, L));
    float3 Lc = mix(CloudColor, float3(1.0), J);

    Color = mix(Color, Lc, V);
  }

  return float4(Color, 1.0);
}
