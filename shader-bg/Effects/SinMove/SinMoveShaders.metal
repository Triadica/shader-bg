//
//  SinMoveShaders.metal
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/16.
//  Based on Shadertoy sin wave effect
//  License: Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported
//  Forked from https://www.shadertoy.com/view/Wt2GDz

#include <metal_stdlib>
using namespace metal;

struct SinMoveData {
  float time;
  float2 resolution;
  float4 mouse;
  float padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

// 顶点着色器 - 全屏三角形
vertex VertexOut sinMove_vertex(uint vertexID [[vertex_id]]) {
  float2 positions[3] = {float2(-1, -1), float2(3, -1), float2(-1, 3)};

  VertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = positions[vertexID];
  return out;
}

// Smoothstep helper
float sinMove_SS(float l, float s, float SF) {
  return smoothstep(SF, -SF, l - s);
}

// 片段着色器
fragment float4 sinMove_fragment(VertexOut in [[stage_in]],
                                 constant SinMoveData &params [[buffer(0)]]) {
  float2 fragCoord = (in.uv * 0.5 + 0.5) * params.resolution;
  float2 iResolution = params.resolution;
  float iTime = params.time;

  // #define SF 1./min(iResolution.x,iResolution.y)
  float SF = 1.0 / min(iResolution.x, iResolution.y);

  // #define BLACK_COL vec3(16,21,25)/255.
  float3 BLACK_COL = float3(16.0, 21.0, 25.0) / 255.0;

  // vec2 uv = (fragCoord - iResolution.xy*.5)/iResolution.y;
  float2 uv = (fragCoord - iResolution * 0.5) / iResolution.y;

  float m = 0.0;
  float t = iTime * 2.0;

  // for(float i = 0.; i< 30.;i+=1.)
  for (float i = 0.0; i < 30.0; i += 1.0) {
    // float sv = sin(uv.x*10. + cos(t+i*.4))*.1;
    float sv = sin(uv.x * 10.0 + cos(t + i * 0.4)) * 0.1;

    // float y = uv.y + i*.025 - .15;
    float y = uv.y + i * 0.025 - 0.15;

    // m += (SS(y, sv) - SS(y + .001 * (0. + i*.5), sv)*.975)*(.75+i*.01) ;
    float ss1 = sinMove_SS(y, sv, SF);
    float ss2 = sinMove_SS(y + 0.001 * (0.0 + i * 0.5), sv, SF);
    m += (ss1 - ss2 * 0.975) * (0.75 + i * 0.01);
  }

  // vec3 col = mix(BLACK_COL, (0.5 + 0.5*cos(iTime+uv.xyx+vec3(0,2,4))), m);
  float3 colorPattern =
      0.5 + 0.5 * cos(iTime + float3(uv.x, uv.y, uv.x) + float3(0.0, 2.0, 4.0));
  float3 col = mix(BLACK_COL, colorPattern, m);

  return float4(col, 1.0);
}
