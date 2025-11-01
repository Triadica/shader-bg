//
//  RainbowTwisterShaders.metal
//  shader-bg
//
//  Created on 2025-11-01.
//
//  Adapted from ShaderToy "Rainbow Twister"
//  Original GLSL shader with anti-aliasing version (239 chars)
//  Forked from https://www.shadertoy.com/view/XsSfW1

#include <metal_stdlib>
using namespace metal;

struct RainbowTwisterParams {
  float2 resolution;
  float time;
  float padding;
};

struct RainbowTwisterVertexOut {
  float4 position [[position]];
  float2 uv;
};

vertex RainbowTwisterVertexOut rainbowTwisterVertex(uint vertexID
                                                    [[vertex_id]]) {
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};

  RainbowTwisterVertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = positions[vertexID] * 0.5 + 0.5;
  return out;
}

fragment float4 rainbowTwisterFragment(RainbowTwisterVertexOut in [[stage_in]],
                                       constant RainbowTwisterParams &params
                                       [[buffer(0)]]) {
  float2 r = params.resolution;
  float2 o = in.uv * r;

  // Center and convert to polar-ish coordinates
  o -= r / 2.0;

  // 计算到中心的归一化距离
  float distFromCenter = length(o) / r.y;

  // 缩小图案: 增大距离值使图案缩小
  float2 polar = float2(distFromCenter / 0.6 - 0.3, atan2(o.y, o.x));

  // 减慢时间到 0.075 倍速度 (原来的 0.3 再除以 4)
  float slowTime = params.time * 0.075;

  // Create rainbow spiral pattern (原始彩色版本)
  float4 s = 0.1 * cos(1.6 * float4(0, 1, 2, 3) + slowTime + polar.y +
                       sin(polar.y) * sin(slowTime) * 1.0);
  float4 c = s.yzwx;

  // Calculate distance fields with anti-aliasing
  float4 f = min(polar.x - s, c - polar.x);

  // Anti-aliased rendering (原始算法)
  float4 aa = clamp(f * r.y, 0.0, 1.0);
  c = dot(40.0 * (s - c), aa) * (s - 0.1) - f;

  // 确保颜色非负
  c = max(c, float4(0.0));

  // 添加距离遮罩: 圆环外围逐渐变黑
  // 在距离 0.5 之前完全显示圆环颜色
  // 从 0.5 到 0.7 之间逐渐过渡到黑色
  float fadeMask = smoothstep(0.5, 0.2, distFromCenter);

  // 应用遮罩,让远处区域变黑
  c *= fadeMask;

  // 返回最终颜色
  return c;
}
