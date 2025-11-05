//
//  RedBlueSwirlShaders.metal
//  shader-bg
//
//  Created on 2025-11-06.
//
//  Based on: https://www.shadertoy.com/view/MtKBRd
//  License: CC BY-NC-SA 4.0

#include <metal_stdlib>
using namespace metal;

struct RedBlueSwirlParams {
  float time;
  float2 resolution;
  int padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 texCoord;
};

// Vertex shader - 全屏三角形
vertex VertexOut redBlueSwirlVertex(uint vertexID [[vertex_id]]) {
  VertexOut out;

  // 创建覆盖整个屏幕的大三角形
  float2 pos = float2((vertexID << 1) & 2, vertexID & 2);
  out.position = float4(pos * 2.0 - 1.0, 0.0, 1.0);
  out.texCoord = pos;

  return out;
}

// Helper function: C(U) = cos(cos(U*i + t) + cos(U.yx*i) + (o.x + t)*i*i)/i/9.
static float2 rbsC(float2 U, float i, float t, float oX) {
  float2 result;
  result.x = cos(cos(U.x * i + t) + cos(U.y * i) + (oX + t) * i * i) / i / 9.0;
  result.y = cos(cos(U.y * i + t) + cos(U.x * i) + (oX + t) * i * i) / i / 9.0;
  return result;
}

// Fragment shader
fragment float4 redBlueSwirlFragment(VertexOut in [[stage_in]],
                                     constant RedBlueSwirlParams &params
                                     [[buffer(0)]]) {
  float2 fragCoord = in.texCoord * params.resolution;
  float2 iResolution = params.resolution;
  float iTime = params.time;

  // 初始化
  float2 u = 4.0 * (fragCoord + fragCoord - iResolution) / iResolution.y;
  float4 o = float4(iResolution, 0.0, 0.0);

  float t, i, d = dot(u, u);
  u /= 1.0 + 0.013 * d;

  o = float4(0.1, 0.4, 0.6, 0.0);

  // 主循环（从 19 降低到 9 以减少 GPU 消耗）
  for (i = 1.0; i < 9.0; i += 1.0) {
    t = iTime / 2.0 / i;

    // u += C(u) + C(u.yx)
    u += rbsC(u, i, t, o.x) + rbsC(u.yx, i, t, o.x);

    // 旋转矩阵
    float angle = i + length(u) * 0.3 / i - t / 2.0;
    float2x2 rot = float2x2(cos(angle), -sin(angle), sin(angle), cos(angle));
    u = 1.17 * (rot * u);

    // 累积颜色
    o += cos(u.x + i + o.y * 9.0 + t) / 4.0 / i;
  }

  // 最终颜色处理
  o = 1.0 + cos(o * 3.0 + float4(8.0, 2.0, 1.8, 0.0));
  o = 1.1 - exp(-1.3 * o * sqrt(o)) + d * min(0.02, 4e-6 / exp(0.2 * u.y));

  return float4(o.xyz, 1.0);
}
